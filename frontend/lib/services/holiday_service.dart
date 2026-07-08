import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HolidayInfo {
  final DateTime date;
  final String name;
  final bool isHoliday;

  HolidayInfo({
    required this.date,
    required this.name,
    required this.isHoliday,
  });
}

class HolidayService extends ChangeNotifier {
  final Dio _dio = Dio();
  Map<String, HolidayInfo> _holidays = {};
  bool _loading = false;
  int? _cachedYear;

  Map<String, HolidayInfo> get holidays => _holidays;
  bool get loading => _loading;

  HolidayInfo? getHoliday(DateTime date) {
    final key = _dateKey(date);
    return _holidays[key];
  }

  bool isHoliday(DateTime date) {
    final h = getHoliday(date);
    return h?.isHoliday ?? false;
  }

  /// 是否显示节假日名称（只有节假日当天才显示，调休/连休的其余天数只标红不显示名称）
  bool isHolidayNameDay(DateTime date) {
    final h = getHoliday(date);
    if (h == null || !h.isHoliday) return false;
    final yesterday = date.subtract(const Duration(days: 1));
    final prev = getHoliday(yesterday);
    return prev?.name != h.name;
  }

  bool isWeekend(DateTime date) {
    if (isHoliday(date)) return true;
    final weekday = date.weekday;
    if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
      final h = getHoliday(date);
      if (h != null && !h.isHoliday) return false;
      return true;
    }
    return false;
  }

  Future<void> fetchHolidays(int year) async {
    if (_cachedYear == year && _holidays.isNotEmpty) return;

    _loading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('holidays_$year');
      if (cached != null) {
        _holidays = _parseHolidayData(cached, year);
        _cachedYear = year;
        _loading = false;
        notifyListeners();
      }

      final response = await _dio.get(
        'https://timor.tech/api/holiday/year/$year',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['code'] == 0 && data['holiday'] != null) {
          final holidayJson = jsonEncode(data['holiday']);
          await prefs.setString('holidays_$year', holidayJson);
          _holidays = _parseHolidayData(holidayJson, year);
          _cachedYear = year;
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch holidays: $e');
    }

    _loading = false;
    notifyListeners();
  }

  Map<String, HolidayInfo> _parseHolidayData(String jsonString, int year) {
    final map = <String, HolidayInfo>{};
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      for (final entry in data.entries) {
        final dateStr = entry.key;
        final info = entry.value as Map<String, dynamic>;
        // API keys may be "01-01" or "2026-01-01"
        late final DateTime date;
        if (dateStr.contains('-')) {
          final parts = dateStr.split('-');
          if (parts.length == 2) {
            date = DateTime(year, int.parse(parts[0]), int.parse(parts[1]));
          } else if (parts.length == 3) {
            date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          } else {
            continue;
          }
        } else {
          continue;
        }
        final key = _dateKey(date);
        map[key] = HolidayInfo(
          date: date,
          name: info['name']?.toString() ?? '',
          isHoliday: info['holiday'] == true,
        );
      }
    } catch (e) {
      debugPrint('Failed to parse holiday data: $e');
    }
    return map;
  }

  static String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
