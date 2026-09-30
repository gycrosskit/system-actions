package io.github.gycrosskit.systemactions

import android.content.ActivityNotFoundException
import android.content.ContextWrapper
import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.pm.ApplicationInfo
import android.content.pm.ResolveInfo
import android.net.Uri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowBuild
import kotlin.test.assertEquals
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class AndroidNativeStoreTest {
    private val application = RuntimeEnvironment.getApplication()
    private val launched = mutableListOf<Intent>()
    private var reject: (Intent) -> Boolean = { false }
    private val context = object : ContextWrapper(application) {
        override fun startActivity(intent: Intent) {
            launched += intent
            if (reject(intent)) throw ActivityNotFoundException()
        }
    }

    private fun resolve(packageName: String, uri: String, resolvedPackage: String = packageName) {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uri)).setPackage(packageName)
        val resolution = ResolveInfo().apply {
            activityInfo = ActivityInfo().apply {
                this.packageName = resolvedPackage
                name = "$resolvedPackage.StoreActivity"
                // 未提供 ApplicationInfo 时 Robolectric 会按 Intent.package 填充，掩盖异包测试。
                applicationInfo = ApplicationInfo().apply { this.packageName = resolvedPackage }
            }
        }
        shadowOf(application.packageManager).addResolveInfoForIntent(intent, resolution)
    }

    @Test fun manufacturerAndPackageSelectTheNativeStoreBeforeThirdParty() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try {
            val expected = listOf(
                Triple(" HUAWEI ", "com.huawei.appmarket", "appmarket://details?id=test.brand"),
                Triple("HONOR", "com.hihonor.appmarket", "appmarket://details?id=test.brand"),
                Triple("Xiaomi", "com.xiaomi.market", "mimarket://details?id=test.brand"),
                Triple("Redmi", "com.xiaomi.market", "mimarket://details?id=test.brand"),
                Triple("OPPO", "com.heytap.market", "oppomarket://details?packagename=test.brand"),
                Triple("OnePlus", "com.heytap.market", "oppomarket://details?packagename=test.brand"),
                Triple("realme", "com.heytap.market", "oppomarket://details?packagename=test.brand"),
                Triple("vivo", "com.bbk.appstore", "vivomarket://details?id=test.brand"),
                Triple("Meizu", "com.meizu.mstore", "market://details?id=test.brand"),
                Triple("samsung", "com.sec.android.app.samsungapps", "samsungapps://ProductDetail/test.brand"),
            )
            resolve("com.tencent.android.qqdownloader", "tmast://appdetails?packagename=test.brand")
            for ((manufacturer, packageName, uri) in expected) {
                ShadowBuild.setManufacturer(manufacturer)
                resolve(packageName, uri)
                launched.clear()
                assertEquals(ActionResult.Requested, AndroidSystemActions(context).openNativeAppStore("test.brand"))
                assertEquals(packageName, launched.single().`package`, manufacturer)
                assertEquals(uri, launched.single().dataString)
                assertTrue(launched.single().flags and Intent.FLAG_ACTIVITY_NEW_TASK != 0)
            }
            // 名称包含厂商单词不能冒充该厂商。
            ShadowBuild.setManufacturer("not-huawei")
            launched.clear()
            assertEquals(ActionResult.Requested, AndroidSystemActions(context).openNativeAppStore("test.brand"))
            assertEquals("com.tencent.android.qqdownloader", launched.single().`package`)
        } finally { Dispatchers.resetMain() }
    }

    @Test fun triesAlternateUriThenFallbackStoreOnlyAfterActualRejection() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try {
            ShadowBuild.setManufacturer("honor")
            resolve("com.hihonor.appmarket", "appmarket://details?id=test.brand")
            resolve("com.hihonor.appmarket", "market://details?id=test.brand")
            resolve("com.huawei.appmarket", "appmarket://details?id=test.brand")
            reject = { it.`package` == "com.hihonor.appmarket" }
            assertEquals(ActionResult.Requested, AndroidSystemActions(context).openNativeAppStore("test.brand"))
            assertEquals(listOf("appmarket", "market", "appmarket"), launched.map { it.data?.scheme })
            assertEquals("com.huawei.appmarket", launched.last().`package`)
        } finally { Dispatchers.resetMain() }
    }

    @Test fun defaultAppIdAndOrderedFallbackAreKeptWithoutImplicitMarketIntent() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try {
            ShadowBuild.setManufacturer("unknown")
            val appId = context.packageName
            resolve("com.tencent.android.qqdownloader", "tmast://appdetails?packagename=$appId")
            resolve("com.tencent.android.qqdownloader", "market://details?id=$appId")
            resolve("com.qihoo.appstore", "market://details?id=$appId")
            resolve("com.baidu.appsearch", "market://details?id=$appId")
            resolve("com.android.vending", "market://details?id=$appId")
            reject = { it.`package` != "com.android.vending" }
            assertEquals(ActionResult.Requested, AndroidSystemActions(context).openNativeAppStore())
            assertEquals(listOf("com.tencent.android.qqdownloader", "com.tencent.android.qqdownloader", "com.qihoo.appstore", "com.baidu.appsearch", "com.android.vending"), launched.map { it.`package` })
            assertTrue(launched.all { it.dataString?.contains(appId) == true })
            reject = { true }
            assertEquals(ActionResult.Unavailable, AndroidSystemActions(context).openNativeAppStore())
        } finally { Dispatchers.resetMain() }
    }

    @Test fun rejectsUriInjectionMissingStoreAndDifferentResolvingPackage() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try {
            ShadowBuild.setManufacturer("huawei")
            val actions = AndroidSystemActions(context)
            for (id in listOf("", "test", "test.brand&x=evil", "test.brand/path", "market://details", "a." + "b".repeat(254))) {
                assertEquals(ActionResult.InvalidInput, actions.openNativeAppStore(id))
            }
            assertTrue(launched.isEmpty())
            assertEquals(ActionResult.Unavailable, actions.openNativeAppStore("test.brand"))
            resolve("com.huawei.appmarket", "appmarket://details?id=test.brand", "evil.store")
            assertEquals(ActionResult.Unavailable, actions.openNativeAppStore("test.brand"))
            assertTrue(launched.isEmpty())
        } finally { Dispatchers.resetMain() }
    }
}
