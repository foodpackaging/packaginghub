# Implementation Changelog — B2B Restaurant Ordering Platform Hardening

This documents the work done against the 17-priority implementation brief for making the existing B2B ordering platform (Flutter + Vercel/Express + MongoDB Atlas + Firebase FCM + Cloudinary + Razorpay) safe and production-ready, without changing the underlying architecture.

Nothing here migrated the backend off Vercel, replaced Firebase FCM, or introduced new infrastructure (no Redis/Kafka/queues/microservices/websockets). Every change is additive or a targeted fix to existing files.

---

## 1. Changes Made

### 🔴 Priority 1 — Server-side order pricing

`POST /api/orders` no longer accepts pricing from the client. The request body is now just `delivery_method`, `payment_method`, `coupon_code?`, `address_id`/`delivery_address`, `notes?`, and `items: [{product_id, quantity}]`. For every item, the server fetches the `Product`, verifies it's active, computes `unitPrice` from `discountedPrice`/`price`, and sums the real `subtotal`. A submitted coupon is re-validated server-side against that real subtotal. Delivery charge is a server-side constant (₹50, matching the value the app used to send). `totalAmount = subtotal + deliveryCharge - discountAmount` — all four of these stored fields are now 100% server-computed; any client-sent `subtotal`/`discount_amount`/`delivery_charge`/`total_amount`/per-item prices are never read.

`POST /api/payments/razorpay/create-order` no longer takes a client `amount`. It now takes `app_order_id`, loads that order (must belong to the caller, must not already be paid), and computes the Razorpay amount from the order's own `totalAmount`. It also now persists `razorpayOrderId` onto the order immediately — this is what makes the Priority 4 webhook able to find the order.

`POST /api/payments/razorpay/verify` additionally now requires the client-supplied `order_id` to match the order's own stored `razorpayOrderId` before accepting a signature (see the "cross-order replay" note under Priority 4).

**New:** `backend/src/utils/pricing.js` — `resolveUnitPrice`, `computeDeliveryCharge`, `computeDiscount`, `validateCouponForAmount`. This is now the one place all server-side money math lives; `routes/coupons.js`'s `/validate` endpoint was refactored to reuse `computeDiscount` from here instead of its own copy, so pricing logic can't drift between the two call sites.

Mobile: `OrderCheckoutService.placeOrder()` now sends only `product_id`+`quantity` per item — no prices. `createRazorpayOrder()` takes the app order id instead of an amount. `PaymentCheckoutScreen` still shows a total in the Razorpay sheet before it opens, but that's now explicitly labeled as display-only — the actual charge is bound server-side to the Razorpay order id.

### 🔴 Priority 2 — Atomic inventory validation + deduction

Order creation runs inside a MongoDB session transaction (`mongoose.startSession()` / `session.withTransaction()`) in `backend/src/routes/orders.js`. Each item's stock check-and-deduct is one atomic conditional update: `Product.findOneAndUpdate({_id, isActive:true, stockQuantity:{$gte:quantity}}, {$inc:{stockQuantity:-quantity}})`. If that fails for any item (inactive, insufficient stock), the whole transaction aborts and every earlier deduction in that same request is rolled back automatically — no manual compensation code was needed. Two concurrent requests for the same last units can't both succeed: MongoDB serializes the conditional update per document, so the loser's match simply fails.

Verified with a real concurrency test (two simultaneous requests for the last 5 units of a 5-unit-stock product) — see Testing, below.

### 🔴 Priority 3 — MOQ enforcement

Backend: inside the same per-item loop as Priority 2, an item with `quantity < product.minOrderQty` aborts the transaction with a 400 naming the product and its MOQ, before any stock is touched. This is authoritative — it doesn't trust the client.

