package io.github.gycrosskit.systemactions

/** 系统分享面板的终态，与表示面板受理的 [ActionResult.Requested] 分开。 */
enum class FileShareOutcome {
    /** 系统分享 completion 确认用户完成动作，不证明远端接收成功。 */
    Completed,
    /** 用户取消或宿主关闭本次面板。 */
    Cancelled,
    /** 系统 completion 返回错误。 */
    Failed,
}
