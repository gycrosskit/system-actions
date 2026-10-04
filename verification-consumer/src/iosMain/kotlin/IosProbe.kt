package consumer
import io.github.gycrosskit.systemactions.IosSystemActions
fun create() = IosSystemActions()

@OptIn(kotlinx.cinterop.ExperimentalForeignApi::class)
fun fileActions(presenter: () -> platform.UIKit.UIViewController?) =
    io.github.gycrosskit.systemactions.IosFileActions(presenter)
