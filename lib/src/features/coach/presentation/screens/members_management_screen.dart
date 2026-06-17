import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../user/models/user_model.dart';
import '../../data/coach_repository.dart';

class MembersManagementScreen extends ConsumerStatefulWidget {
  const MembersManagementScreen({super.key});

  @override
  ConsumerState<MembersManagementScreen> createState() =>
      _MembersManagementScreenState();
}

class _MembersManagementScreenState
    extends ConsumerState<MembersManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(coachMembersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1C1C1E),
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'coach_members'.tr(context),
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1C1C1E),
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.person_add_alt_1_rounded,
              color: Color(0xFF007AFF),
            ),
            onPressed: () => _showAddPlayerModal(context),
          ),
          SizedBox(width: 2.w),
        ],
      ),
      body: membersAsync.when(
        data: (members) {
          if (members.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.group_outlined,
                    size: 40.sp,
                    color: const Color(0xFFC7C7CC),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'coach_no_members_yet'.tr(context),
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF8E8E93),
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    'coach_tap_plus_to_add'.tr(context),
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: const Color(0xFFC7C7CC),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(4.w),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              return _buildMemberCard(member, context);
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF1C1C1E)),
        ),
        error: (err, stack) =>
            Center(child: Text('${'error_prefix'.tr(context)}$err')),
      ),
    );
  }

  Widget _buildMemberCard(UserModel member, BuildContext context) {
    final now = DateTime.now();
    final end = member.subscriptionEnd ?? now;
    final daysLeft = end.difference(now).inDays;
    final owes = member.amountRemaining ?? 0.0;

    // Status Colors
    Color statusColor = const Color(0xFF34C759); // Green by default
    String statusText =
        '${'coach_active_status'.tr(context)} ($daysLeft ${'coach_days'.tr(context)})';

    if (daysLeft < 0) {
      statusColor = const Color(0xFFE53935);
      statusText = 'coach_expired'.tr(context);
    } else if (daysLeft <= 3) {
      statusColor = const Color(0xFFFF9500);
      statusText =
          '${'coach_expiring_soon'.tr(context)} ($daysLeft ${'coach_days'.tr(context)})';
    }

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 3.w,
                    backgroundColor: statusColor,
                    child: Icon(Icons.person, size: 6.w, color: Colors.white),
                  ),
                  SizedBox(width: 2.w),
                  Text(
                    '${member.firstName} ${member.lastName}',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2.w),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 1.5.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${'coach_total'.tr(context)}: ${member.totalAmount} ${'coach_jd'.tr(context)}',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: const Color(0xFF6E6E73),
                    ),
                  ),
                  Text(
                    '${'coach_paid'.tr(context)}: ${member.amountPaid} ${'coach_jd'.tr(context)}',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: const Color(0xFF6E6E73),
                    ),
                  ),
                ],
              ),
              if (owes > 0)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 2.5.w,
                    vertical: 1.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2.w),
                  ),
                  child: Text(
                    '${'coach_owes'.tr(context)} $owes ${'coach_jd'.tr(context)}',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFE53935),
                    ),
                  ),
                )
              else
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 2.5.w,
                    vertical: 1.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34C759).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2.w),
                  ),
                  child: Text(
                    'coach_fully_paid'.tr(context),
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF34C759),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 1.5.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _sendAlert(
                    context,
                    member.uid,
                    'coach_payment_reminder'.tr(context),
                    '${'coach_pay_outstanding_balance'.tr(context)} $owes ${'coach_jd'.tr(context)}',
                    type: 'payment_reminder',
                  ),
                  icon: const Icon(Icons.payments_outlined, size: 22),
                  label: Text('coach_remind_pay'.tr(context)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1C1C1E),
                    side: const BorderSide(color: Color(0xFFE5E5EA)),
                  ),
                ),
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _sendAlert(
                    context,
                    member.uid,
                    'coach_subscription_alert'.tr(context),
                    'coach_sub_expiring_soon_renew'.tr(context),
                    type: 'subscription_alert',
                  ),
                  icon: const Icon(
                    Icons.notifications_active_outlined,
                    size: 22,
                  ),
                  label: Text('coach_alert_expire'.tr(context)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1C1C1E),
                    side: const BorderSide(color: Color(0xFFE5E5EA)),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showAddPlayerModal(context, member),
              icon: const Icon(Icons.edit_note_rounded, size: 22),
              label: Text('coach_edit_player'.tr(context)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF007AFF),
                side: const BorderSide(color: Color(0xFFE5E5EA)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendAlert(
    BuildContext context,
    String uid,
    String title,
    String body, {
    String type = 'general',
  }) async {
    try {
      await ref
          .read(coachRepositoryProvider)
          .sendAlert(uid, title, body, type: type);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('coach_alert_sent'.tr(context)),
            backgroundColor: const Color(0xFF34C759),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'error_prefix'.tr(context)}$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddPlayerModal(BuildContext context, [UserModel? player]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _AddPlayerForm(player: player),
      ),
    );
  }
}

