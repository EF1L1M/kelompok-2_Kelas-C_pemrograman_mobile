import 'package:flutter_test/flutter_test.dart';
import 'package:smart_split_bill/core/exceptions/auth_exception.dart';
import 'package:smart_split_bill/core/extensions/format_extensions.dart';
import 'package:smart_split_bill/features/split_bill/cubit/bill_split_cubit.dart';
import 'package:smart_split_bill/features/split_bill/cubit/bill_state.dart';
import 'package:smart_split_bill/models/erd_models.dart';
import 'package:smart_split_bill/repositories/bill_settlement_repository.dart';
import 'package:smart_split_bill/repositories/open_source_api_repository.dart';

void main() {
  final now = DateTime(2026, 11, 20, 19, 30);
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

  group('BagiTigaKan Business Rules, Edge Cases & Auth Mapping Tests', () {
    test('Extension CurrencyFormatter memformat angka ke Rupiah (Rp 25.000)',
        () {
      expect(25000.toRupiah(), 'Rp 25.000');
      expect(1250500.toRupiah(), 'Rp 1.250.500');
    });

    test(
      'Draft baru mulai bersih (tanpa item fiktif) & BR-01..BR-03 menjamin selisih pembulatan Rp 0',
      () {
        final cubit = BillSplitCubit(
          apiRepository: OpenSourceApiRepository(),
          settlementRepository: BillSettlementRepository(),
        );

        cubit.initializeDraft(members: members);
        final initialLoaded = cubit.state as BillLoaded;
        expect(initialLoaded.items, isEmpty);
        expect(initialLoaded.allItemsAssigned, isFalse);

        // Tambahkan 2 menu dengan harga tidak habis dibagi 3 agar uji pembulatan Rp 0
        cubit.addDraftItem(name: 'Pizza Sharing', qty: 1, unitPriceOrigin: 100000);
        cubit.addDraftItem(name: 'Es Teh', qty: 2, unitPriceOrigin: 12500);
        cubit.updateHeaderAndCharges(
          title: 'Nongkrong Malam',
          taxOrigin: 12500,
          serviceOrigin: 6250,
          discountOrigin: 5000,
        );

        final loaded = cubit.state as BillLoaded;
        expect(loaded.allItemsAssigned, isTrue);
        expect(loaded.roundingDifferenceIdr, 0.0);
        expect(loaded.sumOfParticipantTotalsIdr, loaded.grandTotalIdr);
      },
    );

    test(
      'Diskon melebihi subtotal / input negatif tidak pernah menghasilkan nominal negatif',
      () {
        final cubit = BillSplitCubit(
          apiRepository: OpenSourceApiRepository(),
          settlementRepository: BillSettlementRepository(),
        );

        cubit.initializeDraft(members: members);
        cubit.addDraftItem(name: 'Kopi', qty: 1, unitPriceOrigin: 30000);
        cubit.updateHeaderAndCharges(
          taxOrigin: -5000,
          serviceOrigin: -2000,
          discountOrigin: 999999,
        );

        final loaded = cubit.state as BillLoaded;
        expect(loaded.taxIdr, 0.0);
        expect(loaded.serviceIdr, 0.0);
        expect(loaded.grandTotalIdr, 0.0);
        for (final split in loaded.computedSplits) {
          expect(split.totalDueIdr, greaterThanOrEqualTo(0.0));
        }
      },
    );

    test(
      'Item yang belum dipilih anggotanya tidak membebani peserta terbesar saat pratinjau',
      () {
        final cubit = BillSplitCubit(
          apiRepository: OpenSourceApiRepository(),
          settlementRepository: BillSettlementRepository(),
        );

        cubit.initializeDraft(members: members);
        cubit.addDraftItem(name: 'Nasi Goreng', qty: 1, unitPriceOrigin: 30000);
        cubit.addDraftItem(name: 'Steak Mahal', qty: 1, unitPriceOrigin: 300000);

        final loadedWithBoth = cubit.state as BillLoaded;
        final steakId = loadedWithBoth.items.last.id;

        // Hilangkan semua anggota dari Steak Mahal
        for (final m in members) {
          cubit.toggleMemberOnItem(itemId: steakId, memberUid: m.uid);
        }

        final afterUnassign = cubit.state as BillLoaded;
        expect(afterUnassign.allItemsAssigned, isFalse);
        // Total yang dibebankan ke peserta hanya Rp 30.000 (Nasi Goreng), bukan Rp 330.000!
        expect(afterUnassign.sumOfParticipantTotalsIdr, 30000.0);
      },
    );

    test(
      'Mode Edit mempertahankan status LUNAS peserta jika nominal bagiannya tidak bertambah',
      () {
        final cubit = BillSplitCubit(
          apiRepository: OpenSourceApiRepository(),
          settlementRepository: BillSettlementRepository(),
        );

        final existingBill = BillModel(
          billId: 'b_edit_1',
          groupId: 'g1',
          creatorUid: 'u_andi',
          title: 'Makan Siang',
          currencyCode: 'IDR',
          exchangeRate: 1.0,
          rateDate: now,
          subtotalIdr: 90000,
          taxAmountIdr: 0,
          serviceAmountIdr: 0,
          discountAmountIdr: 0,
          grandTotalIdr: 90000,
          status: BillStatus.open,
          createdAt: now,
        );

        const item = BillItemModel(
          itemId: 'i1',
          billId: 'b_edit_1',
          itemName: 'Paket Ayam',
          qty: 3,
          unitPrice: 30000,
          priceIdr: 90000,
        );

        final rich = RichBillDetail(
          bill: existingBill,
          creator: members[0],
          items: const [item],
          assignmentsByItem: {
            'i1': members
                .map(
                  (m) => ItemAssignmentModel(
                    assignmentId: 'a_${m.uid}',
                    itemId: 'i1',
                    debtorUid: m.uid,
                    shareIdr: 30000,
                  ),
                )
                .toList(),
          },
          participants: [
            ParticipantWithProfile(
              participant: BillParticipantModel(
                participantId: 'p_andi',
                billId: 'b_edit_1',
                debtorUid: 'u_andi',
                itemsSubtotalIdr: 30000,
                taxShareIdr: 0,
                serviceShareIdr: 0,
                discountShareIdr: 0,
                totalDueIdr: 30000,
                paymentStatus: PaymentStatus.paid,
                claimedAt: now,
                verifiedAt: now,
              ),
              user: members[0],
              assignedItems: const [],
            ),
            ParticipantWithProfile(
              participant: BillParticipantModel(
                participantId: 'p_budi',
                billId: 'b_edit_1',
                debtorUid: 'u_budi',
                itemsSubtotalIdr: 30000,
                taxShareIdr: 0,
                serviceShareIdr: 0,
                discountShareIdr: 0,
                totalDueIdr: 30000,
                paymentStatus: PaymentStatus.paid,
                claimedAt: now,
                verifiedAt: now,
              ),
              user: members[1],
              assignedItems: const [],
            ),
            ParticipantWithProfile(
              participant: const BillParticipantModel(
                participantId: 'p_citra',
                billId: 'b_edit_1',
                debtorUid: 'u_citra',
                itemsSubtotalIdr: 30000,
                taxShareIdr: 0,
                serviceShareIdr: 0,
                discountShareIdr: 0,
                totalDueIdr: 30000,
                paymentStatus: PaymentStatus.unpaid,
              ),
              user: members[2],
              assignedItems: const [],
            ),
          ],
        );

        cubit.initializeDraft(members: members, existingBill: rich);
        // Edit judul saja (nominal tetap Rp 30.000)
        cubit.updateHeaderAndCharges(title: 'Makan Siang Bareng');

        final loaded = cubit.state as BillLoaded;
        final builtParts = cubit.buildParticipantsForSubmit(
          current: loaded,
          billId: 'b_edit_1',
          creatorUid: 'u_andi',
          now: DateTime.now(),
          isEdit: true,
        );

        final budiPart = builtParts.firstWhere((p) => p.debtorUid == 'u_budi');
        final citraPart =
            builtParts.firstWhere((p) => p.debtorUid == 'u_citra');
        expect(budiPart.paymentStatus, PaymentStatus.paid);
        expect(citraPart.paymentStatus, PaymentStatus.unpaid);
      },
    );

    test(
      'Higher-Order Balance & Actionable Bills: hitung utang & piutang lintas grup',
      () {
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
