package consumer
import io.github.gycrosskit.systemactions.IosFileActions
import io.github.gycrosskit.systemactions.IosSystemActions
// 宿主离开时关闭传入的文件服务，共同服务不创建额外窗口 owner。
fun createWithFiles(files: IosFileActions) = IosSystemActions(files)