class _AddPlayerForm extends ConsumerStatefulWidget {
  final UserModel? player;

  const _AddPlayerForm({this.player});

  @override
  ConsumerState<_AddPlayerForm> createState() => _AddPlayerFormState();
}

class _AddPlayerFormState extends ConsumerState<_AddPlayerForm> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController(text: 'Nexus2026!');
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _coachNameCtrl = TextEditingController();
  final _gymCodeCtrl = TextEditingController(text: '1001');
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _bodyFatCtrl = TextEditingController();
  final _muscleMassCtrl = TextEditingController();
  final _durationCtrl = TextEditingController(text: '1');
  final _planCtrl = TextEditingController(text: 'Standard');
  final _totalCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');
  final _paidCtrl = TextEditingController();
  DateTime? _birthDate;
  DateTime _startDate = DateTime.now();
  String _goal = 'build_muscle';
  String _gender = 'male';
  String _fitnessLevel = 'beginner';
  String _trainingMode = 'gym_only';
  String _paymentMethod = 'cash';
  bool _isLoading = false;
  bool _phoneChecking = false;
  bool _phoneVerified = false;
  bool _syncingPhoneText = false;
  bool _otpSent = false;
  bool _otpVerifying = false;
  String? _verificationId;
  int? _resendToken;
  Timer? _resendTimer;
  int _resendSeconds = 0;
  String? _phoneError;
  bool get _isEditing => widget.player != null;
  bool get _canRegister =>
      _firstNameCtrl.text.trim().isNotEmpty &&
      _emailCtrl.text.trim().isNotEmpty &&
      (_isEditing || _passwordCtrl.text.length >= 6) &&
      _phoneVerified &&
      _birthDate != null;

  @override
  void initState() {
    super.initState();
    final player = widget.player;
    _phoneCtrl.addListener(_resetPhoneVerification);
    if (player == null) return;

    _firstNameCtrl.text = player.firstName ?? '';
    _lastNameCtrl.text = player.lastName ?? '';
    _emailCtrl.text = player.email;
    _passwordCtrl.clear();
    _phoneCtrl.text = player.phone ?? '';
    _phoneVerified = _phoneCtrl.text.trim().isNotEmpty;
    _coachNameCtrl.text = player.assignedCoachName ?? '';
    _gymCodeCtrl.text = player.gymCode ?? player.gymId ?? '1001';
    _weightCtrl.text = _numberText(player.weight);
    _heightCtrl.text = _numberText(player.height);
    _bodyFatCtrl.text = _numberText(player.bodyFat);
    _muscleMassCtrl.text = _numberText(player.muscleMass);
    _birthDate = player.dateOfBirth;
    _startDate = player.subscriptionStart ?? DateTime.now();
    _durationCtrl.text = _durationMonths(player).toString();
    _planCtrl.text = player.subscriptionPlan ?? 'Standard';
    _totalCtrl.text = _numberText(player.totalAmount);
    _discountCtrl.text = _numberText(player.discountAmount);
    _paidCtrl.text = _numberText(player.amountPaid);
    _goal = _validValue(player.goal, const {
      'build_muscle',
      'lose_fat',
      'maintain',
      'get_fit',
    }, 'build_muscle');
    _gender = _validValue(player.gender, const {'male', 'female'}, 'male');
    _fitnessLevel = _validValue(player.fitnessLevel, const {
      'beginner',
      'intermediate',
      'advanced',
    }, 'beginner');
    _trainingMode = _validValue(player.trainingMode, const {
      'gym_only',
      'home_only',
      'hybrid',
    }, 'gym_only');
    _paymentMethod = _validValue(player.paymentMethod, const {
      'cash',
      'zain_cash',
      'cliq',
      'card',
      'bank_transfer',
    }, 'cash');
  }

  @override
  void dispose() {
    _phoneCtrl.removeListener(_resetPhoneVerification);
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _resendTimer?.cancel();
    _coachNameCtrl.dispose();
    _gymCodeCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _bodyFatCtrl.dispose();
    _muscleMassCtrl.dispose();
    _durationCtrl.dispose();
    _planCtrl.dispose();
    _totalCtrl.dispose();
    _discountCtrl.dispose();
    _paidCtrl.dispose();
    super.dispose();
  }

  void _resetPhoneVerification() {
    if (_syncingPhoneText) return;
    final playerPhone = widget.player?.phone ?? '';
    final isSamePhone =
        _phoneKey(_normalizePhone(_phoneCtrl.text)) ==
        _phoneKey(_normalizePhone(playerPhone));
    final shouldBeVerified =
        _isEditing && isSamePhone && playerPhone.isNotEmpty;
    if (_phoneVerified == shouldBeVerified && _phoneError == null) return;
    setState(() {
      _phoneVerified = shouldBeVerified;
      _phoneError = null;
      _otpSent = false;
      _verificationId = null;
      _resendToken = null;
      _otpCtrl.clear();
    });
  }

  String _normalizePhone(String raw) {
    final value = raw.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (value.startsWith('00962')) return '+962${value.substring(5)}';
    if (value.startsWith('+962')) return value;
    if (value.startsWith('962')) return '+$value';
    if (value.startsWith('0')) return '+962${value.substring(1)}';
    return '+962$value';
  }

  String _phoneKey(String normalized) =>
      normalized.replaceAll(RegExp(r'\D'), '');

  bool _isValidPhoneFormat(String raw) {
    final normalized = _normalizePhone(raw);
    return RegExp(r'^\+9627[789]\d{7}$').hasMatch(normalized);
  }

  void _startOtpCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendSeconds--;
        if (_resendSeconds <= 0) timer.cancel();
      });
    });
  }

  Future<bool> _ensurePhoneCanBeUsed(String normalized) async {
    final key = _phoneKey(normalized);
    final recoveryDoc = await FirebaseFirestore.instance
        .collection('accountRecovery')
        .doc(key)
        .get();
    final ownPhone = _phoneKey(_normalizePhone(widget.player?.phone ?? ''));
    return !recoveryDoc.exists || key == ownPhone;
  }

  Future<void> _sendPhoneOtp({bool isResend = false}) async {
    final raw = _phoneCtrl.text.trim();
    if (!_isValidPhoneFormat(raw)) {
      setState(() => _phoneError = 'phone_invalid_format'.tr(context));
      return;
    }

    setState(() {
      _phoneChecking = true;
      _phoneVerified = false;
      _phoneError = null;
    });

    try {
      final normalized = _normalizePhone(raw);
      final canUsePhone = await _ensurePhoneCanBeUsed(normalized);

      if (!mounted) return;
      if (!canUsePhone) {
        setState(() {
          _phoneChecking = false;
          _phoneError = 'phone_already_registered'.tr(context);
        });
        return;
      }

      _syncingPhoneText = true;
      _phoneCtrl.text = normalized;
      _syncingPhoneText = false;

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: normalized,
        forceResendingToken: isResend ? _resendToken : null,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          await _verifyPhoneCredential(credential);
        },
        verificationFailed: (e) {
          if (!mounted) return;
          setState(() {
            _phoneChecking = false;
            _phoneError = _phoneAuthError(e);
          });
        },
        codeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _otpSent = true;
            _phoneChecking = false;
            _phoneError = null;
          });
          _startOtpCountdown();
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phoneChecking = false;
        _phoneError = '${'error_prefix'.tr(context)}$e';
      });
    }
  }

  Future<void> _verifyOtpCode() async {
    final verificationId = _verificationId;
    final code = _otpCtrl.text.trim();
    if (verificationId == null || code.length < 4) {
      setState(() => _phoneError = 'otp_code_required'.tr(context));
      return;
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: code,
    );
    await _verifyPhoneCredential(credential);
  }

  Future<void> _verifyPhoneCredential(PhoneAuthCredential credential) async {
    setState(() {
      _otpVerifying = true;
      _phoneError = null;
    });

    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await Firebase.initializeApp(
        name: 'PhoneVerifyApp_${DateTime.now().microsecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      await secondaryAuth.signInWithCredential(credential);
      await secondaryAuth.signOut();

      if (!mounted) return;
      setState(() {
        _otpVerifying = false;
        _phoneChecking = false;
        _phoneVerified = true;
        _phoneError = null;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _otpVerifying = false;
        _phoneVerified = false;
        _phoneError = _phoneAuthError(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _otpVerifying = false;
        _phoneVerified = false;
        _phoneError = '${'error_prefix'.tr(context)}$e';
      });
    } finally {
      await secondaryApp?.delete();
    }
  }

  String _phoneAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return 'otp_invalid_code'.tr(context);
      case 'session-expired':
        return 'otp_session_expired'.tr(context);
      case 'too-many-requests':
        return 'otp_too_many_requests'.tr(context);
      case 'invalid-phone-number':
        return 'phone_invalid_format'.tr(context);
      default:
        return e.message ?? '${'error_prefix'.tr(context)}${e.code}';
    }
  }

  void _submit(BuildContext context) async {
    final weight = double.tryParse(_weightCtrl.text.trim());
    final height = double.tryParse(_heightCtrl.text.trim());
    final bodyFat = double.tryParse(_bodyFatCtrl.text.trim());
    final muscleMass = double.tryParse(_muscleMassCtrl.text.trim());
    final durationMonths = int.tryParse(_durationCtrl.text.trim());
    final totalAmount = double.tryParse(_totalCtrl.text.trim()) ?? 0.0;
    final discountAmount = double.tryParse(_discountCtrl.text.trim()) ?? 0.0;
    final amountPaid = double.tryParse(_paidCtrl.text.trim()) ?? 0.0;

    if (_firstNameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        (!_isEditing && _passwordCtrl.text.length < 6) ||
        !_phoneVerified ||
        _birthDate == null ||
        weight == null ||
        weight <= 0 ||
        height == null ||
        height <= 0 ||
        bodyFat == null ||
        bodyFat <= 0 ||
        muscleMass == null ||
        muscleMass <= 0 ||
        durationMonths == null ||
        durationMonths <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('coach_please_fill_required'.tr(context))),
      );
      return;
    }

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final errorPrefix = 'error_prefix'.tr(context);
    setState(() => _isLoading = true);
    try {
      final successMessage = _isEditing
          ? 'coach_player_updated'.tr(context)
          : '${'coach_player_registered_login'.tr(context)} ${_emailCtrl.text.trim()} / ${_passwordCtrl.text}';
      final input = AddPlayerInput(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _isEditing ? 'unchanged-password' : _passwordCtrl.text,
        phone: _normalizePhone(_phoneCtrl.text),
        dateOfBirth: _birthDate!,
        assignedCoachName: _coachNameCtrl.text.trim(),
        weight: weight,
        height: height,
        bodyFat: bodyFat,
        muscleMass: muscleMass,
        goal: _goal,
        gender: _gender,
        fitnessLevel: _fitnessLevel,
        trainingMode: _trainingMode,
        subscriptionPlan: _planCtrl.text.trim().isEmpty
            ? 'Standard'
            : _planCtrl.text.trim(),
        subscriptionStart: _startDate,
        durationMonths: durationMonths,
        totalAmount: totalAmount,
        discountAmount: discountAmount,
        amountPaid: amountPaid,
        paymentMethod: _paymentMethod,
        gymCode: _gymCodeCtrl.text.trim(),
      );
      if (_isEditing) {
        await ref
            .read(coachRepositoryProvider)
            .updatePlayer(playerUid: widget.player!.uid, input: input);
      } else {
        await ref.read(coachRepositoryProvider).addPlayer(input);
      }
      if (mounted) {
        navigator.pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: const Color(0xFF34C759),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('$errorPrefix$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lightTextTheme = ThemeData.light().textTheme.apply(
      bodyColor: const Color(0xFF1C1C1E),
      displayColor: const Color(0xFF1C1C1E),
    );
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.light,
        textTheme: lightTextTheme,
        inputDecorationTheme: const InputDecorationTheme(),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(5.w, 1.5.h, 5.w, 2.h),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF5F5F7),
                      fixedSize: Size(10.w, 10.w),
                    ),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Text(
                      _isEditing
                          ? 'coach_edit_player'.tr(context)
                          : 'coach_register_new_player'.tr(context),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  SizedBox(width: 10.w, height: 10.w),
                ],
              ),
              SizedBox(height: 2.h),
              _section('coach_account'.tr(context)),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _firstNameCtrl,
                      decoration: _inputDec('coach_first_name_req'.tr(context)),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: TextField(
                      controller: _lastNameCtrl,
                      decoration: _inputDec('coach_last_name'.tr(context)),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 1.2.h),
              TextField(
                controller: _emailCtrl,
                decoration: _inputDec(
                  _isEditing
                      ? 'coach_login_email_no_change'.tr(context)
                      : 'coach_email_req'.tr(context),
                ),
                enabled: !_isEditing,
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 1.2.h),
              if (!_isEditing) ...[
                TextField(
                  controller: _passwordCtrl,
                  decoration: _inputDec('coach_login_password_req'.tr(context)),
                ),
                SizedBox(height: 1.2.h),
              ],
              TextField(
                controller: _phoneCtrl,
                style: _fieldStyle(),
                decoration: _inputDec('coach_phone_req'.tr(context)).copyWith(
                  suffixIcon: _phoneVerified
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF34C759),
                        )
                      : null,
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 1.h),
              _buildPhoneOtpSection(),
              SizedBox(height: 1.2.h),
              _dateTile(
                label: 'coach_birth_date_req'.tr(context),
                value: _birthDate,
                onPick: (date) => setState(() => _birthDate = date),
              ),
              SizedBox(height: 2.h),
              _section('coach_responsible_coach'.tr(context)),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _coachNameCtrl,
                      decoration: _inputDec(
                        'coach_coach_name_resp_person'.tr(context),
                      ),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: TextField(
                      controller: _gymCodeCtrl,
                      decoration: _inputDec('coach_gym_code_req'.tr(context)),
                      keyboardType: TextInputType.text,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2.h),
              _section('coach_body_metrics'.tr(context)),
              Row(
                children: [
                  Expanded(
                    child: _numberField(
                      _weightCtrl,
                      'coach_weight_kg_req'.tr(context),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: _numberField(
                      _heightCtrl,
                      'coach_height_cm_req'.tr(context),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 1.2.h),
              Row(
                children: [
                  Expanded(
                    child: _numberField(
                      _bodyFatCtrl,
                      'coach_body_fat_req'.tr(context),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: _numberField(
                      _muscleMassCtrl,
                      'coach_muscle_kg_req'.tr(context),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2.h),
              _section('coach_goal_training'.tr(context)),
              Row(
                children: [
                  Expanded(
                    child: _dropdown(
                      'coach_goal'.tr(context),
                      _goal,
                      {
                        'build_muscle': 'coach_build_muscle'.tr(context),
                        'lose_fat': 'coach_lose_fat'.tr(context),
                        'maintain': 'coach_maintain'.tr(context),
                        'get_fit': 'coach_get_fit'.tr(context),
                      },
                      (value) => setState(() => _goal = value),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: _dropdown(
                      'coach_gender'.tr(context),
                      _gender,
                      {
                        'male': 'coach_male'.tr(context),
                        'female': 'coach_female'.tr(context),
                      },
                      (value) => setState(() => _gender = value),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 1.2.h),
              Row(
                children: [
                  Expanded(
                    child: _dropdown(
                      'coach_level'.tr(context),
                      _fitnessLevel,
                      {
                        'beginner': 'coach_beginner'.tr(context),
                        'intermediate': 'coach_intermediate'.tr(context),
                        'advanced': 'coach_advanced'.tr(context),
                      },
                      (value) => setState(() => _fitnessLevel = value),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: _dropdown(
                      'coach_training_mode'.tr(context),
                      _trainingMode,
                      {
                        'gym_only': 'coach_gym_only'.tr(context),
                        'home_only': 'coach_home_only'.tr(context),
                        'hybrid': 'coach_hybrid'.tr(context),
                      },
                      (value) => setState(() => _trainingMode = value),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2.h),
              _section('coach_subscription_payment'.tr(context)),
              TextField(
                controller: _planCtrl,
                decoration: _inputDec('coach_subscription_plan'.tr(context)),
              ),
              SizedBox(height: 1.2.h),
              _dateTile(
                label: 'coach_start_date'.tr(context),
                value: _startDate,
                onPick: (date) => setState(() => _startDate = date),
              ),
              SizedBox(height: 1.2.h),
              Row(
                children: [
                  Expanded(
                    child: _numberField(
                      _durationCtrl,
                      'coach_duration_months_req'.tr(context),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: _numberField(
                      _totalCtrl,
                      'coach_total_amount'.tr(context),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 1.2.h),
              Row(
                children: [
                  Expanded(
                    child: _numberField(
                      _discountCtrl,
                      'coach_discount'.tr(context),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: _numberField(
                      _paidCtrl,
                      'coach_paid_now'.tr(context),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 1.2.h),
              _dropdown(
                'coach_payment_method'.tr(context),
                _paymentMethod,
                {
                  'cash': 'coach_cash'.tr(context),
                  'zain_cash': 'coach_zain_cash'.tr(context),
                  'cliq': 'coach_cliq'.tr(context),
                  'card': 'coach_card'.tr(context),
                  'bank_transfer': 'coach_bank_transfer'.tr(context),
                },
                (value) => setState(() => _paymentMethod = value),
              ),
              SizedBox(height: 3.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading || !_canRegister
                      ? null
                      : () => _submit(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C1C1E),
                    padding: EdgeInsets.symmetric(vertical: 2.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3.w),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 4.w,
                          height: 4.w,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _isEditing
                              ? 'coach_save_player'.tr(context)
                              : 'coach_register_player'.tr(context),
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.h),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF8E8E93),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildPhoneOtpSection() {
    if (_phoneVerified) {
      return Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF34C759)),
          SizedBox(width: 2.w),
          Expanded(
            child: Text(
              _normalizePhone(_phoneCtrl.text),
              style: TextStyle(
                color: const Color(0xFF1C1C1E),
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(
            onPressed: () => setState(() {
              _phoneVerified = false;
              _otpSent = false;
              _verificationId = null;
              _otpCtrl.clear();
            }),
            child: Text('change'.tr(context)),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _phoneChecking || _resendSeconds > 0
                ? null
                : () => _sendPhoneOtp(isResend: _otpSent),
            icon: _phoneChecking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(
              _otpSent
                  ? (_resendSeconds > 0
                        ? '${'resend_otp_after'.tr(context)} $_resendSeconds'
                        : 'resend_otp'.tr(context))
                  : 'send_otp_verify_phone'.tr(context),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF007AFF),
              side: const BorderSide(color: Color(0xFF007AFF), width: 1.3),
              padding: EdgeInsets.symmetric(vertical: 1.6.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3.w),
              ),
            ),
          ),
        ),
        if (_otpSent) ...[
          SizedBox(height: 1.h),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  style: _fieldStyle(),
                  decoration: _inputDec('otp_code'.tr(context)),
                ),
              ),
              SizedBox(width: 2.w),
              ElevatedButton(
                onPressed: _otpVerifying ? null : _verifyOtpCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1C1C1E),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: 4.w,
                    vertical: 1.55.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3.w),
                  ),
                ),
                child: _otpVerifying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text('verify'.tr(context)),
              ),
            ],
          ),
        ],
        if (_phoneError != null) ...[
          SizedBox(height: 0.8.h),
          Text(
            _phoneError!,
            style: TextStyle(
              color: const Color(0xFFFF3B30),
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  Widget _numberField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      decoration: _inputDec(hint),
      style: _fieldStyle(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    Map<String, String> options,
    ValueChanged<String> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: _inputDec(label),
      style: _fieldStyle(),
      dropdownColor: Colors.white,
      items: options.entries
          .map(
            (entry) => DropdownMenuItem(
              value: entry.key,
              child: Text(
                entry.value,
                style: _fieldStyle(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      selectedItemBuilder: (context) => options.values
          .map(
            (label) => Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                label,
                style: _fieldStyle(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }

  Widget _dateTile({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime> onPick,
  }) {
    return InkWell(
      onTap: () async {
        final selected = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(1940),
          lastDate: DateTime(DateTime.now().year + 10),
        );
        if (selected != null) onPick(selected);
      },
      child: InputDecorator(
        decoration: _inputDec(label),
        child: Text(
          value == null ? 'coach_select_date'.tr(context) : _dateText(value),
          style: TextStyle(fontSize: 14.sp, color: const Color(0xFF1C1C1E)),
        ),
      ),
    );
  }

  String _dateText(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _numberText(num? value) {
    if (value == null) return '';
    if (value == 0) return '';
    if (value % 1 == 0) return value.toInt().toString();
    return value.toString();
  }

  int _durationMonths(UserModel player) {
    final start = player.subscriptionStart;
    final end = player.subscriptionEnd;
    if (start == null || end == null || !end.isAfter(start)) return 1;
    final months = (end.year - start.year) * 12 + end.month - start.month;
    return months <= 0 ? 1 : months;
  }

  String _validValue(String? value, Set<String> values, String fallback) {
    if (value != null && values.contains(value)) return value;
    return fallback;
  }

  TextStyle _fieldStyle() {
    return TextStyle(
      color: const Color(0xFF1C1C1E),
      fontSize: 14.sp,
      fontWeight: FontWeight.w700,
    );
  }

  InputDecoration _inputDec(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: const Color(0xFF8E8E93),
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3.w),
        borderSide: const BorderSide(color: Color(0xFFBBBBC0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3.w),
        borderSide: const BorderSide(color: Color(0xFFBBBBC0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3.w),
        borderSide: const BorderSide(color: Color(0xFF007AFF), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3.w),
        borderSide: const BorderSide(color: Color(0xFFFF3B30)),
      ),
    );
  }
}
