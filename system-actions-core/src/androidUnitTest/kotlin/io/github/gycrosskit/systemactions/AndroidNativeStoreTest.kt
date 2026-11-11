package io.github.gycrosskit.systemactions

import android.content.ActivityNotFoundException
import android.content.ContextWrapper
import android.content.Intent
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
            for ((manufacturer, packageName, uri) in expected) {
                ShadowBuild.setManufacturer(manufacturer)
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
            reject = { it.`package` != "com.android.vending" }
            assertEquals(ActionResult.Requested, AndroidSystemActions(context).openNativeAppStore())
            assertEquals(listOf("com.tencent.android.qqdownloader", "com.tencent.android.qqdownloader", "com.qihoo.appstore", "com.baidu.appsearch", "com.android.vending"), launched.map { it.`package` })
            assertTrue(launched.all { it.dataString?.contains(appId) == true })
            reject = { true }
            assertEquals(ActionResult.Unavailable, AndroidSystemActions(context).openNativeAppStore())
        } finally { Dispatchers.resetMain() }
    }

    @Test fun validatesAppIdAndLaunchesWithoutPackageVisibility() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try {
            ShadowBuild.setManufacturer("huawei")
            val actions = AndroidSystemActions(context)
            for (id in listOf("", "test", "test.brand&x=evil", "test.brand/path", "market://details", "a." + "b".repeat(254))) {
                assertEquals(ActionResult.InvalidInput, actions.openNativeAppStore(id))
            }
            assertTrue(launched.isEmpty())
            assertEquals(ActionResult.Requested, actions.openNativeAppStore("test.brand"))
            assertEquals("com.huawei.appmarket", launched.single().`package`)
            reject = { true }
            assertEquals(ActionResult.Unavailable, actions.openNativeAppStore("test.brand"))
        } finally { Dispatchers.resetMain() }
    }
    @Test fun hostSelectedMarketIsPackageBoundValidatedAndDoesNotProbeVisibility() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try {
            val actions = AndroidSystemActions(context)
            for (url in listOf("intent://details?id=x", "file://details/x", "content://details/x",
                "javascript://details/x", "data://details/x", "market://user@details/x", "market://details/%GG",
                "market://details/a b", "market://details/x#Intent;end", "market://details/\u0000")) {
                assertEquals(ActionResult.InvalidInput, actions.openMarketDetails("com.host.market", url), url)
            }
            assertEquals(ActionResult.InvalidInput, actions.openMarketDetails("invalid", "market://details?id=x"))
            assertTrue(launched.isEmpty())
            assertEquals(ActionResult.Requested, actions.openMarketDetails("com.host.market", "newmarket://details?id=host.app"))
            assertEquals("com.host.market", launched.single().`package`)
            assertEquals("newmarket://details?id=host.app", launched.single().dataString)
            reject = { true }
            assertEquals(ActionResult.Unavailable, actions.openMarketDetails("com.host.market", "market://details?id=x"))
            reject = { throw kotlinx.coroutines.CancellationException() }
            kotlin.test.assertFailsWith<kotlinx.coroutines.CancellationException> {
                actions.openMarketDetails("com.host.market", "market://details?id=x")
            }
        } finally { Dispatchers.resetMain() }
    }

}
