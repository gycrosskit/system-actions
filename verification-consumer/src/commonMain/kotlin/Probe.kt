package consumer
import io.github.gycrosskit.systemactions.*
suspend fun probe(actions: SystemActions): List<ActionResult> = listOf(
    actions.dial("123"), actions.openExternalUrl("https://example.com"), actions.openAppSettings(),
    actions.openNativeAppStore(), actions.openNativeAppStore("consumer.example"),
    actions.openLocationSettings(), actions.openAppStore("https://store.example.com"),
)
