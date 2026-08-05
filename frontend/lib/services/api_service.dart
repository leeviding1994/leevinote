import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:leevinote/utils/constants.dart';

class ApiService {
  late Dio _dio;
  VoidCallback? onUnauthorized;

  ApiService({this.onUnauthorized}) {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _readToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 ||
            error.response?.statusCode == 403) {
          final token = await _readToken();
          if (token != null) {
            await _deleteToken();
            onUnauthorized?.call();
          }
        }
        handler.next(error);
      },
    ));
  }

  Future<String?> _readToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('jwt_token');
    }
    const storage = FlutterSecureStorage();
    return storage.read(key: 'jwt_token');
  }

  Future<void> _deleteToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('jwt_token');
    } else {
      const storage = FlutterSecureStorage();
      await storage.delete(key: 'jwt_token');
    }
  }

  Future<Map<String, dynamic>> post(
      String path, Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(path, data: jsonEncode(data));
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<dynamic>> getList(String path) async {
    try {
      final response = await _dio.get(path);
      final data = response.data;
      if (data is List) return data;
      if (data is Map && data['content'] is List) {
        final items = List<dynamic>.from(data['content'] as List);
        final totalPages = (data['totalPages'] ?? data['total_pages']) as int?;
        final currentPage = data['number'] as int? ?? 0;
        if (totalPages == null || currentPage >= totalPages - 1) {
          return items;
        }

        final separator = path.contains('?') ? '&' : '?';
        for (var page = currentPage + 1; page < totalPages; page++) {
          final pageResponse = await _dio.get('$path${separator}page=$page');
          final pageData = pageResponse.data;
          if (pageData is Map && pageData['content'] is List) {
            items.addAll(pageData['content'] as List);
          }
        }
        return items;
      }
      throw 'Unexpected list response';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getPage(String path,
      {int page = 0, int size = 50}) async {
    try {
      final separator = path.contains('?') ? '&' : '?';
      final response = await _dio.get('$path${separator}page=$page&size=$size');
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw 'Unexpected page response';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> get(String path) async {
    try {
      final response = await _dio.get(path);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> uploadFile(String path, String filePath) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.post(path, data: formData);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> uploadBytes(
      String path, Uint8List bytes, String filename) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final response = await _dio.post(path, data: formData);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> put(
      String path, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put(path, data: jsonEncode(data));
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> delete(String path) async {
    try {
      final response = await _dio.delete(path);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> patch(String path,
      {Map<String, dynamic>? data}) async {
    try {
      final response =
          await _dio.patch(path, data: data != null ? jsonEncode(data) : null);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.response != null) {
      final data = e.response?.data;
      final statusCode = e.response?.statusCode;

      if (data is Map) {
        final msg = data['message'];
        if (msg != null && msg.toString().isNotEmpty) {
          return msg.toString();
        }
        final error = data['error'];
        if (error != null && error.toString().isNotEmpty) {
          return error.toString();
        }
      } else {
        final str = data?.toString();
        if (str != null && str.isNotEmpty) {
          return str;
        }
      }
      return statusCode != null
          ? 'Request failed ($statusCode)'
          : 'Request failed';
    }

    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '无法连接服务器（${ApiConstants.baseUrl}），请确认后端已启动';
      case DioExceptionType.badCertificate:
        return '服务器证书校验失败（${ApiConstants.baseUrl}）';
      default:
        final message = e.message ?? '';
        if (message.contains('CERTIFICATE') ||
            message.contains('HandshakeException') ||
            message.contains('SSL')) {
          return '无法建立安全连接（${ApiConstants.baseUrl}）';
        }
        return message.isNotEmpty ? message : 'Network error';
    }
  }
}
