package io.github.gycrosskit.systemactions

internal actual fun hasValidWebAuthority(value: String): Boolean = try {
    val uri = java.net.URI(value)
    !uri.host.isNullOrEmpty() && uri.rawUserInfo == null && (uri.port == -1 || uri.port in 1..65535)
} catch (_: java.net.URISyntaxException) { false }
