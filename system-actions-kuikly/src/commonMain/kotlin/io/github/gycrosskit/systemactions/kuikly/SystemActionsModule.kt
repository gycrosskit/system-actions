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
    private class Observation(val id: String) { var callback: CallbackRef? = null }
    private var keyboard: Observation? = null
    private var darkMode: Observation? = null
    private val pending = mutableMapOf<String, Pending>()
    private var nextId = 0L
    private var disposed = false

    override fun moduleName(): String = NAME
    override suspend fun dial(phone: String): ActionResult = perform("dial", phone)
    override suspend fun openExternalUrl(url: String): ActionResult = perform("openExternalUrl", url)
    override suspend fun openAppSettings(): ActionResult = perform("openAppSettings")
    override suspend fun openLocationSettings(): ActionResult = perform("openLocationSettings")
    override suspend fun openAppStore(listingUrl: String): ActionResult = perform("openAppStore", listingUrl)
    override suspend fun openNativeAppStore(applicationId: String?): ActionResult = perform("openNativeAppStore", applicationId)

    /** 写入原样文本；Requested 仅表示系统写入受理。 */
    override suspend fun copyText(value: String): ActionResult = perform("copyText", value)

    /** 分享宿主普通沙箱文件；Requested 仅表示面板受理，文件生命周期仍归宿主。 */
    override suspend fun shareFile(path: String, title: String): ActionResult =
        perform("shareFile", path, JSONObject().apply { put("title", title) })

    /** 页面常亮 owner；false 或 dispose 释放自身 lease，不覆盖初始窗口或其他 owner。 */
    suspend fun setKeepScreenOn(enabled: Boolean): ActionResult = perform("setKeepScreenOn", enabled.toString())

    /**
     * 替换本实例旧键盘观察，返回只停止本次观察的幂等取消函数。
     * @param onChange 页面 Context 回调，高度已由当前 Window px2vp 转为 vp，初值 0。
     */
    fun observeKeyboardHeight(onChange: (Float) -> Unit): () -> Unit {
        stopKeyboardHeight()
        if (disposed) return {}
        val observer = Observation((++nextId).toString())
        keyboard = observer
        observer.callback = toNative(true, "observeKeyboardHeight", observationParams(observer), { response ->
            if (!disposed && keyboard === observer) {
                onChange(response?.optDouble("height", 0.0)?.toFloat()?.coerceAtLeast(0f) ?: 0f)
            }
        }).callbackRef
        if (disposed || keyboard !== observer) observer.callback?.let(::removeCallback)
        return { if (keyboard === observer) stopKeyboardHeight() }
    }

    /**
     * 替换本实例旧主题观察，返回只停止本次观察的幂等取消函数。
     * @param onChange 页面 Context 回调，true 为系统深色模式，原生提供初始值与后续变化。
     */
    fun observeDarkMode(onChange: (Boolean) -> Unit): () -> Unit {
        stopDarkMode()
        if (disposed) return {}
        val observer = Observation((++nextId).toString())
        darkMode = observer
        observer.callback = toNative(true, "observeDarkMode", observationParams(observer), { response ->
            if (!disposed && darkMode === observer) onChange(response?.optBoolean("darkMode") == true)
        }).callbackRef
        if (disposed || darkMode !== observer) observer.callback?.let(::removeCallback)
        return { if (darkMode === observer) stopDarkMode() }
    }

    /** 幂等停止当前键盘观察并释放原生回调。 */
    fun stopKeyboardHeight() {
        val observer = keyboard ?: return
        keyboard = null
        stopObservation("stopKeyboardHeight", observer)
    }

    /** 幂等停止当前系统主题观察并释放原生回调。 */
    fun stopDarkMode() {
        val observer = darkMode ?: return
        darkMode = null
        stopObservation("stopDarkMode", observer)
    }

    private fun observationParams(observer: Observation) = JSONObject().apply { put("requestId", observer.id) }.toString()

    private fun stopObservation(method: String, observer: Observation) {
        toNative(false, method, observationParams(observer), null, false)
        observer.callback?.let(::removeCallback)
        observer.callback = null
    }

    private suspend fun perform(method: String, value: String? = null, args: JSONObject = JSONObject()): ActionResult {
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
                    entry.callback = toNative(false, method, args.apply {
                        put("requestId", id)
                        if (value != null) put("value", value)
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

    /** 页面销毁时幂等释放观察和挂起请求；取消不能撤回已受理的系统动作。 */
    fun dispose() {
        if (disposed) return
        stopKeyboardHeight()
        stopDarkMode()
        disposed = true
        pending.toMap().forEach { (id, request) ->
            request.callback?.let(::removeCallback)
            request.callback = null
            request.continuation.cancel()
            cancelNative(id)
        }
        pending.clear()
        // 已发布 OHOS HAR 只有 onDestroy，不能向旧协议发送新增方法。
        if (nativeDisposeSupported) toNative(false, "dispose", null, null, false)
    }

    companion object { /** 与原生注册名一致的桥名称。 */ const val NAME = "GycSystemActionsModule" }
}

internal expect val nativeDisposeSupported: Boolean
