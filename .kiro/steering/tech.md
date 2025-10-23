# Technology Stack & Build System

## Frontend (Flutter)
- **Framework**: Flutter 3.0+ with Dart SDK >=3.0.0
- **State Management**: Provider pattern for app-wide state
- **UI Framework**: Material Design 3 with custom theming
- **Fonts**: Google Fonts (Poppins for headings, Inter for body text)
- **Navigation**: Named routes with MaterialApp routing

### Key Dependencies
- `provider`: State management
- `supabase_flutter`: Backend integration
- `google_sign_in`: Authentication
- `shared_preferences` & `flutter_secure_storage`: Local storage
- `image_picker`, `file_picker`, `camera`: Media handling
- `google_mobile_ads`: Ad monetization
- `in_app_purchase`: Subscription payments
- `flutter_tts` & `speech_to_text`: Audio features
- `google_mlkit_text_recognition`: OCR capabilities
- `webview_flutter`: Web content display

## Backend (Node.js)
- **Framework**: Fastify with TypeScript
- **ORM**: Prisma with MySQL database
- **Authentication**: JWT tokens with bcrypt password hashing
- **Payment Processing**: MercadoPago SDK
- **File Storage**: AWS S3 with presigned URLs
- **API Documentation**: RESTful endpoints

### Key Dependencies
- `fastify`: Web framework
- `@prisma/client`: Database ORM
- `jsonwebtoken`: JWT authentication
- `bcrypt`: Password hashing
- `mercadopago`: Payment processing
- `@aws-sdk/client-s3`: File storage

## Common Commands

### Flutter Development
```bash
# Install dependencies
flutter pub get

# Run on device/emulator
flutter run

# Build for production
flutter build apk --release          # Android
flutter build ios --release          # iOS
flutter build web --release          # Web

# Generate launcher icons
flutter pub run flutter_launcher_icons:main

# Run tests
flutter test
```

### Backend Development
```bash
# Install dependencies
npm install

# Start development server
npm start

# Build TypeScript
npm run build

# Database operations
npx prisma migrate dev    # Apply migrations
npx prisma generate      # Generate client
npx prisma studio        # Database GUI
```

## Development Environment
- **IDE**: VS Code with Flutter/Dart extensions
- **Version Control**: Git with conventional commits
- **Package Management**: pub for Flutter, npm for Node.js
- **Database**: MySQL with Prisma migrations
- **Deployment**: Docker support available