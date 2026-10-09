package consumer

import io.github.gycrosskit.systemactions.IosFileActions
import io.github.gycrosskit.systemactions.kuikly.IosSystemActionsModuleHandler
import platform.Foundation.NSNumber

fun systemActionsNativeHandler(
    fileActions: IosFileActions,
    keepScreenOn: (NSNumber) -> NSNumber,
    keyboard: ((NSNumber) -> NSNumber) -> (() -> NSNumber),
    darkMode: ((NSNumber) -> NSNumber) -> (() -> NSNumber),
    dispose: () -> Unit,
) = IosSystemActionsModuleHandler(fileActions, keepScreenOn, keyboard, darkMode, dispose)
