package io.github.gycrosskit.systemactions

import android.content.ActivityNotFoundException
import android.content.ContextWrapper
import android.content.Intent
import android.provider.Settings
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.ExperimentalCoroutinesApi
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import kotlin.test.assertEquals
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class AndroidSystemActionsTest {
    @Test fun phoneAndWebUrlValidationPrecedesSystemLaunchAndPreservesNormalizedIntent() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try {
            val launched = mutableListOf<Intent>()
            val context = object : ContextWrapper(RuntimeEnvironment.getApplication()) {
                override fun startActivity(intent: Intent) { launched += intent }
            }
            val actions = AndroidSystemActions(context)
            assertEquals(ActionResult.InvalidInput, actions.dial("123;456"))
            assertEquals(ActionResult.InvalidInput, actions.openExternalUrl("https://user@example.com"))
            assertTrue(launched.isEmpty(), "invalid input never reaches system")
            assertEquals(ActionResult.Requested, actions.dial(" +86 (138)-1234 "))
            assertEquals(Intent.ACTION_DIAL, launched.single().action)
            assertEquals("tel", launched.single().data?.scheme)
            assertEquals("+861381234", launched.single().data?.schemeSpecificPart)
            assertEquals(ActionResult.Requested, actions.openExternalUrl(" https://example.com/path%20name "))
            assertEquals(Intent.ACTION_VIEW, launched.last().action)
            assertEquals("https://example.com/path%20name", launched.last().dataString)
            assertTrue(launched.all { it.flags and Intent.FLAG_ACTIVITY_NEW_TASK != 0 })
        } finally { Dispatchers.resetMain() }
    }

    @Test fun locationSettingsReportsActualAcceptanceWithApplicationContext() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try {
            var launched: Intent? = null
            var reject = false
            val context = object : ContextWrapper(RuntimeEnvironment.getApplication()) {
                override fun startActivity(intent: Intent) {
                    launched = intent
                    if (reject) throw ActivityNotFoundException()
                }
            }
            val actions = AndroidSystemActions(context)
            assertEquals(ActionResult.Requested, actions.openLocationSettings())
            assertEquals(Settings.ACTION_LOCATION_SOURCE_SETTINGS, launched?.action)
            assertTrue((launched?.flags ?: 0) and Intent.FLAG_ACTIVITY_NEW_TASK != 0)
            reject = true
            assertEquals(ActionResult.Unavailable, actions.openLocationSettings())
        } finally { Dispatchers.resetMain() }
    }
}
