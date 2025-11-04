# Backend Implementation Guide for GUST Authentication

## 🎯 Quick Start for Java Spring Backend Developer

This guide provides all the backend endpoints needed to complete the GUST authentication system.

---

## 📡 Required API Endpoints

### 1. Password Reset Flow

#### Endpoint 1: Request Password Reset
```
POST /api/auth/forgot-password
Content-Type: application/json

Request Body:
{
  "email": "user@example.com"
}

Success Response (200 OK):
{
  "message": "Password reset email sent successfully"
}

Error Responses:
404 Not Found - Email not registered
500 Internal Server Error - Email service failure
```

**Backend Tasks:**
1. Validate email exists in database
2. Generate unique reset token (UUID)
3. Set token expiration (e.g., 1 hour)
4. Store token in database with user ID
5. Send email with reset link: `https://yourapp.com/reset-password?token={token}`
6. Return success response

**Spring Boot Example:**
```java
@PostMapping("/forgot-password")
public ResponseEntity<?> forgotPassword(@RequestBody ForgotPasswordRequest request) {
    User user = userRepository.findByEmail(request.getEmail())
        .orElseThrow(() -> new UserNotFoundException("Email not registered"));
    
    String resetToken = UUID.randomUUID().toString();
    LocalDateTime expiration = LocalDateTime.now().plusHours(1);
    
    PasswordResetToken token = new PasswordResetToken(resetToken, user, expiration);
    tokenRepository.save(token);
    
    emailService.sendPasswordResetEmail(user.getEmail(), resetToken);
    
    return ResponseEntity.ok(new MessageResponse("Reset email sent"));
}
```

---

#### Endpoint 2: Reset Password
```
POST /api/auth/reset-password
Content-Type: application/json

Request Body:
{
  "token": "uuid-token-here",
  "newPassword": "NewSecurePass123!"
}

Success Response (200 OK):
{
  "message": "Password reset successfully"
}

Error Responses:
400 Bad Request - Invalid or expired token
400 Bad Request - Password doesn't meet requirements
```

**Backend Tasks:**
1. Validate token exists and hasn't expired
2. Validate new password meets requirements (min 6 chars)
3. Hash new password (BCrypt recommended)
4. Update user password
5. Invalidate/delete reset token
6. Return success response

**Spring Boot Example:**
```java
@PostMapping("/reset-password")
public ResponseEntity<?> resetPassword(@RequestBody ResetPasswordRequest request) {
    PasswordResetToken token = tokenRepository.findByToken(request.getToken())
        .orElseThrow(() -> new InvalidTokenException("Invalid reset token"));
    
    if (token.isExpired()) {
        throw new TokenExpiredException("Reset token has expired");
    }
    
    User user = token.getUser();
    user.setPassword(passwordEncoder.encode(request.getNewPassword()));
    userRepository.save(user);
    
    tokenRepository.delete(token);
    
    return ResponseEntity.ok(new MessageResponse("Password reset successful"));
}
```

---

### 2. Apple Sign-In Backend

#### Endpoint: Apple OAuth Verification
```
POST /api/auth/apple
Content-Type: application/json

Request Body:
{
  "identityToken": "eyJraWQiOiJmaDZ...",
  "authorizationCode": "c3e6e8b5c...",
  "email": "user@privaterelay.appleid.com",  // Optional, may be null
  "fullName": "John Doe"  // Optional, only on first sign-in
}

Success Response (200 OK):
{
  "token": "jwt-token-here",
  "user": {
    "id": 123,
    "email": "user@privaterelay.appleid.com",
    "fullName": "John Doe",
    "provider": "apple"
  }
}

Error Responses:
401 Unauthorized - Invalid Apple token
500 Internal Server Error - Verification failure
```

**Backend Tasks:**
1. Verify `identityToken` with Apple's public keys
2. Extract Apple User ID from token claims
3. Check if user exists (by Apple User ID)
4. If new user:
   - Create account with email (if provided)
   - Store Apple User ID
   - Use fullName if provided
