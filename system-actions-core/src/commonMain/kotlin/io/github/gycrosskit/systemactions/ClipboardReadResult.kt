package io.github.gycrosskit.systemactions

/** 只返回第一条记录的真实文本表示，原样保留空串、空白和控制字符；不转换 URI/Intent。 */
sealed interface ClipboardReadResult {
    data class Text(val value: String) : ClipboardReadResult
    data object NoText : ClipboardReadResult
    /** 仅用于系统明确报告的访问拒绝，无文本不推断为拒绝。 */
    data object Denied : ClipboardReadResult
    data object Unavailable : ClipboardReadResult
    data object Failed : ClipboardReadResult
}

/** 原生私有读取边界；OHOS 宿主注入 NAPI 实现，原文不得经过 Renderer。取消协程继续向上传播。 */
fun interface ClipboardTextReader {
    suspend fun readClipboardText(): ClipboardReadResult
}
