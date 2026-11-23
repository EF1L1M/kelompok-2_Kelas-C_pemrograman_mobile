import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

// ============================================================================
// CODE SHOWCASE & TRACEABILITY SCREEN (BUKTI DEMO / RESPONSI 6 SYARAT MINIMUM)
// Memudahkan Anggota 1, Anggota 2, dan Anggota 3 menunjukkan lokasi file dan
// cuplikan kode saat sesi responsi di depan dosen pengampu (BO-05 & Tabel 1.3).
// ============================================================================

class CodeShowcaseScreen extends StatelessWidget {
  const CodeShowcaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bukti Kode & 6 Syarat Minimum'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _ShowcaseSectionCard(
            memberBadge: 'Anggota 1 · Lead Auth, RBAC & Group Management',
            title: '1. Auth Guard, RBAC & Firestore Security Rules',
            filePath:
                'lib/core/router/app_router.dart · firestore.rules · lib/core/utils/form_validator_mixin.dart',
            codeSnippet: '''
// 1. Sealed Class AuthState & Pattern Matching (Dart 3)
sealed class AuthState { const AuthState(); }
final class AuthAuthenticated extends AuthState { final AppUser user; ... }

// 2. Mixin Validasi Form & Custom AuthException
mixin FormValidatorMixin {
  String? validateEmail(String? value) { ... }
}

// 3. Firestore Security Rules (firestore.rules)
match /groups/{gid} {
  allow read: if request.auth != null && isMember(gid); // non-anggota ditolak
  match /bills/{bid}/participants/{debtorUid} {
    // Member hanya boleh unpaid -> pending; Creator boleh pending -> paid/rejected
  }
}''',
          ),
          SizedBox(height: 14),
          _ShowcaseSectionCard(
            memberBadge: 'Anggota 2 · Lead Open-Source API, OCR & Split Engine',
            title:
                '2. Sealed BillState, ApiResponse<T>, Extension Rupiah, Isolate & Higher-Order Function',
            filePath:
                'lib/core/utils/isolate_workers.dart · lib/core/extensions/format_extensions.dart · lib/features/split_bill/cubit/bill_split_cubit.dart',
            codeSnippet: '''
// 1. Extension RupiahFormatter on num (Rp 25.000)
extension CurrencyFormatter on num {
  String toRupiah({bool withPrefix = true}) { ... }
}

// 2. Generics & Sealed Class ApiResponse<T>
sealed class ApiResponse<T> { const ApiResponse(); }
final class ApiSuccess<T> extends ApiResponse<T> { final T data; ... }

// 3. Concurrency Isolate.run (Kompresi Citra & Parsing JSON OCR)
static Future<ParsedReceiptDraft> parseOcrJsonInIsolate(...) {
  return Isolate.run(() {
    final decoded = jsonDecode(rawJsonPayload);
    ...
  });
}

// 4. Higher-Order Function (.where, .fold, .map) & Selisih Rp0 (BR-01 & BR-03)
final double memberSubtotal = items
    .where((item) => item.assignedMemberUids.contains(member.uid))
    .fold<double>(0.0, (sum, item) => sum + (item.totalIdr(rate) / item.assignedMemberUids.length));''',
          ),
          SizedBox(height: 14),
          _ShowcaseSectionCard(
            memberBadge:
                'Anggota 3 · Lead Real-Time Settlement, Streams & Push Notifications',
            title:
                '3. StreamTransformer, async*/yield, Cloud Functions & FCM Local Notifications',
            filePath:
                'lib/repositories/bill_settlement_repository.dart · functions/index.js · lib/core/services/notification_service.dart',
            codeSnippet: '''
// 1. StreamTransformer & Generator async* / yield*
Stream<List<BillModel>> watchGroupBills(String groupId) async* {
  yield* rawStream().transform(_billSortTransformer);
}

// 2. Kalkulasi Saldo Bersih dari BILL_PARTICIPANTS (.where, .map, .fold)
final double youOwe = relevantBills
    .where((b) => b.creatorUid != userUid)
    .map((b) => _store.billParticipants[b.billId] ?? const [])
    .expand((list) => list)
    .where((p) => p.debtorUid == userUid && p.paymentStatus != PaymentStatus.paid)
    .fold<double>(0.0, (sum, p) => sum + p.totalDueIdr);''',
          ),
        ],
      ),
    );
  }
}

class _ShowcaseSectionCard extends StatelessWidget {
  final String memberBadge;
  final String title;
  final String filePath;
  final String codeSnippet;

  const _ShowcaseSectionCard({
    required this.memberBadge,
    required this.title,
    required this.filePath,
    required this.codeSnippet,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryEmerald.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                memberBadge,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryEmerald,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'File: $filePath',
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF64748B),
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                codeSnippet,
                style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontSize: 11.5,
                  fontFamily: 'monospace',
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
