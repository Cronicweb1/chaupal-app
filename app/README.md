# Chaupal — Flutter port

Board games & baithak: Ludo, Carrom, Tic Tac Toe (Classic / Infinity / Nine Board) and Snakes & Ladders, with coins, streaks, Lucky Spin, missions, badges, weekly cups & league, a market (skins, frames, emotes, victory effects, bundles, season pass, daily reward, deals, Diwali collection), status tiers, and the 18+ Baithak chat rooms with moderation.

## Run

```bash
flutter create . --platforms=android,ios     # generates the platform folders next to lib/
flutter pub get
flutter run
```

Requires Flutter 3.16+ (Dart 3.2+). Dependencies: `shared_preferences` (save file), `url_launcher` (WhatsApp share).

For WhatsApp sharing on Android 11+, add to `android/app/src/main/AndroidManifest.xml` inside `<manifest>`:

```xml
<queries>
  <intent><action android:name="android.intent.action.VIEW" /><data android:scheme="https" /></intent>
</queries>
```

## Layout

- `lib/main.dart` — app shell, tab bar Adda · Cups · Play (raised) · Baithak · Profile, coin pill opens Market, global mute, toasts, 45-minute break reminder, dev tools (tap the wordmark 5×).
- `lib/adda_state.dart` — posts, comments, follows, blocks, hidden posts, creator programme state + stats (persisted with the save).
- `lib/store.dart` — all persisted state (`AppStore`), economy, rollover, streak, cups settlement, market, pass, daily reward, spin.
- `lib/models.dart` — games, formats, tiers, leagues, cups, catalogue, rooms, moderation filters, vibe quiz, name rules.
- `lib/theme.dart` — tokens and shared widgets (Btn, Panel, Pill, Face, Seat, DiceWidget, sheet).
- `lib/games/` — `ludo.dart`, `carrom.dart` (time-based physics, 8 s watchdog), `ttt.dart`, `snakes.dart`, `host.dart` (format picker, matchmaking, clock, chat bar, result screen with instant coins + optional 15 s ad to double, WhatsApp share, rematch).
- `lib/tabs/` — Adda (feed, follows, public profiles, reports/blocks, Creator Partner Program), Cups, Play, Baithak, Profile; Market opens from the coin pill.
- `lib/onboarding.dart` — welcome bonus, referral code, 3-step tour.

## Rules carried over from the web build

- Limited-move formats (Snakes Plus, Ludo Turbo): bonus rolls after a six, cut, ladder or home are free.
- Coins are credited the moment a match ends; the rewarded ad only doubles them.
- Sound and haptics follow one global switch and go silent when the app is backgrounded.
- In-game typed words cost 2 coins each; emojis and Hinglish quick lines are free. Baithak words cost 1 coin each unless your tier or a chat pass makes them free.
- Names and age are set once. Under-18 accounts never unlock Baithak.
- Adda: 100-coin unlock, 3 posts/day, follow/unfollow, every profile public, report (child safety / sexual / violence escalate and hide instantly), block hides both ways, three-tier text moderation with a zero-tolerance tier that flags the account.

## Going live — see GO_LIVE_GUIDE.md (plain-language, step by step)

Connection layer already in the app: `lib/config.dart` (3 values), `lib/backend.dart` (Supabase Auth + REST), `lib/realtime.dart` (Socket.IO), `lib/auth_screen.dart` (phone/email OTP, Google), `lib/games/online_host.dart` (live multiplayer for all four boards, rendered from server state). With the config filled, `AppStore` syncs from `/v1/me` and mirrors every purchase/claim to the server; with it empty the app runs offline exactly as before.

## Going live (technical)

The app runs fully on-device today (bots, local saves). To connect it to the Node/Supabase backend in `chaupal-backend/`: add `supabase_flutter` for phone-OTP/Google sign-in, replace `AppStore` mutations with the REST calls in `chaupal-backend/docs/API.md`, and drive the four boards from `match:state` socket events (`socket_io_client`) instead of the local engines. `AppStore` is the single seam — every screen reads from it.

## Not ported (web-only in the original)

Profile photo upload/moderation queue, private 1:1 rooms with vibe-matching and refunds, message reactions, the illustrated SVG avatar set (replaced with palette marks). Synthesised tones are replaced with system click + haptics — drop in an audio package if you want the original chimes.
