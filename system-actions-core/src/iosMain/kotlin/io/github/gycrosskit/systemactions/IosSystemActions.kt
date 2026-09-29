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
    val port = parts.port?.intValue
    return !parts.host.isNullOrEmpty() && parts.user == null && parts.password == null &&
        (port == null || port in 1..65535) && parts.URL != null
}

@OptIn(ExperimentalForeignApi::class)
class IosSystemActions : SystemActions {
    override suspend fun dial(phone: String): ActionResult {
        val normalized = normalizedPhone(phone) ?: return ActionResult.InvalidInput
        return open("tel:$normalized")
    }
    override suspend fun openExternalUrl(url: String): ActionResult {
        val normalized = normalizedWebUrl(url) ?: return ActionResult.InvalidInput
        return open(normalized)
    }
    override suspend fun openAppSettings(): ActionResult = open(UIApplicationOpenSettingsURLString)
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
