import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart'; // Make sure this has baseUrl
import 'main.dart'; // For AppRoutes
import 'services/biometric_auth_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _editing = false;
  bool _loading = true;
  bool _updating = false;
  String? _error;

  // Profile fields
  String _fullName = "";
  String _email = "";
  int _dailySugarGoal = 0;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  
  // Biometric
  final BiometricAuthService _biometricService = BiometricAuthService();
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  String _biometricType = 'Biometric';
  
  // 🔧 DEBUG MODE: Set to true to see biometric UI on web (for testing only)
  final bool _debugShowBiometric = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _checkBiometric();
  }
  
  Future<void> _checkBiometric() async {
    final isAvailable = await _biometricService.isBiometricAvailable();
    final isEnabled = await _biometricService.isBiometricEnabled();
    final biometrics = await _biometricService.getAvailableBiometrics();
    final type = _biometricService.getBiometricTypeName(biometrics);
    
    setState(() {
      _biometricAvailable = isAvailable || _debugShowBiometric; // Show if debug mode
      _biometricEnabled = isEnabled;
      _biometricType = type;
    });
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await _getToken();
      final resp = await http.get(
        Uri.parse('$baseUrl/api/users/me/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
      );
      if (resp.statusCode != 200) {
        throw Exception(resp.body);
      }
      final data = jsonDecode(resp.body);
      _fullName = data['fullName'] ?? "";
      _email = data['email'] ?? "";
      _dailySugarGoal = data['dailySugarGoal'] ?? 0;
      // Reset controllers every load
      _nameController = TextEditingController(text: _fullName);
      _emailController = TextEditingController(text: _email);
    } catch (e) {
      _error = "Failed to load profile: $e";
    }
    setState(() => _loading = false);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _updating = true;
      _error = null;
    });
    try {
      final token = await _getToken();
      final resp = await http.patch(
        Uri.parse('$baseUrl/api/users/me/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({
          'fullName': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'dailySugarGoal': _dailySugarGoal, // send as is
        }),
      );
      if (resp.statusCode != 200) {
        throw Exception(resp.body);
      }
      final data = jsonDecode(resp.body);
      setState(() {
        _editing = false;
        _fullName = data['fullName'] ?? "";
        _email = data['email'] ?? "";
        _dailySugarGoal = data['dailySugarGoal'] ?? 0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      _error = "Failed to update profile: $e";
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_error!), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _updating = false);
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    
    // Clear biometric auth data
    await _biometricService.clearAuthToken();
    
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.purple[50],
      appBar: AppBar(
        backgroundColor: Colors.purple[100],
        title: const Text("My Profile", style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: false,
        leading: null, // Removes back button!
        automaticallyImplyLeading: false,
        actions: [
          // Only show logout if not editing
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.deepPurple),
              tooltip: "Logout",
              onPressed: _logout,
            ),
          if (!_editing && !_loading)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.deepPurple),
              tooltip: "Edit",
              onPressed: () {
                setState(() => _editing = true);
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Avatar with big initial
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: Colors.deepPurple,
                          child: Text(
                            (_fullName.isNotEmpty ? _fullName[0].toUpperCase() : "?"),
                            style: const TextStyle(fontSize: 36, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Editable fields (name, email)
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _nameController,
                                  enabled: _editing,
                                  decoration: InputDecoration(
                                    labelText: "Full Name",
                                    prefixIcon: const Icon(Icons.person),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10)),
                                  ),
                                  style: const TextStyle(fontSize: 17),
                                  validator: (val) => val == null || val.isEmpty
                                      ? "Enter your name"
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _emailController,
                                  enabled: _editing,
                                  decoration: InputDecoration(
                                    labelText: "Email",
                                    prefixIcon: const Icon(Icons.email),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10)),
                                  ),
                                  style: const TextStyle(fontSize: 17),
                                  validator: (val) => val == null || val.isEmpty
                                      ? "Enter your email"
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        // Action Buttons
                        if (_editing)
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurple,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12))),
                                  onPressed: _updating ? null : _saveProfile,
                                  icon: _updating
                                      ? const SizedBox(
                                          width: 20, height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                                      : const Icon(Icons.save),
                                  label: const Text("Save Changes", style: TextStyle(fontSize: 16)),
                                ),
                              ),
                              const SizedBox(width: 18),
                              TextButton(
                                onPressed: _updating
                                    ? null
                                    : () {
                                        setState(() {
                                          _editing = false;
                                          _nameController.text = _fullName;
                                          _emailController.text = _email;
                                        });
                                      },
                                style: TextButton.styleFrom(
                                    foregroundColor: Colors.deepPurple,
                                    textStyle: const TextStyle(fontWeight: FontWeight.bold)),
                                child: const Text("Cancel"),
                              ),
                            ],
                          ),
                        if (!_editing)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Card(
                              color: Colors.white.withOpacity(0.9),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 20, horizontal: 22),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.person, color: Colors.deepPurple),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _fullName,
                                            style: theme.textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold, fontSize: 18),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        const Icon(Icons.email, color: Colors.deepPurple),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _email,
                                            style: theme.textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w500, fontSize: 17),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        // Biometric Toggle Section
                        if (!_editing && _biometricAvailable)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Card(
                              color: Colors.white.withOpacity(0.9),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 22),
                                child: Row(
                                  children: [
                                    Icon(
                                      _biometricType == 'Face ID' 
                                          ? Icons.face 
                                          : Icons.fingerprint,
                                      color: Colors.deepPurple,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$_biometricType Login',
                                            style: theme.textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Quick and secure access',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                                color: Colors.grey[600]),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: _biometricEnabled,
                                      onChanged: (value) => _toggleBiometric(value),
                                      activeColor: Colors.deepPurple,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
    );
  }

  /// Toggle biometric authentication on/off
  Future<void> _toggleBiometric(bool enable) async {
    // Check if we're in debug mode on web
    if (_debugShowBiometric && !await _biometricService.isBiometricAvailable()) {
      // Show info message that this only works on physical devices
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Biometric auth only works on physical devices!\n\nThis is just a preview of the UI.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }
    
    if (enable) {
      // User wants to enable biometric
      final didAuthenticate = await _biometricService.authenticate(
        reason: 'Authenticate to enable $_biometricType login',
      );
      
      if (didAuthenticate) {
        // Get current JWT token
        final token = await _getToken();
        if (token != null) {
          await _biometricService.saveAuthToken(token);
          await _biometricService.enableBiometric();
          
          setState(() {
            _biometricEnabled = true;
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$_biometricType login enabled!'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } else {
      // User wants to disable biometric
      await _biometricService.disableBiometric();
      
      setState(() {
        _biometricEnabled = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$_biometricType login disabled'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
