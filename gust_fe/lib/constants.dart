// Use localhost for local development, or update to your server IP.
const String baseUrl = 'http://10.191.164.207:8081';
// Previous: const String baseUrl = 'http://localhost:8081';

// Flip on via: flutter run --dart-define=ENABLE_MOCK_AUTH=true
const bool enableMockAuth =
    bool.fromEnvironment('ENABLE_MOCK_AUTH', defaultValue: false);

const String googleClientId = '';
