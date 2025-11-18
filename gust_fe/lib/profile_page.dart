import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'constants.dart'; // Make sure this has baseUrl
import 'main.dart'; // For AppRoutes
import 'services/biometric_auth_service.dart';
import 'services/auth_helper.dart';
import 'utils/notification_helper.dart';
import 'data/models/local_user.dart';
import 'repositories/auth_repository.dart';
import 'state/auth_state.dart';
import 'partner_access_page.dart';

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
  bool _guestMode = false;
  final AuthRepository _authRepository = AuthRepository();
  LocalUser? _localUser;

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
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _bootstrapProfile();
    _checkBiometric();
  }

  Future<void> _bootstrapProfile() async {
    final isGuest = await AuthHelper.isGuestSession();
    if (!mounted) return;
    setState(() => _guestMode = isGuest);
    await _fetchProfile();
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

  Future<String?> _getToken() => AuthHelper.getNetworkToken();

  Future<LocalUser?> _ensureLocalUser() async {
    if (_localUser != null) return _localUser;
    final user = await _authRepository.getActiveUser();
    _localUser = user;
    return user;
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_guestMode) {
        final user = await _ensureLocalUser();
        if (user == null) {
          throw Exception('No local profile cached for guest mode.');
        }
        _fullName = user.fullName;
        _email = user.email;
        _dailySugarGoal = user.dailySugarGoal ?? 0;
        _nameController = TextEditingController(text: _fullName);
        _emailController = TextEditingController(text: _email);
      } else {
        final token = await _getToken();
        if (token == null || token.isEmpty) {
          throw Exception('Missing authentication token. Please log in again.');
        }
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
        _nameController = TextEditingController(text: _fullName);
        _emailController = TextEditingController(text: _email);
      }
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
      if (_guestMode) {
        final user = await _ensureLocalUser();
        if (user == null) {
          throw Exception('No local profile found. Please restart the guest session.');
        }
        final updated = await _authRepository.persistUserProfile(
          email: _emailController.text.trim(),
          fullName: _nameController.text.trim(),
          role: user.role,
          provider: user.authProvider,
          goal: _dailySugarGoal,
          allowPartnerRequests: user.allowPartnerRequests,
          biometricEnabled: user.biometricEnabled,
          featureFlags: user.featureFlags,
        );
        _localUser = updated ?? user;
        setState(() {
          _editing = false;
          _fullName = updated?.fullName ?? _fullName;
          _email = updated?.email ?? _email;
          _dailySugarGoal = updated?.dailySugarGoal ?? _dailySugarGoal;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Profile updated!"),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }

      final token = await _getToken();
      if (token == null) {
        throw Exception("Not authenticated. Please login again.");
      }
      
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
      ).timeout(const Duration(seconds: 10));
      
      if (resp.statusCode != 200) {
        throw Exception(resp.body.isNotEmpty ? resp.body : "Server returned status ${resp.statusCode}");
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
      String errorMessage = "Failed to update profile: ";
      if (e.toString().contains("XMLHttpRequest") || e.toString().contains("Failed host lookup")) {
        errorMessage += "Cannot connect to server. Please check if the backend is running.";
      } else if (e.toString().contains("timeout")) {
        errorMessage += "Request timed out. Please try again.";
      } else {
        errorMessage += e.toString();
      }
      
      _error = errorMessage;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_error!),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
    setState(() => _updating = false);
  }

  Future<void> _logout() async {
    final authState = context.read<AuthState>();
    await authState.signOut();
    await _biometricService.clearAuthToken();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _editing ? "Edit Profile" : "My Profile",
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
        leading: null,
        automaticallyImplyLeading: false,
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.white),
              tooltip: "Logout",
              onPressed: _logout,
            ),
          if (!_editing && !_loading)
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: Colors.white),
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
                  child: Column(
                    children: [
                      // Header with gradient and avatar
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF6A1B9A),
                              const Color(0xFF8E24AA),
                              const Color(0xFFAB47BC),
                            ],
                          ),
                        ),
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 80, 24, 40),
                            child: Column(
                              children: [
                                // Avatar with elevation
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 56,
                                    backgroundColor: Colors.white,
                                    child: CircleAvatar(
                                      radius: 52,
                                      backgroundColor: const Color(0xFF4A148C),
                                      child: Text(
                                        (_fullName.isNotEmpty ? _fullName[0].toUpperCase() : "?"),
                                        style: const TextStyle(
                                          fontSize: 48,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Name
                                Text(
                                  _fullName.isNotEmpty ? _fullName : "User",
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _email.isNotEmpty ? _email : 'Email not available',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      // Body content
                      Form(
                        key: _formKey,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Section Header
                              if (_editing)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    "Personal Information",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF6A1B9A),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              
                              // Editable fields
                              if (_editing)
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    children: [
                                      TextFormField(
                                        controller: _nameController,
                                        enabled: _editing,
                                        decoration: InputDecoration(
                                          labelText: "Full Name",
                                          prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF6A1B9A)),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(color: Colors.grey.shade300),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(color: Colors.grey.shade300),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: Color(0xFF6A1B9A), width: 2),
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                        ),
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                        validator: (val) => val == null || val.isEmpty ? "Enter your name" : null,
                                      ),
                                      const SizedBox(height: 16),
                                      TextFormField(
                                        controller: _emailController,
                                        enabled: _editing,
                                        decoration: InputDecoration(
                                          labelText: "Email",
                                          prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF6A1B9A)),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(color: Colors.grey.shade300),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(color: Colors.grey.shade300),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: Color(0xFF6A1B9A), width: 2),
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                        ),
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                        validator: (val) => val == null || val.isEmpty ? "Enter your email" : null,
                                      ),
                                    ],
                                  ),
                                ),
                              
                              if (_editing) const SizedBox(height: 20),
                              
                              // Action Buttons
                              if (_editing)
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF6A1B9A),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          elevation: 2,
                                        ),
                                        onPressed: _updating ? null : _saveProfile,
                                        child: _updating
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.check_circle_outline_rounded, size: 20),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    "Save Changes",
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    OutlinedButton(
                                      onPressed: _updating
                                          ? null
                                          : () {
                                              setState(() {
                                                _editing = false;
                                                _nameController.text = _fullName;
                                                _emailController.text = _email;
                                              });
                                            },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF6A1B9A),
                                        side: const BorderSide(color: Color(0xFF6A1B9A), width: 1.5),
                                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: const Text(
                                        "Cancel",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              
                              // Account Settings Section (when not editing)
                              if (!_editing) ...[
                                const SizedBox(height: 8),
                                const Text(
                                  "Account Settings",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF6A1B9A),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              
                              // Biometric Toggle Card
                              if (!_editing && _biometricAvailable)
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6A1B9A).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          _biometricType == 'Face ID' 
                                              ? Icons.face_rounded 
                                              : Icons.fingerprint_rounded,
                                          color: const Color(0xFF6A1B9A),
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '$_biometricType Login',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                                color: Color(0xFF212121),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Quick and secure access',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[600],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Switch(
                                        value: _biometricEnabled,
                                        onChanged: (value) => _toggleBiometric(value),
                                        activeColor: const Color(0xFF6A1B9A),
                                      ),
                                    ],
                                  ),
                                ),
                              
                              const SizedBox(height: 16),
                              if (!_editing && !_guestMode)
                                _buildPartnerShortcutCard(context),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    ],
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
        NotificationHelper.showInfo(
          context,
          'Biometric authentication only works on physical devices. This is just a UI preview.',
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
            NotificationHelper.showSuccess(
              context,
              '$_biometricType login enabled',
            );
          }
        } else {
          if (mounted) {
            NotificationHelper.showWarning(
              context,
              'No authentication token found. Please log in again.',
            );
          }
        }
      }
      // If authentication fails or is cancelled, just don't show anything
    } else {
      // User wants to disable biometric
      await _biometricService.disableBiometric();
      
      setState(() {
        _biometricEnabled = false;
      });
      
      if (mounted) {
        NotificationHelper.showInfo(
          context,
          '$_biometricType login disabled',
        );
      }
    }
  }

  Widget _buildPartnerShortcutCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF4A148C).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF4A148C).withOpacity(0.15),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4A148C).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.handshake_rounded,
              color: Color(0xFF4A148C),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Partner collaboration',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Color(0xFF212121),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Invite coaches or caregivers and manage requests directly from here.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PartnerAccessPage()),
              );
            },
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Open'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A148C),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
