@file:OptIn(kotlinx.cinterop.ExperimentalForeignApi::class, kotlin.concurrent.atomics.ExperimentalAtomicApi::class)

package io.github.gycrosskit.systemactions

import kotlinx.cinterop.ByteVar
import kotlinx.cinterop.CFunction
import kotlinx.cinterop.CPointer
import kotlinx.cinterop.readBytes
import kotlinx.cinterop.staticCFunction
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.concurrent.atomics.AtomicLong
import kotlin.concurrent.atomics.AtomicReference
import kotlinx.cinterop.invoke
import kotlin.coroutines.resume

/** App 私有 NAPI 安装后可从任意协程调用，不依赖 Kuikly 页面或 Renderer。 */
object OhosClipboardTextReader : ClipboardTextReader {
    private var read: CPointer<CFunction<(Long, CPointer<CFunction<(Int, CPointer<ByteVar>?, Int, Long) -> Unit>>?) -> Int>>? = null
    private var cancel: CPointer<CFunction<(Long) -> Unit>>? = null
    private val nextId = AtomicLong(0)
    private val requests = AtomicReference<Map<Long, kotlinx.coroutines.CancellableContinuation<ClipboardReadResult>>>(emptyMap())

    private fun remove(id: Long): kotlinx.coroutines.CancellableContinuation<ClipboardReadResult>? {
        while (true) {
            val current = requests.load()
            val pending = current[id] ?: return null
            if (requests.compareAndSet(current, current - id)) return pending
        }
    }

    private fun add(id: Long, pending: kotlinx.coroutines.CancellableContinuation<ClipboardReadResult>) {
        while (true) {
            val current = requests.load()
            if (requests.compareAndSet(current, current + (id to pending))) return
        }
    }

    /** 在 NativeManager 初始化阶段、任何读取前安装；函数指针在进程生命周期内有效。 */
    fun install(
        read: CPointer<CFunction<(Long, CPointer<CFunction<(Int, CPointer<ByteVar>?, Int, Long) -> Unit>>?) -> Int>>,
        cancel: CPointer<CFunction<(Long) -> Unit>>,
    ) {
        this.read = read
        this.cancel = cancel
    }

    override suspend fun readClipboardText(): ClipboardReadResult = suspendCancellableCoroutine { pending ->
        val dispatcher = read
        if (dispatcher == null) {
            pending.resume(ClipboardReadResult.Unavailable)
            return@suspendCancellableCoroutine
        }
        val id = nextId.addAndFetch(1L)
        add(id, pending)
        pending.invokeOnCancellation { remove(id); cancel?.invoke(id) }
        if (!pending.isActive) return@suspendCancellableCoroutine
        if (dispatcher(id, staticCFunction { status: Int, bytes: CPointer<ByteVar>?, length: Int, requestId: Long ->
                OhosClipboardTextReader.complete(status, bytes, length, requestId)
            }) == 0) {
            remove(id)?.resume(ClipboardReadResult.Unavailable)
        } else if (!pending.isActive) {
            cancel?.invoke(id)
        }
    }

    private fun complete(status: Int, bytes: CPointer<ByteVar>?, length: Int, id: Long) {
        val pending = remove(id) ?: return
        if (!pending.isActive) return
        val result = when (status) {
            0 -> if (bytes != null && length >= 0) ClipboardReadResult.Text(bytes.readBytes(length).decodeToString()) else ClipboardReadResult.Failed
            1 -> ClipboardReadResult.NoText
            2 -> ClipboardReadResult.Denied
            3 -> ClipboardReadResult.Unavailable
            else -> ClipboardReadResult.Failed
        }
        pending.resume(result)
    }
}
