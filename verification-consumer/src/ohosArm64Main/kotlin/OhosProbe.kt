package consumer
import io.github.gycrosskit.systemactions.SystemActions
import io.github.gycrosskit.systemactions.kuikly.SystemActionsModule
fun create(): SystemActions = SystemActionsModule()
fun dispose(module: SystemActionsModule) = module.dispose()
