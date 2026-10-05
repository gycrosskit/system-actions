package io.github.gycrosskit.systemactions

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Looper
import androidx.core.content.FileProvider
import java.io.File

/**
 * 宿主保留唯一 FileProvider 声明及私有目录映射；库只授予所选文件的临时读取权限。
 * @param context 宿主当前 Context；本实例生命周期由宿主管理，非 Activity 分享追加 NEW_TASK。
 */
class AndroidFileActions(private val context: Context) {
    /**
     * 主线程写剪贴板；系统不可用或非主线程返回 Unavailable。
     * @param value 原样复制的文本，可为空。
     * @param label 剪贴板标签，默认空文本，由宿主本地化。
     */
    fun copyText(value: String, label: String = ""): ActionResult {
        if (Looper.myLooper() != Looper.getMainLooper()) return ActionResult.Unavailable
        return try {
            val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
                ?: return ActionResult.Unavailable
            clipboard.setPrimaryClip(ClipData.newPlainText(label, value))
            ActionResult.Requested
        } catch (_: RuntimeException) { ActionResult.Unavailable }
    }

    /**
     * 主线程显示 chooser；Requested 仅表示受理，不把 chooser 关闭冒充分享完成。
     * @param file 存在的普通文件，须在宿主 FileProvider 映射范围内；所有权仍归宿主。
     * @param authority 宿主 FileProvider 的非空 authority。
     * @param mimeType 非空 MIME 类型。
     * @param title chooser 标题，由宿主本地化。
     */
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
