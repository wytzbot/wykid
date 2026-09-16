# Writing Kids — perfection pass (changes in this build)

I did a full static review of the Flutter app (`lib/main.dart`) and the
Vercel/Supabase payment backend (no Flutter SDK is available in this
environment, so nothing was build-tested — review `README.md`'s existing
"Verification" note and run `flutter analyze` / `flutter build web` before
publishing). Fixes below are all real bugs or missing-feature gaps I found,
not cosmetic guesses.

## 1. The "500-word AI library" wasn't actually wired up (biggest fix)
`assets/data/ai_words.json` bundles the full reviewed 500-word paid corpus
and a 30-word free sample — exactly what the README promises — but
`lib/main.dart` never read that file. The "New Words ✨" screen and Premium
unlock were quietly serving a much smaller, different hardcoded word list
instead. Added a `WordLibrary` loader that reads the bundled JSON at
runtime (via `rootBundle`), with the old hardcoded lists kept only as an
offline-safe fallback if the asset is ever missing or corrupted. The New
Words screen now shows a brief loading spinner while it loads, and never
repeats the same word twice in a row.

## 2. Parents could lose Premium for up to a day for no reason
`api/payments/subscription.js` treated the subscription as inactive the
instant `next_charge_at` passed — but recurring charges only run once a day
via Vercel Cron (`vercel.json`). That meant a paying family's Premium could
flicker off for up to ~24h every month while waiting for the cron job to
actually renew it, even though nothing had failed. Added a 2-day grace
window so access stays smooth through the renewal cron cycle; the cron/
webhook still moves `next_charge_at` forward (or cancels) once it processes
the charge.

## 3. Repeated scary "payment failed" message on a page you didn't touch
`PremiumPage` re-checked any leftover `pendingChargeId` every time it
opened — including days later, with no actual payment attempt in progress —
and showed "Payment was not completed successfully" each time. Now that
background check is silent unless the parent just landed back from an
actual payment redirect; a stale pending charge is cleared quietly instead
of being re-reported as a failure.

## 4. Missing client-side expiry-month validation
The card form only checked that the expiry field had 4 digits, not that the
month was 01–12, so an obviously invalid expiry (e.g. `1325`) would round-trip
to the server before failing. Added an immediate local check.

## 5. Two bundled sound effects were dead code
`good.wav` and `game_tick.wav` shipped in `assets/audio/` but were never
played. A trace/write attempt scoring 40–79% played no sound at all (only
the extremes — "excellent" and "try again" — had audio), which feels like
a missing/broken feedback loop in a kids' app. `good.wav` now plays for
that middle band, and a soft `game_tick.wav` plays on starting a new pen
stroke for a bit of tactile feedback.

## Reviewed and left as-is (working as intended)
- Firebase/FCM startup timeouts, anonymous auth, and the offline-first
  design are all sound — core lessons never block on network calls.
- Flutterwave v4 OAuth, AES-256-GCM card/PIN encryption, and the
  charge → authorize (PIN/OTP) → verify flow in `api/payments/` are
  correctly wired end-to-end and match the documented v4 flow.
- Mosquito Pop's spawn/collision/level-scaling loop, the trace-pad stroke
  scoring, and the welcome-screen floating animations all run cleanly with
  no leaks (animation controllers and audio players are disposed properly).

## One known trade-off worth a decision, not fixed here
`api/payments/cron.js` retries a failed recurring charge daily forever but
never flips a subscription to `cancelled`/`past_due` after repeated
failures (e.g. an expired card). That currently *errs in the child's
favor* — Premium keeps working rather than getting yanked — but means a
truly dead card never actually gets cut off. Fixing this properly needs a
small schema change (a failure-count column) and a decision on the retry
policy, so I left it as a deliberate, documented choice rather than
guessing at business rules.

## 6. The recurring-billing trade-off is now fixed
`api/payments/cron.js` now counts consecutive failed renewal charges
(`fail_count`, added to `supabase/schema.sql` — re-run that file in the
Supabase SQL editor to add the column to an existing table) and cancels the
subscription after 3 in a row instead of retrying forever. A single blip
(bank hiccup, temporary decline) still gets same-day-tomorrow retries and
doesn't cost the family anything; a genuinely dead card now actually stops
being charged against and the child's Premium is correctly turned off.
`fail_count` resets to 0 on any successful charge (initial payment, cron
renewal, or webhook-confirmed charge).
