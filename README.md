# CogniCents

CogniCents is a Flutter-based personal finance and debt-management application designed to help users track debt, plan repayment strategies, monitor savings goals, and receive personalized nudges and AI-generated financial guidance.

This repository is a developer-oriented project overview and setup guide for the app as it currently exists in code.

## Overview

The application combines:

- Debt tracking and payoff planning
- Personal financial snapshot onboarding
- Savings and emergency fund tracking
- Gamification and challenges
- Local notifications and bill reminders
- AI-powered financial chat using Gemini
- Behavioral nudges and progress insights

The project is built in Flutter and stores most user state locally using SharedPreferences. The app currently includes a large portion of the UI and backend logic in a single main application file, with supporting services and page modules under lib/.

## Tech Stack

- Flutter SDK
- Dart
- Material Design UI
- SharedPreferences for local persistence
- HTTP client for API calls
- Gemini API for AI-assisted chat and nudging
- flutter_local_notifications for reminders
- fl_chart for charts and analytics
- timezone for scheduled notifications

## Repository Structure

```text
cognicents/
├── android/                 # Android project files
├── ios/                     # iOS project files
├── lib/
│   ├── gemini_config.dart   # Hardcoded Gemini API key configuration
│   ├── main.dart            # Core app logic, data models, screens, and onboarding flow
│   ├── shared_preferences_stub.dart
│   ├── pages/
│   │   ├── calendar_page.dart
│   │   ├── financial_plan_page.dart
│   │   ├── nudge_test_page.dart
│   │   ├── progress_page.dart
│   │   └── savings_page.dart
│   ├── services/
│   │   ├── banking_service.dart
│   │   ├── bill_reminder_service.dart
│   │   ├── gamification_service.dart
│   │   ├── notification_service.dart
│   │   ├── nudge_manager.dart
│   │   └── spending_analysis_service.dart
│   ├── src/
│   └── widgets/
├── assets/
│   └── images/
├── data/
│   └── userdata.csv
├── test/
│   ├── unit_test.dart
│   └── widget_test.dart
├── analysis_options.yaml
├── l10n.yaml
├── pubspec.yaml
├── README.md
├── .gitignore
├── android/...
├── ios/...
├── web/
├── linux/
├── windows/
└── macos/
```

## Core App Architecture

### 1. App Entry and Main Flow

The application entry point is in [lib/main.dart](lib/main.dart). It initializes Flutter, configures timezone support, and launches the app shell.

The main app includes:

- Data models such as Debt, PaymentRecord, UserFinancialData, Badge, and UserAchievements
- Storage helpers via DataService
- Onboarding flow for setup and personal financial snapshot
- Home dashboard with debt overview and risk indicators
- Settings, badges, leaderboard, banking, savings, progress, and financial plan views
- AI chat dialog for Gemini-based guidance

### 2. Domain Data Layer

The app’s primary runtime data is managed through `DataService`, defined in [lib/main.dart](lib/main.dart). It persists and retrieves:

- `debts`
- `financialData`
- `achievements`
- payment records
- user preferences

This data is serialized to JSON and saved with SharedPreferences under string keys such as:

- `debts`
- `financialData`
- `achievements`
- `gemini_api_key`
- `ai_conversation_history`
- `banking_accounts`

### 3. Pages and User Experience

Key screens include:

- Home dashboard:
  - overall debt snapshot
  - debt payoff estimates
  - risk score and stress calculation
  - gamification summary
  - action shortcuts for plan, calendar, progress, and savings
- Financial plan page:
  - income allocation
  - debt distribution
  - payoff recommendations
  - customizable extra-payment logic
- Progress page:
  - solvency score
  - milestone tracking
  - journey insights
- Savings page:
  - emergency fund progress
  - goal tracking
  - savings streak support
- Banking page:
  - mock bank account and transaction data for spending analysis
- Notifications and nudge pages:
  - bill reminders
  - proactive encouragement messages
  - check-in behaviors

### 4. AI Integration

The project integrates with Google Gemini, not OpenAI.

The active API key is currently defined in [lib/gemini_config.dart](lib/gemini_config.dart). The app also supports a saved runtime key via SharedPreferences using the key name `gemini_api_key`.

AI behavior is used in:

- contextual prompt generation for financial coaching
- proactive suggestions
- Gemini-based chat dialog in the app
- financial nudges and decision-support messaging

Important note: the key is hardcoded in source in the current codebase. This is not production-safe and should be moved to secure environment variables or a backend service before release.

### 5. Notifications and Nudges

