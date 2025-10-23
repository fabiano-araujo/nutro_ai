# Project Structure & Organization

## Root Directory Layout
```
study_ai/
├── lib/                    # Flutter app source code
├── servidor_do_app_nodejs/ # Node.js backend API
├── android/               # Android platform files
├── ios/                   # iOS platform files
├── web/                   # Web platform files
├── windows/               # Windows platform files
├── linux/                # Linux platform files
├── macos/                # macOS platform files
├── assets/               # Static assets (images, files)
├── test/                 # Flutter tests
└── pubspec.yaml          # Flutter dependencies
```

## Flutter App Structure (`lib/`)
```
lib/
├── main.dart                 # App entry point
├── theme.dart               # Legacy theme (use theme/ folder)
├── theme/
│   └── app_theme.dart       # Main theme configuration
├── screens/                 # UI screens/pages
├── widgets/                 # Reusable UI components
├── services/                # Business logic & API calls
├── providers/               # State management (Provider pattern)
├── models/                  # Data models & DTOs
├── controllers/             # UI controllers
├── i18n/                    # Internationalization
├── localization/            # Localization files
├── utils/                   # Utility functions
├── util/                    # Legacy utils (consolidate with utils/)
├── mixins/                  # Dart mixins
├── assets/                  # Asset references
└── examples/                # Code examples
```

## Backend Structure (`servidor_do_app_nodejs/`)
```
servidor_do_app_nodejs/
├── src/                     # TypeScript source code
├── prisma/                  # Database schema & migrations
├── public/                  # Static files
├── examples/                # API examples
├── node_modules/            # Dependencies
├── package.json             # Node.js dependencies
├── tsconfig.json            # TypeScript configuration
├── docker-compose.yml       # Docker setup
└── .env                     # Environment variables
```

## Naming Conventions

### Files & Directories
- **Dart files**: `snake_case.dart` (e.g., `home_screen.dart`)
- **Directories**: `snake_case` (e.g., `user_profile/`)
- **Assets**: Descriptive names in `snake_case`

### Code Conventions
- **Classes**: `PascalCase` (e.g., `UserProfile`, `AuthService`)
- **Variables/Functions**: `camelCase` (e.g., `userName`, `getUserData()`)
- **Constants**: `SCREAMING_SNAKE_CASE` (e.g., `API_BASE_URL`)
- **Private members**: Prefix with `_` (e.g., `_privateMethod()`)

## Architecture Patterns

### State Management
- Use **Provider** pattern for app-wide state
- Create dedicated providers in `providers/` directory
- Services handle business logic, providers manage UI state

### Service Layer
- API calls in `services/` directory
- Separate services by domain (auth, storage, api, etc.)
- Use dependency injection where appropriate

### UI Organization
- Screens represent full pages in `screens/`
- Reusable components in `widgets/`
- Theme configuration centralized in `theme/`

### Model Structure
- Data models in `models/` directory
- Include `fromJson()` and `toJson()` methods
- Use proper null safety annotations

## File Organization Rules
- Group related functionality together
- Avoid deep nesting (max 3-4 levels)
- Use barrel exports (`index.dart`) for complex modules
- Keep platform-specific code in respective directories
- Consolidate duplicate utility directories (`util/` vs `utils/`)

## Asset Management
- Images in `assets/images/`
- Other files in appropriate `assets/` subdirectories
- Reference assets in `pubspec.yaml`
- Use descriptive asset names