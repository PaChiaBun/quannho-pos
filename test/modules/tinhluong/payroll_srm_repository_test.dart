import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quannho_pos/modules/tinhluong/repository/payroll_srm_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  late MockSupabaseClient mockClient;
  int rpcCallCount = 0;
  int logSuccessCount = 0;
  dynamic lastRpcResult;
  Exception? rpcErrorToThrow;
  String? lastRpcName;
  Map<String, dynamic>? lastRpcParams;

  Map<String, String>? currentHeaders;

  Future<dynamic> mockRpcCall(String fn, Map<String, dynamic> params) async {
    rpcCallCount++;
    lastRpcName = fn;
    lastRpcParams = Map<String, dynamic>.from(params);
    if (rpcErrorToThrow != null) {
      throw rpcErrorToThrow!;
    }
    return lastRpcResult;
  }

  void mockLogSuccess(String action, Map<String, dynamic> details) {
    logSuccessCount++;
  }

  PayrollSrmRepository createRepo(Set<String> actions) {
    return PayrollSrmRepository(
      client: mockClient,
      storeId: 's1',
      userId: 'u1',
      effectiveActions: actions,
      rpcCall: mockRpcCall,
      logSuccess: mockLogSuccess,
      getHeaders: () => currentHeaders,
    );
  }

  setUp(() {
    mockClient = MockSupabaseClient();
    rpcCallCount = 0;
    logSuccessCount = 0;
    rpcErrorToThrow = null;
    lastRpcResult = null;
    lastRpcName = null;
    lastRpcParams = null;
    currentHeaders = {'x-store-id': 's1', 'x-user-id': 'u1'};
  });

  group('Models Parsing', () {
    test('JSON safe parsing for Maps and Strings', () {
      final map = {
        'metadata': '{"a": 1}',
        'before_data': {'b': 2},
      };

      final event1 = PayrollSrmPointEvent.fromMap(map);
      expect(event1.metadata['a'], 1);

      final audit1 = PayrollSrmAuditEvent.fromMap(map);
      expect(audit1.beforeData['b'], 2);
    });
  });

  group('RPC Methods with Transport Injection', () {
    test('deny without calling transport when permission is missing', () async {
      final repo = createRepo({});
      expect(
        () => repo.updateSettings(
          enableTam: true,
          enableTue: true,
          pointRules: {},
        ),
        throwsA(isA<PayrollSrmPermissionException>()),
      );
      expect(rpcCallCount, 0);
    });

    test(
      'deny without calling transport when context mismatch (headers wrong)',
      () async {
        final repo = createRepo({'tinhluong.srm_settings'});
        currentHeaders = {'x-store-id': 'wrong', 'x-user-id': 'u1'};

        expect(
          () => repo.updateSettings(
            enableTam: true,
            enableTue: true,
            pointRules: {},
          ),
          throwsA(isA<PayrollSrmContextException>()),
        );
        expect(rpcCallCount, 0);
      },
    );

    test('failure throws and logs 0 successes', () async {
      final repo = createRepo({'tinhluong.srm_settings'});
      rpcErrorToThrow = Exception('Network error');

      await expectLater(
        () => repo.updateSettings(
          enableTam: true,
          enableTue: true,
          pointRules: {},
        ),
        throwsA(isA<Exception>()),
      );
      expect(rpcCallCount, 1);
      expect(logSuccessCount, 0);
    });

    test('success returns mapped model and logs exactly 1 success', () async {
      final repo = createRepo({'tinhluong.srm_settings'});
      lastRpcResult = {
        'store_id': 's1',
        'enable_tam': true,
        'enable_tue': true,
        'point_rules': {},
      };

      final result = await repo.updateSettings(
        enableTam: true,
        enableTue: true,
        pointRules: {},
      );

      expect(result.enableTam, true);
      expect(rpcCallCount, 1);
      expect(logSuccessCount, 1);
      expect(lastRpcName, 'payroll_srm_update_settings');
      expect(lastRpcParams, {
        'p_enable_tam': true,
        'p_enable_tue': true,
        'p_point_rules': <String, dynamic>{},
      });
    });

    test('validation blocks invalid arguments before transport', () async {
      final repo = createRepo({'tinhluong.srm_review'});

      expect(
        () => repo.submitProposal(
          targetUserId: 'u2',
          dimension: 'invalid', // invalid
          proposalType: 'recognition',
          title: 'T1',
          description: 'D1',
          evidence: {},
          proposedPoints: 10,
          idempotencyKey: 'idem1',
        ),
        throwsA(isA<PayrollSrmValidationException>()),
      );
      expect(rpcCallCount, 0);
    });

    test('submit maps normalized payload and caller idempotency key', () async {
      final repo = createRepo({});
      lastRpcResult = {
        'id': 'p1',
        'store_id': 's1',
        'target_user_id': 'u2',
        'dimension': 'tam',
        'proposal_type': 'recognition',
        'title': 'Ghi nhận',
        'proposed_points': 5,
        'idempotency_key': 'idem-1',
      };

      final result = await repo.submitProposal(
        targetUserId: ' u2 ',
        dimension: ' TAM ',
        proposalType: ' Recognition ',
        title: ' Ghi nhận ',
        description: 'Hỗ trợ đồng đội',
        evidence: {'source': 'shift'},
        proposedPoints: 5,
        idempotencyKey: ' idem-1 ',
      );

      expect(result.id, 'p1');
      expect(lastRpcName, 'payroll_srm_submit_proposal');
      expect(lastRpcParams, {
        'p_target_user_id': 'u2',
        'p_dimension': 'tam',
        'p_proposal_type': 'recognition',
        'p_title': 'Ghi nhận',
        'p_description': 'Hỗ trợ đồng đội',
        'p_evidence': {'source': 'shift'},
        'p_proposed_points': 5,
        'p_idempotency_key': 'idem-1',
      });
      expect(logSuccessCount, 1);
    });

    test('review permission denial does not call transport', () async {
      final repo = createRepo({});

      expect(
        () => repo.reviewProposal(
          proposalId: 'p1',
          decision: 'approved',
          notes: 'Đồng ý',
        ),
        throwsA(isA<PayrollSrmPermissionException>()),
      );
      expect(rpcCallCount, 0);
      expect(logSuccessCount, 0);
    });
  });
}
