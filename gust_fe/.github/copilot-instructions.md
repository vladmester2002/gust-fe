# GUST App - AI Coding Assistant Instructions

## Project Overview
GUST (Glucose/Sugar Understanding & Support Tool) is a Flutter health tracking app for monitoring daily sugar intake. Users log sugar consumption, track emotions, view analytics, and receive insights to maintain healthy habits.

## Architecture & Structure

### Core Components
- **Authentication Flow**: Login → Register → Main Navigation (4 tabs: Home, Analytics, Community, Profile)
- **Data Model**: `SugarLog` objects with fields: sugarGrams, date/time, productName, emotion (enum), wasCraving (bool), contextNote
- **Backend Integration**: REST API at `http://localhost:8080` (see `lib/constants.dart`)
  - JWT token stored in SharedPreferences as `jwt_token`
  - All authenticated requests: `Authorization: Bearer $token`
  - API endpoints: `/api/auth/login`, `/api/auth/register`, `/api/sugarlogs`, etc.

### File Organization
```
lib/
├── theme/app_theme.dart          # Design system (colors, spacing, gradients)
├── widgets/                      # Reusable components (GustButton, GustCard, etc.)
├── Login.dart, Register.dart     # Auth pages
├── main_navigation.dart          # Bottom nav with 4 tabs
├── home_page.dart                # Dashboard with daily intake chart
├── analytics_page.dart           # Charts (fl_chart package)
├── sugar_log_creation_dialog.dart # Create/edit logs
├── constants.dart                # Backend URL configuration
├── emotion.dart                  # Emotion enum with emoji extensions
└── SugarLog.dart                 # Data model
```

## Design System (CRITICAL - Follow Strictly)

### Theme System (`lib/theme/app_theme.dart`)
- **Colors**: Use `AppTheme.primaryPurple` (#6A1B9A), `AppTheme.accentTeal` (#00897B), NOT hardcoded Color()
- **Spacing**: 8px grid - `AppTheme.spaceSM` (8), `spaceMD` (16), `spaceLG` (24), `spaceXL` (32), `spaceXXL` (48)
- **Border Radius**: `AppTheme.radiusMedium` (12px) for inputs/buttons, `radiusLarge` (16px) for cards
- **Gradients**: `AppTheme.primaryGradient` (Teal → Purple) for backgrounds, `successGradient`, `errorGradient`

### Reusable Widgets (ALWAYS use these instead of raw Material widgets)
```dart
// Buttons
GustButton(
  text: 'Submit',
  onPressed: _handleSubmit,
  type: ButtonType.primary,  // primary, secondary, success, danger
  isLoading: _isLoading,     // Shows spinner automatically
  icon: Icons.send,          // Optional
)

// Text Inputs
GustTextField(
  controller: _controller,
  label: 'Email',
  prefixIcon: Icons.email_outlined,
  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
)

// Cards
GustCard(
  gradient: AppTheme.primaryGradient,  // Optional
  child: YourContent(),
)

// Empty States
GustEmptyState(
  emoji: '📭',
  title: 'No logs yet',
  actionText: 'Add Entry',
  onAction: _showDialog,
)
```

## Development Patterns

### HTTP Requests
```dart
// Standard pattern for authenticated API calls
Future<void> _fetchData() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('jwt_token');
  if (token == null) {
    // Handle unauthenticated state
    Navigator.pushReplacementNamed(context, '/');
    return;
  }
  
  final response = await http.get(
    Uri.parse('$baseUrl/api/endpoint'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
  );
  
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    // Process data
  }
}
```

### Error Handling
Use `Flushbar` (from `another_flushbar` package) for user feedback:
```dart
Flushbar(
  message: 'Success!',
  duration: const Duration(seconds: 2),
  backgroundColor: AppTheme.successGreen,
  flushbarPosition: FlushbarPosition.TOP,
  icon: const Icon(Icons.check_circle, color: Colors.white),
).show(context);
```

### Navigation
- Routes defined in `main.dart` → `AppRoutes` class
- Auth flow: Login (/) → Register (/register) → MainNav (/main-nav)
- Use named routes: `Navigator.pushNamed(context, '/register')`
- Replace for auth: `Navigator.pushReplacementNamed(context, '/main-nav')`

## Critical Implementation Details

### Emotion Enum
```dart
// From lib/emotion.dart
enum Emotion { HAPPY, SAD, STRESSED, ANXIOUS, TIRED, BORED, NEUTRAL }
// Access emoji: emotion.emoji  (e.g., "😃")
// Access label: emotion.label  (e.g., "Happy")
```

### Charts (fl_chart package)
- Uses `fl_chart` package for visualization
- Color charts with AppTheme colors: `AppTheme.primaryPurple`, NOT `Theme.of(context).primaryColor`
- Example: `LineChart`, `BarChart` with custom gradients

### Date/Time Handling
- `SugarLog` stores `DateTime date` + separate `int hour/minute` fields
- Display with `intl` package: `DateFormat('MMM d, y').format(date)`

## Common Tasks

### Adding a New Page
1. Create `lib/new_page.dart` as StatefulWidget
2. Import AppTheme: `import 'package:gust_fe/theme/app_theme.dart';`
3. Use AppTheme colors/spacing, NOT raw values
4. Add route to `main.dart` → `AppRoutes` and `routes` map
5. Use GustCard, GustButton components

### Modifying API Calls
1. Check `lib/constants.dart` for `baseUrl`
2. Follow JWT auth pattern (see HTTP Requests above)
3. Parse JSON with `jsonDecode(response.body)`
4. Handle errors with Flushbar notifications

### Styling Updates
1. **Never** use hardcoded colors like `Color(0xFF...)` - use AppTheme constants
2. **Never** use raw padding like `EdgeInsets.all(16)` - use `AppTheme.spaceMD`
3. Check existing pages (Login.dart, home_page.dart) for reference

## Build & Run Commands

```powershell
# Run app (Windows/Web/Mobile)
cd c:\Users\vladi\GUST_app\gust-fe\gust_fe
flutter run

# Get dependencies after pubspec.yaml changes
flutter pub get

# Clean build (if issues occur)
flutter clean
flutter pub get
flutter run
```

## Known Patterns & Conventions

### State Management
- Uses StatefulWidget with setState (no external state management)
- Loading states: `bool _isLoading` → triggers GustButton spinner

### Form Validation
- GlobalKey<FormState> for forms
- Validators return String? (null = valid)
- Call `_formKey.currentState!.validate()` before submission

### Async Patterns
- Use async/await for API calls
- Show loading state while fetching: `setState(() => _isLoading = true)`
- Always catch exceptions and show user-friendly errors

## Current Implementation Status
See `IMPLEMENTATION_PROGRESS.md` for detailed status:
- ✅ Complete: Auth pages (Login/Register/ForgotPassword), Theme system, Core widgets, Home page, Sugar log dialog
- 🚧 In Progress: Analytics charts, Profile page, Community features
- Reference `UI_IMPROVEMENT_BLUEPRINT.md` for full design specifications

## Important References
- Design System: `lib/theme/app_theme.dart`
- Component Examples: `lib/Login.dart`, `lib/home_page.dart`
- API Integration: `lib/sugar_log_creation_dialog.dart` (lines 64-180)
- Quick Start Guide: `QUICK_START.md`
