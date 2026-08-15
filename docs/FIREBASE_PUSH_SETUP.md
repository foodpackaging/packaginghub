# Firebase Push Notifications — Setup Guide

Order-lifecycle push notifications for the customer app, delivered through Firebase Cloud
Messaging (FCM).

The code is already in place. Everything below is one-time configuration: creating a Firebase
project and dropping its config files into the two apps. Until you do it, the app still builds
and runs — push simply stays inactive and logs a warning.

---

## 1. What the customer receives

| Trigger | Type | Example |
|---|---|---|
| Order placed (COD / pay-at-store) | `order_placed` | **Order placed 🎉** — Order ORD-… for ₹1,240.50 has been sent to the store. |
| Order created, prepaid, not yet paid | `payment_pending` | **Order created — payment pending** — …is waiting for payment. |
| Razorpay payment verified | `payment_success` | **Payment successful ✅** — We received ₹1,240.50 for order ORD-… |
| Razorpay payment failed | `payment_failed` | **Payment failed** — …Your order is on hold — please try paying again. |
| Store accepts (`processing`) | `order_accepted` | **Order accepted 👍** — The store has accepted order ORD-… |
| Packed, delivery order | `order_packed` | **Order packed 📦** — …lined up for dispatch. |
| Packed, pickup order | `order_ready_for_pickup` | **Ready for pickup 🏬** — …waiting at the store. |
| Store sets a delivery/pickup time | `eta_set` | **Delivery time set ⏰** — …by around 6:30 PM. |
| Store pushes the time back (`is_delayed`) | `order_delayed` | **Delivery delayed ⏳** — …Sorry for the wait! |
| `out_for_delivery` | `out_for_delivery` | **Out for delivery 🚚** — …arriving by around 6:30 PM. |
| `delivered` | `order_delivered` | **Delivered ✅** |
| `picked_up` | `order_picked_up` | **Picked up ✅** |
| `cancelled` | `order_cancelled` | **Order cancelled** (mentions refund if already paid) |

Every notification is also stored server-side and shown in the app's inbox (bell icon on Home),
so nothing is lost if the phone was off or notifications were muted. Tapping a notification opens
that order's details screen.

---

## 2. Create the Firebase project

1. Go to <https://console.firebase.google.com> → **Add project**.
2. Name it (e.g. `b2b-store`). Google Analytics is optional.
3. In **Project settings → Cloud Messaging**, make sure the *Firebase Cloud Messaging API (V1)*
   is enabled.

---

## 3. Android app

1. Firebase console → **Add app → Android**.
2. Package name: **`com.packaginghub`** (must match `applicationId` in
   [android/app/build.gradle.kts](../mobile_app/android/app/build.gradle.kts) — change both
   together if you rename it before publishing).
3. Download **`google-services.json`** and save it to:

   ```
   mobile_app/android/app/google-services.json
   ```

That's the whole Android setup. The Gradle plugin is applied automatically as soon as that file
exists, and the manifest permissions, notification channel and desugaring config are already
committed.

---

## 4. iOS app (skip if Android-only for now)

1. Firebase console → **Add app → iOS**, bundle id matching your Xcode project.
2. Download **`GoogleService-Info.plist`** and add it to `mobile_app/ios/Runner/` **through Xcode**
   (drag into the Runner target so it lands in the bundle — copying the file in Explorer is not
   enough).
3. In the Apple Developer portal create an **APNs authentication key** (`.p8`) and upload it under
   Firebase → *Project settings → Cloud Messaging → Apple app configuration*.
4. In Xcode → *Signing & Capabilities*, add **Push Notifications** and **Background Modes →
   Remote notifications**.

`Info.plist` and `AppDelegate.swift` are already configured.

> Push does not work on the iOS Simulator. Test on a physical device.

---

## 5. Backend service account

The API sends pushes with the Firebase Admin SDK, which needs a service account.

1. Firebase console → **Project settings → Service accounts → Generate new private key**.
   This downloads a JSON file. **Treat it like a password — never commit it.**
2. Add it to `backend/.env` in one of two ways:

   **Option A — paste the whole JSON (easiest):**
   ```
   FIREBASE_SERVICE_ACCOUNT={"type":"service_account","project_id":"...","private_key":"-----BEGIN PRIVATE KEY-----\n...","client_email":"..."}
   ```
   A base64 blob of the same JSON also works, which avoids quoting problems on hosts like Render
   or Railway:
   ```bash
   base64 -w0 service-account.json
   ```

   **Option B — the three fields separately:**
   ```
   FIREBASE_PROJECT_ID=b2b-store
   FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@b2b-store.iam.gserviceaccount.com
   FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nMIIE...\n-----END PRIVATE KEY-----\n"
   ```
   Keep the `\n` escapes literal — the config layer converts them back to real newlines.

