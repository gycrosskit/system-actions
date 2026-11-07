#ifndef GYC_CLIPBOARD_BRIDGE_H
#define GYC_CLIPBOARD_BRIDGE_H
#include <napi/native_api.h>
#include <cstdint>
#include <memory>
#include <mutex>
#include <string>
#include <unordered_map>

// completion 的 bytes 只在回调期间有效，length 是 UTF-8 字节数（包含内嵌 NUL）。
using GycClipboardCompletion = void (*)(int32_t, const char *, int32_t, int64_t);
using GycClipboardRead = int32_t (*)(int64_t, GycClipboardCompletion);
using GycClipboardCancel = void (*)(int64_t);
using GycClipboardInstaller = void (*)(GycClipboardRead, GycClipboardCancel);
namespace gyc_clipboard {
struct Request { int64_t id; GycClipboardCompletion complete; };
struct State {
    std::mutex mutex;
    napi_threadsafe_function queue = nullptr;
    napi_ref actions = nullptr;
    napi_env env = nullptr;
    std::unordered_map<int64_t, std::shared_ptr<Request>> pending;
};
inline State state;
inline void Cancel(int64_t id) {
    std::lock_guard<std::mutex> lock(state.mutex);
    state.pending.erase(id);
}
inline bool Active(const std::shared_ptr<Request>& request) {
    std::lock_guard<std::mutex> lock(state.mutex);
    auto it = state.pending.find(request->id);
    return it != state.pending.end() && it->second == request;
}
inline void Finish(const std::shared_ptr<Request>& request, int32_t status, const std::string& text = {}) {
    {
        std::lock_guard<std::mutex> lock(state.mutex);
        auto it = state.pending.find(request->id);
        if (it == state.pending.end() || it->second != request) return;
        state.pending.erase(it);
    }
    request->complete(status, text.data(), static_cast<int32_t>(text.size()), request->id);
}
inline void FinalizeCallback(napi_env, void* data, void*) {
    delete static_cast<std::shared_ptr<Request>*>(data);
}
inline napi_value Complete(napi_env env, napi_callback_info info) {
    size_t count = 1;
    napi_value value = nullptr;
    void* data = nullptr;
    napi_get_cb_info(env, info, &count, &value, nullptr, &data);
    auto request = *static_cast<std::shared_ptr<Request>*>(data);
    if (!Active(request)) return nullptr;
    int32_t status = 4;
    std::string text;
    napi_value field;
    char label[16] = {};
    size_t length = 0;
    if (count && napi_get_named_property(env, value, "status", &field) == napi_ok &&
        napi_get_value_string_utf8(env, field, label, sizeof(label), &length) == napi_ok) {
        const std::string name(label, length);
        if (name == "no_text") status = 1;
        else if (name == "denied") status = 2;
        else if (name == "unavailable") status = 3;
        else if (name == "text" && napi_get_named_property(env, value, "value", &field) == napi_ok &&
                 napi_get_value_string_utf8(env, field, nullptr, 0, &length) == napi_ok && length <= INT32_MAX) {
            text.resize(length + 1);
            if (napi_get_value_string_utf8(env, field, text.data(), text.size(), &length) == napi_ok) {
                text.resize(length);
                status = 0;
            } else text.clear();
        }
    }
    Finish(request, status, text);
    return nullptr;
}
inline napi_value Reject(napi_env env, napi_callback_info info) {
    void* data = nullptr;
    napi_get_cb_info(env, info, nullptr, nullptr, nullptr, &data);
    Finish(*static_cast<std::shared_ptr<Request>*>(data), 4);
    return nullptr;
}
inline bool Callback(napi_env env, napi_callback cb, const std::shared_ptr<Request>& request, napi_value* out) {
    auto* data = new std::shared_ptr<Request>(request);
    if (napi_create_function(env, "clipboardCompletion", NAPI_AUTO_LENGTH, cb, data, out) != napi_ok) {
        delete data; return false;
    }
    if (napi_add_finalizer(env, *out, data, FinalizeCallback, nullptr, nullptr) != napi_ok) {
        // 没有 finalizer 时不让 JS 持有携带悬空 data 的函数。
        delete data; return false;
    }
    return true;
}
inline void CallJs(napi_env env, napi_value, void*, void* data) {
    std::unique_ptr<std::shared_ptr<Request>> owned(static_cast<std::shared_ptr<Request>*>(data));
    auto request = *owned;
    if (!env || !Active(request)) return;
    napi_value actions, method, promise, then, callbacks[2], ignored;
    bool isPromise = false;
    if (napi_get_reference_value(env, state.actions, &actions) != napi_ok ||
        napi_get_named_property(env, actions, "readClipboardText", &method) != napi_ok ||
        napi_call_function(env, actions, method, 0, nullptr, &promise) != napi_ok ||
        napi_is_promise(env, promise, &isPromise) != napi_ok || !isPromise ||
        napi_get_named_property(env, promise, "then", &then) != napi_ok ||
        !Callback(env, Complete, request, &callbacks[0]) || !Callback(env, Reject, request, &callbacks[1]) ||
        napi_call_function(env, promise, then, 2, callbacks, &ignored) != napi_ok) {
        bool pending = false;
        napi_is_exception_pending(env, &pending);
        if (pending) napi_get_and_clear_last_exception(env, &ignored);
        Finish(request, 4);
    }
}
inline int32_t Read(int64_t id, GycClipboardCompletion completion) {
    std::lock_guard<std::mutex> lock(state.mutex);
    if (!state.queue || !completion || state.pending.count(id)) return 0;
    auto request = std::make_shared<Request>(Request{id, completion});
    state.pending.emplace(id, request);
    auto* queued = new std::shared_ptr<Request>(request);
    if (napi_call_threadsafe_function(state.queue, queued, napi_tsfn_nonblocking) != napi_ok) {
        state.pending.erase(id); delete queued; return 0;
    }
    return 1;
}
inline void Cleanup(void*) {
    std::unordered_map<int64_t, std::shared_ptr<Request>> abandoned;
    {
        std::lock_guard<std::mutex> lock(state.mutex);
        abandoned.swap(state.pending);
        if (state.queue) napi_release_threadsafe_function(state.queue, napi_tsfn_abort);
        state.queue = nullptr;
        if (state.actions) napi_delete_reference(state.env, state.actions);
        state.actions = nullptr;
        state.env = nullptr;
    }
    for (const auto& entry : abandoned) entry.second->complete(3, nullptr, 0, entry.first);
}

} // namespace gyc_clipboard

