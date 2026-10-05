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
        assertEquals(ActionResult.Unavailable, actions.openNativeAppStore())
    }

    @Test fun authorityPortsIpv6AndEscapedPathsPreserveValidInputs() {
        for (url in listOf("HTTPS://example.com:1/path%20name", "http://example.com:65535", "https://[::1]/?q=%E4%B8%AD")) {
            assertEquals(url, normalizedWebUrl(" $url "))
        }
        for (url in listOf("https://example.com:0", "https://example.com:-1", "https://user:pass@example.com",
            "https://example.com/%", "https://example.com/\u0000", "https://[broken]/")) {
            assertNull(normalizedWebUrl(url), url)
        }
        assertEquals("1".repeat(31), normalizedPhone("1".repeat(31)))
        assertNull(normalizedPhone("+"))
        assertNull(normalizedPhone("١٢٣"), "dial protocol accepts ASCII digits only")
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
