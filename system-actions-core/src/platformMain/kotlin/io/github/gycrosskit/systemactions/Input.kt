package io.github.gycrosskit.systemactions

internal fun normalizedPhone(value: String): String? {
    val phone = value.trim()
    if (!Regex("""\+?[0-9][0-9 ()-]{0,30}""").matches(phone)) return null
    return phone.filterNot { it == ' ' || it == '(' || it == ')' || it == '-' }
}
internal fun normalizedWebUrl(value: String): String? {
    val url = value.trim()
    if (url.any { it.isWhitespace() || it.code <= 31 || it.code == 127 || it == '\\' }) return null
    if (!url.startsWith("https://", true) && !url.startsWith("http://", true)) return null
    if (Regex("%(?![0-9A-Fa-f]{2})").containsMatchIn(url)) return null
    return url.takeIf { hasValidWebAuthority(it) }
}
internal expect fun hasValidWebAuthority(value: String): Boolean
