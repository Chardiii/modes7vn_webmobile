class AppConfig {
  // Change this to your PC's local IP when running on a physical device.
  // Run `ipconfig` (Windows) to find your IPv4 address.
  static const String baseIp = '192.168.1.8';
  static const int port = 5000;
  static const String baseUrl = 'http://$baseIp:$port/api/v1';
}