Mobile: `Product.canFulfillMoq` getter added (`stockQuantity >= minOrderQty`). `CartController.addToCart()` now seeds the starting quantity at `max(1, product.minOrderQty)` instead of always `1` (there's no valid quantity between 1 and the MOQ). `decrementQuantity`/`decrementProduct` remove the item entirely rather than letting it drop below the MOQ.

### 🔴 Priority 4 — Razorpay webhook + reconciliation

`server.js`'s `express.json()` now captures the raw request body (`req.rawBody`) via its `verify` callback — additive, harmless to every other route, but required because Razorpay's webhook signature is computed over the exact raw bytes, not a re-serialized JSON object.

New `POST /api/payments/razorpay/webhook` in `routes/payments.js`: verifies `x-razorpay-signature` via `HMAC-SHA256(rawBody, RAZORPAY_WEBHOOK_SECRET)` compared with `crypto.timingSafeEqual`. Resolves the order by the `razorpayOrderId` written during Priority 1's `/create-order` change. Idempotent by construction: `payment.captured` and `payment.failed` handlers both use a `paymentStatus: {$ne: 'paid'}` guard on the update (the same pattern the existing `/razorpay/failed` route already used), so a redelivered webhook event is a harmless no-op — verified with a real "send the same webhook twice" test. Unrecognized event types get a `200` acknowledgement so Razorpay doesn't retry-storm the endpoint. The existing client-side `/verify` call is unchanged and still gives the customer immediate feedback; the webhook is the new authoritative backstop for when the client never gets to report success (crash, lost connection, killed app).

Also fixed while in this code: `/razorpay/verify`'s signature comparison now uses `crypto.timingSafeEqual` instead of `!==`, and now requires the client's `order_id` to match the order's own stored `razorpayOrderId` — closing a real gap where a customer could otherwise replay a valid signature from one of their own paid orders against a different, unpaid order of theirs.

New env var: `RAZORPAY_WEBHOOK_SECRET` (see "Required Manual Setup" below). New index: `Order` gets a sparse index on `razorpayOrderId`, since the webhook now looks orders up by it.

### 🔴 Priority 5 — Auth rate limiting

New `backend/src/middleware/rateLimit.js` (`express-rate-limit`, added as a dependency): `loginLimiter` (10 requests/15 min — customer and admin login), `signupLimiter` (10/hour — signup and forgot-password), `resetLimiter` (20/15 min — verify/consume a reset code, on top of the app's existing 5-attempt/60s-cooldown logic in `auth.js`, which is untouched). Applied to `/signup`, `/login`, `/admin/login`, `/forgot-password`, `/verify-reset-code`, `/reset-password`. Every limiter returns a generic `429 {error: 'Too many attempts...'}` — no detail about which specific check failed.

### 🔴 Priority 6 — Fixed unauthenticated `all=true` access

New `requireAdminForAllTrue` middleware in `middleware/auth.js`: a no-op unless `?all=true` is present, in which case it requires an authenticated admin before letting the request through. Applied to `GET /api/categories`, `GET /api/products`, `GET /api/filters` — the plain (non-`all=true`) listing on all three stays public, exactly as before.

### 🟠 Priority 7 — Admin push notifications (Web Push — see decision note below)

**Decision:** there is no admin-facing mobile app — the vendor uses the React web dashboard, and the Flutter app is customer-only. Implementing literal "push to the supplier's phone" would have meant building a new admin mobile surface, which is out of scope. This was raised explicitly during planning; the chosen approach is **Web Push to the admin dashboard** via the Firebase Web SDK.

Backend: `notifyAdminNewOrder(order, customer)` (new, in `orderNotifications.js`) fetches every `role:'admin'` user and calls the existing `notifyUser()` for each — zero new push infrastructure, reuses `DeviceToken`/multicast/dead-token-pruning exactly as the customer-facing path already does. Fired from `orders.js` right alongside the existing customer `notifyOrderPlaced` call, via the same non-blocking `dispatch()` wrapper. Title: `New Order #<orderNumber>`; body: `Restaurant: <name> • Items: <count> • Total: <amount>` — matches the format from the brief. `Notification.type` enum gained one new value, `admin_new_order`.

`DeviceToken.platform` already had a `'web'` enum value and `POST /api/devices` already worked for any authenticated user (cookie or bearer) — **no backend registration endpoint needed changing.**

New: `admin_dashboard/src/pushService.js` (registers the browser for push on login, using a VAPID key; shows a foreground notification since FCM doesn't auto-display one while the tab is focused) and `admin_dashboard/public/firebase-messaging-sw.js` (background handler + `notificationclick` → reopens the dashboard at `/?order=<id>`). Firebase web config is passed to the static service-worker file via its registration query string, since a `public/` file can't read Vite env vars at runtime — these config values are public/client-safe by Firebase's own design, unlike the backend's service-account private key.

`App.jsx` reads `?order=` on load (as initial state, not a post-mount effect, to avoid a tab flash) and registers push after login; `OrderManager.jsx` accepts a `focusOrderId` prop, scrolls to and briefly highlights that order card. New-order pushes always refer to the newest order (page 1), so no extra fetch was needed for this.

### 🟠 Priority 8 — Order status state machine

New `backend/src/utils/orderStatusMachine.js`: separate allowed-transition maps for delivery orders (`pending→processing→packed→out_for_delivery→delivered`) and pickup orders (`pending→processing→packed→picked_up`), with `cancelled` reachable from any non-terminal state and the terminal states having no further transitions. `PATCH /api/orders/:id` validates a status change against this before applying it — `400` with a specific message (e.g. `Cannot move order from 'delivered' to 'pending'`) on violation. An admin-only escape hatch, `force_status_override: true` in the request body, bypasses the check and logs a `console.warn` with the admin id, order id, and the from/to statuses — a lightweight trace, not a full audit-log system.

### 🟠 Priority 9 — Restaurant/business customer profile

Added the one thing that was genuinely missing: `User.businessName` (the actual business/restaurant name — e.g. "ABC Restaurant" — distinct from the pre-existing `companyType`, which is a category like "Restaurant"/"Cafe"/"Hotel"). Wired through `profile.js`'s editable-field map, `serializeUser`, and the mobile `UserProfile` model. Added a required "Business / Restaurant Name" field to the onboarding form (`onboarding_form_screen.dart`). Also relaxed the GST Number field on that same form from required to optional — it was previously forced (`validator: value.isEmpty ? "Enter GST number" : null`), which directly contradicted the "don't force GST if not required" instruction; the backend model already had no such requirement. Everything else the brief asked for (contact person, phone, email, business/delivery addresses) already existed and needed no changes.

### 🟠 Priority 10 — Order history pagination

`GET /api/orders/mine` and `GET /api/orders/admin/all` now accept `page`/`limit` (reusing the existing `resolvePaging` helper from `utils/productQuery.js` — same `MAX_PAGE_SIZE=100` cap already used by the product endpoints) and return `{orders, total, page, limit, has_more}`.

**Deliberately not extended to `GET /api/customers` or `GET /api/returns/admin/all`**, despite both being similarly unbounded: `OrderManager.jsx`'s customer-name-merge feature depends on fetching *every* customer to look up by `user_id` for *any* order, and paginating that endpoint by default would have silently broken customer names on older orders. Fixing that properly (e.g. a lighter admin endpoint just for the merge, or restructuring the merge) was out of scope for this pass — flagged here rather than done partially. These two endpoints remain exactly as unbounded as before; nothing was regressed.

Admin dashboard: `OrderManager.jsx` now fetches in pages of 25 with a "Load more" button; a poll/push refresh always re-fetches page 1 (where new orders sort to) without disturbing pages already loaded via "Load more."

### 🟠 Priority 11 — Admin order refresh

Push (Priority 7) is now the primary "a new order just arrived" signal. The existing 30-second poll in `OrderManager.jsx` was kept as the explicitly-requested fallback, with its interval bumped to 60 seconds since push now covers the time-sensitive case. No WebSockets, no new architecture.

### 🟡 Priority 12 — Database indexing

Added to `Order`: `{status: 1, createdAt: -1}` (covers the admin status filter, the one confirmed-missing index from the prior audit) and a sparse `{razorpayOrderId: 1}` (the new webhook's lookup). Reviewed everything else the brief listed (Product's indexes, Notification's `{userId, createdAt}`, DeviceToken's unique-token) and left them as-is — already adequate for their actual query patterns. Did not add a SKU index: nothing in the codebase queries products by SKU directly (search is a regex `$or` across name/brand/sku, which can't use a plain index anyway).

### 🟡 Priority 13 — Image upload security

`routes/upload.js`'s `multer` instance gained a `fileFilter`: JPEG/PNG/WebP/GIF only, checked by both MIME type and file extension, rejected with a specific 400 before the file is even buffered. A small `uploadSingle` wrapper was added so that rejection (and the pre-existing 10MB-limit rejection) returns a proper `400 {error: '...'}` instead of falling through to the generic 500 handler, which is what happened before (multer reports these via a callback, not a throw an async handler could catch). Existing folder whitelist and size limit are untouched.

### 🟡 Priority 14 — Error handling

New `backend/src/utils/asyncHandler.js` (`asyncHandler`, `HttpError`). Applied to every route in `orders.js`, `payments.js`, `products.js`, and `auth.js` — the exact areas ("order creation," "payment," "inventory," "authentication") the brief named, and the files this task modified substantially anyway. This matters because Express 4 does **not** forward a thrown/rejected error from an `async` route handler to the global error handler on its own; without `asyncHandler`, a thrown `HttpError` or a Mongoose error inside these new code paths (the transaction, the webhook) would have hung the request or surfaced as an unhandled rejection instead of a clean, safe response. Other, untouched route files (`categories.js`, `filters.js`, `coupons.js`, `returns.js`, `customers.js`, `banners.js`, `devices.js`, `notifications.js`) still have this same latent gap — noted here as a known follow-up rather than rewritten wholesale, since that was outside this task's scope.

### 🟡 Priority 15 — Idempotent order creation

`Order.idempotencyKey` (new field) with a compound sparse-unique index on `{userId, idempotencyKey}`. `POST /api/orders` reads an optional `Idempotency-Key` header; if a matching order already exists for that user+key, it's returned as-is (`200`) instead of creating a second one. The compound unique index is the real safety net for two genuinely concurrent identical requests — the loser gets a duplicate-key error, which is caught and turned into "fetch and return the winner's order" rather than a raw 500.

Mobile: `ApiClient.post()` gained an optional `headers` param (threaded through the 401-retry path too). `OrderCheckoutService` generates one UUID (`uuid` package, already a dependency) per service instance — which lives as long as the checkout/payment screen itself — and sends it as `Idempotency-Key` on every `placeOrder()` call made through that instance, so a double-tap or a retry-after-timeout during one checkout attempt carries the same key.

### 🟡 Priority 16 — Notification reliability

No code changes were needed here — reviewed and confirmed already correct: multi-device fan-out, dead-token pruning, the non-blocking `dispatch()` wrapper (a push failure never fails an order), the inbox-row-written-before-send pattern, and customer deep links were all already in place. The new code from this task (admin notifications, webhook-triggered notifications) consistently reuses the same `notifyUser()`/`dispatch()` path rather than adding a parallel one.

### 🟡 Priority 17 — Tests for critical business logic

Added `jest`, `supertest`, `mongodb-memory-server` as devDependencies (dev-only — nothing added to the production/Vercel dependency tree) plus `npm test`. Three suites under `backend/src/routes/__tests__/`:

- **`orders.test.js`** — server-computed pricing ignores a tampered client total; delivery charge is server-decided; an inactive product is rejected; a below-MOQ quantity is rejected; insufficient stock is rejected (and the product's stock is confirmed untouched — the transaction rolled back); two concurrent requests for the last 5 units of a 5-unit-stock product resolve to exactly one success and stock ending at exactly 0, never negative; an unauthenticated request is rejected; a repeated `Idempotency-Key` returns the original order and the stock is only deducted once.
- **`payments.test.js`** — a correctly signed client verify is accepted; a tampered signature is rejected; a signature valid for a *different* Razorpay order id is rejected (the cross-order replay guard added in Priority 4); a correctly signed webhook marks the order paid; the same webhook delivered twice is a no-op the second time; a webhook with an invalid signature is rejected; a `payment.failed` webhook marks a not-yet-paid order failed.
- **`auth.test.js`** — login succeeds with correct credentials; incorrect credentials get a generic 401; repeated login attempts trip the rate limiter (429 on the 11th); a non-admin token is rejected from an admin-only route (403) and an admin token is accepted (201) on the same route; the `?all=true` bypass is rejected unauthenticated (401) and for a non-admin (403), and works for an admin (200); the plain product listing stays public.

**All 25 tests pass.** (One infrastructure snag along the way, noted for whoever runs this next: `mongodb-memory-server@11.x`'s bundled MongoDB driver (7.6.0) failed its own internal handshake against the replica set it starts — `MongoServerError: Missing required sub-document 'driver'` — unrelated to any of this app's code. Pinning `mongodb-memory-server` to `10.4.3`, which dedupes onto the same driver version (`6.20.0`) Mongoose itself already uses, resolved it. `package.json` reflects this pinned version.)

Explicitly out of scope, per the brief: Flutter widget tests, full end-to-end tests, UI component tests.

---

## 2. Files Modified

### Backend (`backend/`)

| File | Why |
|---|---|
| `src/routes/orders.js` | Core rewrite: server-side pricing (P1), transactional stock deduction (P2), MOQ check (P3), status state machine (P8), pagination (P10), idempotency (P15), `asyncHandler` (P14), admin push dispatch (P7) |
| `src/routes/payments.js` | Server-driven Razorpay amount + `razorpayOrderId` persistence (P1), new webhook endpoint + cross-order replay guard (P4), `asyncHandler` (P14) |
| `src/routes/products.js` | `requireAdminForAllTrue` on the list route (P6), `asyncHandler` on every route (P14) |
| `src/routes/categories.js` | `requireAdminForAllTrue` (P6) |
| `src/routes/filters.js` | `requireAdminForAllTrue` (P6) |
| `src/routes/auth.js` | Rate limiters on the six sensitive endpoints (P5), `asyncHandler` (P14) |
| `src/routes/coupons.js` | Refactored to reuse `utils/pricing.js`'s `computeDiscount` instead of its own copy (P1) |
| `src/routes/profile.js` | `business_name` added to the editable-field map (P9) |
| `src/routes/upload.js` | MIME/extension `fileFilter` + a wrapper that turns multer's callback-style errors into proper 400s (P13) |
| `src/models/Order.js` | `idempotencyKey` field + its unique index (P15), `{status,createdAt}` index (P12), sparse `razorpayOrderId` index (P4/P12) |
| `src/models/User.js` | `businessName` field (P9) |
| `src/models/Notification.js` | `admin_new_order` enum value (P7) |
| `src/middleware/auth.js` | New `requireAdminForAllTrue` middleware (P6) |
| `src/middleware/rateLimit.js` **(new)** | Rate limiter configs (P5) |
| `src/utils/pricing.js` **(new)** | Centralized server-side money math (P1) |
| `src/utils/orderStatusMachine.js` **(new)** | Allowed order-status transitions (P8) |
| `src/utils/asyncHandler.js` **(new)** | Async route error forwarding + `HttpError` (P14) |
| `src/utils/serializers.js` | `business_name` in `serializeUser` (P9) |
| `src/services/orderNotifications.js` | New `notifyAdminNewOrder` (P7) |
| `src/config/env.js` | `RAZORPAY_WEBHOOK_SECRET` (P4) |
| `src/server.js` | `express.json()` raw-body capture for webhook signature verification (P4) |
| `.env.example` | Documented the new `RAZORPAY_WEBHOOK_SECRET` var (P4) |
| `package.json` | `express-rate-limit` dependency (P5); `jest`/`supertest`/`mongodb-memory-server` devDependencies + `test` script (P17) |
| `jest.config.js` **(new)** | Test runner config (P17) |
| `src/routes/__tests__/testHelpers.js`, `orders.test.js`, `payments.test.js`, `auth.test.js` **(new)** | The test suite (P17) |

### Admin dashboard (`admin_dashboard/`)

| File | Why |
|---|---|
| `src/App.jsx` | Push registration on login, `?order=` deep-link handling (P7) |
| `src/components/OrderManager.jsx` | Pagination + "Load more" (P10), highlight/scroll-to on deep link, 60s poll interval (P7/P11) |
| `src/pushService.js` **(new)** | Firebase Web SDK registration, foreground notification display (P7) |
| `public/firebase-messaging-sw.js` **(new)** | Background push handler + notification click → deep link (P7) |
| `.env.example` | New `VITE_FIREBASE_*` web config vars (P7) |
| `package.json` | `firebase` dependency (P7) |

### Mobile app (`mobile_app/`)

| File | Why |
|---|---|
| `lib/shop_ui/services/order_checkout_service.dart` | Minimal (non-financial) order payload, `app_order_id`-based Razorpay order creation, per-instance idempotency key (P1, P4, P15) |
| `lib/shop_ui/screens/checkout/views/payment_checkout_screen.dart` | Passes the order id (not an amount) to `createRazorpayOrder`; local total relabeled as display-only (P1) |
| `lib/shop_ui/controllers/cart_controller.dart` | MOQ-aware starting quantity and decrement floor (P3) |
| `lib/shared/models/product.dart` | `canFulfillMoq` getter (P3) |
| `lib/core/services/api_client.dart` | Optional `headers` param on `post()`, threaded through the token-refresh retry (P15) |
| `lib/shared/services/api_service.dart` | `createOrder()` accepts an `idempotencyKey` (P15) |
| `lib/shared/models/user_profile.dart` | `businessName` field (P9) |
| `lib/shop_ui/screens/onbording/views/onboarding_form_screen.dart` | Business name field (required), GST field relaxed to optional (P9) |

---

## 3. Testing Performed

- **Backend:** `npm test` — all 25 tests pass (see Priority 17 above for exactly what's covered). Every modified route file was also syntax-checked (`node -c`) and the whole app was `require()`'d standalone to confirm no import-time errors.
- **Admin dashboard:** `npm run build` succeeds (Vite). `npx eslint` run specifically on every file this task touched (`App.jsx`, `OrderManager.jsx`, `pushService.js`) — two real issues it caught (`react-hooks/set-state-in-effect` in both `App.jsx` and `OrderManager.jsx`) were fixed properly (deferred/derived state) rather than suppressed; the two remaining lint errors in `OrderManager.jsx` (`etaIsoFromNow`, `handleSet` — unused vars) were confirmed via `git show HEAD` to pre-date this session and were left alone as out of scope.
- **Mobile app:** `flutter analyze` run across the whole project. All pre-existing errors (in `banner_l_style_1.dart`, `checkbox_underline_list_tile.dart`, `order_process.dart`, `app_theme.dart` — dead template leftovers, confirmed via `git status` to be files this task never touched) are unrelated to this work. No new errors in any file this task modified.
- **Not verified end-to-end** (would require live credentials this environment doesn't have): an actual Razorpay webhook delivery against a real Razorpay account, actual FCM web push delivery to a real browser, and the mobile app's Razorpay checkout sheet against a live key. The signature/idempotency/reconciliation *logic* for all of these is covered by the Jest suite using synthetic, correctly-signed payloads.
- **Live backend caution:** this session deliberately did **not** start `npm run dev` against the real `backend/.env`, because that file was confirmed earlier in the session to point at what appears to be the actual production MongoDB Atlas cluster (the backend is live at a real Vercel URL). All verification went through the isolated in-memory test database instead, specifically to avoid writing test data into production.

---

## 4. Required Manual Setup (owner action items — nothing here was or could be done automatically)

1. **Razorpay webhook.** In the Razorpay Dashboard → Settings → Webhooks, add a webhook pointing at `https://<your-backend-url>/api/payments/razorpay/webhook`, subscribed to at least `payment.captured` and `payment.failed`. Copy the webhook secret it generates into `RAZORPAY_WEBHOOK_SECRET` in the backend's production environment variables (Vercel project settings) — **not** the same value as `RAZORPAY_KEY_SECRET`.
2. **Firebase Web App for admin push.** In the Firebase console (the same project already used for the mobile app's FCM), add a Web App (Project settings → General → Your apps → Add app → Web), then generate a Web Push certificate/VAPID key under the Cloud Messaging tab. Set `VITE_FIREBASE_API_KEY`, `VITE_FIREBASE_AUTH_DOMAIN`, `VITE_FIREBASE_PROJECT_ID`, `VITE_FIREBASE_STORAGE_BUCKET`, `VITE_FIREBASE_MESSAGING_SENDER_ID`, `VITE_FIREBASE_APP_ID`, and `VITE_FIREBASE_VAPID_KEY` in the admin dashboard's environment (both local `.env` for dev and its Vercel project settings for production). Until these are set, the dashboard runs exactly as before, with admin push simply disabled (a console warning, nothing broken).
3. **Razorpay production keys.** `RAZORPAY_KEY_ID`/`RAZORPAY_KEY_SECRET` are still test-mode keys (confirmed during the earlier audit) — swap to live keys when ready to accept real payments, and confirm the webhook secret above corresponds to the same (live) Razorpay account.

## 5. Known Follow-Ups (deliberately not done in this pass — flagged, not silently skipped)

- `GET /api/customers` and `GET /api/returns/admin/all` remain unpaginated (see Priority 10 above for why extending pagination there wasn't safe to do as a drive-by change).
- `categories.js`, `filters.js`, `coupons.js`, `returns.js`, `customers.js`, `banners.js`, `devices.js`, and `notifications.js` still lack the `asyncHandler` wrapper the touched files now have (Priority 14) — same latent Express-4-async-error gap, not fixed here since those files weren't otherwise part of this task.
- No GST/tax computation was added (none existed before; no rate/config source exists to compute one from — this was flagged as a legal question for the business owner in the original audit, not something to guess at in code).
- No refund automation, no admin reports/analytics, no delivery/staff role, no audit-log system beyond the single `console.warn` on a forced status override — all consistent with staying inside this task's 17 named priorities and not over-building.
