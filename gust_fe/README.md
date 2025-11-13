# GUST - Sugar Tracking Mobile App
**Mobile Authentication & Onboarding UI/UX Design Assignment**

A high-fidelity Flutter application prototype focusing on complete user authentication and onboarding experience with polished UI/UX design.

## 📱 Features Implemented

### 🔐 Authentication System
- **Email/Password Authentication** - Clean login form with real-time validation
- **Google Sign-In** - OAuth integration with Google branding
- **Facebook Sign-In** - Social authentication with official Facebook design
- **Anonymous Sign-In** - Guest access option
- **Biometric Authentication** - Face ID / Fingerprint support with password fallback

### 🎨 UI/UX Design
- **Modern Material Design** - Clean, intuitive interface with visual hierarchy
- **Responsive Layout** - Adapts to various screen sizes
- **Consistent Design System** - Unified color palette (Purple primary: #6A1B9A), typography, and spacing
- **Smooth Animations** - Engaging transitions and micro-interactions
- **Accessibility** - High contrast ratios, readable fonts, proper touch targets

### ✅ User Feedback & Validation
- **Real-time Input Validation** - Email format, password strength checks
- **Error States** - Clear error messages with retry options
- **Loading Indicators** - Visual feedback during authentication
- **Success States** - Confirmation animations and messages
- **Biometric Prompts** - Enable biometrics modal after first login

### 🚀 User Flows
1. **First-time User**: Login → Biometric Setup Modal → Onboarding → Dashboard
2. **Returning User (Biometric Enabled)**: Biometric Prompt → Dashboard
3. **Biometric Fallback**: Biometric Fail → Password Login → Dashboard
4. **Social Login**: Google/Facebook → Auto-login → Dashboard

## 🏗️ Project Structure

```
lib/
├── login.dart                 # Main authentication screen
├── onboarding_page.dart       # First-time user onboarding
├── home_page.dart             # Dashboard with sugar tracking
├── analytics_page.dart        # Data visualization with charts
├── community_page.dart        # Social features with personal progress
├── profile_page.dart          # User settings & biometric toggle
├── services/
│   └── biometric_auth_service.dart  # Biometric authentication logic
├── widgets/
│   ├── auth_provider_buttons.dart   # Google/Facebook buttons
│   ├── gust_button.dart            # Custom styled buttons
│   └── gust_text_field.dart        # Validated input fields
├── theme/
│   └── app_theme.dart              # Design system constants
└── utils/
    └── notification_helper.dart     # Error/success notifications
```

## 📸 Screenshots

### Authentication Screens
- **Login Screen** - Email/password with social login options
- **Biometric Modal** - Enable Face ID/Fingerprint prompt
- **Error States** - Invalid email, wrong password, network errors
- **Loading States** - Sign-in progress indicators

### Onboarding Flow
- **Welcome Screen** - Introduction to GUST
- **Feature Highlights** - Track sugar, view analytics, community
- **Setup Complete** - Ready to use

### Main Application
- **Dashboard** - Sugar intake logs with daily goal tracking
- **Analytics** - Interactive charts (by time, emotions, monthly trends)
- **Community** - Quick tips, daily motivation, personal progress
- **Profile** - Biometric toggle, logout, settings

## 🛠️ Technical Implementation

### Dependencies
```yaml
dependencies:
  flutter: SDK
  google_sign_in: ^6.2.2        # Google OAuth
  flutter_facebook_auth: ^7.2.0  # Facebook OAuth
  local_auth: ^2.3.0             # Biometric authentication
  fl_chart: ^0.69.0              # Data visualization
  shared_preferences: ^2.3.3     # Local storage
  http: ^1.2.2                   # API communication
```

### Design System
- **Primary Color**: Purple (#6A1B9A)
- **Accent Colors**: Orange (#FF9800), Green (#4CAF50)
- **Typography**: System fonts with clear hierarchy
- **Spacing**: 4px baseline grid
- **Border Radius**: 12-20px for modern feel

### Validation Rules
- **Email**: RFC 5322 compliant regex
- **Password**: Minimum 6 characters (UI-only validation)
- **Real-time feedback**: Invalid format messages
- **Error recovery**: Clear retry mechanisms

## 🚦 How to Run

1. **Clone the repository**
   ```bash
   git clone <your-github-classroom-repo>
   cd gust_fe
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run on device/emulator**
   ```bash
   flutter run
   ```

4. **Test authentication flows**
   - Try email/password login
   - Test Google/Facebook sign-in (requires API keys)
   - Enable biometric authentication
   - Test biometric fallback to password
   - Verify error states with invalid inputs

## 🔑 Configuration Notes

### Google Sign-In Setup
- Add your `googleClientId` to `lib/constants.dart`
- Configure OAuth consent screen in Google Cloud Console
- Add SHA-1/SHA-256 fingerprints for Android

### Facebook Login Setup
- Add `facebookAppId` to `lib/constants.dart`
- Configure Facebook App in Meta Developer Console

### Biometric Authentication
- Requires device with Face ID or Fingerprint sensor
- Automatically falls back to password if biometric fails
- User must enable biometrics after first successful login

## 📋 Assignment Requirements Checklist

- [x] Polished Login/Signup Screen with clean layout
- [x] Visual hierarchy and responsive design
- [x] Google/Apple authentication UI (Google + Facebook)
- [x] Email/Password authentication
- [x] Anonymous sign-in option
- [x] Official branding guidelines followed
- [x] Real-time input validation (email format)
- [x] Error messages for failed login
- [x] Loading indicators for sign-in operations
- [x] Biometric login UI flow (Face ID/Fingerprint)
- [x] Enable biometrics prompt after first login
- [x] Fallback to password if biometrics fail
- [x] Consistent color palette and typography
- [x] Platform design guidelines (Material Design)
- [x] Accessibility best practices (contrast, touch targets)

## 🎯 Key UI/UX Highlights

1. **First Impression**: Clean, minimalist login with clear CTAs
2. **Progressive Disclosure**: Only show what's needed at each step
3. **Error Recovery**: Clear messages with actionable retry buttons
4. **Biometric Integration**: Seamless enrollment and usage flow
5. **Visual Feedback**: Loading states, success animations, error shakes
6. **Accessibility**: WCAG AA compliant contrast ratios, readable fonts

## 📱 Tested On
- Android devices (Samsung Galaxy S21+)
- Various screen sizes (phone, tablet)
- Different authentication methods
- Biometric and non-biometric devices

## 👨‍💻 Developer
Assignment submission for Mobile Application Development course
UBB Cluj-Napoca, 2025

---

**Note**: This is a UI/UX prototype. Authentication flows are functional but use mock/test credentials. No production backend is connected.