5. Generate JWT token
6. Return JWT + user info

**Dependencies Required:**
```xml
<!-- pom.xml -->
<dependency>
    <groupId>io.jsonwebtoken</groupId>
    <artifactId>jjwt</artifactId>
    <version>0.9.1</version>
</dependency>
<!-- For Apple token verification -->
<dependency>
    <groupId>com.auth0</groupId>
    <artifactId>java-jwt</artifactId>
    <version>4.4.0</version>
</dependency>
```

**Spring Boot Example:**
```java
@PostMapping("/apple")
public ResponseEntity<?> appleSignIn(@RequestBody AppleSignInRequest request) {
    // Verify identity token with Apple
    DecodedJWT jwt = appleAuthService.verifyIdentityToken(request.getIdentityToken());
    String appleUserId = jwt.getSubject();
    
    // Find or create user
    User user = userRepository.findByAppleUserId(appleUserId)
        .orElseGet(() -> {
            User newUser = new User();
            newUser.setAppleUserId(appleUserId);
            newUser.setEmail(request.getEmail());
            newUser.setFullName(request.getFullName());
            newUser.setProvider("apple");
            return userRepository.save(newUser);
        });
    
    // Generate JWT
    String token = jwtUtils.generateToken(user);
    
    return ResponseEntity.ok(new AuthResponse(token, user));
}
```

**Apple Token Verification Service:**
```java
@Service
public class AppleAuthService {
    public DecodedJWT verifyIdentityToken(String identityToken) {
        // 1. Fetch Apple's public keys from https://appleid.apple.com/auth/keys
        // 2. Decode and verify JWT signature
        // 3. Verify issuer is "https://appleid.apple.com"
        // 4. Verify audience matches your app's bundle ID
        // 5. Check expiration
        
        Algorithm algorithm = Algorithm.RSA256(getApplePublicKey());
        JWTVerifier verifier = JWT.require(algorithm)
            .withIssuer("https://appleid.apple.com")
            .build();
        
        return verifier.verify(identityToken);
    }
}
```

---

### 3. Anonymous User Management

#### Endpoint 1: Create Anonymous Session
```
POST /api/auth/anonymous
Content-Type: application/json

Request Body: (empty or optional device info)
{}

Success Response (200 OK):
{
  "anonymousToken": "jwt-token-for-anonymous",
  "userId": "anon_123abc",
  "expiresIn": 2592000  // 30 days in seconds
}
```

**Backend Tasks:**
1. Generate unique anonymous user ID
2. Create temporary user record
3. Generate JWT with limited permissions
4. Return token with 30-day expiration

**Spring Boot Example:**
```java
@PostMapping("/anonymous")
public ResponseEntity<?> createAnonymousUser() {
    String anonymousId = "anon_" + UUID.randomUUID().toString();
    
    User anonymousUser = new User();
    anonymousUser.setAnonymousId(anonymousId);
    anonymousUser.setIsAnonymous(true);
    anonymousUser.setCreatedAt(LocalDateTime.now());
    userRepository.save(anonymousUser);
    
    String token = jwtUtils.generateAnonymousToken(anonymousUser);
    
    return ResponseEntity.ok(new AnonymousAuthResponse(token, anonymousId));
}
```

---

#### Endpoint 2: Link Anonymous Account
```
POST /api/auth/link-anonymous
Content-Type: application/json
Authorization: Bearer {anonymous-jwt-token}

Request Body:
{
  "email": "user@example.com",
  "password": "SecurePass123!",
  "fullName": "John Doe"
}

Success Response (200 OK):
{
  "token": "full-jwt-token",
  "user": {
    "id": 123,
    "email": "user@example.com",
    "fullName": "John Doe"
  },
  "migratedRecords": {
    "sugarLogs": 15,
    "preferences": true
  }
}

Error Responses:
400 Bad Request - Email already registered
401 Unauthorized - Invalid anonymous token
```

