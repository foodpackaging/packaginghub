import 'dart:async';

import 'package:b2b_store/core/services/api_client.dart';
import 'package:b2b_store/core/services/push_notification_service.dart';
import 'package:b2b_store/shared/models/app_notification.dart';
import 'package:b2b_store/shared/services/api_service.dart';
import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/shop_ui/route/route_constants.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// The customer's order-update history.
///
/// Everything pushed to the device is stored server-side first, so this list is
/// the fallback for updates that arrived while the phone was off, muted, or not
/// yet registered for push.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _apiService = ApiService();
  final PushNotificationService _push = PushNotificationService.instance;

  List<AppNotification> _notifications = [];
  bool _loading = true;
  String? _error;
  StreamSubscription? _pushSub;

  @override
  void initState() {
    super.initState();
    _load();
    // A push that lands while this screen is open should appear in the list
    // without the customer having to pull to refresh.
    _pushSub = _push.onMessage.listen((_) => _load(silent: true));
  }

  @override
  void dispose() {
    _pushSub?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final feed = await _apiService.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = feed.notifications;
        _error = null;
        _loading = false;
      });
      _push.setUnreadCount(feed.unreadCount);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your notifications.';
        _loading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    final unread = _notifications.where((n) => !n.isRead).toList();
    if (unread.isEmpty) return;

    setState(() {
      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    });
    _push.setUnreadCount(0);

    try {
      await _apiService.markAllNotificationsRead();
    } catch (_) {
      if (mounted) _load(silent: true);
    }
  }

  Future<void> _open(AppNotification notification) async {
    if (!notification.isRead) {
      setState(() {
        _notifications = _notifications
            .map((n) => n.id == notification.id ? n.copyWith(isRead: true) : n)
            .toList();
      });
      _push.setUnreadCount(_notifications.where((n) => !n.isRead).length);
      await _apiService.markNotificationRead(notification.id);
    }

    if (!mounted) return;
    final orderId = notification.orderId;
    if (orderId != null && orderId.isNotEmpty) {
      Navigator.pushNamed(context, orderDetailsScreenRoute, arguments: orderId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _notifications.any((n) => !n.isRead);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: const Text("Mark all read"),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _MessageState(
        icon: Icons.wifi_off_outlined,
        title: "Couldn't load notifications",
        message: _error!,
        actionLabel: "Try again",
        onAction: _load,
      );
    }

    if (_notifications.isEmpty) {
      return const _MessageState(
        icon: Icons.notifications_none_outlined,
        title: "No notifications yet",
        message:
            "Place an order and we'll keep you posted here — payment, store confirmation, delivery time and every step after.",
      );
    }

    return ListView.separated(
      // Keeps pull-to-refresh working even when the list is shorter than the screen.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: defaultPadding / 2),
      itemCount: _notifications.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72, endIndent: defaultPadding),
      itemBuilder: (context, index) => _NotificationTile(
        notification: _notifications[index],
        onTap: () => _open(_notifications[index]),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: unread ? primaryColor.withValues(alpha: 0.04) : null,
        padding: const EdgeInsets.symmetric(horizontal: defaultPadding, vertical: defaultPadding * 0.75),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: notification.accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(notification.icon, size: 20, color: notification.accentColor),
            ),
            const SizedBox(width: defaultPadding * 0.75),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: unread ? FontWeight.bold : FontWeight.w600,
                              ),
                        ),
                      ),
                      if (unread)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 8, top: 4),
                          decoration: const BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: blackColor60),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _relativeTime(notification.createdAt),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: blackColor40),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "12m ago" beats a timestamp for recent updates; older ones get a real date.
  static String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM, h:mm a').format(time);
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Icon(icon, size: 56, color: blackColor20),
        const SizedBox(height: defaultPadding),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: defaultPadding * 2),
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: blackColor60),
              ),
              if (actionLabel != null) ...[
                const SizedBox(height: defaultPadding),
                OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
