import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:b2b_store/shared/services/api_service.dart';
import 'package:b2b_store/shop_ui/route/navigator_key.dart';
import 'package:b2b_store/shop_ui/route/route_constants.dart';

/// Must match ANDROID_CHANNEL_ID in backend/src/services/pushService.js.
/// Android 8+ drops any notification whose channel id it doesn't recognise, so
/// the two names have to stay in step.
const String kOrderUpdatesChannelId = 'order_updates';

const AndroidNotificationChannel _orderUpdatesChannel = AndroidNotificationChannel(
  kOrderUpdatesChannelId,
  'Order updates',
  description: 'Order confirmations, payments, delivery times and delivery status.',
  importance: Importance.high,
);

/// Handles a push that arrives while the app is terminated or backgrounded.
///
/// Runs in its own isolate with no access to app state, so it must re-init
/// Firebase itself. The server sends a `notification` block alongside the data,
/// which the OS renders on its own — this exists so data-only sends still wake
/// the app and get logged.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Already initialized in this isolate, or not configured at all.
  }
  debugPrint('[push] Background message: ${message.messageId}');
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final ApiService _apiService = ApiService();
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  final _incoming = StreamController<RemoteMessage>.broadcast();

  /// Fires whenever a push lands while the app is running, so open screens
  /// (the inbox, an order's tracking view) can refresh themselves.
  Stream<RemoteMessage> get onMessage => _incoming.stream;

  /// Badge source for the notification bell. Kept here rather than in a screen
  /// so a push can update it no matter which tab the customer is looking at.
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  bool _firebaseReady = false;
  bool _initialized = false;
  String? _currentToken;
  StreamSubscription<String>? _tokenRefreshSub;

  bool get isAvailable => _firebaseReady;

  /// Boots Firebase and the local-notification plumbing.
  ///
  /// Safe to call before any Firebase project exists: without google-services.json
  /// (or GoogleService-Info.plist) initialization fails, push quietly turns off,
  /// and the rest of the app keeps working.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
    } catch (e) {
      debugPrint('[push] Firebase not configured — push notifications disabled ($e)');
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _setUpLocalNotifications();

    // iOS suppresses pushes while the app is in front unless asked otherwise.
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _openTarget(message.data),
    );
  }

  Future<void> _setUpLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      // firebase_messaging asks for these permissions itself; asking twice
      // would show the customer two system prompts back to back.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: darwinSettings),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          _openTarget((jsonDecode(payload) as Map).cast<String, dynamic>());
        } catch (_) {
          // Malformed payload — opening the inbox is still better than nothing.
          _navigate(notificationsScreenRoute);
        }
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_orderUpdatesChannel);
  }

  /// Asks for notification permission and registers this device with the API.
  ///
  /// Called after sign-in (and on launch for an existing session) because the
  /// token is stored against a user — registering while logged out would have
  /// nothing to attach it to.
  Future<void> registerDevice() async {
    if (!_firebaseReady) return;

    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[push] Notification permission denied.');
        return;
      }

      // On iOS the APNs token can lag behind app start; without it getToken()
      // throws instead of waiting.
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken == null) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _sendTokenToServer(token);

      // FCM rotates tokens (app restore, data clear); a stale token means the
      // customer silently stops getting order updates.
      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(_sendTokenToServer);

      await refreshUnreadCount();
    } catch (e) {
      debugPrint('[push] Device registration failed: $e');
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      await _apiService.registerDeviceToken(token: token, platform: _platformName);
      _currentToken = token;
    } catch (e) {
      debugPrint('[push] Could not register device token: $e');
    }
  }

  /// Detaches this device from the account being signed out.
  ///
  /// Without it, the next person to sign in on a shared phone would keep
  /// receiving the previous account's order updates.
  Future<void> unregisterDevice() async {
    unreadCount.value = 0;
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    if (!_firebaseReady) return;

    try {
      final token = _currentToken ?? await FirebaseMessaging.instance.getToken();
      if (token != null) await _apiService.unregisterDeviceToken(token);
    } catch (e) {
      debugPrint('[push] Could not unregister device token: $e');
    } finally {
      _currentToken = null;
    }
  }

  Future<void> refreshUnreadCount() async {
    unreadCount.value = await _apiService.getUnreadNotificationCount();
  }

  void setUnreadCount(int value) => unreadCount.value = value < 0 ? 0 : value;

  /// Opens the screen a notification points at, if the app is already running.
  ///
  /// Cold starts go through here too, via [handleLaunchMessage].
  void _openTarget(Map<String, dynamic> data) {
    final orderId = data['order_id']?.toString();
    if (data['route'] == 'order_details' && orderId != null && orderId.isNotEmpty) {
      _navigate(orderDetailsScreenRoute, arguments: orderId);
      return;
    }
    _navigate(notificationsScreenRoute);
  }

  void _navigate(String route, {Object? arguments}) {
    final navigator = shopNavigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushNamed(route, arguments: arguments);
  }

  /// Routes the notification that launched the app from a terminated state.
  ///
  /// Deferred to after the first frame so the navigator exists and the customer
  /// lands on the order screen with the app's home underneath it.
  Future<void> handleLaunchMessage() async {
    if (!_firebaseReady) return;
    final message = await FirebaseMessaging.instance.getInitialMessage();
    if (message == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _openTarget(message.data));
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    _incoming.add(message);
    unreadCount.value = unreadCount.value + 1;

    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      // A stable id per order collapses repeat updates into one card rather
      // than stacking a fresh one for every step of the same order.
      message.data['order_id']?.hashCode ?? DateTime.now().millisecondsSinceEpoch.remainder(100000),
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _orderUpdatesChannel.id,
          _orderUpdatesChannel.name,
          channelDescription: _orderUpdatesChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(notification.body ?? ''),
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      payload: jsonEncode(message.data),
    );
  }

  String get _platformName {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'other';
    }
  }
}
