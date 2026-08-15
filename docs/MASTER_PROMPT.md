# B2B Store — Production Readiness Master Doc

_Last updated: 2026-07-23. This replaces the earlier aspirational spec (which described a Supabase + Google-OAuth architecture that was never actually built). Everything below reflects the **real, current state** of the codebase after the Supabase → MongoDB/Cloudinary/custom-backend migration._

## How to read this doc

Each issue has a **priority**:
- 🔴 **Blocker** — must fix before Play Store submission or before real users touch the app.
- 🟠 **High** — will cause real problems in production; fix soon after launch if not before.
- 🟡 **Medium** — degrades quality/scale but won't break things immediately.
- 🟢 **Low / nice-to-have** — polish.

Every recommendation respects the constraint: **free alternatives only, no paid services.** Where a "free tier of a commercial product" is suggested, that's called out explicitly so you can decide — the default recommendation is always the genuinely-free/open option.

---

## 1. Architecture snapshot (current, accurate)

- **`backend/`** — Node/Express + Mongoose, running against **MongoDB Atlas** (free M0 cluster). JWT auth (access + refresh tokens for the mobile app, httpOnly cookie for the admin dashboard). **Cloudinary** for all images (verified working, including delete-on-replace/delete-on-remove). **Razorpay** for online payments (currently test-mode keys). Nodemailer/SMTP for password-reset emails (6-digit code, not magic link).
- **`mobile_app/`** — Flutter. Talks to the backend over REST via `ApiClient`. No more Supabase, no more Google Sign-In (was declared but never implemented). Cart persists via `shared_preferences` (just fixed — was broken on web via `path_provider`).
- **`admin_dashboard/`** — React/Vite. Real backend-verified admin login (replaced the old hardcoded-credentials client-side gate). Filter Manager, Category Manager, Inventory, Orders, Returns, Coupons, Brands, Banners all wired to the REST API.
- **Nothing is deployed anywhere.** Backend, admin dashboard, and mobile app have only ever been run locally on the dev machine. For the Play Store app to work for real users, the backend needs to be hosted somewhere publicly reachable — see [§5](#5-deployment-nothing-is-hosted-yet-🔴-blocker).

---

## 2. Known issue: inaccurate "select location from map" 🟠 High

Root-caused by direct code inspection (`location_service.dart`, `map_location_picker_screen.dart`). Four concrete, fixable bugs plus one inherent trade-off of using a free geocoder:

1. **GPS accuracy isn't maximized.** `location_service.dart` requests `LocationAccuracy.high` (~10m target) instead of `LocationAccuracy.best`, and accepts the very first GPS fix with no accuracy/staleness check. The map can start centered tens of meters off.
2. **No debouncing on map drag.** `map_location_picker_screen.dart` fires a fresh Nominatim (OpenStreetMap) reverse-geocode request on *every single* map-move-end event, with no debounce timer and no request cancellation. A user nudging the map a few times in quick succession fires several overlapping requests — well past Nominatim's free-tier 1-request/second usage policy, risking `429` rate-limit responses.
3. **Silent, indistinguishable failure fallback — this is almost certainly the dominant cause of "inaccurate" reports.** When a reverse-geocode call fails for *any* reason (rate limit, timeout, sparse OSM data), the code falls back to displaying the raw `"lat, lon"` coordinate string as if it were a real address, with only a `debugPrint` (invisible in production) noting the real cause. A user can select and confirm a location that never actually resolved to a real address, with no visible indication that anything went wrong. A stale, late-arriving response can also silently overwrite a newer one (no request-id guard).
4. **No minimum zoom enforced.** A user can zoom out to city-level and confirm a location — the pin looks "precise" but the underlying coordinate (and the address resolved for it) is coarse.
5. **Inherent limitation (not a bug):** Nominatim/OpenStreetMap's crowd-sourced address data is genuinely sparse in many Indian rural/peri-urban/newly-built areas. Even with all four bugs above fixed, some addresses will only resolve to road/locality level rather than a precise street address — this is the trade-off of a free geocoder vs. a commercial one (Google/Mapbox), and should be treated as accepted, not "fixed."

### Fix (all free, no new paid dependency)
- Raise `LocationAccuracy.high` → `LocationAccuracy.best` in `location_service.dart`.
- Add a ~600-800ms debounce after `MapEventMoveEnd` before calling Nominatim, plus a request-id/token guard so a stale response can't overwrite a newer one.
- Make reverse-geocode failure an explicit, visible UI state ("Couldn't determine address — try again or enter manually") instead of silently showing raw coordinates as if they were a resolved address.
- Add a minimum-zoom gate (e.g. require zoom ≥ 16) before enabling "Confirm Location."
- If Nominatim's public rate limit becomes a real bottleneck at scale, the free (no API key, no payment) alternative is **Photon** (by Komoot, built on the same OSM data, more generous public usage) rather than a commercial geocoder. Only mention as a fallback if debouncing alone isn't enough.

---

## 3. Security hardening needed 🔴 Blocker (before real users) / 🟠 High

All found via direct code review of `backend/src`:

1. **No rate limiting anywhere** — `/api/auth/signup`, `/login`, `/admin/login`, and `/forgot-password` are all brute-forceable today. **Fix (free):** add `express-rate-limit` (free npm package, no external service) — e.g. 5 attempts/15min per IP on auth routes.
2. **No security headers** — no Helmet. **Fix (free):** add the `helmet` npm package, one line in `server.js`.
3. **NoSQL injection / ReDoS risk** — `GET /api/products` passes `req.query.category_id`, `search`, etc. straight into Mongoose filters with no sanitization. Express's default query parser turns bracket-notation strings like `?category_id[$ne]=null` into nested objects, which can flow into a `$ne`/`$in` Mongo operator unintended by the route. The `search` param also goes straight into a `$regex` with no escaping (a crafted pathological search string is a ReDoS vector). **Fix (free):** add `express-mongo-sanitize` middleware (strips `$`-prefixed keys from `req.query`/`req.body`), and escape regex special characters before building the `$regex` filter.
4. **Password policy is minimal** — only a 6-character minimum, no complexity requirement, no max length (long-password bcrypt DoS is low-risk but free to close). **Fix (free):** tighten server-side validation to match what was just added to the mobile signup form (8+ chars, upper/lower/number/special) for consistency, plus a sane max length (e.g. 128 chars).
5. **No structured logging or error tracking** — just `console.error`. Fine for now, but you'll have no visibility into production errors once this is deployed and no longer sitting in front of you in a terminal. **Fix (free):** self-contained option is `pino`/`morgan` for structured request/error logs (fully free, no third party). If you want hosted error alerting, Sentry has a free tier (with a monthly event cap) — optional, not required.

---

## 4. Play Store submission blockers 🔴 Blocker

Everything below must be addressed before this app can be uploaded to Google Play. None of it exists yet:

1. **`applicationId`/`namespace` is still `com.example.b2b_store`** (`android/app/build.gradle.kts`) — the Flutter template default. **This cannot be changed after the first Play Store publish**, so it must be set correctly (a real, owned package id, e.g. `com.yourcompany.b2bstore`) before the very first upload.
2. **Release builds are signed with the debug keystore** (`build.gradle.kts`: `signingConfig = signingConfigs.getByName("debug")`). Google Play will reject an upload signed this way. Need to: generate a real release keystore, create `key.properties` (gitignored, never committed), and wire a proper `signingConfigs.release` block.
3. **App icon is still the default Flutter icon.** `flutter_launcher_icons` is installed as a dependency but never configured (no config block in `pubspec.yaml`, no source PNG). Needs a real logo (a source SVG exists at `assets/logo/Shoplon.svg` but needs converting to PNG and wiring through `flutter_launcher_icons`).
4. **App display label is still `"b2b_store"`** (`AndroidManifest.xml`) — needs the real product/brand name (shows under the home-screen icon and in the Play Store listing).
5. **No privacy policy exists anywhere** — searched the entire app, zero matches for "privacy policy" content or URL. There's a Terms & Conditions screen with a one-line "see our Privacy Policy" reference that points nowhere. **Since the app requests location permission and collects account/order data, Google Play requires a real, publicly-hosted privacy policy URL in the Play Console listing.** This needs to be written (what data is collected, how it's used, third parties involved — Cloudinary, Razorpay, MongoDB Atlas — data retention, deletion process) and hosted somewhere public (a free GitHub Pages page works fine for this, zero cost).
6. **No release minification configured** (no `isMinifyEnabled`, no `proguard-rules.pro`) — not a hard blocker, but worth a deliberate decision (enable + test, or explicitly leave off) rather than defaulting by omission.
7. **Stock white splash screen, unedited `README.md`** — cosmetic, not blockers, but worth doing before a public release.
8. **Leftover dead deep-link intent-filter** in `AndroidManifest.xml` referencing `io.supabase.b2bstore://` from the old Supabase magic-link password reset — no longer used since password reset is now a 6-digit-code flow, not a deep link. Safe, trivial cleanup.

