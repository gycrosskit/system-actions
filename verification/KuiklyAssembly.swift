import SystemActionsConsumer
import GYCWindowPolicy
import UIKit

// 使用真实 Maven consumer framework 的生成 API；当前 presenter 仍由宿主解析。
@MainActor
func registerSystemActionsModuleFromShared(presenter: @escaping () -> UIViewController?) {
    GycSystemActionsModule.register { native in
        let files = IosFileActions(presenterResolver: presenter)
        let handler = IosSystemActionsModuleHandler(
            fileActions: files,
            setKeepScreenOn: native.setKeepScreenOn,
            observeKeyboardHeight: native.observeKeyboardHeight,
            observeDarkMode: native.observeDarkMode,
            disposeNative: native.dispose
        )
        return GycSystemActionsHandler(call: handler.call, dispose: handler.dispose)
    }
}

// 商店入口在宿主业务适配器中调用 Module.openAppStore(buildConfig.storeListingUrl)。
// 组件不推断 AppId；iOS openNativeAppStore 保持 Unavailable。