The app includes structured behavioral nudging and reminders.

Relevant files:

- [lib/services/nudge_manager.dart](lib/services/nudge_manager.dart)
- [lib/services/notification_service.dart](lib/services/notification_service.dart)
- [lib/services/bill_reminder_service.dart](lib/services/bill_reminder_service.dart)

Features include:

- scheduled payment reminders
- upcoming bill nudges
- streak reinforcement prompts
- behavioral re-engagement messaging
- category-based nudge logic (timing, reinforcement, opportunity, re-engagement)
- local push notifications using flutter_local_notifications

### 6. Gamification

A gamification layer is implemented in [lib/services/gamification_service.dart](lib/services/gamification_service.dart).

It includes:

- XP system
- levels and thresholds
- daily and weekly challenges
- login streak tracking
- payment streaks
- badges and challenge progress
- leaderboard-like UX

This is tightly integrated with the home dashboard and debt/payment tracking flows.

### 7. Banking and Spending Simulation

The app includes a mock banking service in [lib/services/banking_service.dart](lib/services/banking_service.dart). It simulates:

- multiple accounts
- transaction generation
- category-based spending
- account persistence

This is useful for demo and testing flows without integrating a real banking API.

## Local Storage and Persistence

The project uses SharedPreferences for local persistence. The app stores data in browser/app local storage-like persistence, which makes it easy to demo and prototype but not ideal for sensitive financial data or production-grade security.

Common keys include:

- `firstName`
- `lastName`
- `totalDebt`
- `debts`
- `financialData`
- `achievements`
- `gemini_api_key`
- `ai_conversation_history`
- `banking_accounts`
- `bill_reminder_last_check`
- `last_nudge_sent`
- `gamification_data`

## Setup Instructions

### Prerequisites

- Flutter SDK installed and configured
- Android Studio or VS Code with Flutter support
- Xcode for iOS development (macOS only)
- A Gemini API key for AI features if you plan to use the embedded flow

### Install Dependencies

```bash
flutter pub get
```

### Run the app

```bash
flutter run
```

### Run tests

```bash
flutter test
```

### Run analyzer

```bash
flutter analyze
```

## Important Configuration Notes

### Gemini setup

The app expects a Gemini API key in [lib/gemini_config.dart](lib/gemini_config.dart):

```dart
const String kGeminiApiKey = 'YOUR_KEY_HERE';
```

For secure production use, replace this with environment variables or server-side API handling.

### Notifications

The notifications flow depends on Flutter local notifications and timezone initialization. The app sets up timezone data at startup in [lib/main.dart](lib/main.dart).

### Platform support

The project contains Android, iOS, Linux, macOS, Windows, and web support based on Flutter defaults.

## Development Notes

### Current architecture strengths

- Rapid MVP development
- Good separation between page-level UI and service logic
- Local persistence for demo use
- Debt and savings tracking logic are central and coherent
- Good use of charts and gamification patterns

### Current architecture limitations

- Large logic concentration in [lib/main.dart](lib/main.dart)
- Hardcoded API key in source control
- SharedPreferences-based persistence is not secure enough for production financial data
- Banking integration is simulated, not real Plaid or bank API-connected
- Some features are prototyped rather than production-hardened
- App logic and UI are not yet fully modularized into clean domain/service layers

## Recommended Improvements for Production

1. Move all API keys out of source control
2. Move app logic out of main.dart into proper feature modules
3. Use a proper state-management solution such as Provider, Riverpod, Bloc, or Cubit
4. Replace SharedPreferences with a secure data layer if real financial data is involved
5. Add real backend or API integration for banking and AI services
6. Add unit and widget testing coverage around debt calculation, risk scoring, and nudge logic
7. Add CI/CD pipeline and secret management
8. Add linting, code generation, and architecture rules

## Testing Status

The repository includes basic tests in [test/unit_test.dart](test/unit_test.dart) and [test/widget_test.dart](test/widget_test.dart), but the app is primarily a prototype/demo codebase and should be expanded before production use.

## Summary

CogniCents is a Flutter financial wellness app focused on debt awareness, payoff planning, behavioral nudges, and smart financial guidance. It is a strong prototype and MVP framework for a consumer finance product, with a clear path to improve security, modularity, and real backend integration.

## Maintainer Notes

When contributing:

- keep financial logic and UI behavior easy to reason about
- avoid committing secrets or API keys
- prefer small, feature-driven modules for new screens
- document any new persistence keys and service behavior

## License

This project does not currently declare a license in the repository metadata. Check your project or organization policy before publishing or distributing the app.
