import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/exceptions/auth_exception.dart';
import '../../../models/erd_models.dart';
import '../../../repositories/bill_settlement_repository.dart';
import '../../../repositories/group_repository.dart';

// ============================================================================
// GROUP CUBIT (STATE MANAGEMENT - ANGGOTA 1)
// Mengelola daftar grup pengguna, saldo utang/piutang lintas grup,
// pembuatan grup (transaksi invite_code unik BR-07), gabung grup,
// dan aksi otorisasi Group Admin (FR-02, Tabel 2.5, UFD-2).
// ============================================================================

class GroupDashboardState {
  final List<GroupModel> groups;
  final UserBalanceSummary overallBalance;
  final int unreadNotifCount;
  final bool isLoading;
  final String? feedbackMessage;
  final bool isErrorFeedback;

  const GroupDashboardState({
    required this.groups,
    required this.overallBalance,
    required this.unreadNotifCount,
    this.isLoading = false,
    this.feedbackMessage,
    this.isErrorFeedback = false,
  });

  GroupDashboardState copyWith({
    List<GroupModel>? groups,
    UserBalanceSummary? overallBalance,
    int? unreadNotifCount,
    bool? isLoading,
    String? feedbackMessage,
    bool? isErrorFeedback,
  }) =>
      GroupDashboardState(
        groups: groups ?? this.groups,
        overallBalance: overallBalance ?? this.overallBalance,
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
  StreamSubscription<List<AppNotification>>? _notifSub;
  String? _activeUserUid;

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
    _groupsSub?.cancel();
    _notifSub?.cancel();
    _activeUserUid = userUid;

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
      final balance = _settlementRepository.calculateUserBalance(userUid);
      emit(
        state.copyWith(
          groups: groups,
          overallBalance: balance,
        ),
      );
    });

    _notifSub = _settlementRepository
        .watchUserNotifications(userUid)
        .listen((notifications) {
      final unread = notifications.where((n) => !n.isRead).length;
      final balance = _settlementRepository.calculateUserBalance(userUid);
      emit(
        state.copyWith(
          unreadNotifCount: unread,
          overallBalance: balance,
        ),
      );
    });
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
    }
  }

  GroupRole? getRoleInGroup(String groupId, String userUid) =>
      _groupRepository.getUserRoleInGroup(groupId, userUid);

  @override
  Future<void> close() {
    _groupsSub?.cancel();
    _notifSub?.cancel();
    return super.close();
  }
}
