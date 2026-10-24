package io.github.gycrosskit.systemactions

/** 系统分享面板的终态，与表示面板受理的 [ActionResult.Requested] 分开。 */
enum class FileShareOutcome {
    /** 系统分享 completion 确认用户完成动作，不证明远端接收成功。 */
    Completed,
    /** 用户取消或宿主关闭本次面板。 */
    Cancelled,
    /** 系统 completion 返回错误。 */
    Failed,
    /** 当前平台没有可靠终态回执，或等待超时；不能推断分享成功。 */
    Unknown,
}

/** 未受理时 outcome 为 null；Requested 与系统终态始终分别表达。 */
data class FileShareResult(val acceptance: ActionResult, val outcome: FileShareOutcome?)
