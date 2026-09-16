# Writing Kids — full UX upgrade

## Included
- Offline-first TRACE → COPY → WRITE lessons.
- A–Z uppercase + lowercase, 0–9, beginner words.
- 500 paid-library words in a one-time AI-prepared/reviewed corpus; runtime only picks locally.
- Free and paid word pools.
- Pronunciation with browser Speech Synthesis; the previous utterance is cancelled before a new one so taps do not build a long queue.
- Bundled background music and tiny local sound effects.
- Lightweight moving objects on Welcome, Home and Practice screens.
- Mosquito Pop: child stays on a fixed spot; mosquitoes approach; tapping them creates a cartoon burst/pop, score and misses. Levels are unlimited and each level adds more mosquitoes.
- Local mastery/progress storage.
- Firebase Anonymous Auth + FCM web setup, with startup timeouts so Firebase cannot block offline learning.
- Privacy, Terms, About and Disclaimer screens.
- Parent/guardian confirmation before Premium purchase.
- Premium is unlocked only after server-side Flutterwave verification.
- Flutterwave v4 direct-card server endpoints for customer, encrypted card payment method, charge, PIN/OTP authorization, verification and webhook handling.

## Flutterwave v4 recurring billing
The Premium subscription is **$1.99 USD/month or ₦2,000 NGN/month**, selected by the parent before payment. This build uses Flutterwave's current **v4 OAuth API**: `FLW_CLIENT_ID`, `FLW_CLIENT_SECRET`, and `FLW_V4_ENCRYPTION_KEY`. Flutterwave v4 documents OAuth client credentials, AES-256 card encryption, payment-method tokenization, and recurring charges using a stored payment-method ID. citeturn0search6turn0search7turn1search1

The first payment creates a Flutterwave customer and card payment method, then starts a charge. If Flutterwave requires PIN, OTP, or a redirect/3-D Secure step, the app continues that authorization flow. After a successful charge, only the Flutterwave customer/payment-method IDs and subscription metadata are stored; raw card data, CVV and PIN are not stored. Flutterwave documents that recurring tokenized charges use the stored payment-method ID with `recurring: true` and do not require another authorization step. citeturn1search1

Because v4 tokenization itself does not create a calendar subscription, this project includes a Vercel Cron job that checks stored subscriptions and creates the next monthly recurring charge. Subscription records are stored in Supabase Postgres. Required additional server variables are `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and `CRON_SECRET`. The cron job runs daily and only charges subscriptions whose next billing time is due. Vercel Hobby supports daily cron execution; more frequent scheduling requires a plan that supports it.

Required Vercel variables:
- `FLW_CLIENT_ID` — Flutterwave v4 Client ID.
- `FLW_CLIENT_SECRET` — Flutterwave v4 Client Secret.
- `FLW_V4_ENCRYPTION_KEY` — Flutterwave v4 encryption key.
- `FLW_WEBHOOK_SECRET_HASH` — webhook signature secret.
- `PUBLIC_APP_URL` — your deployed Writing Kids URL.
- `SUPABASE_URL` — Supabase project URL.
- `SUPABASE_SERVICE_ROLE_KEY` — Supabase server-only service-role key. Never expose this in Flutter/web code.
- `CRON_SECRET` — random secret used to protect the recurring-billing cron endpoint.
- `FLW_V4_BASE_URL` — optional; defaults to Flutterwave production v4 base.

**Important:** automatic recurring billing cannot be honestly implemented with only three Flutterwave credentials and no persistent subscription store/scheduler. The three Flutterwave credentials authenticate and encrypt the payment flow; Supabase stores the tokenized subscription record and Vercel Cron performs the monthly billing job.

## Monthly billing
Premium is implemented with Flutterwave v4 tokenized recurring charges, Supabase Postgres for persistent subscription state, and Vercel Cron for the monthly billing check. It does **not** use Flutterwave v3 Payment Plans. Run `supabase/schema.sql` once in the Supabase SQL Editor before deploying.

## Firebase / FCM
Firebase Web config and the FCM VAPID public key are hardcoded as requested. Anonymous Auth must be enabled in Firebase Console. Web FCM requires HTTPS, notification permission and the Firebase Messaging service worker. Firebase's current Flutter/Web guidance confirms the service-worker requirement and VAPID/token flow. citeturn3search0turn3search4

## Privacy / child safety baseline
The app is designed to minimize data: core learning and progress stay local; there is no child-facing account creation; notifications use an anonymous Firebase identity/token only when enabled; payment data is used only for payment processing and is not intentionally stored by the Flutter client. The legal screens are a baseline, not a substitute for jurisdiction/store-specific legal review.

## Important technical limitation
The tracing percentage is still a **practice/activity score**, not genuine handwriting-shape recognition. Do not market it as AI handwriting recognition until stroke-template/path matching or a handwriting-recognition engine is added.

## Verification
This environment does not contain the Flutter SDK, so `flutter analyze` and `flutter build web` could not be executed here. JavaScript payment functions were syntax-checked with Node, assets were inspected, and the project was statically reviewed. Run the final Flutter build on Flutter-enabled CI or a machine before publishing.
