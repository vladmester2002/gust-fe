import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants.dart';
import 'auth_helper.dart';

class PartnerAccessApi {
  const PartnerAccessApi();

  Future<String?> _getToken() => AuthHelper.getNetworkToken();

  Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('You need to login first.');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  Future<PartnerOverview> fetchOverview() async {
    final response =
        await http.get(_uri('/api/partners/overview'), headers: await _headers());
    _ensureSuccess(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return PartnerOverview.fromJson(json);
  }

  Future<void> submitRequest({
    required int ownerId,
    required String module,
    String? note,
    int durationDays = 30,
  }) async {
    final body = jsonEncode({
      'ownerId': ownerId,
      'module': module,
      'note': note,
      'durationDays': durationDays,
    });
    final response = await http.post(
      _uri('/api/partners/requests'),
      headers: await _headers(),
      body: body,
    );
    _ensureSuccess(response);
  }

  Future<List<PartnerOwnerSuggestion>> searchOwners(String query,
      {int limit = 8}) async {
    final response = await http.get(
      _uri('/api/partners/owners/search', {'query': query, 'limit': '$limit'}),
      headers: await _headers(),
    );
    _ensureSuccess(response);
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) =>
            PartnerOwnerSuggestion.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> updatePreference({required bool allowRequests}) async {
    final response = await http.patch(
      _uri('/api/partners/preferences/allow-requests'),
      headers: await _headers(),
      body: jsonEncode({'allowRequests': allowRequests}),
    );
    _ensureSuccess(response);
  }

  Future<void> decideRequest({
    required int entryId,
    required String status,
    int? durationDays,
  }) async {
    final payload = <String, dynamic>{'status': status};
    if (durationDays != null) {
      payload['durationDays'] = durationDays;
    }
    final response = await http.patch(
      _uri('/api/partners/requests/$entryId'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    _ensureSuccess(response);
  }

  Future<List<SharedLogEntry>> fetchSharedLogs({required int ownerId}) async {
    final response = await http.get(
      _uri('/api/sugarlogs/shared/$ownerId'),
      headers: await _headers(),
    );
    _ensureSuccess(response);
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => SharedLogEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> applyForPartnerRole({
    required String expertise,
    required String motivation,
  }) async {
    final response = await http.post(
      _uri('/api/partners/applications'),
      headers: await _headers(),
      body: jsonEncode({
        'expertise': expertise,
        'motivation': motivation,
      }),
    );
    _ensureSuccess(response);
  }

  Future<List<PartnerApplicationRecord>> fetchApplications() async {
    final response = await http.get(
      _uri('/api/partners/applications'),
      headers: await _headers(),
    );
    _ensureSuccess(response);
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) =>
            PartnerApplicationRecord.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> reviewApplication({
    required int applicationId,
    required String status,
  }) async {
    final response = await http.patch(
      _uri('/api/partners/applications/$applicationId'),
      headers: await _headers(),
      body: jsonEncode({'status': status}),
    );
    _ensureSuccess(response);
  }

  Future<List<PartnerDirectoryEntry>> fetchDirectory() async {
    final response = await http.get(
      _uri('/api/partners/directory'),
      headers: await _headers(),
    );
    _ensureSuccess(response);
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map(
            (item) => PartnerDirectoryEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<PartnerAccessEntry>> assignmentsForModule(String module) async {
    final response = await http.get(
      _uri('/api/partners/assignments',
          {'view': 'granted', 'status': 'APPROVED'}),
      headers: await _headers(),
    );
    _ensureSuccess(response);
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => PartnerAccessEntry.fromJson(item as Map<String, dynamic>))
        .where((entry) => entry.module == module)
        .toList();
  }

  Future<List<PartnerAccessEntry>> incomingRequests({String? status}) async {
    final query = <String, String>{};
    if (status != null) query['status'] = status;
    final response = await http.get(
      _uri('/api/partners/requests/incoming', query),
      headers: await _headers(),
    );
    _ensureSuccess(response);
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => PartnerAccessEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    final message = response.body.isEmpty
        ? 'Request failed (${response.statusCode})'
        : response.body;
    throw Exception(message);
  }
}

class PartnerOverview {
  final bool allowRequests;
  final String? applicationStatus;
  final PartnerApplicationRecord? lastApplication;
  final List<PartnerAccessEntry> incoming;
  final List<PartnerAccessEntry> outgoing;
  final List<PartnerAccessEntry> assignments;

  const PartnerOverview({
    required this.allowRequests,
    required this.applicationStatus,
    required this.lastApplication,
    required this.incoming,
    required this.outgoing,
    required this.assignments,
  });

  factory PartnerOverview.fromJson(Map<String, dynamic> json) {
    return PartnerOverview(
      allowRequests: json['allowRequests'] as bool? ?? true,
      applicationStatus: json['applicationStatus'] as String?,
      lastApplication: json['lastApplication'] != null
          ? PartnerApplicationRecord.fromJson(
              json['lastApplication'] as Map<String, dynamic>)
          : null,
      incoming: (json['incoming'] as List<dynamic>? ?? const [])
          .map((e) => PartnerAccessEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      outgoing: (json['outgoing'] as List<dynamic>? ?? const [])
          .map((e) => PartnerAccessEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      assignments: (json['assignments'] as List<dynamic>? ?? const [])
          .map((e) => PartnerAccessEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PartnerAccessEntry {
  PartnerAccessEntry({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.ownerEmail,
    required this.partnerId,
    required this.partnerName,
    required this.partnerEmail,
    required this.module,
    required this.status,
    this.note,
    this.expiresAt,
  });

  final int id;
  final int? ownerId;
  final String ownerName;
  final String? ownerEmail;
  final int? partnerId;
  final String partnerName;
  final String? partnerEmail;
  final String module;
  final String status;
  final String? note;
  final String? expiresAt;

  factory PartnerAccessEntry.fromJson(Map<String, dynamic> json) {
    return PartnerAccessEntry(
      id: json['id'] as int? ?? 0,
      ownerId: json['ownerId'] as int?,
      ownerName: json['ownerName'] as String? ?? 'Owner',
      ownerEmail: json['ownerEmail'] as String?,
      partnerId: json['partnerId'] as int?,
      partnerName: json['partnerName'] as String? ?? 'Partner',
      partnerEmail: json['partnerEmail'] as String?,
      module: json['module'] as String? ?? 'SUGAR_LOGS',
      status: json['status'] as String? ?? 'PENDING',
      note: json['note'] as String?,
      expiresAt: json['expiresAt'] as String?,
    );
  }
}

class SharedLogEntry {
  SharedLogEntry({
    required this.id,
    required this.sugarGrams,
    required this.productName,
    required this.emotion,
    required this.visibility,
    required this.date,
  });

  final int id;
  final int sugarGrams;
  final String productName;
  final String emotion;
  final String visibility;
  final DateTime date;

  factory SharedLogEntry.fromJson(Map<String, dynamic> json) {
    return SharedLogEntry(
      id: json['id'] as int? ?? 0,
      sugarGrams: json['sugarGrams'] as int? ?? 0,
      productName: json['productName'] as String? ?? 'Entry',
      emotion: json['emotion'] as String? ?? 'NEUTRAL',
      visibility: json['visibility'] as String? ?? 'PRIVATE',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class PartnerOwnerSuggestion {
  const PartnerOwnerSuggestion({
    required this.id,
    required this.email,
    required this.displayName,
  });

  final int id;
  final String email;
  final String displayName;

  factory PartnerOwnerSuggestion.fromJson(Map<String, dynamic> json) {
    return PartnerOwnerSuggestion(
      id: json['id'] as int? ?? -1,
      email: json['email'] as String? ?? '',
      displayName: json['fullName'] as String? ?? json['email'] as String? ?? '',
    );
  }
}

class PartnerApplicationRecord {
  PartnerApplicationRecord({
    required this.id,
    required this.email,
    required this.displayName,
    required this.expertise,
    required this.motivation,
    required this.submittedAt,
    required this.status,
  });

  final int id;
  final String email;
  final String displayName;
  final String expertise;
  final String motivation;
  final DateTime submittedAt;
  final String status;

  factory PartnerApplicationRecord.fromJson(Map<String, dynamic> json) {
    return PartnerApplicationRecord(
      id: json['id'] as int? ?? -1,
      email: json['applicantEmail'] as String? ?? '',
      displayName: json['applicantName'] as String? ?? '',
      expertise: json['expertise'] as String? ?? '',
      motivation: json['motivation'] as String? ?? '',
      submittedAt: DateTime.tryParse(json['submittedAt'] as String? ?? '') ??
          DateTime.now(),
      status: json['status'] as String? ?? 'PENDING',
    );
  }
}

class PartnerDirectoryEntry {
  PartnerDirectoryEntry({
    required this.email,
    required this.displayName,
    required this.allowRequests,
    required this.isPartner,
  });

  final String email;
  final String displayName;
  final bool allowRequests;
  final bool isPartner;

  factory PartnerDirectoryEntry.fromJson(Map<String, dynamic> json) {
    return PartnerDirectoryEntry(
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      allowRequests: json['allowRequests'] as bool? ?? true,
      isPartner: json['partner'] as bool? ?? false,
    );
  }
}