// ArkTS 主线程调用一次，参数为当前 Ability 的原生 SystemActions；不接受 Renderer Module。
inline napi_value GycClipboardInstall(napi_env env, napi_callback_info info, GycClipboardInstaller install) {
    using namespace gyc_clipboard;
    size_t count = 1;
    napi_value actions, name;
    napi_get_cb_info(env, info, &count, &actions, nullptr, nullptr);
    std::lock_guard<std::mutex> lock(state.mutex);
    if (state.queue || !count || !install) {
        napi_throw_error(env, nullptr, "clipboard bridge requires one native actions instance and a single install");
        return nullptr;
    }
    if (napi_create_reference(env, actions, 1, &state.actions) != napi_ok ||
        napi_create_string_utf8(env, "nativeClipboard", NAPI_AUTO_LENGTH, &name) != napi_ok ||
        napi_create_threadsafe_function(env, nullptr, nullptr, name, 0, 1, nullptr, nullptr, nullptr, CallJs, &state.queue) != napi_ok) {
        if (state.actions) napi_delete_reference(env, state.actions);
        state.actions = nullptr;
        napi_throw_error(env, nullptr, "clipboard bridge installation failed");
        return nullptr;
    }
    state.env = env;
    napi_unref_threadsafe_function(env, state.queue);
    napi_add_env_cleanup_hook(env, Cleanup, nullptr);
    install(Read, Cancel);
    return nullptr;
}
#endif
