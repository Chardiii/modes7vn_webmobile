import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final _api = ApiService();
  // Use your Web Client ID from Google Cloud Console → APIs & Services → Credentials
  // This is required to get the idToken on Android
  final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: '505559201710-83fkmb277hr8i0v7lg3025mh8kl7grtk.apps.googleusercontent.com',
  );
  Map<String, dynamic>? _user;
  bool _loading = false;
  bool _initializing = true;
  String? _error;

  Map<String, dynamic>? get user => _user;
  bool get loading => _loading;
  bool get initializing => _initializing;
  String? get error => _error;
  bool get isLoggedIn => _user != null;

  Future<void> checkAuth() async {
    _initializing = true;
    notifyListeners();
    if (await _api.isLoggedIn) {
      try {
        _user = await _api.getMe();
      } catch (_) {
        await _api.clearToken();
        _user = null;
      }
    }
    _initializing = false;
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _api.login(username, password);
      _user = data['user'];  // now contains full profile from _user_dict
      return true;
    } on DioException catch (e) {
      final body = e.response?.data;
      if (body is Map && body['error'] != null) {
        _error = body['error'].toString();
      } else {
        _error = _friendlyError(e);
      }
      return false;
    } catch (e) {
      _error = 'Something went wrong. Please try again.';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await _api.updateProfile(data);
      _user = response;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      final body = e.response?.data;
      _error = (body is Map && body['error'] != null)
          ? body['error'].toString()
          : _friendlyError(e);
      return false;
    } catch (e) {
      _error = 'Update failed: ${e.toString()}';
      return false;
    }
  }

  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _api.clearToken();
    _user = null;
    notifyListeners();
  }

  Future<bool> googleLogin() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        _loading = false;
        notifyListeners();
        return false;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      final accessToken = auth.accessToken;

      if (idToken == null && accessToken == null) {
        _error = 'Could not get Google credentials.';
        return false;
      }

      final data = await _api.googleLogin(
        idToken: idToken,
        accessToken: accessToken,
      );
      _user = data['user'];
      return true;
    } on DioException catch (e) {
      final body = e.response?.data;
      _error = (body is Map && body['error'] != null)
          ? body['error'].toString()
          : _friendlyError(e);
      return false;
    } catch (e) {
      _error = 'Google sign-in failed: ${e.toString()}';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  String _friendlyError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Request timed out. Make sure Flask is running and try again.';
      case DioExceptionType.connectionError:
        return 'Cannot reach server at $kBaseUrl. Make sure Flask is running and your phone is on the same Wi-Fi.';
      case DioExceptionType.sendTimeout:
        return 'Request timed out while sending. Check your connection.';
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        if (status == 401) return 'Invalid username or password.';
        if (status == 403) return e.response?.data?['error'] ?? 'Access denied.';
        return 'Server error ($status).';
      default:
        return 'Network error. Please try again.';
    }
  }
}
