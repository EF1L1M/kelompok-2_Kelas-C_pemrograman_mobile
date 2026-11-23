import 'package:flutter_test/flutter_test.dart';
import 'package:smart_split_bill/core/exceptions/auth_exception.dart';
import 'package:smart_split_bill/core/extensions/format_extensions.dart';
import 'package:smart_split_bill/features/split_bill/cubit/bill_split_cubit.dart';
import 'package:smart_split_bill/features/split_bill/cubit/bill_state.dart';
import 'package:smart_split_bill/models/erd_models.dart';
import 'package:smart_split_bill/repositories/bill_settlement_repository.dart';
import 'package:smart_split_bill/repositories/open_source_api_repository.dart';

void main() {
  group('Patungin Business Rules, Models & Auth Mapping Tests', () {
    test('Extension CurrencyFormatter memformat angka ke Rupiah (Rp 25.000)',
        () {
      expect(25000.toRupiah(), 'Rp 25.000');
      expect(1250500.toRupiah(), 'Rp 1.250.500');
    });

    test(
      'BR-01, BR-02 & BR-03: Kalkulasi proporsional menjamin selisih pembulatan Rp 0',
      () {
        final now = DateTime.now();
        final members = [
          AppUser(
            uid: 'u_andi',
            fullName: 'Andi Pratama',
            email: 'andi@example.com',
            photoUrl: '',
            createdAt: now,
          ),
          AppUser(
            uid: 'u_budi',
            fullName: 'Budi Santoso',
            email: 'budi@example.com',
            photoUrl: '',
            createdAt: now,
          ),
          AppUser(
            uid: 'u_citra',
            fullName: 'Citra Lestari',
            email: 'citra@example.com',
            photoUrl: '',
            createdAt: now,
          ),
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
      'Higher-Order Balance & Actionable Bills: hitung utang & piutang lintas grup',
      () {
        final now = DateTime.now();
        final repo = BillSettlementRepository();
        final group = GroupModel(
          groupId: 'g1',
          groupName: 'Grup Kos',
          inviteCode: 'KOS123',
          adminUid: 'u1',
          memberUids: const ['u1', 'u2'],
          createdAt: now,
        );

        final bill = BillModel(
          billId: 'b1',
          groupId: 'g1',
          creatorUid: 'u1',
          title: 'Makan Malam',
          currencyCode: 'IDR',
          exchangeRate: 1.0,
          rateDate: now,
          subtotalIdr: 100000,
          taxAmountIdr: 0,
          serviceAmountIdr: 0,
          discountAmountIdr: 0,
          grandTotalIdr: 100000,
          status: BillStatus.open,
          participantSummaries: const {
            'u1': BillParticipantSummary(
              debtorUid: 'u1',
              totalDueIdr: 50000,
              paymentStatus: PaymentStatus.paid,
            ),
            'u2': BillParticipantSummary(
              debtorUid: 'u2',
              totalDueIdr: 50000,
              paymentStatus: PaymentStatus.unpaid,
            ),
          },
          createdAt: now,
        );

        final creatorBal = repo.calculateUserBalanceFromBills(
          userUid: 'u1',
          bills: [bill],
        );
        expect(creatorBal.totalOwedToYouIdr, 50000);
        expect(creatorBal.totalYouOweIdr, 0);

        final debtorBal = repo.calculateUserBalanceFromBills(
          userUid: 'u2',
          bills: [bill],
        );
        expect(debtorBal.totalYouOweIdr, 50000);
        expect(debtorBal.totalOwedToYouIdr, 0);

        final actionable = repo.buildActionableBills(
          userUid: 'u2',
          groups: [group],
          bills: [bill],
        );
        expect(actionable.length, 1);
        expect(actionable.first.amountIdr, 50000);
      },
    );

    test('Firebase Auth error codes terpetakan ke pesan Bahasa Indonesia', () {
      expect(
        AppAuthException.fromFirebaseCode('email-already-in-use').message,
        contains('sudah terdaftar'),
      );
      expect(
        AppAuthException.fromFirebaseCode('invalid-credential').message,
        contains('salah'),
      );
      expect(
        AppAuthException.fromFirebaseCode('permission-denied').code,
        'permission-denied',
      );
    });
  });
}
