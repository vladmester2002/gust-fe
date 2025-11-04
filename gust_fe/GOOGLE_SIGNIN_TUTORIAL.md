# 📖 Complete Step-by-Step Tutorial: Google Sign-In Setup

## 🎯 Goal
Get your Google Client ID and enable Google Sign-In in your GUST app.

**Time Required:** 10-15 minutes  
**Cost:** FREE (no credit card needed)

---

## 📋 Prerequisites

- [ ] Google account (Gmail)
- [ ] Your Flutter app running
- [ ] Internet connection

---

# Part 1: Google Cloud Console Setup

## Step 1: Go to Google Cloud Console

1. Open your browser
2. Go to: **https://console.cloud.google.com/**
3. Sign in with your Google account

---

## Step 2: Create a New Project

### 2.1 Click "Select a project" dropdown
- Located at the top-left of the page (next to "Google Cloud")
- If you see a project name, click on it

### 2.2 Click "NEW PROJECT"
- Button at the top-right of the modal dialog
- Or use this direct link: https://console.cloud.google.com/projectcreate

### 2.3 Fill in Project Details
```
Project name: GUST App
               (or any name you prefer)

Location: No organization
          (leave as default)
```

### 2.4 Click "CREATE"
- Wait 10-20 seconds for project creation
- You'll see a notification when it's ready

### 2.5 Select Your New Project
- Click "Select a project" again
- Choose "GUST App" from the list

✅ **Checkpoint:** You should see "GUST App" at the top of the page

---

## Step 3: Enable Google+ API (Required for Sign-In)

### 3.1 Open Navigation Menu
- Click the **☰** (hamburger menu) at top-left

### 3.2 Go to APIs & Services
```
Navigation path:
☰ → APIs & Services → Library
```
- Or use this link (replace PROJECT_ID with yours):
  https://console.cloud.google.com/apis/library?project=YOUR_PROJECT_ID

### 3.3 Search for Google+ API
- In the search bar, type: `Google+ API`
- Click on "Google+ API" from results

### 3.4 Enable the API
- Click the blue **"ENABLE"** button
- Wait 5-10 seconds

✅ **Checkpoint:** You should see "API enabled" message

---

## Step 4: Configure OAuth Consent Screen

### 4.1 Go to OAuth Consent Screen
```
Navigation path:
☰ → APIs & Services → OAuth consent screen
```
- Or use: https://console.cloud.google.com/apis/credentials/consent

### 4.2 Choose User Type
- Select: **"External"**
- Click **"CREATE"**

### 4.3 Fill in App Information (Page 1)

**App information:**
```
App name: GUST
          (your app name)

User support email: your-email@gmail.com
                    (select from dropdown)
```

**App logo:** (Optional - can skip)

**App domain:** (Can leave blank for now)

**Developer contact information:**
```
Email addresses: your-email@gmail.com
```

### 4.4 Click "SAVE AND CONTINUE"

### 4.5 Scopes Page (Page 2)
- Click **"ADD OR REMOVE SCOPES"**
- Check these boxes:
  - ✅ `.../auth/userinfo.email`
  - ✅ `.../auth/userinfo.profile`
  - ✅ `openid`
- Click **"UPDATE"**
- Click **"SAVE AND CONTINUE"**

### 4.6 Test Users Page (Page 3)
- Click **"ADD USERS"**
- Add your email: `your-email@gmail.com`
- Click **"ADD"**
- Click **"SAVE AND CONTINUE"**

### 4.7 Summary Page (Page 4)
- Review your settings
- Click **"BACK TO DASHBOARD"**

✅ **Checkpoint:** OAuth consent screen configured

---

## Step 5: Create OAuth 2.0 Client ID

### 5.1 Go to Credentials
```
Navigation path:
☰ → APIs & Services → Credentials
```
- Or use: https://console.cloud.google.com/apis/credentials

### 5.2 Create Credentials
- Click **"+ CREATE CREDENTIALS"** (at the top)
- Select: **"OAuth client ID"**

### 5.3 Choose Application Type
- Select: **"Web application"**

### 5.4 Configure Web Client

**Name:**
```
GUST Web Client
(or any descriptive name)
```

**Authorized JavaScript origins:**
Click **"+ ADD URI"** and add these URLs (one at a time):
```
http://localhost
http://localhost:49795
http://localhost:65078
http://localhost:60148
http://127.0.0.1
```

**Why multiple ports?**
Flutter web uses random ports. Adding multiple ensures it works.

**Authorized redirect URIs:**
Leave EMPTY (not needed for this flow)

### 5.5 Click "CREATE"

### 5.6 Copy Your Client ID
- A modal appears with your credentials
- **Client ID** looks like: `123456789012-abcdefghijklmnop.apps.googleusercontent.com`
- Click the **"COPY"** button (📋 icon)
- Or manually select and copy the entire Client ID

**⚠️ IMPORTANT:** Save this somewhere safe! You'll need it in the next section.

### 5.7 Click "OK"

✅ **Checkpoint:** You have your Client ID copied!

---

# Part 2: Add Client ID to Your Flutter App

## Step 6: Update constants.dart

### 6.1 Open Your Flutter Project
- Navigate to: `C:\Users\vladi\GUST_app\gust-fe\gust_fe`

