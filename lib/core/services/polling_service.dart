// lib/core/services/polling_service.dart
// Smart adaptive polling - tiết kiệm pin tối đa
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../constants/app_constants.dart';

enum AppState { active, idle, background }

class PollingService with WidgetsBindingObserver {
  static final PollingService _instance = PollingService._internal();
  factory PollingService() => _instance;
  PollingService._internal();

  Timer? _timer;
  AppState _appState = AppState.active;
  DateTime? _lastInteraction;
  Function()? _onTick;
  bool _isConnected = true;

  void init(Function() onTick) {
    _onTick = onTick;
    WidgetsBinding.instance.addObserver(this);
    Connectivity().onConnectivityChanged.listen((result) {
      _isConnected = result != ConnectivityResult.none;
      if (_isConnected) _restartTimer();
    });
    _startTimer();
  }

  // Gọi khi user tương tác (gõ, scroll, tap)
  void onUserInteraction() {
    _lastInteraction = DateTime.now();
    if (_appState != AppState.active) {
      _appState = AppState.active;
      _restartTimer();
    }
  }

  // Tính interval thông minh dựa trên trạng thái
  int get _currentInterval {
    if (!_isConnected) return 30000; // 30s nếu mất mạng
    switch (_appState) {
      case AppState.active:
        return AppConstants.pollActiveMs; // 2s
      case AppState.idle:
        return AppConstants.pollIdleMs; // 8s
      case AppState.background:
        return AppConstants.pollBackgroundMs; // 15s
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: _currentInterval), (_) {
      _checkIdleState();
      if (_onTick != null) _onTick!();
    });
  }

  void _restartTimer() {
    _startTimer();
  }

  void _checkIdleState() {
    if (_appState == AppState.background) return;
    final now = DateTime.now();
    if (_lastInteraction != null) {
      final idle = now.difference(_lastInteraction!).inSeconds;
      if (idle > 30 && _appState == AppState.active) {
        _appState = AppState.idle;
        _restartTimer(); // Chuyển sang 8s
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _appState = AppState.active;
        _lastInteraction = DateTime.now();
        _restartTimer();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _appState = AppState.background;
        _restartTimer();
        break;
      default:
        break;
    }
  }

  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
