package io.github.gycrosskit.systemactions.kuikly

import com.tencent.kuikly.core.module.CallbackRef
import com.tencent.kuikly.core.module.Module
import com.tencent.kuikly.core.nvi.serialization.json.JSONObject
import io.github.gycrosskit.systemactions.ActionResult
import io.github.gycrosskit.systemactions.SystemActions
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.coroutines.resume

/** 每个页面持有一个实例，在 Kuikly 页面协程上下文调用，并在页面销毁时 [dispose]。 */
class SystemActionsModule : Module(), SystemActions {
    private class Pending(val continuation: CancellableContinuation<ActionResult>) {
        var callback: CallbackRef? = null
    }
    private val pending = mutableMapOf<String, Pending>()
    private var nextId = 0L
    private var disposed = false

    override fun moduleName(): String = NAME
    override suspend fun dial(phone: String): ActionResult = perform("dial", phone)
    override suspend fun openExternalUrl(url: String): ActionResult = perform("openExternalUrl", url)
    override suspend fun openAppSettings(): ActionResult = perform("openAppSettings")
    override suspend fun openLocationSettings(): ActionResult = perform("openLocationSettings")
    override suspend fun openAppStore(listingUrl: String): ActionResult = perform("openAppStore", listingUrl)

    private suspend fun perform(method: String, value: String = ""): ActionResult {
        if (disposed) return ActionResult.Unavailable
        val id = (++nextId).toString()
        var request: Pending? = null
        var completed = false
        try {
            val action = withTimeoutOrNull(20_000L) {
                suspendCancellableCoroutine { result ->
                    if (!result.isActive || disposed) {
                        result.cancel()
                        return@suspendCancellableCoroutine
                    }
                    val entry = Pending(result)
                    request = entry
                    pending[id] = entry
                    entry.callback = toNative(false, method, JSONObject().apply {
                        put("requestId", id)
                        put("value", value)
                    }.toString(), { response ->
                        if (!disposed && result.isActive) {
                            completed = true
                            result.resume(when (response?.optString("status")) {
                                "requested" -> ActionResult.Requested
                                "invalid_input" -> ActionResult.InvalidInput
                                else -> ActionResult.Unavailable
                            })
                        }
                    }, false).callbackRef
                }
            } ?: ActionResult.Unavailable
            // 回执可能已入协程队列，页面销毁后不能继续交付成功。
            if (disposed) throw CancellationException("SystemActionsModule is disposed")
            return action
        } finally {
            pending.remove(id)
            request?.callback?.let(::removeCallback)
            if (!completed && !disposed) cancelNative(id)
        }
    }

    private fun cancelNative(id: String) {
        toNative(false, "cancel", JSONObject().apply { put("requestId", id) }.toString(), null, false)
    }

    fun dispose() {
        if (disposed) return
        disposed = true
        pending.toMap().forEach { (id, request) ->
            request.callback?.let(::removeCallback)
            request.callback = null
            request.continuation.cancel()
            cancelNative(id)
        }
        pending.clear()
    }

    companion object { const val NAME = "GycSystemActionsModule" }
}
