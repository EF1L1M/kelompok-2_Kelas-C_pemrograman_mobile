import 'package:flutter_test/flutter_test.dart';
import 'package:smart_split_bill/core/exceptions/auth_exception.dart';
import 'package:smart_split_bill/core/extensions/format_extensions.dart';
import 'package:smart_split_bill/features/split_bill/cubit/bill_split_cubit.dart';
import 'package:smart_split_bill/features/split_bill/cubit/bill_state.dart';
import 'package:smart_split_bill/repositories/bill_settlement_repository.dart';
import 'package:smart_split_bill/repositories/group_repository.dart';
import 'package:smart_split_bill/repositories/mock_realtime_database.dart';
import 'package:smart_split_bill/repositories/open_source_api_repository.dart';

void main() {
  group('Smart Split-Bill Business Rules & RBAC Verification Tests', () {
    test('Extension CurrencyFormatter memformat angka ke Rupiah (Rp 25.000)',
        () {
      expect(25000.toRupiah(), 'Rp 25.000');
      expect(1250500.toRupiah(), 'Rp 1.250.500');
    });

    test(
      'BR-01, BR-02 & BR-03: Kalkulasi proporsional menjamin selisih pembulatan Rp 0',
      () {
        final store = RealtimeDatabaseStore.instance;
        final members = [
          store.users['u_andi']!,
          store.users['u_budi']!,
          store.users['u_citra']!,
        ];

        final cubit = BillSplitCubit(
          apiRepository: OpenSourceApiRepository(),
          settlementRepository: BillSettlementRepository(),
        );

        cubit.initializeDraft(members: members);
        expect(cubit.state, isA<BillLoaded>());

        final loaded = cubit.state as BillLoaded;
        expect(loaded.roundingDifferenceIdr, 0.0);
        expect(loaded.sumOfParticipantTotalsIdr, loaded.grandTotalIdr);
      },
    );

    test(
      'RBAC Security Rules (FR-02 & FR-05): Non-anggota ditolak membaca grup & Debitur ditolak mengubah status ke paid sendiri',
      () async {
        final groupRepo = GroupRepository();
        final settlementRepo = BillSettlementRepository();

        // 1. Akun u_doni (Non-Anggota) mencoba membaca grup g_kos_melati -> harus ditolak!
        expect(
          () => groupRepo.getGroupGuarded(
            groupId: 'g_kos_melati',
            requesterUid: 'u_doni',
          ),
          throwsA(isA<AppAuthException>()),
        );

        // 2. Akun u_citra (Debitur) mencoba memverifikasi pembayarannya sendiri ke PAID -> harus ditolak!
        expect(
          () => settlementRepo.verifyOrRejectClaim(
            billId: 'bill_makan_jepang',
            requesterUid: 'u_citra',
            debtorUid: 'u_citra',
            isApproved: true,
          ),
          throwsA(isA<AppAuthException>()),
        );
      },
    );
  });
}
