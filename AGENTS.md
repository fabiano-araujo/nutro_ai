# AGENTS.md

This file guides coding agents working in this repository.

## 1) Repository Snapshot

- Mobile app: Flutter project in repository root (`lib/`, `android/`, `ios/`).
- Backend API: Fastify + Prisma in `dieta_api/`.
- App name: `nutro_ai` (`pubspec.yaml`).
- API constants used by Flutter are defined in `lib/util/app_constants.dart`:
  - `API_BASE_URL = https://nutro-api.snapdark.com`
  - `DIET_API_BASE_URL = https://nutro-api.snapdark.com` (same origin as `API_BASE_URL`)

## 2) Architecture

### Flutter frontend

- Entry point: `lib/main.dart`
  - Initializes Firebase, notifications, ads, auth restore, providers, theme, and i18n.
- Main navigation: `lib/screens/main_navigation.dart`
  - Uses `IndexedStack` with 5 tabs:
    - `NutritionAssistantScreen`
    - `DailyMealsScreen`
    - `PersonalizedDietScreen`
    - `SocialHubScreen`
    - `ProfileTabWrapper` (Profile/Login by auth state)
- State management: `provider` + `ChangeNotifier`.
- AI client service: `lib/services/ai_service.dart`.

### Backend (`dieta_api`)

- Server entry: `dieta_api/src/index.ts` (Fastify app, CORS, optional HTTPS in production).
- Route registry: `dieta_api/src/routes/index.ts`.
- AI endpoints: `dieta_api/src/routes/ai.routes.ts`.
  - Includes `POST /ai/transcribe-audio` for chat audio transcription on the server.
- Subscription purchase confirmation: `POST /subscription/google-play/confirm`
  - Validates the Google Play `purchaseToken` on the backend and upserts the user subscription as premium.
- Rewarded ad credit grant: `POST /credits/rewarded-ad`
  - Requires auth token, credits the authenticated user with the server-side rewarded ad amount, and returns the updated credit balance.
- AI model mapping: `dieta_api/src/config/ai-models.config.ts`.
  - Global default text model: `deepseek/deepseek-v4-flash-0731` for server fallbacks, text aliases, and My Diet generation.
  - `deepseek/deepseek-v4-flash-0731` delegates dynamic provider selection to OpenRouter with price sorting, preferred p50 throughput of 60 TPS, preferred p50/p90 latency of 1s/3s, fallbacks enabled, and hard prompt/completion price limits of $0.14/$0.28 per million tokens. Do not add periodic endpoint-metadata polling for this routing.
  - Automatic image analysis and profile-shape image generation use the same OpenRouter-managed provider policy. Explicit provider overrides remain supported. Image analysis performs one model request only; do not add shadow/comparison model calls.
- Streaming connection lifecycle: `dieta_api/src/services/connection.service.ts`.
- OpenRouter integration: `dieta_api/src/services/openrouter.service.ts`.
- Prisma access: `dieta_api/src/services/prisma.ts`, schema at `dieta_api/prisma/schema.prisma`.

## 3) Core Contracts (Do Not Break)

1. Credit tracking depends on `userId` being sent in AI requests when user-scoped consumption is expected.
2. Stop-generation flow contract:
   - Frontend: `AIService.stopGenerationOnServer(connectionId, userId)`
   - Backend: `GET /ai/stop-generation?connectionId=...&userId=...`
3. Streaming responses are incremental and parsed client-side from event chunks.
   - Frontend AI service currently expects SSE-like chunks (`data: {...}`) and may emit `[CONEXAO_ID]<id>` for active connection tracking.
   - Backend can use SSE or NDJSON depending on agent (`diet` currently uses NDJSON in controller logic).
4. `MainNavigation` uses `IndexedStack`; screens stay alive and lifecycle-sensitive logic relies on this behavior.
5. Localization is mandatory for user-facing text (`lib/i18n/`, `LanguageController`).
6. Model aliases/quality labels are resolved server-side in AI controller/config; keep client and server naming aligned when changing model options.
7. Chat voice input now records raw audio client-side and sends it to `POST /ai/transcribe-audio`; the server transcribes with `google/gemini-2.5-flash-lite`.
8. Agentic chat may emit app commands that the Flutter app executes locally before asking the backend for a final natural-language reply. Current command families include nutrition status, weekly summary, weight status, diet generation, diet-generation preference setup/status, and nutrition-goal setup/status updates.
9. Agentic chat requests can return `{"app_command": {...}}` or `{"app_commands":[...]}` from the backend for app-scoped actions/data. The Flutter chat executes the command(s) via providers, sends the result back to the server in a second request, and only the final natural-language answer should remain visible to the user.
10. Agentic follow-up prompts now include `[APP_CURRENT_STATE_BEGIN]... [APP_CURRENT_STATE_END]` with the latest structured app state so the backend can decide the next step without relying on fragile local heuristics.
10. Natural-language chat responses may append a hidden UI hint block such as `[APP_UI_HINT_BEGIN]{"actions":["login","configure_goals_ui","edit_macros_ui"]}[APP_UI_HINT_END]`. The Flutter app must strip that block from the visible message and use it only to render native action buttons.
11. Authenticated app bootstrap/sync uses a single app-state contract:
   - `GET /user/app-state` returns user profile/subscription, credits, server goal setup, macro targets, diet-generation preferences, and free-chat conversations.
   - `PUT /user/app-state` syncs pending nutrition goals and/or free-chat conversations saved locally while offline.
