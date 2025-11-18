import 'dart:convert';

import 'package:http/http.dart' as http;
import '../constants.dart';
import 'partner_access_api.dart';
import 'auth_helper.dart';

class AdminApi {
  const AdminApi();

  Future<Map<String, String>> _headers() async {
    final token = await AuthHelper.getNetworkToken();
    if (token == null) {
      throw Exception('Authentication required');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Future<AdminInsights> fetchInsights() async {
    final response =
        await http.get(_uri('/api/admin/insights'), headers: await _headers());
    _ensureSuccess(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return AdminInsights.fromJson(json);
  }

  Future<List<AdminUser>> fetchUsers() async {
    final response =
        await http.get(_uri('/api/admin/users'), headers: await _headers());
    _ensureSuccess(response);
    final List<dynamic> payload = jsonDecode(response.body) as List<dynamic>;
    return payload
        .map((item) => AdminUser.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AdminUser> updateRole({
    required int userId,
    required String role,
  }) async {
    final response = await http.patch(
      _uri('/api/admin/users/$userId/role'),
      headers: await _headers(),
      body: jsonEncode({'role': role}),
    );
    _ensureSuccess(response);
    return AdminUser.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<PartnerApplicationRecord>> fetchApplications() async {
    // reuse partner API to keep models consistent
    return const PartnerAccessApi().fetchApplications();
  }

  Future<List<PartnerDirectoryEntry>> fetchPartnerDirectory() async {
    return const PartnerAccessApi().fetchDirectory();
  }

  Future<void> syncPartnerDirectoryIntoUsers() async {
    // No-op now that everything comes from the backend.
  }

  Future<void> reviewApplication({
    required PartnerApplicationRecord record,
    required String status,
  }) async {
    await const PartnerAccessApi().reviewApplication(
      applicationId: record.id,
      status: status,
    );
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw Exception(
      response.body.isEmpty
          ? 'Request failed (${response.statusCode})'
          : response.body,
    );
  }
}

class AdminInsights {
  final int totalUsers;
  final int adminCount;
  final int partnerCount;
  final int pendingPartnerRequests;
  final int sugarLogCount;
  final double averageDailySugar;

  const AdminInsights({
    required this.totalUsers,
    required this.adminCount,
    required this.partnerCount,
    required this.pendingPartnerRequests,
    required this.sugarLogCount,
    required this.averageDailySugar,
  });

  factory AdminInsights.fromJson(Map<String, dynamic> json) {
    return AdminInsights(
      totalUsers: json['totalUsers'] as int? ?? 0,
      adminCount: json['adminCount'] as int? ?? 0,
      partnerCount: json['partnerCount'] as int? ?? 0,
      pendingPartnerRequests: json['pendingPartnerRequests'] as int? ?? 0,
      sugarLogCount: json['sugarLogCount'] as int? ?? 0,
      averageDailySugar:
          (json['averageDailySugar'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class AdminUser {
  final int id;
  final String fullName;
  final String email;
  final String role;
  final bool allowPartnerRequests;
  final int? dailySugarGoal;
  final String? createdAt;

  const AdminUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.allowPartnerRequests,
    this.dailySugarGoal,
    this.createdAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as int? ?? -1,
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'USER',
      allowPartnerRequests: json['allowPartnerRequests'] as bool? ?? true,
      dailySugarGoal: json['dailySugarGoal'] as int?,
      createdAt: json['createdAt'] as String?,
    );
  }

  AdminUser copyWith({
    int? id,
    String? fullName,
    String? email,
    String? role,
    bool? allowPartnerRequests,
    int? dailySugarGoal,
    String? createdAt,
  }) {
    return AdminUser(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      allowPartnerRequests:
          allowPartnerRequests ?? this.allowPartnerRequests,
      dailySugarGoal: dailySugarGoal ?? this.dailySugarGoal,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
