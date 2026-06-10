import 'package:flutter/material.dart';
import '../data/auth_service.dart';
import '../data/user_service.dart';
import '../data/api_client.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  UserModel? _user;
  bool _isLoading = false;
  bool _loggedIn = false;
  bool _hasLoaded = false;

  UserModel? get user    => _user;
  bool get isLoading     => _isLoading;
  bool get isLoggedIn    => _loggedIn;
  String? get userId     => _user?.id;
  String get displayName => _user?.displayName ?? 'Guest';
  String get initials    => _user?.initials ?? 'G';
  String? get email      => _user?.email;

  Future<void> checkLogin() async {
    _loggedIn = await _authService.isLoggedIn;
    notifyListeners();
  }

  Future<void> loadUser({bool force = false}) async {
    if (_hasLoaded && !force) return;
    _loggedIn = await _authService.isLoggedIn;
    if (!_loggedIn) { notifyListeners(); return; }
    _isLoading = true;
    notifyListeners();
    _user = await _userService.getProfile();
    _hasLoaded = true;
    _isLoading = false;
    notifyListeners();
  }

  Future<String?> updateProfile({String? fullName, String? phone}) async {
    final error = await _userService.updateProfile(fullName: fullName, phone: phone);
    if (error == null) {
      _user = _user?.copyWith(fullName: fullName, phone: phone);
      notifyListeners();
    }
    return error;
  }

  Future<void> signOut() async {
    try {
      await ApiClient.put('/api/users/me', {'fcm_token': null});
    } catch (_) {}
    await _authService.signOut();
    _user = null;
    _loggedIn = false;
    notifyListeners();
  }

  void clear() {
    _user = null;
    _loggedIn = false;
    _hasLoaded = false;
    notifyListeners();
  }
}
