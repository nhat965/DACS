class SessionStore {
  static String? _token;

  Future<String?> readToken() async => _token;

  Future<void> writeToken(String token) async {
    _token = token;
  }

  Future<void> clearToken() async {
    _token = null;
  }
}
