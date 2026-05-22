class AppConfig {
  // Development: local Flask backend
  static const String baseIp = '192.168.1.7';
  static const int port = 5000;
  static const String baseUrl = 'http://$baseIp:$port/api/v1';

  // Production: Railway backend (comment out above and uncomment below)
  // static const String baseUrl = 'https://modes7vnwebmobile-production.up.railway.app/api/v1';
}
