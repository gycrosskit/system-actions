package io.github.gycrosskit.systemactions

/** Requested 仅代表系统接受动作，不代表用户已完成拨号、购买或浏览。 */
enum class ActionResult { Requested, InvalidInput, Unavailable }

interface SystemActions {
    suspend fun dial(phone: String): ActionResult
    suspend fun openExternalUrl(url: String): ActionResult
    suspend fun openAppSettings(): ActionResult
    /** 商店详情的 HTTP(S) URL 由宿主按品牌与平台提供。 */
    suspend fun openAppStore(listingUrl: String): ActionResult = openExternalUrl(listingUrl)
}

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
