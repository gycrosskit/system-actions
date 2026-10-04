package io.github.gycrosskit.systemactions

import android.content.ActivityNotFoundException
import android.content.ClipboardManager
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import java.io.File
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], shadows = [FileProviderBoundary::class])
class AndroidFileActionsTest {
    @Test fun clipboardAndShareUseActualSystemIntentWithReadOnlyGrant() {
        val app = RuntimeEnvironment.getApplication()
        var launched: Intent? = null
        val context = object : ContextWrapper(app) {
            override fun startActivity(intent: Intent) { launched = intent }
        }
        val actions = AndroidFileActions(context)
        assertEquals(ActionResult.Requested, actions.copyText("诊断内容", "host-label"))
        val clipboard = app.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        assertEquals("诊断内容", clipboard.primaryClip?.getItemAt(0)?.text?.toString())
        val file = File.createTempFile("diagnostics-", ".zip", app.cacheDir)
        try {
            assertEquals(ActionResult.Requested, actions.shareFile(file, "host.fileprovider", "application/zip", "分享诊断"))
            val chooser = assertNotNull(launched)
            assertEquals(Intent.ACTION_CHOOSER, chooser.action)
            assertTrue(chooser.flags and Intent.FLAG_ACTIVITY_NEW_TASK != 0)
            @Suppress("DEPRECATION") val send = assertNotNull(chooser.getParcelableExtra<Intent>(Intent.EXTRA_INTENT))
            assertEquals(Intent.ACTION_SEND, send.action)
            assertEquals("application/zip", send.type)
            assertEquals(Intent.FLAG_GRANT_READ_URI_PERMISSION, send.flags)
            assertEquals("content://host.fileprovider/${file.name}", send.clipData?.getItemAt(0)?.uri.toString())
            @Suppress("DEPRECATION") val stream = send.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            assertEquals(send.clipData?.getItemAt(0)?.uri, stream)
            assertEquals("分享诊断", chooser.getStringExtra(Intent.EXTRA_TITLE))
        } finally { file.delete() }
    }

    @Test fun missingFilesProviderFailureAndRejectedChooserAreUnavailable() {
        val app = RuntimeEnvironment.getApplication()
        var launches = 0
        val context = object : ContextWrapper(app) {
            override fun startActivity(intent: Intent) { launches++; throw ActivityNotFoundException() }
        }
        val actions = AndroidFileActions(context)
        assertEquals(ActionResult.Unavailable, actions.shareFile(File(app.cacheDir, "missing.zip"), "host.fileprovider", "application/zip", "分享"))
        assertEquals(ActionResult.InvalidInput, actions.shareFile(app.cacheDir, "", "application/zip", "分享"))
        val file = File.createTempFile("diagnostics-", ".zip", app.cacheDir)
        try {
            assertEquals(ActionResult.Unavailable, actions.shareFile(file, "invalid", "application/zip", "分享"))
            assertEquals(0, launches)
            assertEquals(ActionResult.Unavailable, actions.shareFile(file, "host.fileprovider", "application/zip", "分享"))
            assertEquals(1, launches)
        } finally { file.delete() }
    }
}

/** FileProvider 的目录/authority 配置属于宿主；这里只替换上游边界，执行库真实 Intent/clipboard 代码。 */
@Implements(FileProvider::class)
class FileProviderBoundary {
    companion object {
        @JvmStatic @Implementation
        fun getUriForFile(context: Context, authority: String, file: File): Uri {
            if (authority == "invalid") throw IllegalArgumentException("unconfigured authority")
            return Uri.parse("content://$authority/${file.name}")
        }
    }
}
