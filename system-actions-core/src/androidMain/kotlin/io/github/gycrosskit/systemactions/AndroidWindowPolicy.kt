package io.github.gycrosskit.systemactions

import android.os.Looper
import android.view.Window
import android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
import android.view.WindowManager.LayoutParams.FLAG_SECURE

/** Window 策略不持有 Activity/Compose 生命周期，宿主在离开时关闭自己的 lease。 */
object AndroidWindowPolicy {
    private val windows = mutableMapOf<Window, WindowOwners>()

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
