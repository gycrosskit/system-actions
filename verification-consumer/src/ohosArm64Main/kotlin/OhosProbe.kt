package consumer
import io.github.gycrosskit.systemactions.SystemActions
import io.github.gycrosskit.systemactions.kuikly.SystemActionsModule
fun create(): SystemActions = SystemActionsModule()
fun dispose(module: SystemActionsModule) = module.dispose()

suspend fun fileActions(module: SystemActionsModule, path: String) {
    module.copyText("consumer")
    module.shareFile(path, "Share")
    module.setKeepScreenOn(true)
    module.setKeepScreenOn(false)
}
