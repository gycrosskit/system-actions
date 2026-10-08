package io.github.gycrosskit.systemactions

import android.app.Activity
import android.content.pm.ActivityInfo
import android.view.View
import android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
import android.view.WindowManager.LayoutParams.FLAG_SECURE
import android.view.WindowManager.LayoutParams.FLAG_FULLSCREEN
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class AndroidWindowPolicyTest {
    class RestoreFailingActivity : Activity() {
        var failRestore = false
        override fun setRequestedOrientation(value: Int) {
            if (failRestore && value == ActivityInfo.SCREEN_ORIENTATION_PORTRAIT) error("restore rejected")
            super.setRequestedOrientation(value)
        }
    }

    @Test fun failedFullscreenRestoreRetainsOwnerAndBaselineForRetry() {
        val activity = Robolectric.buildActivity(RestoreFailingActivity::class.java).setup().get()
        activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        val lease = AndroidWindowPolicy.acquireFullscreen(activity, ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE)
        activity.failRestore = true
        assertFailsWith<IllegalStateException> { lease.close() }
        assertTrue(lease.isActive, "restore failure must retain a retryable owner")
        activity.failRestore = false
        lease.close()
        assertEquals(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT, activity.requestedOrientation)
        assertEquals(false, lease.isActive)
    }

    @Test fun fullscreenReplacementRestoresFirstBaselineWithoutRelaxingOtherWindowOwners() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        val initialUi = View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
        activity.window.decorView.systemUiVisibility = initialUi
        val secure = AndroidWindowPolicy.acquire(activity.window)
        val first = AndroidWindowPolicy.acquireFullscreen(activity, ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE)
        val second = AndroidWindowPolicy.acquireFullscreen(activity, ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE)
        first.close()
        assertEquals(ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE, activity.requestedOrientation)
        second.close(); second.close()
        assertEquals(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT, activity.requestedOrientation)
        assertEquals(initialUi, activity.window.decorView.systemUiVisibility)
        assertEquals(FLAG_SECURE or FLAG_KEEP_SCREEN_ON,
            activity.window.attributes.flags and (FLAG_SECURE or FLAG_KEEP_SCREEN_ON or FLAG_FULLSCREEN))
        secure.close()
    }

    @Test fun layoutOnlyLeaseDoesNotRestoreOrientationButReplacementKeepsPriorRotationBaseline() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        val layoutOnly = AndroidWindowPolicy.acquireFullscreen(activity)
        activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_REVERSE_PORTRAIT
        layoutOnly.close()
        assertEquals(ActivityInfo.SCREEN_ORIENTATION_REVERSE_PORTRAIT, activity.requestedOrientation)
        val rotating = AndroidWindowPolicy.acquireFullscreen(activity, ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE)
        val replacement = AndroidWindowPolicy.acquireFullscreen(activity)
        rotating.close()
        replacement.close()
        assertEquals(ActivityInfo.SCREEN_ORIENTATION_REVERSE_PORTRAIT, activity.requestedOrientation)
    }

    @Test fun overlappingOwnersCannotRelaxProtectionAndRestoreOnlyTheirFlags() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val window = activity.window
        window.addFlags(FLAG_FULLSCREEN)
        val baseline = window.attributes.flags
        val first = AndroidWindowPolicy.acquire(window)
        val second = AndroidWindowPolicy.acquire(window, screenRecordingAllowed = true)
        assertEquals(baseline or FLAG_KEEP_SCREEN_ON or FLAG_SECURE, window.attributes.flags)
        first.update(true)
        assertEquals(baseline or FLAG_KEEP_SCREEN_ON, window.attributes.flags)
        first.close()
        assertEquals(baseline or FLAG_KEEP_SCREEN_ON, window.attributes.flags)
        first.update(false)
        second.close()
        second.close()
        assertEquals(baseline, window.attributes.flags)
    }

    @Test fun preexistingSecureAndKeepScreenFlagsArePreservedAndWindowsAreIndependent() {
        val firstWindow = Robolectric.buildActivity(Activity::class.java).setup().get().window
        val secondWindow = Robolectric.buildActivity(Activity::class.java).setup().get().window
        firstWindow.addFlags(FLAG_SECURE or FLAG_KEEP_SCREEN_ON)
        val baseline = firstWindow.attributes.flags
        val first = AndroidWindowPolicy.acquire(firstWindow, keepScreenOn = false, screenRecordingAllowed = true)
        val secondBaseline = secondWindow.attributes.flags
        val second = AndroidWindowPolicy.acquire(secondWindow)
        first.close()
        assertEquals(baseline, firstWindow.attributes.flags)
        assertEquals(secondBaseline or FLAG_SECURE or FLAG_KEEP_SCREEN_ON, secondWindow.attributes.flags)
        second.close()
        assertEquals(secondBaseline, secondWindow.attributes.flags)
    }
}
