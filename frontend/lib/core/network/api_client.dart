import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, [this.statusCode = 500]);

  @override
  String toString() => message;
}

class ApiClient {
  static Uri _buildUri(String path, [Map<String, String>? queryParams]) {
    final cleanParams = <String, String>{};
    if (queryParams != null) {
      queryParams.forEach((key, value) {
        if (value.trim().isNotEmpty) {
          cleanParams[key] = value.trim();
        }
      });
    }
    return Uri.parse('${AppConfig.apiBaseUrl}$path').replace(
      queryParameters: cleanParams.isEmpty ? null : cleanParams,
    );
  }

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    Map<String, dynamic> body = {};
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      body = {'detail': response.body};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    final errorMsg = body['detail']?.toString() ??
        body['message']?.toString() ??
        'Request failed with status ${response.statusCode}';
    throw ApiException(errorMsg, response.statusCode);
  }

  static Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    final response = await http.get(_buildUri(path, queryParams));
    return _decodeResponse(response);
  }

  static Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await http.post(
      _buildUri(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body ?? {}),
    );
    return _decodeResponse(response);
  }

  static Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await http.put(
      _buildUri(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body ?? {}),
    );
    return _decodeResponse(response);
  }

  static Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await http.patch(
      _buildUri(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body ?? {}),
    );
    return _decodeResponse(response);
  }

  static Future<Map<String, dynamic>> delete(String path) async {
    final response = await http.delete(_buildUri(path));
    return _decodeResponse(response);
  }
}