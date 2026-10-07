package consumer
import android.content.Context
import io.github.gycrosskit.systemactions.AndroidSystemActions
fun createWithFiles(context: Context, providerAuthority: String) = AndroidSystemActions(context, providerAuthority)
