package consumer
import io.github.gycrosskit.systemactions.*
suspend fun probeFileActions(actions: SystemActions): List<ActionResult> = listOf(
    actions.copyText("consumer"), actions.shareFile("/sandbox/diagnostics.zip", "Share"),
)
