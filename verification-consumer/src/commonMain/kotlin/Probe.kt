package consumer
import io.github.gycrosskit.systemactions.*
suspend fun probe(actions: SystemActions): ActionResult = actions.openExternalUrl("https://example.com")
