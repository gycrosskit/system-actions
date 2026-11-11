package io.github.gycrosskit.systemactions.kuikly

import android.app.Activity
import android.os.Looper
import android.view.WindowManager
import com.tencent.kuikly.core.render.android.IKuiklyRenderContext
import com.tencent.kuikly.core.render.android.IKuiklyRenderExport
import com.tencent.kuikly.core.render.android.export.IKuiklyRenderModuleExport
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.lang.reflect.Proxy
import kotlin.test.*

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class AndroidSystemActionsModuleTest {
    @Test fun actualSdkRegistrationInjectsHostStorePolicyWithoutChangingDefaultConstructor() {
        lateinit var factory: () -> IKuiklyRenderModuleExport
        val export = Proxy.newProxyInstance(javaClass.classLoader, arrayOf(IKuiklyRenderExport::class.java)) { _, method, args ->
            if (method.name == "moduleExport") {
                @Suppress("UNCHECKED_CAST")
                factory = args[1] as () -> IKuiklyRenderModuleExport
            }
            null
        } as IKuiklyRenderExport
        val ids = mutableListOf<String?>()
        export.registerGycSystemActionsModule(null) { id ->
            ids += id
            io.github.gycrosskit.systemactions.ActionResult.Requested
        }
        val module = factory() as AndroidSystemActionsModule
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        module.kuiklyRenderContext = Proxy.newProxyInstance(javaClass.classLoader, arrayOf(IKuiklyRenderContext::class.java)) { _, method, _ ->
            if (method.name == "getContext") activity else null
        } as IKuiklyRenderContext
        val replies = mutableListOf<Any?>()
        module.call("openNativeAppStore", "{\"requestId\":\"self\"}", replies::add)
        module.call("openNativeAppStore", "{\"requestId\":\"other\",\"value\":\"other.app\"}", replies::add)
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(listOf(null, "other.app"), ids)
        assertEquals(2, replies.size)
        module.onDestroy()
        module.call("openNativeAppStore", "{\"requestId\":\"late\"}", replies::add)
        assertEquals(2, ids.size)
        AndroidSystemActionsModule() // 旧无参构造与工厂仍可用。
    }

    @Test fun actualSdkFactoryCreatesDistinctOwnersAndDestroyRestoresOnlyOwnLease() {
        lateinit var factory: () -> IKuiklyRenderModuleExport
        val export = Proxy.newProxyInstance(javaClass.classLoader, arrayOf(IKuiklyRenderExport::class.java)) { _, method, args ->
            if (method.name == "moduleExport") {
                assertEquals(SystemActionsModule.NAME, args[0])
                @Suppress("UNCHECKED_CAST")
                factory = args[1] as () -> IKuiklyRenderModuleExport
            }
            null
        } as IKuiklyRenderExport
        export.registerGycSystemActionsModule()
        val first = factory() as AndroidSystemActionsModule
        val second = factory() as AndroidSystemActionsModule
        assertNotSame(first, second)
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val context = Proxy.newProxyInstance(javaClass.classLoader, arrayOf(IKuiklyRenderContext::class.java)) { _, method, _ ->
            if (method.name == "getContext") activity else null
        } as IKuiklyRenderContext
        first.kuiklyRenderContext = context
        second.kuiklyRenderContext = context
        val replies = mutableListOf<Any?>()
        first.call("setKeepScreenOn", "{\"requestId\":\"1\",\"value\":\"true\"}", replies::add)
        second.call("setKeepScreenOn", "{\"requestId\":\"1\",\"value\":\"true\"}", replies::add)
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(2, replies.size)
        assertTrue(activity.window.attributes.flags and WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON != 0)
        assertEquals(0, activity.window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE)
        first.onDestroy()
        assertTrue(activity.window.attributes.flags and WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON != 0)
        second.onDestroy()
        assertEquals(0, activity.window.attributes.flags and WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        first.call("copyText", "{\"requestId\":\"late\",\"value\":\"x\"}", replies::add)
        assertEquals(2, replies.size)
    }
}
