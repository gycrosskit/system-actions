package io.github.gycrosskit.systemactions

import android.app.Activity
import android.os.Looper
import android.view.View
import android.view.Window
import android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
import android.view.WindowManager.LayoutParams.FLAG_SECURE
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat

/** Window 策略不持有 Activity/Compose 生命周期，宿主在离开时关闭自己的 lease。 */
object AndroidWindowPolicy {
    private val windows = mutableMapOf<Window, WindowOwners>()
    private val fullscreen = mutableMapOf<Window, AndroidFullscreenWindowLease>()

    /**
     * 一个 Window 同时只有一个全屏 owner；新 owner 继承首次基线，旧 close 不恢复新状态。
     * @param orientation 宿主请求的 ActivityInfo.SCREEN_ORIENTATION_*；null 保留当前方向。
     * @param hideSystemBars 隐藏状态栏和导航栏；系统手势可能临时显示系统栏。
     * @param layoutFullscreen 是否延伸布局到系统栏区域；只改本次拥有的 legacy layout flags。
     */
    fun acquireFullscreen(activity: Activity, orientation: Int? = null,
        hideSystemBars: Boolean = true, layoutFullscreen: Boolean = true): AndroidFullscreenWindowLease {
        requireMainThread()
        require(orientation == null || orientation in -1..14) { "Invalid Android screen orientation" }
        val previous = fullscreen[activity.window]
        val insets = ViewCompat.getRootWindowInsets(activity.window.decorView)
        val statusVisible = insets?.isVisible(WindowInsetsCompat.Type.statusBars())
            ?: (activity.window.attributes.flags and android.view.WindowManager.LayoutParams.FLAG_FULLSCREEN == 0)
        val navigationVisible = insets?.isVisible(WindowInsetsCompat.Type.navigationBars())
            ?: (activity.window.decorView.systemUiVisibility and View.SYSTEM_UI_FLAG_HIDE_NAVIGATION == 0)
        val lease = AndroidFullscreenWindowLease(activity,
            previous?.initialOrientation ?: activity.requestedOrientation,
            previous?.initialSystemUiVisibility ?: activity.window.decorView.systemUiVisibility,
            previous?.initialFullscreen ?: (activity.window.attributes.flags and android.view.WindowManager.LayoutParams.FLAG_FULLSCREEN != 0),
            previous?.initialVisibleBars ?: ((if (statusVisible) WindowInsetsCompat.Type.statusBars() else 0) or
                (if (navigationVisible) WindowInsetsCompat.Type.navigationBars() else 0)),
            previous?.initialBarsBehavior ?: WindowInsetsControllerCompat(activity.window, activity.window.decorView).systemBarsBehavior,
            previous?.orientationChanged ?: false)
        previous?.replaced()
        fullscreen[activity.window] = lease
        try { lease.apply(orientation, hideSystemBars, layoutFullscreen) }
        catch (error: RuntimeException) { lease.close(); throw error }
        return lease
    }

    internal fun releaseFullscreen(lease: AndroidFullscreenWindowLease) {
        requireMainThread()
        if (fullscreen[lease.activity.window] !== lease) return
        lease.restore()
        fullscreen.remove(lease.activity.window)
    }

    /**
     * 主线程获取独占 lease；任一 owner 禁录时保留 FLAG_SECURE，原有保护不会被放宽。
     * @param window 本次生命周期的窗口，lease 关闭前保留引用。
     * @param keepScreenOn 默认 true，请求常亮；任一 owner 请求即可生效。
     * @param screenRecordingAllowed 默认 false，禁止截图/录屏；已有 FLAG_SECURE 不会被放宽。
     */
    fun acquire(
        window: Window,
        keepScreenOn: Boolean = true,
        screenRecordingAllowed: Boolean = false,
    ): AndroidWindowPolicyLease {
        requireMainThread()
        val owners = windows.getOrPut(window) { WindowOwners(window, window.attributes.flags) }
        val lease = AndroidWindowPolicyLease(window, keepScreenOn, screenRecordingAllowed)
        owners.leases += lease
        owners.apply()
        return lease
    }

    internal fun update(lease: AndroidWindowPolicyLease) {
        requireMainThread()
        windows[lease.window]?.apply()
    }