12. OpenRouter chat prompt caching depends on a stable `sessionId` per logical chat. The Flutter chat may send `conversationMessages` (completed `user`/`assistant` turns) plus a `modelPrompt` containing only the current dynamic context/request; the backend forwards these as `messages` and `session_id` to OpenRouter.
13. Food logging must always calculate and persist fiber for every user, including free users. Fiber visibility is a premium-only presentation rule; never gate `fiber`/`dietaryFiber` in AI food JSON parsing, meal models, local storage, or `/meals/sync`, so previously logged data becomes visible immediately after subscription.
14. Registration streak check-ins are event-driven and idempotent:
   - `POST /streak/checkin` receives the app's `localDate` (`YYYY-MM-DD`) and returns `data`, `didAdvance`, and an optional canonical `event`.
   - `GET /streak/me` is a read-only projection (apart from first-row creation) and can return the oldest `pendingEvent`; it must never consume a protection or rewrite `registrationLastDate`.
   - `POST /streak/events/:eventId/ack` acknowledges a celebration only after its fullscreen flow closes.
   - `StreakCheckInEvent` is unique by user/date. A one-day gap can emit `protectedMissedDate` and `freezesRecovered`; retries must not increment or create another event.
15. Email/password recovery uses the same 3-step flow as Whatlisten:
   - `POST /email/forgot-password` with `{ email, lang }` sends a 4-digit code and never reveals whether the account exists.
   - `POST /auth/verify-reset-code` with `{ email, code }` validates the code.
   - `POST /auth/reset-password` with `{ email, code, newPassword }` updates the hashed password and consumes the code.
16. Admin email dashboard is served at `/admin/login` and `/admin/email`. Auth uses `ADMIN_EMAIL` / `ADMIN_PASSWORD` and an `admin_session` cookie. Email send counts live in `email_stats` / `email_log`.

## 4) Main Commands

### Flutter (repository root)

```bash
flutter pub get
flutter run
flutter build apk --release --split-per-abi
flutter analyze
flutter test
flutter test test/ai_service_stream_test.dart
dart run tool/remote_android_runner.dart quick
dart run tool/remote_android_runner.dart hot
```

### Android device run rule

- When the user asks to run/open/test the app on Android, default to:
  `dart run tool/remote_android_runner.dart quick`
- This runner is the preferred path over `flutter devices` / plain `flutter run` for normal device checks because it:
  - connects to the default remote device `100.72.202.76:5555`
  - falls back automatically to one authorized USB device when the remote device is unavailable
  - detects whether the local debug APK is stale
  - rebuilds only when needed
  - installs only when needed
  - force-stops and opens `br.com.snapdark.apps.nutreai/.MainActivity`
- To authorize/setup wireless once after connecting the phone by USB, use:
  `dart run tool/remote_android_runner.dart setup-wireless`
  The phone must be unlocked and the RSA prompt should be accepted with "Always allow from this computer".
- If any code or asset was changed before the Android run, ensure the APK is rebuilt before opening the app. Prefer letting `quick` detect stale sources automatically; if there is any doubt, run `dart run tool/remote_android_runner.dart quick --force-build`.
- Use `dart run tool/remote_android_runner.dart hot` only when the user explicitly needs a persistent hot-reload session.
- After running, report whether the APK was rebuilt/installed, which device was used, and whether the app was opened. If useful, confirm with the resolved device serial, for example:
  `adb -s 100.72.202.76:5555 shell pidof br.com.snapdark.apps.nutreai`

### Backend (`dieta_api/`)

```bash
cd dieta_api
npm install
npm start
npm run build
npx prisma generate
npx prisma migrate dev --name <migration_name>
npx prisma studio
```

### Backend deploy (`dieta_api`)

