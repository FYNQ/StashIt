// SPDX-License-Identifier: Apache-2.0
import 'package:http/http.dart' as http;

class Cloud {
  static String _baseUrl = '';
  static final http.Client _client = http.Client();
  static String? _bearer;

  // Call once in main():
  // await Cloud.init(apiBase: 'http://10.0.2.2:8000'); // emulator
  // await Cloud.init(apiBase: 'http://127.0.0.1:8000'); // dev server
  // await Cloud.init(apiBase: 'https://your-domain');   // prod
  static Future<void> init({required String apiBase}) async {
    _baseUrl = apiBase.trim().replaceAll(RegExp(r'/+$'), '');
  }

  static void setBearer(String? token) => _bearer = token;

  static Uri uri(String path, [Map<String, dynamic>? q]) {
    final u = Uri.parse('$_baseUrl$path');
    return q == null ? u : u.replace(queryParameters: q.map((k, v) => MapEntry(k, '$v')));
  }

  static Map<String, String> headersJson() => {
        'Content-Type': 'application/json',
        if (_bearer != null && _bearer!.isNotEmpty) 'Authorization': 'Bearer $_bearer',
      };

  static http.Client get client => _client;
}
