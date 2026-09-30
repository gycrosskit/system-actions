package io.github.gycrosskit.systemactions
import kotlin.test.*
import kotlinx.coroutines.runBlocking
class InputTest {
    @Test fun existingImplementationsDefaultToUnavailableLocationSettings() = runBlocking {
        val actions = object : SystemActions {
            override suspend fun dial(phone: String) = ActionResult.Requested
            override suspend fun openExternalUrl(url: String) = ActionResult.Requested
            override suspend fun openAppSettings() = ActionResult.Requested
        }
        assertEquals(ActionResult.Unavailable, actions.openLocationSettings())
    }

    @Test fun validatesInputsBeforeAnySystemAction() {
        assertEquals("+8613812345678", normalizedPhone(" +86 138-1234-5678 "))
        listOf("", "tel:123", "*123#", "123;456", "12\n34", "1".repeat(32)).forEach { assertNull(normalizedPhone(it)) }
        assertEquals("https://example.com/path?q=1", normalizedWebUrl("https://example.com/path?q=1"))
        listOf("javascript:alert(1)", "https://", "http:///x", "https://a@b.com", "https://a.com\\evil", "https://a.com/ x", "https://a.com:99999", "https://a.com/%ZZ").forEach {
            assertNull(normalizedWebUrl(it), it)
        }
    }
}
