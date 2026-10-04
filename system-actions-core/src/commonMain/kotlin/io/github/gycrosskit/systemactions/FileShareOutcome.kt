package io.github.gycrosskit.systemactions

/** 系统分享面板的终态，与表示面板受理的 [ActionResult.Requested] 分开。 */
enum class FileShareOutcome { Completed, Cancelled, Failed }
