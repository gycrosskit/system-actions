package io.github.gycrosskit.systemactions

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.Locale

/** Android Intent 动作实现，自动切主线程。@param context 宿主 Context；非 Activity 时追加 NEW_TASK。 */
class AndroidSystemActions(private val context: Context) : SystemActions {
    override suspend fun dial(phone: String): ActionResult {
        val normalized = normalizedPhone(phone) ?: return ActionResult.InvalidInput
        return launch(Intent(Intent.ACTION_DIAL, Uri.fromParts("tel", normalized, null)))
    }
    override suspend fun openExternalUrl(url: String): ActionResult {
        val normalized = normalizedWebUrl(url) ?: return ActionResult.InvalidInput
        return launch(Intent(Intent.ACTION_VIEW, Uri.parse(normalized)))
    }
    override suspend fun openAppSettings(): ActionResult = launch(
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null))
    )
    override suspend fun openLocationSettings(): ActionResult = launch(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS))

    override suspend fun openNativeAppStore(applicationId: String?): ActionResult {
        val appId = applicationId?.trim() ?: context.packageName
        if (appId.length > 255 || !APP_ID.matches(appId)) return ActionResult.InvalidInput
        return withContext(Dispatchers.Main.immediate) {
            val targets = storeTargets(appId, Build.MANUFACTURER.trim().lowercase(Locale.ROOT))
            for (target in targets) {
                for (uri in target.uris) {
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uri)).setPackage(target.packageName)
                    // 只接受固定商店包名，不能让其他注册相同 scheme 的应用替代详情页。
                    val resolved = try { intent.resolveActivity(context.packageManager) } catch (_: RuntimeException) { null }
                    if (resolved?.packageName == target.packageName && launch(intent) == ActionResult.Requested) {
                        return@withContext ActionResult.Requested
                    }
                }
            }
            ActionResult.Unavailable
        }
    }

    private fun storeTargets(appId: String, manufacturer: String): List<StoreTarget> {
        val market = "market://details?id=$appId"
        val builtIn = when (manufacturer) {
            "huawei" -> listOf(StoreTarget("com.huawei.appmarket", listOf("appmarket://details?id=$appId", market)))
            "honor" -> listOf(
                StoreTarget("com.hihonor.appmarket", listOf("appmarket://details?id=$appId", market)),
                StoreTarget("com.huawei.appmarket", listOf("appmarket://details?id=$appId", market)),
            )
            "xiaomi", "redmi" -> listOf(StoreTarget("com.xiaomi.market", listOf("mimarket://details?id=$appId", market)))
            "oppo", "oneplus", "realme" -> listOf(
                StoreTarget("com.heytap.market", listOf("oppomarket://details?packagename=$appId", market)),
                StoreTarget("com.oppo.market", listOf("oppomarket://details?packagename=$appId", market)),
            )
            "vivo" -> listOf(StoreTarget("com.bbk.appstore", listOf("vivomarket://details?id=$appId", market)))
            "meizu" -> listOf(StoreTarget("com.meizu.mstore", listOf(market)))
            "samsung" -> listOf(StoreTarget("com.sec.android.app.samsungapps", listOf("samsungapps://ProductDetail/$appId", market)))
            else -> emptyList()
        }
        return builtIn + listOf(
            StoreTarget("com.tencent.android.qqdownloader", listOf("tmast://appdetails?packagename=$appId", market)),
            StoreTarget("com.qihoo.appstore", listOf(market)),
            StoreTarget("com.baidu.appsearch", listOf(market)),
            StoreTarget("com.android.vending", listOf(market)),
        )
    }

    private data class StoreTarget(val packageName: String, val uris: List<String>)

    private companion object {
        val APP_ID = Regex("[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z][A-Za-z0-9_]*)+")
    }

    private suspend fun launch(intent: Intent): ActionResult = withContext(Dispatchers.Main.immediate) {
        try {
            if (context !is Activity) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            ActionResult.Requested
        } catch (_: RuntimeException) { ActionResult.Unavailable }
    }
}
