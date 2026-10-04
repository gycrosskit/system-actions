package io.github.gycrosskit.systemactions

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Looper
import androidx.core.content.FileProvider
import java.io.File

/** 宿主保留唯一 FileProvider 声明及私有目录映射；库只授予所选文件的临时读取权限。 */
class AndroidFileActions(private val context: Context) {
    fun copyText(value: String, label: String = ""): ActionResult {
        if (Looper.myLooper() != Looper.getMainLooper()) return ActionResult.Unavailable
        return try {
            val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
                ?: return ActionResult.Unavailable
            clipboard.setPrimaryClip(ClipData.newPlainText(label, value))
            ActionResult.Requested
        } catch (_: RuntimeException) { ActionResult.Unavailable }
    }

    /** Requested 只表示 chooser 受理；Android 不把 chooser 关闭冒充分享完成。 */
    fun shareFile(file: File, authority: String, mimeType: String, title: String): ActionResult {
        if (authority.isBlank() || mimeType.isBlank()) return ActionResult.InvalidInput
        if (Looper.myLooper() != Looper.getMainLooper() || !file.isFile) return ActionResult.Unavailable
        return try {
            val uri = FileProvider.getUriForFile(context, authority, file)
            val send = Intent(Intent.ACTION_SEND).apply {
                type = mimeType
                putExtra(Intent.EXTRA_STREAM, uri)
                clipData = ClipData.newRawUri(file.name, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            val chooser = Intent.createChooser(send, title)
            if (context !is Activity) chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(chooser)
            ActionResult.Requested
        } catch (_: RuntimeException) { ActionResult.Unavailable }
    }
}
