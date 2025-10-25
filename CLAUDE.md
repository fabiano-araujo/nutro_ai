# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Nutro AI is a Flutter-based educational mobile application with a Node.js/Fastify backend. The app provides AI-powered study assistance including text Q&A, image analysis, document summarization, essay correction, code help, and YouTube video summaries. It uses OpenRouter API for AI capabilities and includes features like credit-based usage, subscription management, and Google Mobile Ads integration.

## Architecture

### Frontend (Flutter)
- **Main Entry Point**: `lib/main.dart` - Initializes providers (CreditProvider, AuthService, PurchaseService, EssayProvider), WebView platform, Google Mobile Ads, and handles theme management
- **Navigation**: `lib/screens/main_navigation.dart` - Bottom navigation with 4 tabs using IndexedStack:
  - Tools (ToolsScreen)
  - Camera Scan (CameraScanScreen)
  - AI Tutor (AITutorScreen)
  - Profile/Login (conditional based on auth state)
- **State Management**: Provider pattern for global state (credits, auth, essays, purchases)
- **AI Service**: `lib/services/ai_service.dart` - Centralized service for all AI interactions via streaming SSE responses. All methods accept `userId` parameter for credit tracking
- **Theme**: `lib/theme.dart` and `theme/app_theme.dart` - Custom light/dark theme with system theme support

### Backend (Node.js/Fastify)
- **Server Entry**: `servidor_do_app_nodejs/src/index.ts` - Fastify server with CORS, static files, and periodic subscription cleanup
- **API Base URL**: Configured in `lib/util/app_constants.dart` as `http://study.snapdark.com:3001`
- **Database**: Prisma ORM (configured in `servidor_do_app_nodejs/src/services/prisma.ts`)
- **Key Services**:
  - `openrouter.service.ts` - AI model integration
  - `connection.service.ts` - Manages SSE connections for streaming
  - Repositories for users, credits, subscriptions

### Key Architectural Patterns
1. **Streaming AI Responses**: All AI methods in `AIService` use Server-Sent Events (SSE) with a buffer-based parser that processes `data: ` prefixed events. Connection IDs are returned via special `[CONEXAO_ID]` markers in the stream
2. **Credit System**: Every AI request includes `userId` parameter, backend tracks credit consumption per request
3. **Provider Architecture**: Heavy use of ChangeNotifier providers for reactive state management
4. **Internationalization**: `lib/i18n/` directory with `AppLocalizations`, `LanguageController` for multi-language support
5. **Ad Management**: `services/ad_manager.dart` and `services/ad_settings_service.dart` handle Google Mobile Ads with app open count tracking

## Common Development Commands

### Flutter (Frontend)

**Install dependencies:**
```bash
flutter pub get
```

**Run the app:**
```bash
flutter run
```

**Build for Android:**
```bash
flutter build apk
```

**Build for iOS:**
```bash
flutter build ios
```

**Run tests:**
```bash
flutter test
```

**Generate app icons:**
```bash
flutter pub run flutter_launcher_icons:main
```

**Analyze code:**
```bash
flutter analyze
```

### Node.js Backend

**Install dependencies:**
```bash
cd servidor_do_app_nodejs
npm install
```

**Start development server (with auto-reload):**
```bash
npm start
```
This runs nodemon watching TypeScript files and auto-restarts on changes.

**Build TypeScript:**
```bash
npm run build
```
Compiles TypeScript to JavaScript.

**Run Prisma commands:**
```bash
npx prisma generate    # Generate Prisma client
npx prisma migrate dev # Run database migrations
npx prisma studio      # Open Prisma Studio GUI
```

## Important Implementation Details

### AI Service Integration
- All AI streaming methods parse SSE events in the format `data: {"text": "...", "done": true/false, "error": "...", "status": "..."}`
- Connection tracking: Look for `[CONEXAO_ID]` prefix in stream to extract connection ID for stop generation feature
- The service estimates token costs and logs detailed metrics for each request (see `_logTokensAndCost` method)

