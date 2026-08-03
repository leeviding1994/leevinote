import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:leevinote/services/api_service.dart';
import 'package:leevinote/services/local_health_service.dart';
import 'package:leevinote/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('旧模块顺序会自动合并新增模块', () async {
    SharedPreferences.setMockInitialValues({
      'module_order': ['notes', 'profile'],
    });
    final settings = SettingsService(apiService: ApiService());

    await settings.ensureLoaded();

    final ids = settings.modules.map((module) => module.id).toList();
    expect(ids.first, 'notes');
    expect(ids.last, 'profile');
    expect(ids, containsAll(['alarms', 'music', 'videos', 'schedules']));
    expect(ids, containsAll(['transactions', 'health']));
  });

  test('餐食估算明确照片不参与图像分析', () {
    final service = LocalHealthService();

    final estimate = service.estimateMeal(
      title: '鸡胸肉沙拉',
      description: '小份',
      photoPath: '/tmp/meal.png',
    );

    expect(estimate.calories, greaterThan(0));
    expect(estimate.note, contains('照片仅作为餐食凭证'));
    expect(estimate.note, contains('粗略估算'));
  });
}
