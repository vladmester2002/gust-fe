# GUST App - AI Coding Assistant Instructions

## Project Overview
GUST (Glucose/Sugar Understanding & Support Tool) is a Flutter health tracking app for monitoring daily sugar intake. Users log consumption, track emotions, view analytics, and build healthy habits through streak tracking and goal setting.

## Architecture & Data Flow

### Authentication & Navigation Flow
Login  Onboarding (first-time)  Main Navigation (4 tabs: Home, Analytics, Community, Profile)

**Auth Methods**: Email/Password, Google OAuth (partial), Apple Sign-In (UI only), Anonymous/Guest mode
**Session**: JWT token in SharedPreferences as `jwt_token`, attached to all API requests as `Authorization: Bearer $token`
**First-time UX**: After first login  Onboarding (3 swipeable screens)  Biometric enrollment prompt  Main app

### Backend Integration Pattern
**Base URL**: Configurable in `lib/constants.dart` (default: http://10.100.155.207:8081)
**Critical Endpoints**: /api/auth/login, /api/auth/register, /api/sugarlogs, /api/users/me/*

**Standard HTTP Pattern** (see home_page.dart, sugar_log_creation_dialog.dart):
- Get token from SharedPreferences
- Add Authorization: Bearer header
- Parse response with jsonDecode()
- Handle errors with Flushbar notifications

### Data Models
**SugarLog** (lib/SugarLog.dart): id, sugarGrams, date, hour, minute, productName, emotion (enum), wasCraving (bool), contextNote, sugarType
**Emotion Enum** (lib/emotion.dart): HAPPY, SAD, STRESSED, ANXIOUS, TIRED, BORED, NEUTRAL with .emoji and .label extensions

### File Organization
lib/
 theme/app_theme.dart - Design system constants (CRITICAL - reference constantly)
 widgets/ - Reusable components (GustButton, GustCard, GustTextField, etc.)
 services/ - Biometric auth, theme management
 state/ - Authentication state
 Login.dart, Register.dart - Auth pages with gradient backgrounds
 onboarding_page.dart - 3-screen welcome flow
 home_page.dart - Dashboard with daily intake, weekly chart, streak
 sugar_log_creation_dialog.dart - Modal for creating/editing logs
 constants.dart - Backend URL + Google Client ID

## Design System (CRITICAL - Follow Strictly)

### Theme System (lib/theme/app_theme.dart)
**NEVER hardcode colors or spacing** - always reference AppTheme constants.

**Colors**:
- Primary: AppTheme.primaryPurple (deep purple), AppTheme.accentTeal
- Semantic: successGreen, warningOrange, errorRed, infoBlue
- Neutrals: backgroundGrey, textPrimary, textSecondary

**Spacing** (8px grid): spaceXS (4), spaceSM (8), spaceMD (16), spaceLG (24), spaceXL (32), spaceXXL (48)
**Border Radius**: radiusSmall (8), radiusMedium (12), radiusLarge (16), radiusXLarge (24)
**Gradients**: primaryGradient, successGradient, errorGradient, warningGradient

### Reusable Widgets (ALWAYS use these)
**GustButton**: Custom button with loading states, icon support, ButtonType enum
**GustTextField**: Styled text input with validation, onChanged callback for real-time updates
**GustCard**: Elevated card container with optional gradient
**GustEmptyState**: Empty state placeholder with emoji, title, subtitle, action button

## Development Patterns

### State Management
- Pattern: StatefulWidget with setState() (no external state management)
- Loading states: bool _isLoading  passed to GustButton.isLoading
- Form validation: GlobalKey<FormState>, validators return String? (null = valid)

### Error Handling
ALWAYS use Flushbar (another_flushbar package) for notifications with AppTheme colors

### Navigation
Routes in main.dart  AppRoutes class:
- /  Login
- /register  Register
- /forgot-password  Forgot Password
- /onboarding  Onboarding
- /main-nav  Main Navigation

Use Navigator.pushNamed() for forward, Navigator.pushReplacementNamed() for auth flow

### API Integration
1. Check for JWT token before API calls
2. Set loading state before/after async operations
3. Parse JSON with jsonDecode()
4. Show Flushbar on success/error

### Charts (fl_chart)
- Use AppTheme colors, NOT Theme.of(context).primaryColor
- See home_page.dart lines 500-700 for LineChart example
- Gradient line, custom tooltips, interactive touch data

### Date/Time
- intl package: DateFormat('MMM d, y').format(date)
- SugarLog stores date + separate hour/minute integers

## Critical Implementation Details

### Emotion Selector
Emotion.HAPPY.emoji returns "", Emotion.HAPPY.label returns "Happy"

### Biometric Authentication
lib/services/biometric_auth_service.dart - local_auth wrapper
- isBiometricAvailable(), authenticate(), stored in SharedPreferences

### Password Strength Indicator
lib/widgets/password_strength_indicator.dart - Real-time validation, scoring 0-7 points, color-coded

### Onboarding Flow
lib/onboarding_page.dart - 3 screens (Welcome, Analytics, Reminders), PageView with indicators, completion tracked

### Anonymous Mode
"Continue as Guest" sets is_anonymous flag, navigates to main app immediately

## Common Tasks

### Adding a New Page
1. Create lib/new_page.dart as StatefulWidget
2. Import AppTheme
3. Use AppTheme colors/spacing (NO hardcoded values)
4. Use GustButton, GustCard, GustTextField
5. Add route to main.dart AppRoutes

### Modifying Styles
1. Check lib/theme/app_theme.dart first
2. Never hardcode colors - use AppTheme.primaryPurple
3. Never hardcode spacing - use AppTheme.spaceMD
4. Reference Login.dart and home_page.dart for examples

## Build Commands

cd c:\Users\vladi\GUST_app\gust-fe\gust_fe
flutter run
flutter pub get
flutter clean (if issues)

## Key Dependencies
- http: HTTP client
- shared_preferences: Local storage
- fl_chart: Data visualization
- intl: Date/time formatting
- another_flushbar: Notifications
- google_sign_in: OAuth
- local_auth: Biometric authentication

## Implementation Status (70% Complete)
Completed: Auth pages, Onboarding, Theme system, Home page, Sugar log dialog, Password strength, Biometric prompt
In Progress: Analytics charts, Profile settings, Community features
Backend Required: Apple Sign-In, Anonymous user management, Password reset emails

## Important Documentation
- Design System: lib/theme/app_theme.dart (THE source of truth)
- Component Examples: lib/Login.dart, lib/home_page.dart
- API Integration: lib/sugar_log_creation_dialog.dart
- Auth Setup: AUTH_IMPLEMENTATION_SUMMARY.md
- Backend Spec: BACKEND_IMPLEMENTATION_GUIDE.md
- UI Mockups: UI_IMPROVEMENT_BLUEPRINT.md

## Known Issues
- Backend URL must be configured in lib/constants.dart for target environment
- Google Client ID empty by default
- Auth pages use full-screen gradients, main app uses solid backgrounds
- Chart maxY rounds to nearest 10
- SugarLog stores date + separate hour/minute fields

## AI Agent Tips
1. Design consistency is paramount - check AppTheme before adding styles
2. Component reuse - use existing widgets instead of rebuilding
3. Reference existing code - home_page.dart and Login.dart are most up-to-date
4. Backend integration - all API calls follow same JWT pattern
5. User feedback - every action needs visual feedback
6. Error handling - wrap API calls in try-catch
7. Responsive design - use flexible layouts, not fixed sizes
8. Accessibility - maintain semantic labels, touch targets 48dp

---
Last Updated: November 5, 2025
Project Status: 70% Complete (Frontend ready, backend integration pending)
Architecture: Flutter 3.3.4+, Dart SDK 3.3.4, Material 3 design
