import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// StaffPro → integration bridge client (POS data + employee provisioning).
class BridgeApiClient {
  BridgeApiClient({
    String? baseUrl,
    http.Client? httpClient,
    FirebaseAuth? auth,
  })  : baseUrl = (baseUrl ?? const String.fromEnvironment(
          'BRIDGE_API_BASE',
          defaultValue: 'http://127.0.0.1:3080/api/v1',
        )).replaceAll(RegExp(r'/$'), ''),
        _http = httpClient ?? http.Client(),
        _auth = auth ?? FirebaseAuth.instance;

  final String baseUrl;
  final http.Client _http;
  final FirebaseAuth _auth;

  bool get isConfigured => baseUrl.isNotEmpty;

  Future<Map<String, String>> _headers({String? businessId}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in is required for bridge API calls.');
    }
    final token = await user.getIdToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      if (businessId != null && businessId.isNotEmpty) 'x-business-id': businessId,
    };
  }

  Future<Map<String, dynamic>?> getSession() async {
    try {
      return await _get('/auth/session');
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getDashboard({String? businessId, String? branchId}) async {
    try {
      final query = branchId == null || branchId.isEmpty ? '' : '?branchId=$branchId';
      return await _get('/dashboard$query', businessId: businessId);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getSalesReport({
    String? businessId,
    String? branchId,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final params = <String, String>{};
      if (branchId != null && branchId.isNotEmpty) params['branchId'] = branchId;
      if (from != null) params['from'] = from.toUtc().toIso8601String();
      if (to != null) params['to'] = to.toUtc().toIso8601String();
      final query = params.isEmpty
          ? ''
          : '?${params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
      return await _get('/reports/sales$query', businessId: businessId);
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertEmployee({
    required String email,
    required String displayName,
    required String staffproRole,
    String? password,
    String? phone,
    String? employeeCode,
    String? staffproFirebaseUid,
    String? staffproBusinessId,
    String? staffproBranchId,
    bool posAccess = true,
    String status = 'active',
  }) async {
    await _post('/employees', {
      'email': email.trim().toLowerCase(),
      'displayName': displayName,
      if (password != null && password.isNotEmpty) 'password': password,
      'staffproRole': staffproRole,
      if (phone != null) 'phone': phone,
      if (employeeCode != null) 'employeeCode': employeeCode,
      if (staffproFirebaseUid != null) 'staffproFirebaseUid': staffproFirebaseUid,
      if (staffproBusinessId != null) 'staffproBusinessId': staffproBusinessId,
      if (staffproBranchId != null) 'staffproBranchId': staffproBranchId,
      'posAccess': posAccess,
      'status': status,
    });
  }

  Future<Map<String, dynamic>> _get(String path, {String? businessId}) async {
    final response = await _http.get(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(businessId: businessId),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final response = await _http.post(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw StateError('Unexpected bridge response.');
    }
    final map = Map<String, dynamic>.from(decoded);
    if (response.statusCode >= 400 || map['success'] == false) {
      final error = map['error'];
      final message = error is Map ? error['message']?.toString() : null;
      throw StateError(message ?? 'Bridge request failed (${response.statusCode}).');
    }
    final data = map['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is List) return {'items': data};
    return map;
  }
}
