package io.github.gycrosskit.systemactions

import android.app.Activity
import android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
import android.view.WindowManager.LayoutParams.FLAG_SECURE
import android.view.WindowManager.LayoutParams.FLAG_FULLSCREEN
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import kotlin.test.assertEquals

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class AndroidWindowPolicyTest {
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
