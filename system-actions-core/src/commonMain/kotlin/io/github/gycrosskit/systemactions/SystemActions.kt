package io.github.gycrosskit.systemactions

/** Requested 仅代表系统接受动作，不代表用户已完成拨号、购买或浏览。 */
enum class ActionResult {
    /** 系统受理动作，不是用户操作的完成回执。 */
    Requested,
    /** 输入格式不允许，尚未调用系统。 */
    InvalidInput,
    /** 系统不支持、拒绝或无法启动。 */
    Unavailable,
}

/** 宿主系统动作；平台自动切到主线程，Kuikly 实现在页面 Context 调用。取消不撤回已受理的系统动作。 */
interface SystemActions {
    /** 原样写剪贴板；Requested 只表示写入受理，允许空文本，不读取剪贴板。 */
    suspend fun copyText(value: String): ActionResult = ActionResult.Unavailable
    /**
     * 分享宿主拥有的普通文件，Requested 只表示面板受理，不表示用户完成分享。
     * @param path 绝对本地路径，不接受 URI、空路径或点段；文件所有权仍归宿主。
     * @param title 分享标题，由宿主本地化。
     * Android 须配置宿主 FileProvider；iOS 须提供有当前 presenter 的 IosFileActions 并管理其 close。
     */
    suspend fun shareFile(path: String, title: String): ActionResult = ActionResult.Unavailable

    /**
     * 打开系统拨号入口；不表示电话已接通。
     * @param phone 允许可选前导 +、数字及空格/括号/连字符，trim 后数字与分隔部分总长最多 31。
     */
    suspend fun dial(phone: String): ActionResult
    /**
     * 交给外部系统处理 HTTP(S) URL；拒绝凭据、空白、控制字符、反斜杠和非法百分号编码。
     * @param url 完整且有 host 的地址，显式端口范围 1..65535；文案和品牌归宿主。
     */
    suspend fun openExternalUrl(url: String): ActionResult
    /** 打开当前宿主应用设置页；返回只说明系统受理。 */
    suspend fun openAppSettings(): ActionResult
    /** Android 打开系统定位服务设置；iOS/OHOS 当前未建立可靠公开的全局定位设置入口，返回 Unavailable。 */
    suspend fun openLocationSettings(): ActionResult = ActionResult.Unavailable
    /** 打开宿主提供的品牌商店详情。@param listingUrl 与 openExternalUrl 相同的 HTTP(S) 地址契约。 */
    suspend fun openAppStore(listingUrl: String): ActionResult = openExternalUrl(listingUrl)
    /**
     * Android 厂商商店 / OHOS AppGallery；iOS 不支持。
     * @param applicationId null 使用当前应用标识；非 null 为最多 255 字符的点分应用 ID，不接受 URI。
     */
    suspend fun openNativeAppStore(applicationId: String? = null): ActionResult = ActionResult.Unavailable
}

/** 公共边界只验证路径形状；文件存在、Provider/沙箱权限仍由原生验证。 */
internal fun isValidSharePath(path: String): Boolean =
    path.startsWith('/') && '\u0000' !in path && path.drop(1).split('/').all { it.isNotEmpty() && it != "." && it != ".." }