**Backend Tasks:**
1. Validate anonymous JWT token
2. Check email isn't already registered
3. Create new authenticated user account
4. Migrate data from anonymous user:
   - Sugar logs
   - Preferences
   - Analytics data
5. Delete anonymous user record
6. Generate full JWT token
7. Return authenticated user info

**Spring Boot Example:**
```java
@PostMapping("/link-anonymous")
public ResponseEntity<?> linkAnonymousAccount(
    @RequestHeader("Authorization") String anonymousToken,
    @RequestBody LinkAccountRequest request
) {
    // Validate anonymous token
    String anonymousId = jwtUtils.getAnonymousIdFromToken(anonymousToken);
    User anonymousUser = userRepository.findByAnonymousId(anonymousId)
        .orElseThrow(() -> new UserNotFoundException("Anonymous user not found"));
    
    // Check email availability
    if (userRepository.existsByEmail(request.getEmail())) {
        throw new EmailAlreadyExistsException("Email already registered");
    }
    
    // Create authenticated user
    User authenticatedUser = new User();
    authenticatedUser.setEmail(request.getEmail());
    authenticatedUser.setPassword(passwordEncoder.encode(request.getPassword()));
    authenticatedUser.setFullName(request.getFullName());
    authenticatedUser.setIsAnonymous(false);
    userRepository.save(authenticatedUser);
    
    // Migrate data
    MigrationResult result = dataMigrationService.migrateAnonymousData(
        anonymousUser, authenticatedUser
    );
    
    // Delete anonymous user
    userRepository.delete(anonymousUser);
    
    // Generate JWT
    String token = jwtUtils.generateToken(authenticatedUser);
    
    return ResponseEntity.ok(new LinkAccountResponse(token, authenticatedUser, result));
}
```

---

## 🗄️ Database Schema Updates

### PasswordResetToken Table
```sql
CREATE TABLE password_reset_tokens (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    token VARCHAR(255) UNIQUE NOT NULL,
    user_id BIGINT NOT NULL,
    expiration_date TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_token (token),
    INDEX idx_expiration (expiration_date)
);
```

### User Table Updates
```sql
ALTER TABLE users
ADD COLUMN apple_user_id VARCHAR(255) UNIQUE,
ADD COLUMN anonymous_id VARCHAR(255) UNIQUE,
ADD COLUMN is_anonymous BOOLEAN DEFAULT FALSE,
ADD COLUMN provider VARCHAR(50) DEFAULT 'email',  -- 'email', 'google', 'apple'
ADD INDEX idx_apple_user_id (apple_user_id),
ADD INDEX idx_anonymous_id (anonymous_id);
```

---

## 📧 Email Service Configuration

### Email Template: Password Reset

**Subject:** Reset Your GUST Password

**HTML Body:**
```html
<!DOCTYPE html>
<html>
<body style="font-family: Arial, sans-serif; background-color: #f5f5f5; padding: 20px;">
    <div style="max-width: 600px; margin: 0 auto; background-color: white; padding: 40px; border-radius: 12px;">
        <h1 style="color: #6A1B9A;">Reset Your Password</h1>
        <p>You requested to reset your password for your GUST account.</p>
        <p>Click the button below to reset your password:</p>
        <a href="${resetLink}" style="display: inline-block; background-color: #6A1B9A; color: white; padding: 12px 32px; text-decoration: none; border-radius: 8px; margin: 20px 0;">Reset Password</a>
        <p style="color: #757575; font-size: 14px;">This link will expire in 1 hour.</p>
        <p style="color: #757575; font-size: 14px;">If you didn't request this, please ignore this email.</p>
    </div>
</body>
</html>
```

