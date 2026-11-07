#include "../system-actions-native/src/main/resources/rawfile/native/gyc_clipboard_bridge.h"
#include <cassert>
#include <thread>

static int calls = 0;
static std::string received;
static void Receive(int32_t status, const char* text, int32_t size, int64_t id) {
    assert(status == 0 && id == 1);
    received.assign(text, size);
    ++calls;
}
int main() {
    using namespace gyc_clipboard;
    auto first = std::make_shared<Request>(Request{1, Receive});
    state.pending.emplace(1, first);
    const std::string text("a\0b", 3);
    std::thread background([&] { Finish(first, 0, text); });
    background.join();
    assert(calls == 1 && received == text);
    Finish(first, 0, "late");
    assert(calls == 1);
    auto cancelled = std::make_shared<Request>(Request{2, Receive});
    state.pending.emplace(2, cancelled);
    Cancel(2);
    Finish(cancelled, 0, "must not deliver");
    assert(calls == 1 && state.pending.empty());
    auto replaced = std::make_shared<Request>(Request{1, Receive});
    state.pending.emplace(1, replaced);
    Finish(first, 0, "old request");
    assert(calls == 1 && Active(replaced));
    Cancel(1);
}
