import 'package:flutter/foundation.dart';
import 'package:leevinote/models/health_entry.dart';
import 'package:leevinote/services/database_helper.dart';

class LocalHealthService extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  List<HealthEntry> _entries = [];
  List<MealEntry> _meals = [];
  bool _loaded = false;

  List<HealthEntry> get entries => List.unmodifiable(_entries);
  List<MealEntry> get meals => List.unmodifiable(_meals);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _load();
    _loaded = true;
  }

  Future<void> _load() async {
    try {
      final entryRows = await _db.getAllHealthEntries();
      final mealRows = await _db.getAllMealEntries();
      _entries = entryRows.map(_entryFromRow).toList();
      _meals = mealRows.map(_mealFromRow).toList();
    } catch (e, st) {
      debugPrint('加载健康数据失败: $e\n$st');
      rethrow;
    }
  }

  HealthEntry? entryForDate(DateTime date) {
    final day = _dayOnly(date);
    for (final entry in _entries) {
      if (_dayOnly(entry.entryDate) == day) return entry;
    }
    return null;
  }

  List<MealEntry> mealsForDate(DateTime date) {
    final day = _dayOnly(date);
    return _meals.where((meal) => _dayOnly(meal.mealDate) == day).toList();
  }

  List<HealthEntry> recentEntries({int limit = 14}) {
    return _entries.take(limit).toList();
  }

  Future<void> saveWeight(
      {required DateTime date, required double weightKg}) async {
    await ensureLoaded();
    final existing = entryForDate(date);
    final entry = existing == null
        ? HealthEntry(entryDate: _dayOnly(date), weightKg: weightKg)
        : existing.copyWith(weightKg: () => weightKg);
    await _db.insertHealthEntry(_entryToRow(entry));
    _upsertEntry(entry);
    notifyListeners();
  }

  Future<void> saveBodyPhoto({
    required DateTime date,
    required String photoPath,
    double? currentWeightKg,
  }) async {
    await ensureLoaded();
    final existing = entryForDate(date);
    final estimatedBodyFat = _estimateBodyFat(
      currentWeightKg ?? existing?.weightKg,
      _entries.length,
    );
    final entry = existing == null
        ? HealthEntry(
            entryDate: _dayOnly(date),
            weightKg: currentWeightKg,
            bodyPhotoPath: photoPath,
            estimatedBodyFatPercent: estimatedBodyFat,
            bodyAnalysisNote: _bodyAnalysisNote(estimatedBodyFat),
          )
        : existing.copyWith(
            weightKg: () => currentWeightKg ?? existing.weightKg,
            bodyPhotoPath: () => photoPath,
            estimatedBodyFatPercent: () => estimatedBodyFat,
            bodyAnalysisNote: () => _bodyAnalysisNote(estimatedBodyFat),
          );
    await _db.insertHealthEntry(_entryToRow(entry));
    _upsertEntry(entry);
    notifyListeners();
  }

  Future<void> addMeal(MealEntry meal) async {
    await ensureLoaded();
    await _db.insertMealEntry(_mealToRow(meal));
    _meals.insert(0, meal);
    notifyListeners();
  }

  Future<void> deleteMeal(String localId) async {
    await ensureLoaded();
    await _db.deleteMealEntry(localId);
    _meals.removeWhere((meal) => meal.localId == localId);
    notifyListeners();
  }

  MealEstimate estimateMeal({
    required String title,
    String? description,
    String? photoPath,
  }) {
    final text = '${title.toLowerCase()} ${description?.toLowerCase() ?? ''}';
    var calories = 420.0;
    var protein = 24.0;
    var carbs = 48.0;
    var fat = 14.0;

    const calorieHints = <String, double>{
      '沙拉': 260,
      '鸡胸': 360,
      '牛肉': 560,
      '米饭': 520,
      '面': 620,
      '汉堡': 720,
      '奶茶': 420,
      '咖啡': 90,
      '蛋': 180,
      '鱼': 430,
      '火锅': 900,
      '披萨': 780,
      '粥': 240,
    };
    for (final entry in calorieHints.entries) {
      if (text.contains(entry.key)) {
        calories = entry.value;
        break;
      }
    }
    if (photoPath != null) calories += 35;
    if (text.contains('大份')) calories *= 1.25;
    if (text.contains('小份')) calories *= 0.75;

    protein = (calories * 0.22 / 4).roundToDouble();
    carbs = (calories * 0.48 / 4).roundToDouble();
    fat = (calories * 0.30 / 9).roundToDouble();

    return MealEstimate(
      calories: calories.roundToDouble(),
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
      note: photoPath == null
          ? '基于食物名称和描述估算，可在保存前手动调整。'
          : '照片仅作为餐食凭证；当前版本仍按名称、描述和常见份量粗略估算。',
    );
  }

  void _upsertEntry(HealthEntry entry) {
    final index = _entries.indexWhere((e) => e.localId == entry.localId);
    if (index == -1) {
      _entries.insert(0, entry);
    } else {
      _entries[index] = entry;
    }
    _entries.sort((a, b) => b.entryDate.compareTo(a.entryDate));
  }

  double _estimateBodyFat(double? weightKg, int sampleCount) {
    final base = weightKg == null ? 20.0 : 12.0 + (weightKg / 10.0);
    final sampleAdjustment = (sampleCount % 4) * 0.4;
    return double.parse(
        (base + sampleAdjustment).clamp(10.0, 34.0).toStringAsFixed(1));
  }

  String _bodyAnalysisNote(double bodyFat) {
    const disclaimer = '该数值为简化公式粗略估算，不构成医疗建议。';
    if (bodyFat < 15) return '估算值偏低，建议关注恢复和充足摄入。$disclaimer';
    if (bodyFat < 22) return '估算值处于常见区间，建议维持稳定饮食和训练节奏。$disclaimer';
    return '估算值偏高，可持续记录趋势并增加日常活动量。$disclaimer';
  }

  HealthEntry _entryFromRow(Map<String, dynamic> row) {
    return HealthEntry(
      localId: row['local_id'] as String,
      entryDate: DateTime.fromMillisecondsSinceEpoch(row['entry_date'] as int),
      weightKg: (row['weight_kg'] as num?)?.toDouble(),
      bodyPhotoPath: row['body_photo_path'] as String?,
      estimatedBodyFatPercent:
          (row['estimated_body_fat_percent'] as num?)?.toDouble(),
      bodyAnalysisNote: row['body_analysis_note'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }

  MealEntry _mealFromRow(Map<String, dynamic> row) {
    return MealEntry(
      localId: row['local_id'] as String,
      mealDate: DateTime.fromMillisecondsSinceEpoch(row['meal_date'] as int),
      mealType: row['meal_type'] as String,
      title: row['title'] as String,
      description: row['description'] as String?,
      photoPath: row['photo_path'] as String?,
      estimatedCalories: (row['estimated_calories'] as num).toDouble(),
      proteinG: (row['protein_g'] as num).toDouble(),
      carbsG: (row['carbs_g'] as num).toDouble(),
      fatG: (row['fat_g'] as num).toDouble(),
      analysisNote: row['analysis_note'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }

  Map<String, dynamic> _entryToRow(HealthEntry entry) {
    return {
      'local_id': entry.localId,
      'entry_date': _dayOnly(entry.entryDate).millisecondsSinceEpoch,
      'weight_kg': entry.weightKg,
      'body_photo_path': entry.bodyPhotoPath,
      'estimated_body_fat_percent': entry.estimatedBodyFatPercent,
      'body_analysis_note': entry.bodyAnalysisNote,
      'created_at': entry.createdAt.millisecondsSinceEpoch,
      'updated_at': entry.updatedAt.millisecondsSinceEpoch,
      'is_deleted': 0,
    };
  }

  Map<String, dynamic> _mealToRow(MealEntry meal) {
    return {
      'local_id': meal.localId,
      'meal_date': _dayOnly(meal.mealDate).millisecondsSinceEpoch,
      'meal_type': meal.mealType,
      'title': meal.title,
      'description': meal.description,
      'photo_path': meal.photoPath,
      'estimated_calories': meal.estimatedCalories,
      'protein_g': meal.proteinG,
      'carbs_g': meal.carbsG,
      'fat_g': meal.fatG,
      'analysis_note': meal.analysisNote,
      'created_at': meal.createdAt.millisecondsSinceEpoch,
      'updated_at': meal.updatedAt.millisecondsSinceEpoch,
      'is_deleted': 0,
    };
  }

  DateTime _dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);
}

class MealEstimate {
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final String note;

  const MealEstimate({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.note,
  });
}
