# Google Sign-In Setup Guide

## ✅ What's Already Done

- ✅ Google Sign-In package installed (`google_sign_in: ^5.4.0`)
- ✅ Frontend code implemented in `Login.dart`
- ✅ Google Sign-In button added to UI
- ✅ Token exchange logic with backend

---

## 🔧 Setup Required

### 1. **Get Google OAuth Credentials**

#### For Web App:
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable **Google+ API**
4. Go to **Credentials** → **Create Credentials** → **OAuth 2.0 Client ID**
5. Choose **Web application**
6. Add Authorized JavaScript origins:
   - `http://localhost` (for development)
   - `http://localhost:61954` (or whatever port Flutter web uses)
   - Your production domain
7. Add Authorized redirect URIs:
   - `http://localhost/auth/callback`
   - Your production callback URL
8. Copy the **Client ID** (looks like: `xxxxx.apps.googleusercontent.com`)

#### For Android:
1. In same Google Cloud Console project
2. Create **OAuth 2.0 Client ID** → **Android**
3. Get SHA-1 fingerprint: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`
4. Add SHA-1 and package name (`com.yourcompany.gust_fe`)

#### For iOS:
1. Create **OAuth 2.0 Client ID** → **iOS**
2. Add bundle identifier

---

### 2. **Configure Flutter App**

Update `lib/constants.dart`:
```dart
const String googleClientId = 'YOUR_CLIENT_ID_HERE.apps.googleusercontent.com';
```

---

### 3. **Configure Web (index.html)**

Add to `web/index.html` in the `<head>` section:

```html
<head>
  <!-- ... existing meta tags ... -->
  
  <!-- Google Sign-In -->
  <meta name="google-signin-client_id" content="YOUR_CLIENT_ID_HERE.apps.googleusercontent.com">
</head>
```

---

### 4. **Configure Android**

No additional configuration needed if using the default setup!

---

### 5. **Configure iOS**

Update `ios/Runner/Info.plist`:

```xml
<!-- Google Sign-In -->
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <!-- Reversed client ID from Google Cloud Console -->
      <string>com.googleusercontent.apps.YOUR_REVERSED_CLIENT_ID</string>
    </array>
  </dict>
</array>
```

---

### 6. **Backend Implementation (Java Spring)**

Your backend needs to handle the Google ID token. Add this endpoint:

```java
@PostMapping("/api/auth/google")
public ResponseEntity<?> googleSignIn(@RequestBody GoogleSignInRequest request) {
    try {
        // Verify the ID token with Google
        GoogleIdTokenVerifier verifier = new GoogleIdTokenVerifier.Builder(transport, jsonFactory)
            .setAudience(Collections.singletonList(GOOGLE_CLIENT_ID))
            .build();
        
        GoogleIdToken idToken = verifier.verify(request.getIdToken());
        
        if (idToken != null) {
            GoogleIdToken.Payload payload = idToken.getPayload();
            
            String googleUserId = payload.getSubject();
            String email = payload.getEmail();
            String name = (String) payload.get("name");
            String pictureUrl = (String) payload.get("picture");
            
            // Find or create user
            User user = userRepository.findByGoogleUserId(googleUserId)
                .orElseGet(() -> {
                    User newUser = new User();
                    newUser.setGoogleUserId(googleUserId);
                    newUser.setEmail(email);
                    newUser.setFullName(name);
                    newUser.setProfilePictureUrl(pictureUrl);
                    newUser.setProvider("google");
                    return userRepository.save(newUser);
                });
            
            // Generate JWT
            String jwtToken = jwtUtils.generateToken(user);
            
            return ResponseEntity.ok(new AuthResponse(jwtToken, user));
        }
        
        return ResponseEntity.status(401).body("Invalid ID token");
        
    } catch (Exception e) {
        return ResponseEntity.status(500).body("Google sign-in failed: " + e.getMessage());
    }
}
```

**Required Maven Dependencies:**
```xml
<dependency>
    <groupId>com.google.api-client</groupId>
    <artifactId>google-api-client</artifactId>
    <version>2.2.0</version>
</dependency>
<dependency>
    <groupId>com.google.oauth-client</groupId>
    <artifactId>google-oauth-client-jetty</artifactId>
    <version>1.34.1</version>
</dependency>
```

**Update `application.properties`:**
```properties
google.client.id=YOUR_CLIENT_ID_HERE.apps.googleusercontent.com
```

---

## 🧪 Testing

### Test on Web:
1. Run: `flutter run -d chrome`
2. Click "Sign in with Google"
3. Select Google account
4. Should redirect back to app with user logged in

### Test on Android/iOS:
1. Run on device/emulator
2. Click "Sign in with Google"
3. Native Google sign-in flow should appear
4. Complete sign-in

---

## 🐛 Troubleshooting

### "Sign-in failed" or "Invalid client"
- Check that Client ID matches exactly
- Verify authorized origins/redirect URIs in Google Console
- Make sure Google+ API is enabled

### "popup_closed_by_user"
- User closed sign-in window (normal behavior)
- Try again

### Web: "idpiframe_initialization_failed"
- Check that meta tag in index.html has correct Client ID
- Clear browser cache
- Check browser console for details

### Android: "DEVELOPER_ERROR"
- SHA-1 fingerprint doesn't match
- Package name doesn't match
- Regenerate debug keystore: `keytool -genkey -v -keystore ~/.android/debug.keystore -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000`

### iOS: Issues
- Check Info.plist has correct reversed client ID
- Make sure bundle identifier matches

---

## 📝 Current Implementation Status

### Frontend:
- ✅ Google Sign-In button displayed
- ✅ Sign-in flow implemented
- ✅ Token sent to backend
- ✅ Error handling
- ⚠️ **Needs Client ID configured**

### Backend:
- ✅ Endpoint structure defined in `BACKEND_IMPLEMENTATION_GUIDE.md`
- ❌ **Needs implementation**
- ❌ **Needs Google token verification**
- ❌ **Needs user creation/lookup logic**

---

## 🎯 Next Steps

1. **Get Google OAuth Client ID** from Google Cloud Console
2. **Add Client ID** to `lib/constants.dart` and `web/index.html`
3. **Implement backend endpoint** `/api/auth/google`
4. **Test** on web first, then mobile
5. **Deploy** and update production URLs in Google Console

---

## 🔗 Useful Links

- [Google Cloud Console](https://console.cloud.google.com/)
- [Google Sign-In for Flutter](https://pub.dev/packages/google_sign_in)
- [Google Identity Documentation](https://developers.google.com/identity)
- [Backend Implementation Guide](./BACKEND_IMPLEMENTATION_GUIDE.md)
