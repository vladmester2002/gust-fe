# ✅ Google Sign-In Setup Checklist

Print this or keep it open while you follow the tutorial!

---

## 🎯 Quick Navigation

**Main Tutorial:** `GOOGLE_SIGNIN_TUTORIAL.md`  
**Quick Setup:** `GOOGLE_SIGNIN_QUICKSTART.md`  
**Backend Docs:** `BACKEND_IMPLEMENTATION_GUIDE.md`

---

## 📋 Step-by-Step Checklist

### Phase 1: Google Cloud Console (8 minutes)

- [ ] **1.1** Go to https://console.cloud.google.com/
- [ ] **1.2** Sign in with Google account
- [ ] **1.3** Create new project named "GUST App"
- [ ] **1.4** Wait for project creation
- [ ] **1.5** Select your new project

**Checkpoint:** See "GUST App" at top of page ✓

---

- [ ] **2.1** Open navigation menu (☰)
- [ ] **2.2** Go to: APIs & Services → Library
- [ ] **2.3** Search for "Google+ API"
- [ ] **2.4** Click "ENABLE"
- [ ] **2.5** Wait for enable confirmation

**Checkpoint:** See "API enabled" ✓

---

- [ ] **3.1** Go to: APIs & Services → OAuth consent screen
- [ ] **3.2** Select "External" user type
- [ ] **3.3** Click "CREATE"
- [ ] **3.4** Enter app name: "GUST"
- [ ] **3.5** Enter support email
- [ ] **3.6** Enter developer email
- [ ] **3.7** Click "SAVE AND CONTINUE"
- [ ] **3.8** Add scopes: email, profile, openid
- [ ] **3.9** Click "SAVE AND CONTINUE"
- [ ] **3.10** Add test user (your email)
- [ ] **3.11** Click "SAVE AND CONTINUE"
- [ ] **3.12** Click "BACK TO DASHBOARD"

**Checkpoint:** OAuth consent screen configured ✓

---

- [ ] **4.1** Go to: APIs & Services → Credentials
- [ ] **4.2** Click "+ CREATE CREDENTIALS"
- [ ] **4.3** Select "OAuth client ID"
- [ ] **4.4** Choose "Web application"
- [ ] **4.5** Name: "GUST Web Client"
- [ ] **4.6** Add JavaScript origin: `http://localhost`
- [ ] **4.7** Add JavaScript origin: `http://localhost:49795`
- [ ] **4.8** Add JavaScript origin: `http://localhost:65078`
- [ ] **4.9** Add JavaScript origin: `http://localhost:60148`
- [ ] **4.10** Click "CREATE"
- [ ] **4.11** **COPY YOUR CLIENT ID** 📋
- [ ] **4.12** Save Client ID somewhere safe
- [ ] **4.13** Click "OK"

**Checkpoint:** Client ID copied to clipboard ✓

---

### Phase 2: Update Flutter App (2 minutes)

- [ ] **5.1** Open your Flutter project
- [ ] **5.2** Open file: `lib/constants.dart`
- [ ] **5.3** Find line: `const String googleClientId = '';`
- [ ] **5.4** Paste your Client ID between the quotes
- [ ] **5.5** Verify no extra spaces
- [ ] **5.6** Save file (Ctrl + S)

**Example:**
```dart
const String googleClientId = '123456789-abc.apps.googleusercontent.com';
```

**Checkpoint:** Client ID in constants.dart ✓

---

### Phase 3: Test (2 minutes)

- [ ] **6.1** Go to terminal running Flutter
- [ ] **6.2** Press `r` and Enter (hot reload)
- [ ] **6.3** Wait for "Reloaded" message
- [ ] **6.4** Go to your app in browser
- [ ] **6.5** Click "Sign in with Google"
- [ ] **6.6** Google popup appears
- [ ] **6.7** Select your Google account
- [ ] **6.8** Approve permissions
- [ ] **6.9** Popup closes
- [ ] **6.10** You're logged in!

**Checkpoint:** Successfully signed in with Google ✓

---

## 🎉 Completion Status

Total Steps: 35  
Estimated Time: 12 minutes  
Difficulty: Easy ⭐⭐☆☆☆

---

## 📸 What You Should See

### Google Cloud Console:
```
GUST App (at top)
└── APIs & Services
    ├── Enabled APIs (Google+)
    ├── OAuth consent screen (Configured)
    └── Credentials (1 OAuth 2.0 Client)
```

### Your Flutter App:
```
lib/constants.dart
└── googleClientId = 'YOUR_ACTUAL_ID_HERE'
```

### Login Screen:
```
[ Sign in with Google ]  ← Should work!
[ Continue as Guest ]
───────── OR ─────────
[ Email ]
[ Password ]
[ Login ]
```

---

## 🐛 Common Issues

| Issue | Quick Fix |
|-------|-----------|
| "ClientID not set" | Check constants.dart has Client ID |
| "Invalid client" | Add current port to Google Console |
| Popup closed | Normal - just try again |
| Network error | Start backend server |

---

## 📞 Need Help?

1. **Read full tutorial:** `GOOGLE_SIGNIN_TUTORIAL.md`
2. **Check error message** - it tells you what's wrong
3. **Verify each checkbox** above
4. **Make sure backend is running** on port 8081

---

## ✅ Final Verification

After completing all steps, you should be able to:

- [x] See "Sign in with Google" button
- [x] Click it without errors
- [x] See Google sign-in popup
- [x] Sign in with your Google account
- [x] Get redirected back to app
- [x] Be logged in automatically

**If all checked: CONGRATULATIONS! 🎉**

---

**Created:** November 3, 2025  
**Your Backend:** ✅ Ready at http://localhost:8081  
**Status:** Ready for Google Sign-In setup!
