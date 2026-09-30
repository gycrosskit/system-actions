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