### Credit Management
- Credits are tracked via `CreditProvider` in frontend
- Backend deducts credits per AI request based on model quality settings (ruim/mediano/bom/otimo)
- User authentication required for credit tracking (`userId` passed to all AI methods)

### Essay Correction System
- Complex feature with models for essays, corrections, templates, and progress tracking
- Uses `EssayProvider` for state management
- Services: `essay_correction_service.dart`, `essay_template_service.dart`, `progress_tracker_service.dart`
- Radar charts and progress visualization with `fl_chart` package

### Authentication Flow
- `AuthService` handles initialization, token storage via `flutter_secure_storage`
- On app start, attempts to restore session and fetch user data from server
- Profile screen conditionally shows `LoginScreen` or `ProfileScreen` based on `isAuthenticated` state

### Media Processing
- Image uploads: `image_upload.dart`, `test_image.dart`
- Camera integration: `camera_scan_screen.dart`, `image_edit_screen.dart`
- OCR via `google_mlkit_text_recognition` package
- Video recording: `video_recorder.dart`
- Audio recording: `audio_recorder.dart`

### Backend Routes Structure
All routes registered in `servidor_do_app_nodejs/src/routes/index.ts`:
- `/auth` - Authentication endpoints
- `/user` - User management
- `/credits` - Credit operations
- `/ai` - AI generation endpoints (text, image analysis)
- `/subscription` - Subscription management
- `/pix-payment` - PIX payment integration

### Important Files for AI Features
- `lib/controllers/ai_tutor_controller.dart` - Manages AI tutor conversations with history limiting
- `lib/utils/ai_interaction_helper.dart` - Helper utilities for AI interactions
- `lib/utils/conversation_helper.dart` - Conversation management utilities
- `lib/widgets/streaming_response_display.dart` - Real-time display of streamed AI responses
- `servidor_do_app_nodejs/src/config/ai-models.config.ts` - AI model configurations

### Stopping AI Generation
- Frontend calls `AIService.stopGenerationOnServer(connectionId, userId)`
- Backend endpoint: `GET /ai/stop-generation?connectionId=xxx&userId=yyy`
- Connection management handled by `connection.service.ts`

### Quality Settings Mapping
The app uses quality settings that map to different AI models:
- `ruim` (low) - Fastest, cheapest
- `mediano` (medium) - Balanced
- `bom` (good) - Higher quality
- `otimo` (optimal) - Best quality, most expensive

These are sent to backend and mapped in `ai-models.config.ts`.

## Testing Notes

- Main test file: `test/widget_test.dart`
- Run specific tests: `flutter test test/widget_test.dart`
- Backend currently has no test suite defined

## Environment Configuration

### Flutter
- Theme settings stored via `StorageService` using `shared_preferences`
- Secure credentials via `flutter_secure_storage`
- API base URL hardcoded in `lib/util/app_constants.dart`

### Backend
- Uses `.env` file for environment variables (not tracked in repo)
- SSL certificates loaded from `src/certificates/` in production
- Database connection configured via Prisma

## Special Considerations

1. **API Key Security**: The OpenAI API key is currently hardcoded in `lib/services/ai_service.dart:24`. This should be moved to environment variables or secure backend storage.

2. **Subscription Cleanup**: Server automatically cleans expired pending subscriptions on startup and every 6 hours (see `index.ts:38-53`)

3. **Navigation with Ads**: `MainNavigation` tracks tab changes to show interstitial ads when leaving AI Tutor screen via `AITutorScreen.handleTabExit()`

4. **IndexedStack Usage**: All screens remain in memory for fast tab switching, but causes lifecycle issues requiring manual handling (see `main_navigation.dart:51-68`)

5. **Language Detection**: All AI responses are returned in the device language determined by `LanguageController`

6. **Token Estimation**: Uses approximation of 3.5 characters per token for Portuguese text (see `AIService.estimateTokenCount`)
