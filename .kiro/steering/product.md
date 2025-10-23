# Study AI - Product Overview

Study AI is a Flutter-based mobile application that provides AI-powered study assistance and educational tools. The app offers features like essay writing assistance, image analysis, file processing, video summarization, and text-to-speech capabilities.

## Key Features
- **AI Study Companion**: Text generation and analysis using various AI models
- **Essay Writing Assistant**: Guided essay creation and correction
- **Multimedia Analysis**: Image recognition, file analysis, and video summarization
- **Multi-language Support**: Internationalization with Portuguese and English
- **Subscription System**: Freemium model with credit-based usage and premium plans
- **Authentication**: Google Sign-In and email/password authentication
- **Cross-platform**: Supports Android, iOS, Web, Windows, macOS, and Linux

## Architecture
- **Frontend**: Flutter mobile app with Provider state management
- **Backend**: Node.js API with Fastify framework
- **Database**: MySQL with Prisma ORM
- **Authentication**: JWT tokens with Google OAuth integration
- **Payment**: MercadoPago integration for subscription payments
- **Storage**: AWS S3 for file storage

## Business Model
- Free tier with daily credit limits
- Premium subscriptions (weekly, monthly, annual)
- Ad-supported revenue for free users
- Credit system for AI service usage