**Spring Boot Email Service:**
```java
@Service
public class EmailService {
    
    @Autowired
    private JavaMailSender mailSender;
    
    @Value("${app.frontend.url}")
    private String frontendUrl;
    
    public void sendPasswordResetEmail(String toEmail, String resetToken) {
        String resetLink = frontendUrl + "/reset-password?token=" + resetToken;
        
        MimeMessage message = mailSender.createMimeMessage();
        MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
        
        try {
            helper.setTo(toEmail);
            helper.setSubject("Reset Your GUST Password");
            helper.setText(buildEmailTemplate(resetLink), true);
            helper.setFrom("noreply@gustapp.com");
            
            mailSender.send(message);
        } catch (MessagingException e) {
            throw new EmailSendException("Failed to send reset email", e);
        }
    }
}
```

---

## 🔐 Security Considerations

### JWT Token Configuration
```java
@Configuration
public class JwtConfig {
    // Regular user tokens: 24 hours
    public static final long JWT_EXPIRATION = 86400000;
    
    // Anonymous tokens: 30 days
    public static final long ANONYMOUS_JWT_EXPIRATION = 2592000000L;
    
    // Password reset tokens: 1 hour
    public static final long RESET_TOKEN_EXPIRATION = 3600000;
}
```

### Password Requirements
- Minimum 6 characters (frontend already validates)
- Optional: Add server-side validation for:
  - At least 1 uppercase letter
  - At least 1 number
  - At least 1 special character

### Rate Limiting
Implement rate limiting for sensitive endpoints:
- Password reset: Max 3 requests per email per hour
- Login attempts: Max 5 failed attempts per IP per 15 minutes

---

## ✅ Testing Checklist

### Password Reset Flow
- [ ] Request reset for existing email → receives email
- [ ] Request reset for non-existing email → no email sent (security)
- [ ] Reset with valid token → password changed
- [ ] Reset with expired token → error message
- [ ] Reset with invalid token → error message
- [ ] Token is invalidated after successful reset

### Apple Sign-In
- [ ] First-time Apple user → account created
- [ ] Returning Apple user → existing account logged in
- [ ] Invalid Apple token → rejected
- [ ] Token verification with Apple servers works

### Anonymous Users
- [ ] Create anonymous session → returns token
- [ ] Anonymous user can use app features
- [ ] Link anonymous to email account → data migrated
- [ ] Linked account cannot use anonymous token anymore
- [ ] Original anonymous user deleted after link

---

## 📚 Useful Resources

- **Apple Sign-In Documentation:** https://developer.apple.com/sign-in-with-apple/
- **Spring Security JWT:** https://spring.io/guides/tutorials/spring-boot-oauth2/
- **Email with Spring Boot:** https://spring.io/guides/gs/sending-email/
- **BCrypt Password Encoding:** https://docs.spring.io/spring-security/reference/features/authentication/password-storage.html

---

## 🚀 Deployment Notes

### Environment Variables
```properties
# application.properties
app.frontend.url=https://gustapp.com
app.jwt.secret=your-super-secret-jwt-key-here
app.jwt.expiration=86400000

spring.mail.host=smtp.gmail.com
spring.mail.port=587
spring.mail.username=noreply@gustapp.com
spring.mail.password=${MAIL_PASSWORD}
spring.mail.properties.mail.smtp.auth=true
spring.mail.properties.mail.smtp.starttls.enable=true

apple.signin.key.id=${APPLE_KEY_ID}
apple.signin.team.id=${APPLE_TEAM_ID}
apple.signin.bundle.id=com.gustapp.mobile
```

---

## 📞 Questions?

If you need clarification on any endpoint or implementation detail, check the Flutter frontend code:
- `lib/Login.dart` - Shows how frontend calls these endpoints
- `lib/forgot_password.dart` - Password reset flow
- `lib/widgets/auth_provider_buttons.dart` - Provider button implementations

**Frontend is ready and waiting for these backend endpoints!** 🎉
