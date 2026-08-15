import 'package:b2b_store/core/services/push_notification_service.dart';
import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/shop_ui/route/route_constants.dart';
import 'package:flutter/material.dart';

/// Bell that opens the notification inbox, badged with the unread count.
///
/// The count lives on [PushNotificationService] rather than in this widget, so
/// a push that arrives while the customer is on any tab updates the badge
/// immediately instead of waiting for the next rebuild.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key, this.color = navyDark});

  final Color color;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PushNotificationService.instance.refreshUnreadCount();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Notifications tapped from the system tray (or read on another device)
    // change the count while the app is away.
    if (state == AppLifecycleState.resumed) {
      PushNotificationService.instance.refreshUnreadCount();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: PushNotificationService.instance.unreadCount,
      builder: (context, count, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: blackColor10),
          ),
          child: Badge(
            label: Text(count > 99 ? '99+' : '$count'),
            isLabelVisible: count > 0,
            child: IconButton(
              onPressed: () async {
                await Navigator.pushNamed(context, notificationsScreenRoute);
                PushNotificationService.instance.refreshUnreadCount();
              },
              icon: Icon(Icons.notifications_none_rounded, color: widget.color),
            ),
          ),
        );
      },
    );
  }
}
