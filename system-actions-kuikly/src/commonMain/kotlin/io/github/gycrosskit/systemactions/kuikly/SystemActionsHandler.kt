package io.github.gycrosskit.systemactions.kuikly

import com.tencent.kuikly.core.nvi.serialization.json.JSONObject
import io.github.gycrosskit.systemactions.ActionResult
import io.github.gycrosskit.systemactions.SystemActions
import kotlinx.coroutines.*

/** Android/iOS receiver 共用协议；调用、取消、原生观察与回调均在 Main 串行。 */
internal class SystemActionsHandler(
    private val actions: SystemActions,
    private val setKeepScreenOn: (Boolean) -> Boolean,
    private val observeKeyboard: ((Float) -> Unit) -> (() -> Unit),
    private val observeDark: ((Boolean) -> Unit) -> (() -> Unit),
    private val closeNative: () -> Unit,
) {
    private class Observation(val id: String) { var stop: (() -> Unit)? = null }
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val pending = mutableMapOf<String, Job>()
    private var keyboard: Observation? = null
    private var dark: Observation? = null
    private var disposed = false

    fun call(method: String, params: String, callback: (String) -> Unit) {
        if (disposed) return
        if (method == "dispose") { dispose(); return }
        val args = try { JSONObject(params) } catch (_: Exception) {
            callback(status(ActionResult.InvalidInput)); return
        }
        val id = args.opt("requestId") as? String
        if (id.isNullOrEmpty()) { callback(status(ActionResult.InvalidInput)); return }
        when (method) {
            "cancel" -> { pending.remove(id)?.cancel(); return }
            "stopKeyboardHeight" -> {
                keyboard?.takeIf { it.id == id }?.let { keyboard = null; it.stop?.invoke() }; return
            }
            "stopDarkMode" -> {
                dark?.takeIf { it.id == id }?.let { dark = null; it.stop?.invoke() }; return
            }
            "observeKeyboardHeight" -> {
                val old = keyboard
                keyboard = null
                old?.stop?.invoke()
                val entry = Observation(id)
                keyboard = entry
                entry.stop = observeKeyboard { height ->
                    if (!disposed && keyboard === entry) callback(JSONObject().apply { put("height", height) }.toString())
                }
                if (disposed || keyboard !== entry) entry.stop?.invoke()
                return
            }
            "observeDarkMode" -> {
                val old = dark
                dark = null
                old?.stop?.invoke()
                val entry = Observation(id)
                dark = entry
                entry.stop = observeDark { value ->
                    if (!disposed && dark === entry) callback(JSONObject().apply { put("darkMode", value) }.toString())
                }
                if (disposed || dark !== entry) entry.stop?.invoke()
                return
            }
        }
        if (pending.containsKey(id) || (args.has("value") && args.opt("value") !is String)) {
            callback(status(ActionResult.InvalidInput)); return
        }
        val value = args.opt("value") as? String ?: ""
        val job = scope.launch(start = CoroutineStart.LAZY) {
            val result = try {
                when (method) {
                    "copyText" -> actions.copyText(value)
                    "shareFile" -> (args.opt("title") as? String)?.let { actions.shareFile(value, it) }
                        ?: ActionResult.InvalidInput
                    "dial" -> actions.dial(value)
                    "openExternalUrl" -> actions.openExternalUrl(value)
                    "openAppSettings" -> actions.openAppSettings()
                    "openLocationSettings" -> actions.openLocationSettings()
                    "openAppStore" -> actions.openAppStore(value)
                    "openNativeAppStore" -> actions.openNativeAppStore(args.opt("value") as? String)
                    "setKeepScreenOn" -> when (value) {
                        "true", "false" -> if (setKeepScreenOn(value == "true")) ActionResult.Requested else ActionResult.Unavailable
                        else -> ActionResult.InvalidInput
                    }
                    else -> ActionResult.Unavailable
                }
            } catch (cancelled: CancellationException) { throw cancelled }
            catch (_: Exception) { ActionResult.Unavailable }
            pending.remove(id)
            if (!disposed) callback(status(result))
        }
        pending[id] = job
        job.invokeOnCompletion { if (pending[id] === job) pending.remove(id) }
        job.start()
    }

    fun dispose() {
        if (disposed) return
        disposed = true
        scope.cancel()
        pending.clear()
        val oldKeyboard = keyboard
        val oldDark = dark
        keyboard = null
        dark = null
        oldKeyboard?.stop?.invoke()
        oldDark?.stop?.invoke()
        closeNative()
    }

    private fun status(result: ActionResult) = JSONObject().apply {
        put("status", when (result) {
            ActionResult.Requested -> "requested"
            ActionResult.InvalidInput -> "invalid_input"
            ActionResult.Unavailable -> "unavailable"
        })
    }.toString()
}