3. Optionally set the wording locale:
   ```
   APP_TIMEZONE=Asia/Kolkata
   APP_CURRENCY=INR
   ```
   These control how "Arriving by 6:30 PM" and "₹1,240.50" are rendered.

Restart the API. With no credentials set it logs
`[push] Firebase credentials not configured — push notifications are disabled.` and keeps running
normally; orders and payments are unaffected.

---

## 6. Verify

```bash
cd backend && npm run dev
```

```bash
cd mobile_app && flutter run
```

1. Sign in on the device. The app requests notification permission and registers its FCM token
   (`POST /api/devices`).
2. Place a COD order → **Order placed 🎉** should arrive within a second or two.
3. In the admin dashboard, move the order to *Processing*, set an ETA, mark it delayed, then
   *Delivered* — one notification per step.
4. Send a manual test to any user:
   ```bash
   cd backend && node scripts/testPush.js customer@example.com
   ```

Test all three app states — foreground, backgrounded, and force-quit. They take different code
paths (in-app local notification, system tray, and cold-start routing respectively).

---

## 7. How it fits together

```
Order/payment changes           Delivery
─────────────────────           ────────
routes/orders.js      ┐
routes/payments.js    ├─▶ services/orderNotifications.js  (decides what to say)
                      ┘         │
                                ▼
                        services/pushService.js
                                │
                    ┌───────────┴───────────┐
                    ▼                       ▼
          Notification (Mongo)        FCM multicast
          → in-app inbox              → DeviceToken rows for that user
```

Client side: `mobile_app/lib/core/services/push_notification_service.dart` owns permission, token
registration, the foreground/background/cold-start handlers and the unread badge.

Design notes worth knowing before you change things:

- **Push never blocks a request.** Order and payment routes dispatch notifications
  fire-and-forget; a Firebase outage cannot fail a checkout.
- **The inbox row is written before the send.** So the history survives failed or skipped
  deliveries.
- **Tokens are keyed by token, not by user.** When a second account signs in on the same phone,
  FCM returns the same token and it is reassigned — the previous user stops receiving pushes meant
  for someone else. Logout also calls `DELETE /api/devices`.
- **Dead tokens are pruned automatically** when FCM reports them as unregistered.
- **Only real transitions notify.** `PATCH /api/orders/:id` reads the order before writing and
  compares, so the store re-saving an unchanged form doesn't ping the customer again.
- **The channel id `order_updates` appears in three places** — `pushService.js`,
  `push_notification_service.dart`, and `AndroidManifest.xml`. Android silently drops
  notifications for an unknown channel, so change all three together.

---

## 8. Troubleshooting

| Symptom | Cause |
|---|---|
| `Firebase not configured — push notifications disabled` in the Flutter log | `google-services.json` / `GoogleService-Info.plist` missing. |
| Server logs `Firebase credentials not configured` | Service-account env vars missing or malformed. |
| Token registers but nothing arrives on Android 13+ | Notification permission denied — check Android app settings. |
| Works in foreground only | Channel id mismatch, or battery optimisation is killing the app. |
| iOS: `getToken()` throws / returns null | APNs key not uploaded to Firebase, or Push Notifications capability not enabled. |
| Notification arrives but tapping does nothing | The payload lost its `order_id` — check `data` in `orderNotifications.js`. |

---

## 9. Files

**Backend**
- `src/config/firebase.js` — Admin SDK init (null when unconfigured)
- `src/services/pushService.js` — persist + multicast + prune dead tokens
- `src/services/orderNotifications.js` — the copy for every event
- `src/models/DeviceToken.js`, `src/models/Notification.js`
- `src/routes/devices.js` — `POST/DELETE /api/devices`
- `src/routes/notifications.js` — inbox list, unread count, mark read
- `scripts/testPush.js` — manual send

**Mobile app**
- `lib/core/services/push_notification_service.dart`
- `lib/shared/models/app_notification.dart`
- `lib/shop_ui/screens/notification/view/notifications_screen.dart` — inbox
- `lib/shop_ui/components/notification_bell.dart` — badge on Home
