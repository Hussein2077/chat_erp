/// Model representing a server‑sent event for the chat list.
/// Currently the UI only needs to know that *something* changed, so the
/// class is intentionally minimal. Extend it later if the backend sends
/// additional fields (e.g., event type, chat id, timestamp).
class GlobalChatEvent {
  GlobalChatEvent();

  /// Factory constructor to create an instance from JSON.
  /// The backend SSE payload is a JSON object; we ignore its contents for now.
  factory GlobalChatEvent.fromJson(Map<String, dynamic> json) =>
      GlobalChatEvent();

  /// Convert the instance back to JSON (not used at the moment).
  Map<String, dynamic> toJson() => {};
}
