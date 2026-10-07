/// Application exceptions thrown by data sources and network clients.
class ServerException implements Exception {
  final String message;
  const ServerException([this.message = 'Server Error occurred.']);

  @override
  String toString() => message;
}

class NetworkException implements Exception {
  final String message;
  const NetworkException([this.message = 'No internet connection.']);

  @override
  String toString() => message;
}

class AuthException implements Exception {
  final String message;
  const AuthException([this.message = 'Authentication failed.']);

  @override
  String toString() => message;
}