### 6.2 Open constants.dart
- Path: `lib\constants.dart`
- Open in your code editor (VS Code)

### 6.3 Update the File

**Before:**
```dart
const String googleClientId = ''; // TODO: Add your Google Client ID here
```

**After:**
```dart
const String googleClientId = '123456789012-abcdefghijklmnop.apps.googleusercontent.com';
```

**⚠️ Important:**
- Paste your ACTUAL Client ID (the one you copied)
- Keep the single quotes `'...'`
- No spaces before or after

### 6.4 Save the File
- Press `Ctrl + S` (Windows)
- Or `File → Save`

✅ **Checkpoint:** Client ID added to your app!

---

# Part 3: Test Google Sign-In

## Step 7: Hot Reload Your App

### 7.1 Go to Your Terminal
- Where Flutter is running

### 7.2 Hot Reload
- Press `r` and Enter
- OR refresh your browser (F5)

### 7.3 Wait for Reload
- Should take 2-5 seconds
- Look for "Reloaded" message

---

## Step 8: Test Sign-In

### 8.1 Go to Login Page
- Your app should show the login screen

### 8.2 Click "Sign in with Google"
- The button with the Google "G" logo

### 8.3 What You Should See

**Scenario A: Success! ✅**
- Google sign-in popup appears
- Shows your Google accounts
- Click your account
- Popup closes
- You're logged into the app!

**Scenario B: Error ❌**
See troubleshooting section below.

---

# 🐛 Troubleshooting

## Issue 1: "ClientID not set" Error

**Cause:** Client ID not properly copied to constants.dart

**Solution:**
1. Check `lib/constants.dart`
2. Make sure Client ID is between quotes: `'YOUR_ID_HERE'`
3. No extra spaces
4. Save file
5. Hot reload (press `r`)

---

## Issue 2: "Invalid client" Error

**Cause:** Authorized JavaScript origins not configured

**Solution:**
1. Go back to Google Cloud Console
2. APIs & Services → Credentials
3. Click on your "GUST Web Client"
4. Add this URL to **Authorized JavaScript origins:**
   ```
   http://localhost:YOUR_CURRENT_PORT
   ```
   (Check browser URL for current port)
5. Click **"SAVE"**
6. Wait 1-2 minutes for changes to propagate
7. Refresh your app and try again

---

## Issue 3: "popup_closed_by_user"

**Cause:** You closed the Google sign-in popup

**Solution:**
- This is normal! Just click "Sign in with Google" again
- Don't close the popup this time

---

## Issue 4: "redirect_uri_mismatch"

**Cause:** Flutter web port changed

**Solution:**
1. Check your browser URL for current port
   Example: `http://localhost:61234`
2. Add this port to Google Console:
   - Go to Credentials
   - Edit your OAuth client
   - Add: `http://localhost:61234`
   - Save
3. Try again

---

## Issue 5: Network Error

**Cause:** Backend not running

**Solution:**
1. Make sure your Spring Boot backend is running
2. Check it's on port 8081
3. Try this URL in browser: http://localhost:8081/api/auth/google
4. Should show "Method not allowed" (that's good!)

---

# ✅ Verification Checklist

After completing all steps, verify:

- [ ] Google Cloud project created
- [ ] Google+ API enabled
- [ ] OAuth consent screen configured
- [ ] Web OAuth client created
- [ ] Client ID copied
- [ ] Client ID pasted in `lib/constants.dart`
- [ ] File saved
- [ ] App hot reloaded
- [ ] "Sign in with Google" button clicked
- [ ] Google popup appeared
- [ ] Successfully signed in!

---

# 📝 Summary

## What You Created:

1. **Google Cloud Project:** GUST App
2. **OAuth Client ID:** For web authentication
3. **Configured Origins:** Allow localhost development

## What You Updated:

1. `lib/constants.dart` with your Client ID

## Files Modified:
```
lib/constants.dart
```

## Time Spent:
~10-15 minutes

---

# 🎉 Success!

You've successfully set up Google Sign-In for your GUST app!

## What Works Now:

- ✅ Click "Sign in with Google"
- ✅ Google popup appears
- ✅ Select your account
- ✅ Automatically logged in
- ✅ No password needed!

## Next Steps:

1. Test with different Google accounts
2. Deploy to production (will need to add production URLs)
3. Consider adding Apple Sign-In (optional)

---

# 📚 Additional Resources

- **Google Cloud Console:** https://console.cloud.google.com/
- **OAuth 2.0 Documentation:** https://developers.google.com/identity/protocols/oauth2
- **Flutter google_sign_in package:** https://pub.dev/packages/google_sign_in

---

# 🆘 Still Having Issues?

Check these files in your project:
- `GOOGLE_SIGNIN_QUICKSTART.md` - Quick reference
- `GOOGLE_SIGNIN_SETUP.md` - Detailed setup
- `BACKEND_IMPLEMENTATION_GUIDE.md` - Backend API info

Or review the error message carefully - it usually tells you exactly what's wrong!

---

**Last Updated:** November 3, 2025  
**Tutorial Version:** 1.0  
**Your Backend Status:** ✅ Ready at `http://localhost:8081`