---

## 5. Deployment: nothing is hosted yet 🔴 Blocker

Backend, admin dashboard, and mobile app's `.env` all point at `localhost`. For the Play Store app to function for a single real user outside this dev machine, the backend must be deployed somewhere publicly reachable, with production env vars (Mongo URI, JWT secrets, Cloudinary, Razorpay, SMTP, and a production `CORS_ORIGIN`) configured there — not on this machine.

**Free hosting options for the backend** (genuinely free, not just a trial credit):
- **Render** — free web service tier, ~750 hrs/month. Known trade-off: free-tier services spin down after ~15 min of inactivity and take 30-60s to cold-start on the next request — noticeable but acceptable for early-stage traffic, not something you'd want at real scale.
- **Fly.io** — has a limited free allowance for small always-on VMs; check current terms, allowance changes over time.
- MongoDB Atlas (already in use) and Cloudinary (already in use) are both already on genuinely free tiers — no change needed there.

**Be upfront with yourself about the trade-off**: free hosting tiers for a production consumer app come with cold starts and resource caps. That's an acceptable starting point, not a permanent architecture — plan to revisit once there's real order volume.

Once hosted, the mobile app's `API_BASE_URL` and the admin dashboard's `VITE_API_BASE_URL` need to point at the real backend URL instead of `localhost`, and the backend's `CORS_ORIGIN` needs to include the admin dashboard's real deployed origin (Vercel/Netlify free tiers both work fine for the Vite admin dashboard, and `admin_dashboard/.vercel/` suggests Vercel was already set up for it at some point).

