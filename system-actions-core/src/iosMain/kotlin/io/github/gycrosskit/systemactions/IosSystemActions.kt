package io.github.gycrosskit.systemactions

import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import platform.Foundation.NSURL
import platform.Foundation.NSURLComponents
import platform.UIKit.UIApplication
import platform.UIKit.UIApplicationOpenSettingsURLString
import kotlin.coroutines.resume

@OptIn(ExperimentalForeignApi::class)
internal actual fun hasValidWebAuthority(value: String): Boolean {
    val parts = NSURLComponents.componentsWithString(value) ?: return false
    val port = parts.port
    return !parts.host.isNullOrEmpty() && parts.user == null && parts.password == null &&
        (port == null || port.stringValue.toIntOrNull()?.let { it in 1..65535 } == true) && parts.URL != null
}

/**
 * iOS 系统服务，自动切主线程；按系统 openURL completion 返回受理状态。
 * @param fileActions 宿主持有的文件服务；分享须解析当前 presenter，宿主生命周期结束时调用其 close。
 * 默认文件服务仅可复制文本，分享返回 Unavailable；不猜测业务根控制器或复制窗口 owner。
 */
@OptIn(ExperimentalForeignApi::class)
class IosSystemActions(private val fileActions: IosFileActions) : SystemActions {
    constructor() : this(IosFileActions { null })

    override suspend fun copyText(value: String): ActionResult = withContext(Dispatchers.Main.immediate) {
        fileActions.copyText(value)
    }

    override suspend fun shareFile(path: String, title: String): ActionResult {
        if (!isValidSharePath(path)) return ActionResult.InvalidInput
        return withContext(Dispatchers.Main.immediate) {
            fileActions.shareFile(path, title) {}
        }
    }

    override suspend fun dial(phone: String): ActionResult {
        val normalized = normalizedPhone(phone) ?: return ActionResult.InvalidInput
        return open("tel:$normalized")
    }
    override suspend fun openExternalUrl(url: String): ActionResult {
        val normalized = normalizedWebUrl(url) ?: return ActionResult.InvalidInput
        return open(normalized)
    }
    override suspend fun openAppSettings(): ActionResult = open(UIApplicationOpenSettingsURLString)
    override suspend fun openNativeAppStore(applicationId: String?): ActionResult = ActionResult.Unavailable
    private suspend fun open(value: String): ActionResult = withContext(Dispatchers.Main.immediate) {
        val url = NSURL.URLWithString(value) ?: return@withContext ActionResult.InvalidInput
        suspendCancellableCoroutine { pending ->
            if (pending.isActive) {
                UIApplication.sharedApplication.openURL(url, emptyMap<Any?, Any>()) { accepted ->
                    if (pending.isActive) pending.resume(if (accepted) ActionResult.Requested else ActionResult.Unavailable)
                }
            }
        }
    }
}
