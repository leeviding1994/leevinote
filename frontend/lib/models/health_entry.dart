import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class HealthEntry {
  final String localId;
  final DateTime entryDate;
  final double? weightKg;
  final String? bodyPhotoPath;
  final double? estimatedBodyFatPercent;
  final String? bodyAnalysisNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  HealthEntry({
    String? localId,
    required this.entryDate,
    this.weightKg,
    this.bodyPhotoPath,
    this.estimatedBodyFatPercent,
    this.bodyAnalysisNote,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : localId = localId ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  HealthEntry copyWith({
    DateTime? entryDate,
    double? Function()? weightKg,
    String? Function()? bodyPhotoPath,
    double? Function()? estimatedBodyFatPercent,
    String? Function()? bodyAnalysisNote,
    DateTime? updatedAt,
  }) {
    return HealthEntry(
      localId: localId,
      entryDate: entryDate ?? this.entryDate,
      weightKg: weightKg != null ? weightKg() : this.weightKg,
      bodyPhotoPath:
          bodyPhotoPath != null ? bodyPhotoPath() : this.bodyPhotoPath,
      estimatedBodyFatPercent: estimatedBodyFatPercent != null
          ? estimatedBodyFatPercent()
          : this.estimatedBodyFatPercent,
      bodyAnalysisNote:
          bodyAnalysisNote != null ? bodyAnalysisNote() : this.bodyAnalysisNote,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

class MealEntry {
  final String localId;
  final DateTime mealDate;
  final String mealType;
  final String title;
  final String? description;
  final String? photoPath;
  final double estimatedCalories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final String? analysisNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  MealEntry({
    String? localId,
    required this.mealDate,
    required this.mealType,
    required this.title,
    this.description,
    this.photoPath,
    required this.estimatedCalories,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.analysisNote,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : localId = localId ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();
}
