# 🚀 Quick Start: Enable Google Sign-In

## ✅ Backend Status: READY ✅
Your backend at `http://localhost:8081/api/auth/google` is ready to accept Google Sign-In requests!

---

## 📋 3 Simple Steps to Enable Google Sign-In

### Step 1: Get Your Google Client ID

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project (or create a new one)
3. Go to **APIs & Services** → **Credentials**
4. Click **Create Credentials** → **OAuth 2.0 Client ID**
5. Choose **Web application**
6. Add **Authorized JavaScript origins**:
   ```
   http://localhost
   http://localhost:65078
   ```
7. Copy your **Client ID** (it looks like: `123456789-abc.apps.googleusercontent.com`)

---

### Step 2: Add Client ID to Your App

Open `lib/constants.dart` and update:

```dart
const String googleClientId = 'YOUR_CLIENT_ID_HERE.apps.googleusercontent.com';
```

**Example:**
```dart
const String googleClientId = '123456789-abc.apps.googleusercontent.com';
```

---

### Step 3: Test It!

1. **Hot reload** the app (press `r` in terminal or refresh browser)
2. Click **"Sign in with Google"**
3. Select your Google account
4. ✅ Done! You should be logged in

---

## 🎯 What Happens Behind the Scenes

```
1. User clicks "Sign in with Google"
   ↓
2. Google login popup appears
   ↓
3. User selects account & approves
   ↓
4. Google sends ID token to your app
   ↓
5. Your app sends ID token to: http://localhost:8081/api/auth/google
   ↓
6. Backend verifies token & returns JWT
   ↓
7. App stores JWT and navigates to home
   ↓
8. ✅ User is logged in!
```

---

## 🐛 Troubleshooting

### Error: "ClientID not set"
**Solution:** Add your Client ID to `lib/constants.dart` (see Step 2)

### Error: "Invalid client"
**Solution:** 
- Make sure Client ID matches exactly (no extra spaces)
- Verify `http://localhost` is in Authorized JavaScript origins
- Clear browser cache and try again

### Error: "popup_closed_by_user"
**Solution:** User closed the popup - this is normal, just try again

---

## 📚 Full Documentation

- **Complete setup guide:** `GOOGLE_SIGNIN_SETUP.md`
- **Backend implementation:** `BACKEND_IMPLEMENTATION_GUIDE.md`

---

## ⏱️ Estimated Time: 5 minutes

That's it! Once you add the Client ID, Google Sign-In will work immediately.

Your backend team has already implemented everything on their end! 🎉
