package io.github.gycrosskit.systemactions.kuikly

import com.tencent.kuikly.core.nvi.serialization.json.JSONObject
import io.github.gycrosskit.systemactions.ActionResult
import io.github.gycrosskit.systemactions.SystemActions
import kotlinx.coroutines.*
import kotlinx.coroutines.test.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import kotlin.coroutines.resume
import kotlin.test.*

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class SystemActionsHandlerTest {
    private open class Actions : SystemActions {
        var copied: String? = null
        override suspend fun copyText(value: String): ActionResult { copied = value; return ActionResult.Requested }
        override suspend fun shareFile(path: String, title: String) = ActionResult.Requested
        override suspend fun dial(phone: String) = ActionResult.Requested
        override suspend fun openExternalUrl(url: String) = ActionResult.Requested
        override suspend fun openAppSettings() = ActionResult.Requested
        override suspend fun openNativeAppStore(applicationId: String?) = ActionResult.Unavailable
    }

    @Test fun validatesParametersAndPreservesEmptyClipboardText() = runTest {
        Dispatchers.setMain(UnconfinedTestDispatcher(testScheduler))
        val actions = Actions()
        val handler = SystemActionsHandler(actions, { true }, { {} }, { {} }, {})
        val replies = mutableListOf<String>()
        try {
            handler.call("copyText", "{\"requestId\":\"1\",\"value\":\"\"}", replies::add)
            assertEquals("", actions.copied)
            assertEquals("requested", JSONObject(replies.last()).optString("status"))
            handler.call("copyText", "{\"requestId\":\"2\",\"value\":3}", replies::add)
            assertEquals("invalid_input", JSONObject(replies.last()).optString("status"))
            handler.call("shareFile", "{\"requestId\":\"3\",\"value\":\"/tmp/a\"}", replies::add)
            assertEquals("invalid_input", JSONObject(replies.last()).optString("status"))
            handler.call("copyText", "bad json", replies::add)
            assertEquals("invalid_input", JSONObject(replies.last()).optString("status"))
        } finally { handler.dispose(); Dispatchers.resetMain() }
    }

    @Test fun cancellationDisposalAndDuplicateIdDoNotDeliverLateSuccess() = runTest {
        Dispatchers.setMain(UnconfinedTestDispatcher(testScheduler))
        lateinit var continuation: CancellableContinuation<ActionResult>
        val actions = object : Actions() {
            override suspend fun dial(phone: String) = suspendCancellableCoroutine { continuation = it }
        }
        var closed = 0
        val handler = SystemActionsHandler(actions, { true }, { {} }, { {} }, { closed++ })
        val replies = mutableListOf<String>()
        try {
            handler.call("dial", "{\"requestId\":\"a\",\"value\":\"10086\"}", replies::add)
            handler.call("dial", "{\"requestId\":\"a\",\"value\":\"10086\"}", replies::add)
            assertEquals("invalid_input", JSONObject(replies.single()).optString("status"))
            handler.call("cancel", "{\"requestId\":\"a\"}", replies::add)
            assertTrue(continuation.isCancelled)
            continuation.resume(ActionResult.Requested)
            assertEquals(1, replies.size)
            handler.call("dial", "{\"requestId\":\"b\",\"value\":\"10086\"}", replies::add)
            handler.call("dispose", "", replies::add)
            assertTrue(continuation.isCancelled)
            handler.dispose()
            assertEquals(1, closed)
            handler.call("copyText", "{}", replies::add)
            assertEquals(1, replies.size)
        } finally { handler.dispose(); Dispatchers.resetMain() }
    }

    @Test fun oldStopAndLateObserverCannotAffectReplacement() = runTest {
        Dispatchers.setMain(UnconfinedTestDispatcher(testScheduler))
        val observers = mutableListOf<(Float) -> Unit>()
        var stopped = 0
        val handler = SystemActionsHandler(Actions(), { true }, { change ->
            observers += change
            change(0f)
            val stop: () -> Unit = { stopped++ }
            stop
        }, { {} }, {})
        val replies = mutableListOf<String>()
        try {
            handler.call("observeKeyboardHeight", "{\"requestId\":\"old\"}", replies::add)
            handler.call("observeKeyboardHeight", "{\"requestId\":\"new\"}", replies::add)
            handler.call("stopKeyboardHeight", "{\"requestId\":\"old\"}", replies::add)
            observers[0](300f)
            observers[1](100f)
            assertEquals(1, stopped)
            assertEquals(3, replies.size)
            assertEquals(100.0, JSONObject(replies.last()).optDouble("height"))
            handler.dispose()
            observers[1](200f)
            assertEquals(2, stopped)
            assertEquals(3, replies.size)
        } finally { handler.dispose(); Dispatchers.resetMain() }
    }
}
