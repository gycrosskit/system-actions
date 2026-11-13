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
@Config(sdk = [28], shadows = [FileProviderBoundary::class])
class AndroidSystemActionsTest {
    @Test fun clipboardReadsOnlyFirstActualTextWithFocusedActivity() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        val controller = org.robolectric.Robolectric.buildActivity(android.app.Activity::class.java).setup()
        try {
            val activity = controller.get()
            val actions = AndroidSystemActions(activity)
            val clipboard = activity.getSystemService(android.content.Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
            assertEquals(ClipboardReadResult.Unavailable, AndroidSystemActions(activity.applicationContext).readClipboardText())
            controller.windowFocusChanged(true)
            for (value in listOf("", " ", "a\u0000b", "长".repeat(20000))) {
                clipboard.setPrimaryClip(android.content.ClipData.newPlainText("", value).apply {
                    addItem(android.content.ClipData.Item("ignored"))
                })
                assertEquals(ClipboardReadResult.Text(value), actions.readClipboardText())
            }
            val styled = android.text.SpannableString(" 原文 ").apply {
                setSpan(android.text.style.StyleSpan(android.graphics.Typeface.BOLD), 1, 3, 0)
            }
            clipboard.setPrimaryClip(android.content.ClipData.newPlainText("", styled))
            assertEquals(ClipboardReadResult.Text(" 原文 "), actions.readClipboardText())
            clipboard.setPrimaryClip(android.content.ClipData.newHtmlText("", "原文", "<b>different</b>"))
            assertEquals(ClipboardReadResult.Text("原文"), actions.readClipboardText())
            clipboard.setPrimaryClip(android.content.ClipData.newRawUri("", android.net.Uri.parse("https://example.com")).apply {
                addItem(android.content.ClipData.Item("ignored"))
            })
            assertEquals(ClipboardReadResult.NoText, actions.readClipboardText())
            clipboard.setPrimaryClip(android.content.ClipData.newIntent("", Intent(Intent.ACTION_VIEW)))
            assertEquals(ClipboardReadResult.NoText, actions.readClipboardText())
            controller.windowFocusChanged(false)
            assertEquals(ClipboardReadResult.Unavailable, actions.readClipboardText())
        } finally {
            controller.pause().stop().destroy()
            Dispatchers.resetMain()
        }
    }

    @Test fun clipboardDistinguishesExplicitDenialFromFailureAndEmptyClip() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        val controller = org.robolectric.Robolectric.buildActivity(ClipboardFailureActivity::class.java).setup()
        try {
            controller.windowFocusChanged(true)
            val activity = controller.get()
            val actions = AndroidSystemActions(activity)
            val clipboard = activity.getSystemService(android.content.Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
            clipboard.clearPrimaryClip()
            assertEquals(ClipboardReadResult.NoText, actions.readClipboardText())
            activity.failure = SecurityException()
            assertEquals(ClipboardReadResult.Denied, actions.readClipboardText())
            activity.failure = IllegalStateException()
            assertEquals(ClipboardReadResult.Failed, actions.readClipboardText())
            activity.failure = kotlinx.coroutines.CancellationException()
            kotlin.test.assertFailsWith<kotlinx.coroutines.CancellationException> { actions.readClipboardText() }
        } finally {
            controller.pause().stop().destroy()
            Dispatchers.resetMain()
        }
    }

    @Test fun sharedServiceUsesClipboardAndProviderWithoutNewWindowOwner() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try {
            val app = RuntimeEnvironment.getApplication()
            var launched: Intent? = null
            val context = object : ContextWrapper(app) {
                override fun startActivity(intent: Intent) { launched = intent }
            }
            val actions: SystemActions = AndroidSystemActions(context, "host.fileprovider")
            assertEquals(ActionResult.Requested, actions.copyText("共同服务"))
            val clipboard = app.getSystemService(android.content.Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
            assertEquals("共同服务", clipboard.primaryClip?.getItemAt(0)?.text?.toString())
            assertEquals(ActionResult.InvalidInput, actions.shareFile("file:///tmp/a.zip", "分享"))
            assertEquals(ActionResult.InvalidInput, actions.shareFile("/tmp/../a.zip", "分享"))
            assertEquals(null, launched)
            val file = java.io.File.createTempFile("service-", ".zip", app.cacheDir)
            try {
                assertEquals(ActionResult.Unavailable, AndroidSystemActions(context).shareFile(file.path, "分享"))
                assertEquals(ActionResult.Requested, actions.shareFile(file.path, "分享"))
                @Suppress("DEPRECATION")
                val send = launched!!.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)!!
                assertEquals(Intent.ACTION_SEND, send.action)
                assertEquals("application/zip", send.type)
                assertEquals(Intent.FLAG_GRANT_READ_URI_PERMISSION, send.flags)
            } finally { file.delete() }
        } finally { Dispatchers.resetMain() }
    }

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
    @Test fun missingClipboardDoesNotReportAcceptance() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try {
            val context = object : ContextWrapper(RuntimeEnvironment.getApplication()) {
                override fun getSystemService(name: String): Any? =
                    if (name == android.content.Context.CLIPBOARD_SERVICE) null else super.getSystemService(name)
            }
            assertEquals(ActionResult.Unavailable, AndroidSystemActions(context).copyText("sample"))
        } finally { Dispatchers.resetMain() }
    }

}

class ClipboardFailureActivity : android.app.Activity() {
    var failure: RuntimeException? = null
    override fun getSystemService(name: String): Any? {
        if (name == android.content.Context.CLIPBOARD_SERVICE) failure?.let { throw it }
        return super.getSystemService(name)
    }
}
