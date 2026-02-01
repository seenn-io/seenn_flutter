/// Connection state for polling
enum SeennConnectionState {
  /// Not connected
  disconnected,

  /// Attempting to connect
  connecting,

  /// Connected and polling
  connected,

  /// Connection lost, attempting to reconnect
  reconnecting;

  /// Check if currently connected
  bool get isConnected => this == connected;

  /// Check if actively trying to connect
  bool get isConnecting => this == connecting || this == reconnecting;
}
