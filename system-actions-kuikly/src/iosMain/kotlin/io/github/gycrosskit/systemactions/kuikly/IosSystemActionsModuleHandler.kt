package io.github.gycrosskit.systemactions.kuikly

import io.github.gycrosskit.systemactions.ActionResult
import io.github.gycrosskit.systemactions.IosFileActions
import io.github.gycrosskit.systemactions.IosSystemActions
import kotlinx.cinterop.ExperimentalForeignApi
import platform.Foundation.NSNumber

/** 由宿主已有 Shared framework 导出；Pod receiver 在 Main 调用，不打包第二份 Kotlin runtime。
 * native 闭包取组件 GYCSystemActionsNativeServices，文件服务解析当前 presenter。 */
@OptIn(ExperimentalForeignApi::class)
class IosSystemActionsModuleHandler(
    fileActions: IosFileActions,
    setKeepScreenOn: (NSNumber) -> NSNumber,
    observeKeyboardHeight: ((NSNumber) -> NSNumber) -> (() -> NSNumber),
    observeDarkMode: ((NSNumber) -> NSNumber) -> (() -> NSNumber),
    disposeNative: () -> Unit,
) {
    private var openNativeAppStore: (suspend (String?) -> ActionResult)? = null
    private val actions = IosSystemActions(fileActions)

    /** 由 Kotlin 宿主装配品牌商店策略；旧 Swift 构造入口和缺省不可用合同保持不变。 */
    constructor(
        fileActions: IosFileActions,
        setKeepScreenOn: (NSNumber) -> NSNumber,
        observeKeyboardHeight: ((NSNumber) -> NSNumber) -> (() -> NSNumber),
        observeDarkMode: ((NSNumber) -> NSNumber) -> (() -> NSNumber),
        disposeNative: () -> Unit,
        openNativeAppStore: suspend (String?) -> ActionResult,
    ) : this(fileActions, setKeepScreenOn, observeKeyboardHeight, observeDarkMode, disposeNative) {
        this.openNativeAppStore = openNativeAppStore
    }

    // 嵌套函数的 Unit 会导出 KotlinUnit；Foundation 回执让 Swift 方法引用无需宿主转换。
    private val handler = SystemActionsHandler(actions,
        { enabled -> setKeepScreenOn(NSNumber(bool = enabled)).boolValue },
        { change ->
            val stop = observeKeyboardHeight { change(it.floatValue); NSNumber(bool = true) }
            val cancel: () -> Unit = { stop(); Unit }
            cancel
        },
        { change ->
            val stop = observeDarkMode { change(it.boolValue); NSNumber(bool = true) }
            val cancel: () -> Unit = { stop(); Unit }
            cancel
        },
        { openNativeAppStore = null; fileActions.close(); disposeNative() },
        { id -> openNativeAppStore?.invoke(id) ?: actions.openNativeAppStore(id) })

    fun call(method: String, params: String, callback: (String) -> Unit) = handler.call(method, params, callback)
    fun dispose() = handler.dispose()
}
