class ApiConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://backend.leevinote.leeviding.cn/api',
  );

  static const String signup = '/auth/signup';
  static const String login = '/auth/login';
  static const String notes = '/notes';
  static const String folders = '/folders';
  static const String alarms = '/alarms';
  static const String music = '/music';
  static const String videos = '/videos';
  static const String schedules = '/schedules';
  static const String transactions = '/transactions';
  static const String transactionCategories = '/transaction-categories';
}
