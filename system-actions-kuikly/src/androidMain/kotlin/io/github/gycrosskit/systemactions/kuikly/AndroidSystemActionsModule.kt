package io.github.gycrosskit.systemactions.kuikly

import android.app.Activity
import android.content.ContextWrapper
import android.os.Handler
import android.os.Looper
import android.view.ViewGroup
import com.tencent.kuikly.core.render.android.IKuiklyRenderExport
import com.tencent.kuikly.core.render.android.export.KuiklyRenderBaseModule
import com.tencent.kuikly.core.render.android.export.KuiklyRenderCallback
import io.github.gycrosskit.systemactions.*

/** 每个 Renderer 的系统动作接收端；不持有宿主进程服务或独立 SDK runtime。 */
class AndroidSystemActionsModule(private val fileProviderAuthority: String? = null) : KuiklyRenderBaseModule() {
    private val main = Handler(Looper.getMainLooper())
    @Volatile private var destroyed = false
    private var handler: SystemActionsHandler? = null
    private var observations: AndroidSystemObservations? = null
    private var keepScreen: AndroidWindowPolicyLease? = null

    override fun call(method: String, params: String?, callback: KuiklyRenderCallback?): Any? {
        onMain {
            val current = handler ?: kuiklyRenderContext?.context?.let { hostContext ->
                SystemActionsHandler(AndroidSystemActions(hostContext, fileProviderAuthority), { enabled ->
                    if (!enabled) { keepScreen?.close(); keepScreen = null; true }
                    else {
                        val window = activity?.window
                        if (window == null) false else {
                            if (keepScreen == null) keepScreen = AndroidWindowPolicy.acquire(window, true, true)
                            true
                        }
                    }
                }, { change -> nativeObservations()?.observeKeyboardHeight(change) ?: {} },
                    { change -> nativeObservations()?.observeDarkMode(change) ?: {} }, {
                        observations?.dispose(); observations = null
                        keepScreen?.close(); keepScreen = null
                    }).also { handler = it }
            }
            current?.call(method, params.orEmpty()) { result -> if (!destroyed) callback?.invoke(result) }
                ?: callback?.invoke("{\"status\":\"unavailable\"}")
        }
        return null
    }

    // SDK base 的 context 会先解包 Activity；窗口能力需从 Renderer 原始 Context 解析。
    override val activity: Activity?
        get() {
            var current = kuiklyRenderContext?.context
            while (current is ContextWrapper) {
                if (current is Activity) return current
                current = current.baseContext
            }
            return current as? Activity
        }

    private fun nativeObservations(): AndroidSystemObservations? {
        if (observations == null) (kuiklyRenderContext?.kuiklyRenderRootView as? ViewGroup)?.let {
            observations = AndroidSystemObservations(it)
        }
        return observations
    }

    override fun onDestroy() {
        destroyed = true
        val cleanup = { handler?.dispose(); handler = null; kuiklyRenderContext = null }
        if (Looper.myLooper() == Looper.getMainLooper()) cleanup() else main.post { cleanup() }
    }

    private fun onMain(action: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) { if (!destroyed) action() }
        else main.post { if (!destroyed) action() }
    }
}

/** 在宿主既有 registerExternalModule 入口调用；factory 每个 Renderer 生成独占 owner。 */
fun IKuiklyRenderExport.registerGycSystemActionsModule(fileProviderAuthority: String? = null) {
    moduleExport(SystemActionsModule.NAME) { AndroidSystemActionsModule(fileProviderAuthority) }
}
