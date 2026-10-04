package consumer
import android.content.Context
import android.view.Window
import io.github.gycrosskit.systemactions.AndroidSystemActions
import io.github.gycrosskit.systemactions.AndroidWindowPolicy
fun create(context: Context) = AndroidSystemActions(context)
fun windowPolicy(window: Window) {
    val lease = AndroidWindowPolicy.acquire(window)
    lease.update(screenRecordingAllowed = true)
    lease.close()
}

fun fileActions(context: Context) = io.github.gycrosskit.systemactions.AndroidFileActions(context)
