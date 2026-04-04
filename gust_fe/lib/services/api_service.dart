import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../constants.dart';
import 'auth_helper.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  static ApiService get instance => _instance;

  ApiService._internal();

  final http.Client _client = http.Client();
  final _offlineController = StreamController<bool>.broadcast();
  bool _isOffline = false;
  
  Stream<bool> get isOffline => _offlineController.stream;
  bool get isOfflineSync => _isOffline;

  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthHelper.getNetworkToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ... (methods get, post, put, patch, delete remain same) ...

  dynamic _handleResponse(http.Response response) {
    _isOffline = false;
    _offlineController.add(false); // We got a response, so we are online
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      try {
        return jsonDecode(response.body);
      } catch (_) {
        return response.body;
      }
    } else {
      throw ApiException(
        'Request failed: ${response.body}',
        response.statusCode,
      );
    }
  }

  Exception _handleError(dynamic error) {
    if (error is ApiException) return error;
    _isOffline = true;
    _offlineController.add(true); // Network error implies offline
    return ApiException('Network error: $error');
  }

  Future<dynamic> get(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      );
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> post(String endpoint, dynamic body) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      );
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> put(String endpoint, dynamic body) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      );
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> patch(String endpoint, dynamic body) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.patch(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      );
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }


  Future<dynamic> delete(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      );
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }


}
