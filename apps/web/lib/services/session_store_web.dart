// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

class SessionStore {
  static const _key = 'lumi_access_token';

  Future<String?> readToken() async => html.window.localStorage[_key];

  Future<void> writeToken(String token) async {
    html.window.localStorage[_key] = token;
  }

  Future<void> clearToken() async {
    html.window.localStorage.remove(_key);
  }
}
