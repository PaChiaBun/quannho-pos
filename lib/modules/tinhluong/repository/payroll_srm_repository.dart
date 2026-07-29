import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/app_logger.dart';

class PayrollSrmPermissionException implements Exception {
  final String message;
  PayrollSrmPermissionException(this.message);
  @override
  String toString() => message;
}

class PayrollSrmValidationException implements Exception {
  final String message;
  PayrollSrmValidationException(this.message);
  @override
  String toString() => message;
}

class PayrollSrmContextException implements Exception {
  final String message;
  PayrollSrmContextException(this.message);
  @override
  String toString() => message;
}

Map<String, dynamic> _parseJsonMapSafe(dynamic value) {
  try {
    if (value is Map) {
      return Map<String, dynamic>.unmodifiable(
        value.map((key, item) => MapEntry(key.toString(), item)),
      );
    }
    if (value is String) {
      final parsed = jsonDecode(value);
      if (parsed is Map) {
        return Map<String, dynamic>.unmodifiable(
          parsed.map((key, item) => MapEntry(key.toString(), item)),
        );
      }
    }
  } catch (_) {
    // Malformed JSON is represented as an empty immutable object.
  }
  return const <String, dynamic>{};
}

DateTime? _parseDate(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

class PayrollSrmSettings {
  final String storeId;
  final bool enableTam;
  final bool enableTue;
  final Map<String, dynamic> pointRules;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PayrollSrmSettings({
    required this.storeId,
    required this.enableTam,
    required this.enableTue,
    required this.pointRules,
    this.createdAt,
    this.updatedAt,
  });

  factory PayrollSrmSettings.fromMap(Map<String, dynamic> map) {
    return PayrollSrmSettings(
      storeId: map['store_id']?.toString() ?? '',
      enableTam: map['enable_tam'] as bool? ?? false,
      enableTue: map['enable_tue'] as bool? ?? false,
      pointRules: _parseJsonMapSafe(map['point_rules']),
      createdAt: _parseDate(map['created_at']),
      updatedAt: _parseDate(map['updated_at']),
    );
  }
}

class PayrollSrmProposal {
  final String id;
  final String storeId;
  final String targetUserId;
  final String proposedByUserId;
  final String? reviewerUserId;
  final String dimension;
  final String proposalType;
  final String title;
  final String description;
  final Map<String, dynamic> evidence;
  final int proposedPoints;
  final String status;
  final String? reviewNotes;
  final String idempotencyKey;
  final DateTime? reviewedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PayrollSrmProposal({
    required this.id,
    required this.storeId,
    required this.targetUserId,
    required this.proposedByUserId,
    this.reviewerUserId,
    required this.dimension,
    required this.proposalType,
    required this.title,
    required this.description,
    required this.evidence,
    required this.proposedPoints,
    required this.status,
    this.reviewNotes,
    required this.idempotencyKey,
    this.reviewedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory PayrollSrmProposal.fromMap(Map<String, dynamic> map) {
    return PayrollSrmProposal(
      id: map['id']?.toString() ?? '',
      storeId: map['store_id']?.toString() ?? '',
      targetUserId: map['target_user_id']?.toString() ?? '',
      proposedByUserId: map['proposed_by_user_id']?.toString() ?? '',
      reviewerUserId: map['reviewer_user_id']?.toString(),
      dimension: map['dimension']?.toString() ?? '',
      proposalType: map['proposal_type']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      evidence: _parseJsonMapSafe(map['evidence']),
      proposedPoints: (map['proposed_points'] as num?)?.toInt() ?? 0,
      status: map['status']?.toString() ?? 'pending',
      reviewNotes: map['review_notes']?.toString(),
      idempotencyKey: map['idempotency_key']?.toString() ?? '',
      reviewedAt: _parseDate(map['reviewed_at']),
      createdAt: _parseDate(map['created_at']),
      updatedAt: _parseDate(map['updated_at']),
    );
  }
}

class PayrollSrmPointEvent {
  final String id;
  final String storeId;
  final String proposalId;
  final String targetUserId;
  final String dimension;
  final int points;
  final DateTime? occurredAt;
  final String createdByUserId;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;

  const PayrollSrmPointEvent({
    required this.id,
    required this.storeId,
    required this.proposalId,
    required this.targetUserId,
    required this.dimension,
    required this.points,
    this.occurredAt,
    required this.createdByUserId,
    required this.metadata,
    this.createdAt,
  });

  factory PayrollSrmPointEvent.fromMap(Map<String, dynamic> map) {
    return PayrollSrmPointEvent(
      id: map['id']?.toString() ?? '',
      storeId: map['store_id']?.toString() ?? '',
      proposalId: map['proposal_id']?.toString() ?? '',
      targetUserId: map['target_user_id']?.toString() ?? '',
      dimension: map['dimension']?.toString() ?? '',
      points: (map['points'] as num?)?.toInt() ?? 0,
      occurredAt: _parseDate(map['occurred_at']),
      createdByUserId: map['created_by_user_id']?.toString() ?? '',
      metadata: _parseJsonMapSafe(map['metadata']),
      createdAt: _parseDate(map['created_at']),
    );
  }
}

class PayrollSrmAuditEvent {
  final String id;
  final String storeId;
  final String? actorUserId; // nullable
  final String entityType;
  final String entityId;
  final String action;
  final Map<String, dynamic> beforeData;
  final Map<String, dynamic> afterData;
  final DateTime? createdAt;

  const PayrollSrmAuditEvent({
    required this.id,
    required this.storeId,
    this.actorUserId,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.beforeData,
    required this.afterData,
    this.createdAt,
  });

  factory PayrollSrmAuditEvent.fromMap(Map<String, dynamic> map) {
    return PayrollSrmAuditEvent(
      id: map['id']?.toString() ?? '',
      storeId: map['store_id']?.toString() ?? '',
      actorUserId: map['actor_user_id']?.toString(),
      entityType: map['entity_type']?.toString() ?? '',
      entityId: map['entity_id']?.toString() ?? '',
      action: map['action']?.toString() ?? '',
      beforeData: _parseJsonMapSafe(map['before_data']),
      afterData: _parseJsonMapSafe(map['after_data']),
      createdAt: _parseDate(map['created_at']),
    );
  }
}

typedef PayrollSrmRpcCall =
    Future<dynamic> Function(String fn, Map<String, dynamic> params);
typedef PayrollSrmLogger =
    void Function(String action, Map<String, dynamic> details);
typedef PayrollSrmHeaderReader = Map<String, String>? Function();

class PayrollSrmRepository {
  final SupabaseClient client;
  final String storeId;
  final String userId;
  final Set<String> effectiveActions;

  late final PayrollSrmRpcCall _rpcCall;
  late final PayrollSrmLogger _logSuccess;
  late final PayrollSrmHeaderReader _getHeaders;

  PayrollSrmRepository({
    required this.client,
    required String storeId,
    required String userId,
    required Set<String> effectiveActions,
    PayrollSrmRpcCall? rpcCall,
    PayrollSrmLogger? logSuccess,
    PayrollSrmHeaderReader? getHeaders,
  }) : storeId = storeId.trim(),
       userId = userId.trim(),
       effectiveActions = Set<String>.unmodifiable(effectiveActions) {
    if (this.storeId.isEmpty || this.userId.isEmpty) {
      throw ArgumentError('storeId and userId must not be empty');
    }
    _rpcCall =
        rpcCall ?? ((fn, params) async => await client.rpc(fn, params: params));
    _logSuccess =
        logSuccess ??
        ((action, details) => AppLogger.logUserAction(
          tag: 'payroll_srm',
          action: action,
          details: details,
        ));
    _getHeaders = getHeaders ?? (() => client.rest.headers);
  }

  void _checkPermission(String action) {
    if (!effectiveActions.contains(action)) {
      throw PayrollSrmPermissionException(
        'Permission denied: requires $action',
      );
    }
  }

  void _validateContext() {
    final headers = _getHeaders();
    if (headers == null) {
      throw PayrollSrmContextException('Headers are missing');
    }
    if (headers['x-store-id'] != storeId || headers['x-user-id'] != userId) {
      throw PayrollSrmContextException(
        'Context mismatch: Headers do not match initialized storeId and userId',
      );
    }
  }

  void _validateLimit(int limit) {
    if (limit < 1 || limit > 200) {
      throw ArgumentError('Limit must be between 1 and 200');
    }
  }

  String _requireId(String value, String fieldName) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw PayrollSrmValidationException('$fieldName cannot be empty');
    }
    return normalized;
  }

  // ── READ METHODS ────────────────────────────────────────────────────────────

  Future<PayrollSrmSettings?> fetchSettings() async {
    _validateContext();
    final res = await client
        .from('payroll_srm_settings')
        .select()
        .eq('store_id', storeId)
        .maybeSingle();
    if (res == null) {
      return null;
    }
    return PayrollSrmSettings.fromMap(res);
  }

  Future<List<PayrollSrmProposal>> fetchProposals({
    String? status,
    String? dimension,
    String? targetUserId,
    int limit = 100,
  }) async {
    _validateContext();
    _validateLimit(limit);
    var filter = client
        .from('payroll_srm_proposals')
        .select()
        .eq('store_id', storeId);

    if (status != null && status.isNotEmpty) {
      filter = filter.eq('status', status);
    }
    if (dimension != null && dimension.isNotEmpty) {
      filter = filter.eq('dimension', dimension);
    }
    if (targetUserId != null && targetUserId.isNotEmpty) {
      filter = filter.eq('target_user_id', targetUserId);
    }

    final res = await filter.order('created_at', ascending: false).limit(limit);
    return (res as List)
        .map((e) => PayrollSrmProposal.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<PayrollSrmPointEvent>> fetchPointEvents({
    String? targetUserId,
    int limit = 100,
  }) async {
    _validateContext();
    _validateLimit(limit);
    var filter = client
        .from('payroll_srm_point_events')
        .select()
        .eq('store_id', storeId);

    if (targetUserId != null && targetUserId.isNotEmpty) {
      filter = filter.eq('target_user_id', targetUserId);
    }

    final res = await filter
        .order('occurred_at', ascending: false)
        .limit(limit);
    return (res as List)
        .map((e) => PayrollSrmPointEvent.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<PayrollSrmAuditEvent>> fetchAuditEvents({
    String? entityType,
    String? entityId,
    int limit = 100,
  }) async {
    _validateContext();
    _validateLimit(limit);
    var filter = client
        .from('payroll_srm_audit_events')
        .select()
        .eq('store_id', storeId);

    if (entityType != null && entityType.isNotEmpty) {
      filter = filter.eq('entity_type', entityType);
    }
    if (entityId != null && entityId.isNotEmpty) {
      filter = filter.eq('entity_id', entityId);
    }

    final res = await filter.order('created_at', ascending: false).limit(limit);
    return (res as List)
        .map((e) => PayrollSrmAuditEvent.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // ── RPC MUTATION METHODS ───────────────────────────────────────────────────

  Future<PayrollSrmSettings> updateSettings({
    required bool enableTam,
    required bool enableTue,
    required Map<String, dynamic> pointRules,
  }) async {
    _checkPermission('tinhluong.srm_settings');
    _validateContext();

    final res = await _rpcCall('payroll_srm_update_settings', {
      'p_enable_tam': enableTam,
      'p_enable_tue': enableTue,
      'p_point_rules': pointRules,
    });

    final result = PayrollSrmSettings.fromMap(res as Map<String, dynamic>);
    _logSuccess('Updated recognition settings', {
      'enableTam': enableTam,
      'enableTue': enableTue,
    });
    return result;
  }

  Future<PayrollSrmProposal> submitProposal({
    required String targetUserId,
    required String dimension,
    required String proposalType,
    required String title,
    required String description,
    required Map<String, dynamic> evidence,
    required int proposedPoints,
    required String idempotencyKey,
  }) async {
    final target = _requireId(targetUserId, 'Target user ID');
    final dim = dimension.trim().toLowerCase();
    if (dim != 'tam' && dim != 'tue') {
      throw PayrollSrmValidationException('Invalid dimension');
    }
    final pType = proposalType.trim().toLowerCase();
    if (pType != 'recognition' &&
        pType != 'initiative' &&
        pType != 'coaching') {
      throw PayrollSrmValidationException('Invalid proposal type');
    }
    final t = title.trim();
    if (t.isEmpty) {
      throw PayrollSrmValidationException('Title cannot be empty');
    }
    final idem = idempotencyKey.trim();
    if (idem.isEmpty) {
      throw PayrollSrmValidationException('Idempotency key cannot be empty');
    }
    if (proposedPoints < 0) {
      throw PayrollSrmValidationException('Points must be >= 0');
    }

    _validateContext();

    final res = await _rpcCall('payroll_srm_submit_proposal', {
      'p_target_user_id': target,
      'p_dimension': dim,
      'p_proposal_type': pType,
      'p_title': t,
      'p_description': description,
      'p_evidence': evidence,
      'p_proposed_points': proposedPoints,
      'p_idempotency_key': idem,
    });

    final result = PayrollSrmProposal.fromMap(res as Map<String, dynamic>);
    _logSuccess('Submitted proposal', {
      'proposalId': result.id,
      'dimension': dim,
      'type': pType,
      'points': proposedPoints,
    });
    return result;
  }

  Future<PayrollSrmProposal> reviewProposal({
    required String proposalId,
    required String decision,
    required String notes,
  }) async {
    _checkPermission('tinhluong.srm_review');
    final proposal = _requireId(proposalId, 'Proposal ID');
    final d = decision.trim().toLowerCase();
    if (d != 'approved' && d != 'rejected') {
      throw PayrollSrmValidationException('Invalid decision');
    }
    _validateContext();

    final res = await _rpcCall('payroll_srm_review_proposal', {
      'p_proposal_id': proposal,
      'p_decision': d,
      'p_notes': notes,
    });

    final result = PayrollSrmProposal.fromMap(res as Map<String, dynamic>);
    _logSuccess('Reviewed proposal', {'proposalId': proposal, 'decision': d});
    return result;
  }

  Future<PayrollSrmProposal> cancelProposal({
    required String proposalId,
  }) async {
    final proposal = _requireId(proposalId, 'Proposal ID');
    _validateContext();

    final res = await _rpcCall('payroll_srm_cancel_proposal', {
      'p_proposal_id': proposal,
    });

    final result = PayrollSrmProposal.fromMap(res as Map<String, dynamic>);
    _logSuccess('Cancelled proposal', {'proposalId': proposal});
    return result;
  }
}
