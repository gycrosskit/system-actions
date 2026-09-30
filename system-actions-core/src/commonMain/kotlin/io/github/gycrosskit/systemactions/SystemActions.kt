package io.github.gycrosskit.systemactions

/** Requested 仅代表系统接受动作，不代表用户已完成拨号、购买或浏览。 */
enum class ActionResult { Requested, InvalidInput, Unavailable }

interface SystemActions {
    suspend fun dial(phone: String): ActionResult
    suspend fun openExternalUrl(url: String): ActionResult
    suspend fun openAppSettings(): ActionResult
    /** Android 打开系统定位服务设置；iOS/OHOS 无独立公开入口，返回 Unavailable。 */
    suspend fun openLocationSettings(): ActionResult = ActionResult.Unavailable
    /** 商店详情的 HTTP(S) URL 由宿主按品牌与平台提供。 */
    suspend fun openAppStore(listingUrl: String): ActionResult = openExternalUrl(listingUrl)
}
