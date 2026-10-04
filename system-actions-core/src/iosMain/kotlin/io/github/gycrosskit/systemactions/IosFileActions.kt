package io.github.gycrosskit.systemactions

import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.cinterop.useContents
import platform.CoreGraphics.CGRectMake
import platform.Foundation.NSFileManager
import platform.Foundation.NSFileType
import platform.Foundation.NSFileTypeRegular
import platform.Foundation.NSThread
import platform.Foundation.NSURL
import platform.UIKit.UIActivityViewController
import platform.UIKit.UIPasteboard
import platform.UIKit.UIViewController
import platform.UIKit.popoverPresentationController

/** 在主线程调用；presenter 每次由宿主即时解析，不缓存旧 Scene 或业务根控制器。 */
@OptIn(ExperimentalForeignApi::class)
class IosFileActions(private val presenterResolver: () -> UIViewController?) {
    private var active: UIActivityViewController? = null
    private var completion: ((FileShareOutcome) -> Unit)? = null

    fun copyText(value: String): ActionResult {
        if (!NSThread.isMainThread) return ActionResult.Unavailable
        UIPasteboard.generalPasteboard.string = value
        return ActionResult.Requested
    }

    /** 返回值只表示展示受理；成功、取消和错误仅由系统 completion 交付。 */
    fun shareFile(path: String, title: String, onComplete: (FileShareOutcome) -> Unit): ActionResult {
        if (!NSThread.isMainThread || active != null) return ActionResult.Unavailable
        if (path.isBlank()) return ActionResult.InvalidInput
        if (NSFileManager.defaultManager.attributesOfItemAtPath(path, null)?.get(NSFileType) != NSFileTypeRegular) {
            return ActionResult.Unavailable
        }
        val presenter = presenterResolver() ?: return ActionResult.Unavailable
        if (presenter.view.window == null || presenter.isBeingDismissed() || presenter.isBeingPresented() ||
            presenter.presentedViewController != null) return ActionResult.Unavailable
        val controller = UIActivityViewController(listOf(NSURL.fileURLWithPath(path)), null)
        controller.title = title
        controller.popoverPresentationController?.apply {
            sourceView = presenter.view
            sourceRect = presenter.view.bounds.useContents { CGRectMake(size.width / 2, size.height / 2, 0.0, 0.0) }
            permittedArrowDirections = 0uL
        }
        active = controller
        completion = onComplete
        controller.completionWithItemsHandler = { _, completed, _, error ->
            if (active === controller) finish(when {
                error != null -> FileShareOutcome.Failed
                completed -> FileShareOutcome.Completed
                else -> FileShareOutcome.Cancelled
            })
        }
        presenter.presentViewController(controller, animated = true, completion = null)
        return ActionResult.Requested
    }

    /** 只关闭本实例的分享面板；生命周期销毁时调用，终态至多交付一次。 */
    fun close() {
        if (!NSThread.isMainThread) return
        val controller = active ?: return
        finish(FileShareOutcome.Cancelled)
        controller.dismissViewControllerAnimated(false, completion = null)
    }

    private fun finish(outcome: FileShareOutcome) {
        val callback = completion
        active?.completionWithItemsHandler = null
        active = null
        completion = null
        callback?.invoke(outcome)
    }
}
