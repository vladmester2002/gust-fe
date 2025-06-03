// lib/constants.dart

// baseUrl is used for all API calls in the app.
// For local development, use 'http://127.0.0.1:8080' or your machine's LAN IP if testing from another device.
// For production, set this to your deployed backend URL (e.g. 'https://api.myapp.com').

// To manage environments more easily, consider using the flutter_dotenv package:
// 1. Add flutter_dotenv to pubspec.yaml:   flutter_dotenv: ^5.1.0
// 2. Create a .env file in your project root:
//      BASE_URL=http://127.0.0.1:8080
// 3. In main.dart, load dotenv:   await dotenv.load();
// 4. Then use:   dotenv.env['BASE_URL'] ?? 'http://127.0.0.1:8080'

const String baseUrl = 'http://127.0.0.1:8080'; // Change as needed
