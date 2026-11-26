import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/exceptions/auth_exception.dart';
import '../../../core/services/notification_service.dart';
import '../../../models/erd_models.dart';
import '../../../repositories/bill_settlement_repository.dart';
import '../../../repositories/group_repository.dart';

// ============================================================================
// GROUP CUBIT (REAL-TIME FIRESTORE STATE MANAGEMENT)
// Mengelola daftar grup pengguna, saldo utang/piutang lintas grup,
// daftar tagihan "Perlu Perhatian", notifikasi penerima real-time,
// pembuatan grup (invite_code unik BR-07), serta gabung grup via kode.
// ============================================================================

class GroupDashboardState {
  final List<GroupModel> groups;
  final List<BillModel> allBills;
  final UserBalanceSummary overallBalance;
  final Map<String, UserBalanceSummary> balanceByGroup;
  final List<ActionableBillItem> actionableBills;
  final int unreadNotifCount;
  final bool isLoading;
  final String? feedbackMessage;
  final bool isErrorFeedback;

  const GroupDashboardState({
    required this.groups,
    this.allBills = const [],
    required this.overallBalance,
    this.balanceByGroup = const {},
    this.actionableBills = const [],
    required this.unreadNotifCount,
    this.isLoading = false,
    this.feedbackMessage,
    this.isErrorFeedback = false,
  });

  UserBalanceSummary balanceForGroup(String groupId) =>
      balanceByGroup[groupId] ??
      const UserBalanceSummary(totalYouOweIdr: 0, totalOwedToYouIdr: 0);

  GroupDashboardState copyWith({
    List<GroupModel>? groups,
    List<BillModel>? allBills,
    UserBalanceSummary? overallBalance,
    Map<String, UserBalanceSummary>? balanceByGroup,
    List<ActionableBillItem>? actionableBills,
    int? unreadNotifCount,
    bool? isLoading,
    String? feedbackMessage,
    bool? isErrorFeedback,
  }) =>
      GroupDashboardState(
        groups: groups ?? this.groups,
        allBills: allBills ?? this.allBills,
        overallBalance: overallBalance ?? this.overallBalance,
        balanceByGroup: balanceByGroup ?? this.balanceByGroup,
        actionableBills: actionableBills ?? this.actionableBills,
        unreadNotifCount: unreadNotifCount ?? this.unreadNotifCount,
        isLoading: isLoading ?? this.isLoading,
        feedbackMessage: feedbackMessage,
        isErrorFeedback: isErrorFeedback ?? false,
      );
}

class GroupCubit extends Cubit<GroupDashboardState> {
  final GroupRepository _groupRepository;
  final BillSettlementRepository _settlementRepository;

  StreamSubscription<List<GroupModel>>? _groupsSub;
  StreamSubscription<List<BillModel>>? _billsSub;
  StreamSubscription<List<AppNotification>>? _notifSub;
  String? _activeUserUid;
  String _subscribedGroupIdsKey = '';
  List<GroupModel> _latestGroups = const [];
  final Set<String> _knownNotifIds = <String>{};
  bool _notifInitialLoaded = false;

  GroupCubit({
    required GroupRepository groupRepository,
    required BillSettlementRepository settlementRepository,
  })  : _groupRepository = groupRepository,
        _settlementRepository = settlementRepository,
        super(
          const GroupDashboardState(
            groups: [],
            overallBalance: UserBalanceSummary(
              totalYouOweIdr: 0,
              totalOwedToYouIdr: 0,
            ),
            unreadNotifCount: 0,
          ),
        );

