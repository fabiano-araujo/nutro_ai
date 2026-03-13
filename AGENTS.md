# AGENTS.md

This file guides coding agents working in this repository.

## 1) Repository Snapshot

- Mobile app: Flutter project in repository root (`lib/`, `android/`, `ios/`).
- Backend API: Fastify + Prisma in `dieta_api/`.
- App name: `nutro_ai` (`pubspec.yaml`).
- API constants used by Flutter are defined in `lib/util/app_constants.dart`:
  - `API_BASE_URL = https://nutro.snapdark.com`
  - `DIET_API_BASE_URL = http://157.230.238.117:3000`

## 2) Architecture

### Flutter frontend

- Entry point: `lib/main.dart`
  - Initializes Firebase, notifications, ads, auth restore, providers, theme, and i18n.
- Main navigation: `lib/screens/main_navigation.dart`
  - Uses `IndexedStack` with 4 tabs:
    - `NutritionAssistantScreen`
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
- AI model mapping: `dieta_api/src/config/ai-models.config.ts`.
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
7. Chat voice input now records raw audio client-side and sends it to `POST /ai/transcribe-audio`; the server transcribes with `google/gemini-2.5-flash-lite-preview-09-2025`.
8. Agentic chat may emit app commands that the Flutter app executes locally before asking the backend for a final natural-language reply. Current command families include nutrition status, weekly summary, weight status, diet generation, and nutrition-goal setup/status updates.
8. Agentic chat requests can return `{"app_command": {...}}` from the backend for app-scoped actions/data. The Flutter chat executes the command via providers, sends the result back to the server in a second request, and only the final natural-language answer should remain visible to the user.

## 4) Main Commands

### Flutter (repository root)

```bash
flutter pub get
flutter run
flutter analyze
flutter test
flutter test test/ai_service_stream_test.dart
```

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

- `lib/screens/ai_tutor_screen.dart` (`NutritionAssistantScreen`)
- `lib/controllers/ai_tutor_controller.dart`
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
- `lib/providers/credit_provider.dart`
- `dieta_api/src/routes/auth.routes.ts`
- `dieta_api/src/routes/credits.routes.ts`

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

