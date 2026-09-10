# Chaupal — go-live guide

This guide walks through connecting the app to the backend and shipping it. The app already works offline with bots; the online pieces are optional.

## Part 1 — Supabase (free tier is enough to start)

1. Go to **supabase.com** → sign in → **New project** → pick a strong database password.
2. In the left sidebar click **SQL Editor** → **New query**.
3. On your computer open the folder `chaupal-backend/supabase/migrations/`. Open `0001_schema.sql` in Notepad (or TextEdit), select all, copy, paste into the Supabase query box, click **Run**. You should see "Success".
4. Repeat step 4 for `0002_adda.sql`, `0003_adda_social_safety.sql`, `0004_security_scale.sql` — **in that order** — and then `chaupal-backend/supabase/seed.sql`.
5. Sidebar → **Authentication** → **Providers**. Turn on **Email** (keep "Confirm email" off for testing). Phone sign-in needs an SMS provider (MSG91 or Twilio) — you can add that later; email codes work for testing.
6. Sidebar → **Project Settings** (gear) → **API**. Copy these three into your notes:
   - **Project URL** (looks like `https://abcd1234.supabase.co`)
   - **anon public** key (long text starting with `eyJ`)
   - **service_role** key (also starts with `eyJ` — this one is secret; never put it in the app)
7. Same page, scroll to **JWT Settings** → copy the **JWT Secret** into your notes.

## Part 2 — The game server (Railway, ~₹400/month)

1. Go to **github.com** → sign up → **New repository** → name `chaupal-backend`, Private → **Create repository**.
2. On the new repo page click **uploading an existing file**. Drag the *contents* of your `chaupal-backend` folder (the `src` folder, `package.json`, `supabase` folder, etc.) into the box. Click **Commit changes**. (Do **not** upload a `.env` file.)
3. Go to **railway.app** → **Login with GitHub** → **New Project** → **Deploy from GitHub repo** → pick `chaupal-backend`.
4. Click the new service → **Variables** → **Raw Editor** → paste this, replacing the values from your notes:
   ```
   SUPABASE_URL=https://abcd1234.supabase.co
   SUPABASE_SERVICE_ROLE_KEY=eyJ...service role key...
   SUPABASE_JWT_SECRET=...jwt secret...
   PORT=8080
   CORS_ORIGINS=*
   ADS_DEV_MODE=true
   STAFF_TOKEN=pick-a-long-random-password
   KYC_SALT=pick-another-long-random-text
   VISION_PROVIDER=manual
   ATTEST_REQUIRED=false
   ```
   Click **Update variables**. Railway redeploys automatically.
5. **Settings** → **Networking** → **Generate Domain**. Copy the address (like `https://chaupal-backend-production.up.railway.app`).
6. Open that address with `/health` on the end in your browser. You should see `{"ok":true,...}`. If you see an error, click **Deployments** → the latest one → **View logs**; the last red line says what's missing.

## Part 3 — The app (Flutter)

1. Install **Flutter**: go to **docs.flutter.dev/get-started/install**, choose your computer type, follow the installer. Also install **Android Studio** when it asks. This is the longest step (30–60 min) — it's a one-time setup.
2. Open the folder `chaupal_flutter/lib/` and open **`config.dart`** in Notepad. Fill the three lines between the quotes:
   ```
   static const backendUrl = 'https://chaupal-backend-production.up.railway.app';
   static const supabaseUrl = 'https://abcd1234.supabase.co';
   static const supabaseAnonKey = 'eyJ...anon key...';
   ```
   Save. (Leave them empty and the app runs offline against bots — that still works.)
3. On your Android phone: **Settings → About phone → tap "Build number" 7 times** to enable Developer options, then **Settings → Developer options → USB debugging: on**. Plug the phone in and tap **Allow**.
4. Open a terminal (Windows: search "cmd"; Mac: "Terminal"), then type these lines one at a time, pressing Enter after each:
   ```
   cd path/to/chaupal_flutter
   flutter create . --platforms=android,ios
   flutter pub get
   flutter run
   ```
   The first `flutter run` takes several minutes. The app opens on your phone.
5. Sign in with your email → enter the 6-digit code from the email → play **Quick Play**. When the game ends, go to Supabase → **Table Editor** → **wallets** and you'll see your coins on the server.

To make an installable file to share with friends: `flutter build apk --release`. The file is at `build/app/outputs/flutter-apk/app-release.apk`. Send it on WhatsApp; they tap it to install (they'll need to allow "install from unknown sources").

---

## If something goes wrong

- **"flutter: command not found"** → Flutter isn't on your PATH; re-run the installer step "Update your path".
- **Red text when running `flutter run`** → copy the first error line and search it; most first-build errors are one missing line. A Flutter developer fixes these in an hour — the app was written without a compiler at hand.
- **App shows "Offline · …"** → check `config.dart` values and that `/health` opens in your browser.
- **"Rate limited" on sign-in** → Supabase free tier allows a few emails per hour; wait or add an SMS provider.
- **Server logs say `relation … does not exist`** → a migration didn't run; re-run Parts 1.4–1.5 in order.

## What still needs a professional (budget for it)

1. Play Store / App Store listing, signing keys, privacy policy hosting (₹2,000 Play Console fee, $99/yr Apple).
2. Real rewarded ads: AdMob account + SDK in the app, then set `ADS_DEV_MODE=false` and point AdMob's server-side verification to `<your server>/ads/ssv`.
3. Creator payouts: a KYC vendor (Digio/HyperVerge) and a payout gateway (Razorpay/Cashfree), plus a CA for TDS.
4. SMS OTP provider (MSG91 is cheapest in India), push notifications, crash reporting.
5. A moderation person with access to `/staff/*` endpoints (a small admin page is a good first job for the developer).

Keep these safe and never share them: the **service_role key**, the **JWT secret**, `STAFF_TOKEN`, `KYC_SALT`, and your Supabase database password.