  void bindUser(String? userUid) {
    if (_activeUserUid == userUid && _groupsSub != null) {
      return;
    }

    _groupsSub?.cancel();
    _billsSub?.cancel();
    _notifSub?.cancel();
    _groupsSub = null;
    _billsSub = null;
    _notifSub = null;
    _activeUserUid = userUid;
    _subscribedGroupIdsKey = '';
    _latestGroups = const [];
    _knownNotifIds.clear();
    _notifInitialLoaded = false;

    if (userUid == null) {
      emit(
        const GroupDashboardState(
          groups: [],
          overallBalance: UserBalanceSummary(
            totalYouOweIdr: 0,
            totalOwedToYouIdr: 0,
          ),
          unreadNotifCount: 0,
        ),
      );
      return;
    }

    _groupsSub = _groupRepository.watchUserGroups(userUid).listen((groups) {
      _latestGroups = groups;
      _recomputeAndEmit(
        userUid: userUid,
        groups: groups,
        bills: state.allBills,
      );

      final sortedIds = groups.map((g) => g.groupId).toList()..sort();
      final nextKey = sortedIds.join(',');
      if (nextKey != _subscribedGroupIdsKey) {
        _subscribedGroupIdsKey = nextKey;
        _billsSub?.cancel();
        _billsSub = _settlementRepository.watchBillsForGroups(groups).listen(
          (bills) {
            _recomputeAndEmit(
              userUid: userUid,
              groups: _latestGroups,
              bills: bills,
            );
          },
        );
      }
    });

    _notifSub = _settlementRepository
        .watchUserNotifications(userUid)
        .listen((notifications) {
      if (!_notifInitialLoaded) {
        _notifInitialLoaded = true;
        _knownNotifIds.addAll(notifications.map((n) => n.notifId));
      } else {
        // Hanya tampilkan push banner lokal di perangkat PENERIMA saat
        // dokumen notifikasi baru masuk dari Firestore
        for (final notif in notifications) {
          if (!notif.isRead && _knownNotifIds.add(notif.notifId)) {
            NotificationService.instance.showPushNotification(
              notifId: notif.notifId,
              title: 'BagiTigaKan · ${notif.type.label}',
              body: notif.message,
              groupId: notif.groupId,
              billId: notif.billId,
              type: notif.type.code,
            );
          }
        }
      }

      final unread = notifications.where((n) => !n.isRead).length;
      emit(state.copyWith(unreadNotifCount: unread));
    });
  }

  void _recomputeAndEmit({
    required String userUid,
    required List<GroupModel> groups,
    required List<BillModel> bills,
  }) {
    final validGroupIds = groups.map((g) => g.groupId).toSet();
    final scopedBills =
        bills.where((b) => validGroupIds.contains(b.groupId)).toList();

    final overallBalance = _settlementRepository.calculateUserBalanceFromBills(
      userUid: userUid,
      bills: scopedBills,
    );

    final Map<String, UserBalanceSummary> perGroup = {
      for (final g in groups)
        g.groupId: _settlementRepository.calculateUserBalanceFromBills(
          userUid: userUid,
          bills: scopedBills,
          groupIdFilter: g.groupId,
        ),
    };

    final actionable = _settlementRepository.buildActionableBills(
      userUid: userUid,
      groups: groups,
      bills: scopedBills,
    );

    emit(
      state.copyWith(
        groups: groups,
        allBills: scopedBills,
        overallBalance: overallBalance,
        balanceByGroup: perGroup,
        actionableBills: actionable,
      ),
    );
  }

  Future<GroupModel?> createGroup({
    required String groupName,
    required String description,
  }) async {
    final uid = _activeUserUid;
    if (uid == null) return null;

    emit(state.copyWith(isLoading: true));
    try {
      final created = await _groupRepository.createGroup(
        groupName: groupName,
        description: description,
        creatorUid: uid,
      );
      emit(
        state.copyWith(
          isLoading: false,
          feedbackMessage:
              'Grup "${created.groupName}" dibuat! Kode undangan unik: ${created.inviteCode}',
        ),
      );
      return created;
    } on AppAuthException catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          feedbackMessage: e.message,
          isErrorFeedback: true,
        ),
      );
      return null;
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          feedbackMessage: 'Gagal membuat grup: $e',
          isErrorFeedback: true,
        ),
      );
      return null;
    }
  }

  Future<GroupModel?> joinGroupByCode(String inviteCode) async {
    final uid = _activeUserUid;
    if (uid == null) return null;

    emit(state.copyWith(isLoading: true));
    try {
      final group = await _groupRepository.joinGroupByInviteCode(
        inviteCode: inviteCode,
        userUid: uid,
      );
      emit(
        state.copyWith(
          isLoading: false,
          feedbackMessage: 'Berhasil bergabung ke grup "${group.groupName}"!',
        ),
      );
      return group;
    } on AppAuthException catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          feedbackMessage: e.message,
          isErrorFeedback: true,
        ),
      );
      return null;
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          feedbackMessage: 'Gagal bergabung ke grup: $e',
          isErrorFeedback: true,
        ),
      );
      return null;
    }
  }

  @override
  Future<void> close() {
    _groupsSub?.cancel();
    _billsSub?.cancel();
    _notifSub?.cancel();
    return super.close();
  }
}
