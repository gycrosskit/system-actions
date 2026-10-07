package io.github.gycrosskit.systemactions

import kotlin.test.*

class SharePathTest {
    @Test fun rejectsUrisRelativePathsNulAndDotSegmentsBeforeNativeShare() {
        for (path in listOf("", "/", "a.zip", "file:///a.zip", "/tmp/../a.zip", "/tmp/./a.zip", "/tmp//a.zip", "/tmp/a/", "/tmp/a\u0000.zip")) {
            assertFalse(isValidSharePath(path), path)
        }
        assertTrue(isValidSharePath("/tmp/诊断报告.zip"))
    }
}
