package io.github.gycrosskit.systemactions

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class AndroidSystemActions(private val context: Context) : SystemActions {
    override suspend fun dial(phone: String): ActionResult {
        val normalized = normalizedPhone(phone) ?: return ActionResult.InvalidInput
        return launch(Intent(Intent.ACTION_DIAL, Uri.fromParts("tel", normalized, null)))
    }
    override suspend fun openExternalUrl(url: String): ActionResult {
        val normalized = normalizedWebUrl(url) ?: return ActionResult.InvalidInput
        return launch(Intent(Intent.ACTION_VIEW, Uri.parse(normalized)))
    }
    override suspend fun openAppSettings(): ActionResult = launch(
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null))
    )
    private suspend fun launch(intent: Intent): ActionResult = withContext(Dispatchers.Main.immediate) {
        try {
            if (context !is Activity) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            ActionResult.Requested
        } catch (_: RuntimeException) { ActionResult.Unavailable }
    }
}
