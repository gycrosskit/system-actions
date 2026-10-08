package io.github.gycrosskit.systemactions

import android.content.ComponentCallbacks
import android.content.res.Configuration
import android.view.View
import android.view.ViewGroup
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat

/** 主线程使用；宿主传当前 View，并在页面结束时 dispose。不替换宿主的 WindowInsets listener。 */
class AndroidSystemObservations(private val hostView: ViewGroup) {
    private var keyboard: View? = null
    private var environment: ComponentCallbacks? = null
    private var disposed = false

    /** 初值 0，后续高度按当前 View 的 density 转为 dp；旧 stop 不影响后继观察。 */
    fun observeKeyboardHeight(onChange: (Float) -> Unit): () -> Unit {
        AndroidWindowPolicy.requireMainThread()
        stopKeyboardHeight()
        if (disposed) return {}
        var last = 0f
        val observer = View(hostView.context)
        ViewCompat.setOnApplyWindowInsetsListener(observer) { _, insets ->
            if (!disposed && keyboard === observer) {
                val height = insets.getInsets(WindowInsetsCompat.Type.ime()).bottom / hostView.resources.displayMetrics.density
                if (height != last) { last = height; onChange(height) }
            }
            insets
        }
        keyboard = observer
        onChange(0f)
        if (!disposed && keyboard === observer) {
            hostView.addView(observer, ViewGroup.LayoutParams(0, 0))
            ViewCompat.requestApplyInsets(observer)
        }
        return { if (keyboard === observer) stopKeyboardHeight() }
    }

    /** 立即交付当前深浅色，再观察系统配置；不会替宿主选择应用主题。 */
    fun observeDarkMode(onChange: (Boolean) -> Unit): () -> Unit {
        AndroidWindowPolicy.requireMainThread()
        stopDarkMode()
        if (disposed) return {}
        val observer = object : ComponentCallbacks {
            override fun onConfigurationChanged(configuration: Configuration) {
                if (!disposed && environment === this) onChange(configuration.isDarkMode())
            }
            override fun onLowMemory() = Unit
        }
        environment = observer
        onChange(hostView.resources.configuration.isDarkMode())
        if (!disposed && environment === observer) hostView.context.registerComponentCallbacks(observer)
        return { if (environment === observer) stopDarkMode() }
    }

    fun stopKeyboardHeight() {
        AndroidWindowPolicy.requireMainThread()
        keyboard?.let {
            ViewCompat.setOnApplyWindowInsetsListener(it, null)
            (it.parent as? ViewGroup)?.removeView(it)
        }
        keyboard = null
    }

    fun stopDarkMode() {
        AndroidWindowPolicy.requireMainThread()
        environment?.let(hostView.context::unregisterComponentCallbacks)
        environment = null
    }

    /** 永久关闭；初始回调中 dispose 也不会在返回后重新注册。 */
    fun dispose() {
        AndroidWindowPolicy.requireMainThread()
        disposed = true
        stopKeyboardHeight()
        stopDarkMode()
    }

    private fun Configuration.isDarkMode() = uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
}
