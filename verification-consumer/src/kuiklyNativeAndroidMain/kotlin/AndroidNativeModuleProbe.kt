package consumer

import com.tencent.kuikly.core.render.android.IKuiklyRenderExport
import io.github.gycrosskit.systemactions.kuikly.registerGycSystemActionsModule

fun registerSystemActionsNative(export: IKuiklyRenderExport, authority: String) =
    export.registerGycSystemActionsModule(authority)