---

## 6. Missing features / incomplete flows 🟠 High / 🟡 Medium

- **No push notifications** 🟠 — order/return status updates only refresh while the specific screen is open (5-second polling). Close the app or navigate away, and the customer gets zero notification of "your order is out for delivery" etc. **Free fix:** Firebase Cloud Messaging (FCM) is free with no usage cap for this kind of volume — this is the standard, no-cost way to add real push notifications to a Flutter app. This is a real feature addition (needs Firebase project setup, `firebase_messaging` package, backend trigger on order-status change), not a quick patch — worth scoping as its own task when ready.
- **"Edit Profile" button does nothing** 🟡 — `user_info_screen.dart` has a literal `// TODO: Implement Edit Profile` with an empty button handler.
- **Admin has no in-product password recovery** 🟡 — the admin dashboard login has no "forgot password" link. The only way to set/reset an admin account today is the `npm run seed` script with `ADMIN_SEED_EMAIL`/`ADMIN_SEED_PASSWORD` env vars. The backend's generic reset-password endpoints would technically work for an admin account too (no role restriction), just nothing in the admin UI is wired to them.
- **Admin order/return lists are unbounded** 🟡 — `GET /api/orders/admin/all` and `GET /api/returns/admin/all` have no pagination (`.limit()`/`.skip()`) at all, unlike the customer-facing product endpoints which cap at 100. Fine today, will slow down and re-fetch/re-render everything on every 30-second poll once order volume grows. Fix is straightforward — add the same limit/skip pattern already used elsewhere in the backend.
- **Two Flutter web-testing-only crash modes** (not relevant to the real Android app, documented here so they're not mistaken for app bugs later): a browser-back-button Navigator assertion crash, and `razorpay_flutter` has no web implementation at all (Online Payment simply can't be tested outside a real device/emulator). Neither affects the production Android build.

---

## 7. Testing — essentially none 🟡 Medium

- `mobile_app/test/widget_test.dart` is the **unmodified default Flutter template** "counter increments" smoke test — it doesn't test anything about this app (auth, cart, checkout, orders) and would likely fail or be meaningless if run.
- `backend/` has no test files and no test framework installed at all.
- `admin_dashboard/` has no test files and no test runner configured.

This isn't a blocker for a first release given the scope of everything else here, but it means every change from now on is verified manually. Worth adding basic coverage (a handful of backend route tests with Jest/Vitest + supertest is the highest-leverage first step, since that's the one shared dependency both frontends rely on) before the app has real users and real money moving through it.

---

## 8. What's already been fixed this session (for context — don't re-investigate these)

- Full Supabase → MongoDB Atlas + Cloudinary + custom JWT auth migration, including the two Razorpay edge functions ported to Express routes.
- Fixed: products' split `is_active`/`is_available` flags unified into one.
- Fixed: coupon schema mismatch between admin and mobile (`discount_percent`/`min_order_value` → `discount_type`/`discount_value`/`min_order_amount`).
- Fixed: admin dashboard's client-side-only login (zero real access control) replaced with real backend-verified auth + role checks on every admin endpoint.
- Fixed: `AddProduct.jsx`'s duplicated, buggy filter-scope-matching logic replaced with a direct call to the backend's already-correct endpoint; re-enabled the "Global" filter scope in Filter Manager (was fully wired everywhere except the admin UI that creates them).
- Verified end-to-end: Cloudinary upload/delete lifecycle (confirmed via Cloudinary's own Admin API that replaced/removed images are actually deleted, not orphaned).
- Fixed: order creation crash (`FormatException: Invalid date format`) caused by `estimatedDeliveryTime` defaulting to `''` instead of `null`.
- Fixed: cart persistence crash on web (`path_provider` → `shared_preferences`); note this also incidentally makes cart persistence more robust on real devices, not just web.
- Improved: signup form now has show/hide password toggles, real password-strength validation, and the non-functional "I agree to Terms" checkbox was removed.

---

## 9. Suggested priority order

1. **Security hardening** (§3) — rate limiting, Helmet, Mongo sanitization. Small, fast, no new infra.
2. **Deploy the backend somewhere real** (§5) — nothing else matters until this exists; the app is untestable by anyone but you until then.
3. **Play Store blockers** (§4) — package id, signing, icon, label, privacy policy. These gate submission entirely.
4. **Location/map fixes** (§2) — debounce + explicit failure state are the highest-value, lowest-effort wins; GPS accuracy and min-zoom are quick follow-ups.
5. **Missing features** (§6) — push notifications is the biggest one; everything else there is small.
6. **Testing** (§7) — start once the above stabilizes, so tests are written against the real production shape rather than a moving target.