- `dieta_api/deploy.md` is the single source of truth for every backend deploy, restart, status check, and production log request in this repository. Read it completely before acting and follow its current host, SSH key, remote directory, package manager, build command, PM2 process name, and verification steps.
- Do not use deploy instructions, skills, credentials, hosts, process names, or directories from another repository or service. In particular, instructions for `music_api`, Whatlisten, or a generic deploy skill do not apply to the Nutro backend.
- If a generic or external deploy instruction conflicts with this repository, stop using it and follow this `AGENTS.md` plus `dieta_api/deploy.md`. If the project-specific file is missing or internally inconsistent, ask the user before deploying.
- Current production identity for a sanity check: host `46.202.89.177`, user `root`, directory `/var/dieta_api`, PM2 process `nutro-api`, API `https://nutro-api.snapdark.com`, and local SSH key `C:\Users\Fabiano\Documents\server_oracle\private.ppk`. Treat `dieta_api/deploy.md` as canonical if these values are intentionally updated there, and update this section in the same change.
- Deploys must use Git: commit and push the intended `dieta_api` changes, then update production with `git pull origin main`.
- Do not use `pscp`, manual file copy, or direct server edits as an automatic fallback; ask the user before using any non-Git deploy path.
- Preserve production data directories, especially `/var/dieta_api/data`.

## 5) Agent Workflow

1. Confirm scope first and locate exact files before editing.
2. Prefer minimal, surgical changes that preserve existing architecture (Provider + current route patterns).
3. Validate what changed:
   - Flutter code changes: `flutter analyze` and relevant `flutter test` targets.
   - Backend TypeScript changes: `cd dieta_api && npm run build`.
4. In handoff, always report:
   - files changed
   - behavior impact
   - validation commands executed with results
   - remaining risks or follow-up work

## 6) Key File Map By Domain

### AI chat and streaming

- `lib/screens/nutrition_assistant_screen.dart` (`NutritionAssistantScreen`)
- `lib/controllers/nutrition_assistant_controller.dart`
- `lib/services/ai_service.dart`
- `lib/services/app_agent_service.dart`
- `lib/widgets/streaming_response_display.dart`
- `lib/utils/ai_interaction_helper.dart`
- `lib/utils/conversation_helper.dart`
- `dieta_api/src/controllers/ai.controller.ts`
- `dieta_api/src/routes/ai.routes.ts`
- `lib/services/chat_audio_recorder.dart`

### Auth and credits

- `lib/services/auth_service.dart`
- `lib/screens/email_login_screen.dart`
- `lib/screens/email_register_screen.dart`
- `lib/screens/forgot_password_screen.dart`
- `dieta_api/src/routes/auth.routes.ts`
- `dieta_api/src/routes/email.routes.ts`
- `dieta_api/src/routes/email.dashboard.routes.ts`
- `dieta_api/src/services/email.service.ts`
- `lib/services/purchase_service.dart`
- `lib/providers/credit_provider.dart`
- `dieta_api/src/routes/auth.routes.ts`
- `dieta_api/src/routes/credits.routes.ts`
- `dieta_api/src/services/google.play.service.ts`
- `dieta_api/src/routes/subscription.routes.ts`

### Diet, meals, and nutrition flow

- `lib/providers/diet_plan_provider.dart`
- `lib/providers/daily_meals_provider.dart`
- `lib/providers/nutrition_goals_provider.dart`
- `dieta_api/src/routes/diet.routes.ts`
- `dieta_api/src/routes/meals.routes.ts`
- `dieta_api/src/routes/food.routes.ts`

### Social features

- `lib/providers/feed_provider.dart`
- `lib/providers/friends_provider.dart`
- `lib/providers/challenges_provider.dart`
- `lib/providers/streak_provider.dart`
- `dieta_api/src/routes/feed.routes.ts`
- `dieta_api/src/routes/friend.routes.ts`
- `dieta_api/src/routes/challenge.routes.ts`
- `dieta_api/src/routes/streak.routes.ts`

## 7) Known Risks / Technical Debt

1. Sensitive key hardcoded in `lib/services/ai_service.dart` (`_apiKey`) and should be removed from client code.
2. CORS is fully open in `dieta_api/src/index.ts` (`origin: '*'`).
3. API URLs are hardcoded in `lib/util/app_constants.dart`.
4. Backend has no automated test suite configured; manual validation is required after backend edits.

## 8) Keep This File Updated

Update this document whenever any of the following changes:

- backend folder structure or route names
- API base URLs
- model alias/quality conventions
- startup/build/test commands
- main navigation tabs or provider bootstrap in `lib/main.dart`