    internal fun release(lease: AndroidWindowPolicyLease) {
        requireMainThread()
        val owners = windows[lease.window] ?: return
        owners.leases.remove(lease)
        owners.apply()
        if (owners.leases.isEmpty()) windows.remove(lease.window)
    }

    internal fun requireMainThread() {
        check(Looper.myLooper() == Looper.getMainLooper()) { "Window policy requires the main thread" }
    }

    private class WindowOwners(val window: Window, val initialFlags: Int) {
        val leases = mutableSetOf<AndroidWindowPolicyLease>()
        fun apply() {
            setFlag(FLAG_KEEP_SCREEN_ON, initialFlags and FLAG_KEEP_SCREEN_ON != 0 || leases.any { it.keepScreenOn })
            setFlag(FLAG_SECURE, initialFlags and FLAG_SECURE != 0 || leases.any { !it.screenRecordingAllowed })
        }
        private fun setFlag(flag: Int, enabled: Boolean) {
            if (enabled) window.addFlags(flag) else window.clearFlags(flag)
        }
    }
}

/** 主线程生命周期句柄；方向和系统栏都是系统请求，不保证多窗口/设备策略允许全屏。 */
class AndroidFullscreenWindowLease internal constructor(
    internal val activity: Activity,
    internal val initialOrientation: Int,
    internal val initialSystemUiVisibility: Int,
    internal val initialFullscreen: Boolean,
    internal val initialVisibleBars: Int,
    internal val initialBarsBehavior: Int,
    internal var orientationChanged: Boolean,
) : AutoCloseable {
    var isActive: Boolean = true
        private set

    internal fun apply(orientation: Int?, hideBars: Boolean, layoutFullscreen: Boolean) {
        orientation?.let {
            orientationChanged = true
            activity.requestedOrientation = it
        }
        val window = activity.window
        if (hideBars) window.addFlags(android.view.WindowManager.LayoutParams.FLAG_FULLSCREEN)
        else window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_FULLSCREEN)
        val controller = WindowInsetsControllerCompat(window, window.decorView)
        controller.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        if (hideBars) controller.hide(WindowInsetsCompat.Type.systemBars()) else controller.show(WindowInsetsCompat.Type.systemBars())
        val ownedFlags = View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
            View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        window.decorView.systemUiVisibility = (window.decorView.systemUiVisibility and ownedFlags.inv()) or
            (if (layoutFullscreen) View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_LAYOUT_STABLE else 0)
    }

    internal fun replaced() { isActive = false }

    internal fun restore() {
        if (orientationChanged) activity.requestedOrientation = initialOrientation
        val controller = WindowInsetsControllerCompat(activity.window, activity.window.decorView)
        controller.systemBarsBehavior = initialBarsBehavior
        controller.show(initialVisibleBars)
        controller.hide(WindowInsetsCompat.Type.systemBars() and initialVisibleBars.inv())
        val ownedFlags = View.SYSTEM_UI_FLAG_FULLSCREEN or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
            View.SYSTEM_UI_FLAG_IMMERSIVE or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
            View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        activity.window.decorView.systemUiVisibility = (activity.window.decorView.systemUiVisibility and ownedFlags.inv()) or
            (initialSystemUiVisibility and ownedFlags)
        if (initialFullscreen) activity.window.addFlags(android.view.WindowManager.LayoutParams.FLAG_FULLSCREEN)
        else activity.window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_FULLSCREEN)
    }

    override fun close() {
        AndroidWindowPolicy.requireMainThread()
        if (!isActive) return
        AndroidWindowPolicy.releaseFullscreen(this)
        isActive = false
    }
}

/** close 幂等；关闭后 update 不会重新接管 Window。 */
class AndroidWindowPolicyLease internal constructor(
    internal val window: Window,
    internal val keepScreenOn: Boolean,
    internal var screenRecordingAllowed: Boolean,
) : AutoCloseable {
    private var closed = false

    /** 主线程更新本 owner 的录制策略。@param screenRecordingAllowed true 允许，但不覆盖其他 owner 或原有保护。 */
    fun update(screenRecordingAllowed: Boolean) {
        AndroidWindowPolicy.requireMainThread()
        if (closed) return
        this.screenRecordingAllowed = screenRecordingAllowed
        AndroidWindowPolicy.update(this)
    }

    override fun close() {
        AndroidWindowPolicy.requireMainThread()
        if (closed) return
        closed = true
        AndroidWindowPolicy.release(this)
    }
}
