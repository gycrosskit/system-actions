package io.github.gycrosskit.systemactions

import android.app.Activity
import android.content.res.Configuration
import android.view.ViewGroup
import androidx.core.graphics.Insets
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import kotlin.test.assertEquals

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
class AndroidSystemObservationsTest {
    @Test fun replacingAndDisposingObserversKeepsOwnership() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val container = activity.window.decorView as ViewGroup
        val observations = AndroidSystemObservations(container)
        val themes = mutableListOf<Boolean>()
        val oldStop = observations.observeDarkMode { themes += it }
        observations.observeDarkMode { themes += it }
        oldStop()
        activity.application.onConfigurationChanged(Configuration(activity.resources.configuration).apply {
            uiMode = Configuration.UI_MODE_NIGHT_YES
        })
        assertEquals(listOf(false, false, true), themes)
        val heights = mutableListOf<Float>()
        val oldKeyboardStop = observations.observeKeyboardHeight { heights += it }
        observations.observeKeyboardHeight { heights += it }
        oldKeyboardStop()
        val observer = container.getChildAt(container.childCount - 1)
        ViewCompat.dispatchApplyWindowInsets(observer, WindowInsetsCompat.Builder()
            .setInsets(WindowInsetsCompat.Type.ime(), Insets.of(0, 0, 0, 240)).build())
        assertEquals(listOf(0f, 0f, 240f / activity.resources.displayMetrics.density), heights)
        val childCount = container.childCount
        observations.dispose()
        assertEquals(childCount - 1, container.childCount, "dispose removes only its own insets View")
        ViewCompat.dispatchApplyWindowInsets(observer, WindowInsetsCompat.Builder()
            .setInsets(WindowInsetsCompat.Type.ime(), Insets.of(0, 0, 0, 300)).build())
        assertEquals(3, heights.size, "disposed View cannot deliver late keyboard events")
        observations.observeDarkMode { error("disposed observer reopened") }
        observations.observeKeyboardHeight { error("disposed observer reopened") }
    }

    @Test fun initialCallbackMayDisposeWithoutRegisteringAgain() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val observations = AndroidSystemObservations(activity.window.decorView as ViewGroup)
        observations.observeDarkMode { observations.dispose() }
        activity.application.onConfigurationChanged(Configuration().apply { uiMode = Configuration.UI_MODE_NIGHT_YES })
        observations.observeDarkMode { error("disposed observer reopened") }
    }
}
