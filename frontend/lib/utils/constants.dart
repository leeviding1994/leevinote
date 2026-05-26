import 'package:flutter/foundation.dart';

class ApiConstants {
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:8080/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://localhost:8080/api';
    }
    return 'http://localhost:8080/api';
  }

  static const String signup = '/auth/signup';
  static const String login = '/auth/login';
  static const String notes = '/notes';
  static const String alarms = '/alarms';
  static const String music = '/music';
  static const String videos = '/videos';
  static const String schedules = '/schedules';
}
