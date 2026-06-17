import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/providers/locale_provider.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../onboarding/controllers/firebase_storage_service.dart';
import '../../providers/body_metrics_provider.dart';
import '../../providers/profile_provider.dart';

class ProfileSettingsScreen extends ConsumerWidget {
  const ProfileSettingsScreen({super.key});

  static const _bg = Color(0xFFF5F5F7);
  static const _surface = Colors.white;
  static const _primary = Color(0xFF1C1C1E);
  static const _secondary = Color(0xFF8E8E93);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildMiniProfile(context, ref),
                    _buildSettingsList(context, ref),
                    SizedBox(height: 4.h),
                    Text(
                      'NEXUS v1.0.0',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: const Color(0xFFC7C7CC),
                      ),
                    ),
                    SizedBox(height: 6.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.8.w, vertical: 1.5.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: SizedBox(
              width: 8.w,
              height: 8.w,
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16.sp,
                color: _primary,
              ),
            ),
          ),
          Text(
            'settings_title'.tr(context),
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: _primary,
            ),
          ),
          SizedBox(width: 8.w),
        ],
      ),
    );
  }

  Widget _buildMiniProfile(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(profileUserProvider);

    return userAsync.when(
      loading: () => _profileShell(
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) =>
          _profileShell(child: Text('could_not_load_profile'.tr(context))),
      data: (profile) {
        final photoUrl = profile['photoUrl'] as String?;
        return _profileShell(
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _pickAndUploadPhoto(context, ref),
                child: Container(
                  width: 12.w,
                  height: 12.w,
                  decoration: BoxDecoration(
                    color: _primary,
                    shape: BoxShape.circle,
                    image: photoUrl != null && photoUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(photoUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: photoUrl != null && photoUrl.isNotEmpty
                      ? null
                      : Text(
                          profile['initials'] as String,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: _surface,
                          ),
                        ),
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile['name'] as String,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                        color: _primary,
                      ),
                    ),
                    SizedBox(height: 0.2.h),
                    Text(
                      '${profile['handle']} - ${profile['gym']}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _showEditProfileSheet(context, ref),
                child: Icon(
                  Icons.edit_rounded,
                  color: const Color(0xFF8E8E93),
                  size: 19.sp,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _profileShell({required Widget child}) {
    return Builder(
      builder: (context) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 4.8.w, vertical: 1.5.h),
          padding: EdgeInsets.all(3.w),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(4.w),
          ),
          child: child,
        );
      },
    );
  }

  Widget _buildSettingsList(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileUserProvider).asData?.value;
    final userModel = ref.watch(currentUserModelProvider).asData?.value;
    final metrics = ref.watch(bodyMetricsProvider).value ?? BodyMetrics();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.8.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGroupTitle('account'.tr(context)),
          _buildSettingsGroup([
            _buildSettingsRow(
              icon: Icons.person_outline,
              bg: const Color(0xFFE8F5FF),
              iconColor: const Color(0xFF007AFF),
              label: 'edit_profile'.tr(context),
              onTap: () => _showEditProfileSheet(context, ref),
            ),
            _buildSettingsRow(
              icon: Icons.add_a_photo_outlined,
              bg: const Color(0xFFE8FFF0),
              iconColor: const Color(0xFF1A7A30),
              label: 'profile_photo'.tr(context),
              val: 'upload'.tr(context),
              onTap: () => _pickAndUploadPhoto(context, ref),
            ),
            _buildSettingsRow(
              icon: Icons.store_mall_directory_outlined,
              bg: const Color(0xFFFFF0E8),
              iconColor: const Color(0xFFC05A0A),
              label: 'my_gym'.tr(context),
              val:
                  profile?['gym'] as String? ??
                  userModel?.gymId ??
                  'none'.tr(context),
            ),
          ]),
          _buildGroupTitle('profile_data'.tr(context)),
          _buildSettingsGroup([
            _buildSettingsRow(
              icon: Icons.cake_outlined,
              bg: const Color(0xFFFFF8E8),
              iconColor: const Color(0xFF7A4D0A),
              label: 'age'.tr(context),
              val: metrics.age <= 0
                  ? 'required'.tr(context)
                  : '${metrics.age} ${'years_short'.tr(context)}',
            ),
            _buildSettingsRow(
              icon: Icons.flag_outlined,
              bg: const Color(0xFFF0EEFF),
              iconColor: const Color(0xFF5B3FBF),
              label: 'goal'.tr(context),
              val: _displayChoice(context, metrics.goal),
            ),
            _buildSettingsRow(
              icon: Icons.fitness_center_outlined,
              bg: const Color(0xFFE8FFF0),
              iconColor: const Color(0xFF1A7A30),
              label: 'experience_level'.tr(context),
              val: _displayChoice(context, metrics.experienceLevel),
            ),
            _buildSettingsRow(
              icon: Icons.wc_outlined,
              bg: const Color(0xFFFFF0E8),
              iconColor: const Color(0xFFC05A0A),
              label: 'gender'.tr(context),
              val: _displayChoice(context, metrics.gender),
            ),
            _buildSettingsRow(
              icon: Icons.phone_iphone_outlined,
              bg: const Color(0xFFF0EEFF),
              iconColor: const Color(0xFF5B3FBF),
              label: 'phone'.tr(context),
              val: userModel?.phone ?? 'not_set'.tr(context),
            ),
            _buildSettingsRow(
              icon: Icons.badge_outlined,
              bg: const Color(0xFFE8F5FF),
              iconColor: const Color(0xFF007AFF),
              label: 'role'.tr(context),
              val: userModel?.role?.tr(context) ?? 'not_set'.tr(context),
            ),
            _buildSettingsRow(
              icon: Icons.verified_user_outlined,
              bg: const Color(0xFFE8FFF0),
              iconColor: const Color(0xFF1A7A30),
              label: 'email_verified'.tr(context),
              val: userModel?.emailVerified ?? false
                  ? 'yes'.tr(context)
                  : 'no'.tr(context),
            ),
          ]),
          _buildGroupTitle('app_settings'.tr(context)),
          _buildSettingsGroup([
            _buildSettingsRow(
              icon: Icons.language_rounded,
              bg: const Color(0xFFF0EEFF),
              iconColor: const Color(0xFF5B3FBF),
              label: 'settings_language'.tr(context),
              val: ref.watch(localeProvider).languageCode == 'ar'
                  ? 'settings_arabic'.tr(context)
                  : 'settings_english'.tr(context),
              onTap: () {
                _showLanguageSheet(context, ref);
              },
            ),
            _buildSettingsRow(
              icon: Icons.favorite_rounded,
              bg: const Color(0xFFF2F2F7),
              iconColor: const Color(0xFFC7C7CC),
              label: 'favorites'.tr(context),
              onTap: () {
                context.push('/favorites');
              },
            ),
          ]),
          SizedBox(height: 1.h),
          _buildSettingsGroup([
            _buildSettingsRow(
              icon: Icons.logout_rounded,
              bg: const Color(0xFFFFF0F0),
              iconColor: const Color(0xFFFF3B30),
              label: 'logout'.tr(context),
              isDanger: true,
              onTap: () async {
                await ref.read(authRepositoryProvider).signOut();
                if (context.mounted) context.go('/onboarding');
              },
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildGroupTitle(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(1.w, 2.h, 1.w, 1.h),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13.sp,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF8E8E93),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Builder(
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(4.w),
          ),
          child: Column(
            children: children.asMap().entries.map((entry) {
              final isLast = entry.key == children.length - 1;
              return Column(
                children: [
                  entry.value,
                  if (!isLast) Container(height: 1, color: _bg),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildSettingsRow({
    required IconData icon,
    required Color bg,
    required Color iconColor,
    required String label,
    String? val,
    bool isDanger = false,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Builder(
      builder: (context) {
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4.w),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
            child: Row(
              children: [
                Container(
                  width: 9.w,
                  height: 9.w,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(2.w),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: iconColor, size: 16.sp),
                ),
                SizedBox(width: 3.5.w),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: isDanger ? const Color(0xFFFF3B30) : _primary,
                    ),
                  ),
                ),
                if (val != null)
                  Flexible(
                    child: Text(
                      val,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14.sp, color: _secondary),
                    ),
                  ),
                if (trailing != null)
                  trailing
                else if (onTap != null && !isDanger)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: const Color(0xFFC7C7CC),
                    size: 20.sp,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadPhoto(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;

    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1200,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    final url = await FirebaseStorageService().uploadProfileImage(
      user.uid,
      bytes,
      'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    if (url == null) {
      if (context.mounted) {
        _showSnack(context, 'photo_upload_failed'.tr(context));
      }
      return;
    }

    await ref.read(authRepositoryProvider).updateCurrentUserPhotoUrl(url);
    ref.invalidate(profileUserProvider);
    if (context.mounted) _showSnack(context, 'profile_photo_saved'.tr(context));
  }

  void _showLanguageSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.fromLTRB(5.w, 3.h, 5.w, 5.h),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(5.w)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 12.w,
                  height: 0.6.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(1.w),
                  ),
                ),
              ),
              SizedBox(height: 3.h),
              Text(
                'settings_language'.tr(context),
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: _primary,
                ),
              ),
              SizedBox(height: 3.h),
              ListTile(
                title: Text(
                  'settings_english'.tr(context),
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                trailing: ref.watch(localeProvider).languageCode == 'en'
                    ? const Icon(Icons.check, color: Color(0xFF34C759))
                    : null,
                onTap: () {
                  ref
                      .read(localeProvider.notifier)
                      .setLocale(const Locale('en'));
                  Navigator.pop(ctx);
                },
              ),
              Divider(color: _bg),
              ListTile(
                title: Text(
                  'settings_arabic'.tr(context),
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                trailing: ref.watch(localeProvider).languageCode == 'ar'
                    ? const Icon(Icons.check, color: Color(0xFF34C759))
                    : null,
                onTap: () {
                  ref
                      .read(localeProvider.notifier)
                      .setLocale(const Locale('ar'));
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditProfileSheet(BuildContext context, WidgetRef ref) {
    final userModel = ref.read(currentUserModelProvider).asData?.value;
    final currentMetrics = ref.read(bodyMetricsProvider).value ?? BodyMetrics();
    final firstNameCtrl = TextEditingController(
      text: userModel?.firstName ?? '',
    );
    final lastNameCtrl = TextEditingController(text: userModel?.lastName ?? '');
    final originalPhone = userModel?.phone ?? '';
    final phoneCtrl = TextEditingController(text: originalPhone);
    final otpCtrl = TextEditingController();
    final weightCtrl = TextEditingController(
      text: _metricText(currentMetrics.weight),
    );
    final heightCtrl = TextEditingController(
      text: _metricText(currentMetrics.height),
    );
    final bodyFatCtrl = TextEditingController(
      text: _metricText(currentMetrics.bodyFat),
    );
    final muscleCtrl = TextEditingController(
      text: _metricText(currentMetrics.muscleMass),
    );
    final birthDateCtrl = TextEditingController(
      text: currentMetrics.dateOfBirth,
    );
    final ageCtrl = TextEditingController(
      text: currentMetrics.age <= 0 ? '' : currentMetrics.age.toString(),
    );
    String? selectedGoal = _normalizedChoice(
      currentMetrics.goal,
      _goalOptions.keys,
    );
    String? selectedExperienceLevel = _normalizedChoice(
      currentMetrics.experienceLevel,
      _experienceOptions.keys,
    );
    String? selectedGender = _normalizedChoice(
      currentMetrics.gender,
      _genderOptions.keys,
    );
    String error = '';
    String? verificationId;
    String? otpError;
    bool otpSent = false;
    bool phoneVerified = true;
    bool sendingOtp = false;
    bool verifyingOtp = false;

    bool phoneChanged() =>
        _phoneKey(_normalizePhone(phoneCtrl.text)) !=
        _phoneKey(_normalizePhone(originalPhone));

    Future<void> sendOtp(StateSetter setState) async {
      final normalizedPhone = _normalizePhone(phoneCtrl.text);
      if (!_isValidPhoneFormat(normalizedPhone)) {
        setState(() => otpError = 'phone_invalid_format'.tr(context));
        return;
      }
      setState(() {
        sendingOtp = true;
        otpError = null;
      });
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: normalizedPhone,
        verificationCompleted: (credential) async {
          await FirebaseAuth.instance.currentUser?.updatePhoneNumber(
            credential,
          );
          setState(() {
            phoneVerified = true;
            sendingOtp = false;
            otpError = null;
          });
        },
        verificationFailed: (e) {
          setState(() {
            sendingOtp = false;
            otpError = e.message ?? 'auth_unexpected_error'.tr(context);
          });
        },
        codeSent: (id, _) {
          setState(() {
            verificationId = id;
            otpSent = true;
            sendingOtp = false;
          });
        },
        codeAutoRetrievalTimeout: (id) => verificationId = id,
      );
    }

    Future<void> verifyOtp(StateSetter setState) async {
      final id = verificationId;
      if (id == null || otpCtrl.text.trim().isEmpty) {
        setState(() => otpError = 'auth_required'.tr(context));
        return;
      }
      setState(() {
        verifyingOtp = true;
        otpError = null;
      });
      try {
        final credential = PhoneAuthProvider.credential(
          verificationId: id,
          smsCode: otpCtrl.text.trim(),
        );
        await FirebaseAuth.instance.currentUser?.updatePhoneNumber(credential);
        setState(() {
          verifyingOtp = false;
          phoneVerified = true;
        });
      } on FirebaseAuthException catch (e) {
        setState(() {
          verifyingOtp = false;
          otpError = e.message ?? 'auth_unexpected_error'.tr(context);
        });
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Container(
              height: 88.h,
              padding: EdgeInsets.fromLTRB(
                5.w,
                2.h,
                5.w,
                MediaQuery.of(ctx).viewInsets.bottom + 2.h,
              ),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(5.w)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 12.w,
                      height: 0.6.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E5EA),
                        borderRadius: BorderRadius.circular(1.w),
                      ),
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    'edit_profile'.tr(context),
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w800,
                      color: _primary,
                    ),
                  ),
                  SizedBox(height: 0.6.h),
                  Text(
                    'required_body_data_desc'.tr(context),
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: const Color(0xFF8E8E93),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildTextInput(
                            'first_name'.tr(context),
                            firstNameCtrl,
                          ),
                          SizedBox(height: 1.5.h),
                          _buildTextInput(
                            'last_name'.tr(context),
                            lastNameCtrl,
                          ),
                          SizedBox(height: 1.5.h),
                          _buildTextInput(
                            'phone'.tr(context),
                            phoneCtrl,
                            keyboardType: TextInputType.phone,
                            onChanged: (_) => setState(() {
                              phoneVerified = !phoneChanged();
                              otpSent = false;
                              verificationId = null;
                              otpError = null;
                            }),
                          ),
                          if (phoneChanged() && !phoneVerified) ...[
                            SizedBox(height: 1.h),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: sendingOtp
                                        ? null
                                        : () => sendOtp(setState),
                                    icon: sendingOtp
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.sms_outlined),
                                    label: Text('send_otp'.tr(context)),
                                  ),
                                ),
                              ],
                            ),
                            if (otpSent) ...[
                              SizedBox(height: 1.h),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTextInput(
                                      'otp_code'.tr(context),
                                      otpCtrl,
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  SizedBox(width: 2.w),
                                  ElevatedButton(
                                    onPressed: verifyingOtp
                                        ? null
                                        : () => verifyOtp(setState),
                                    child: verifyingOtp
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text('verify'.tr(context)),
                                  ),
                                ],
                              ),
                            ],
                            if (otpError != null) ...[
                              SizedBox(height: 0.8.h),
                              Text(
                                otpError!,
                                style: TextStyle(
                                  color: const Color(0xFFFF3B30),
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                          SizedBox(height: 2.h),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextInput(
                                  'weight_kg_req'.tr(context),
                                  weightCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                ),
                              ),
                              SizedBox(width: 3.w),
                              Expanded(
                                child: _buildTextInput(
                                  'height_cm_req'.tr(context),
                                  heightCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 1.5.h),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextInput(
                                  'body_fat_pct_req'.tr(context),
                                  bodyFatCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                ),
                              ),
                              SizedBox(width: 3.w),
                              Expanded(
                                child: _buildTextInput(
                                  'muscle_kg_req'.tr(context),
                                  muscleCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 1.5.h),
                          _buildTextInput(
                            'age_req'.tr(context),
                            ageCtrl,
                            keyboardType: TextInputType.number,
                          ),
                          SizedBox(height: 1.5.h),
                          _buildTextInput(
                            'birth_date_req'.tr(context),
                            birthDateCtrl,
                            readOnly: true,
                            suffixIcon: Icons.calendar_month_outlined,
                            onTap: () async {
                              final existing = DateTime.tryParse(
                                birthDateCtrl.text,
                              );
                              final selected = await showDatePicker(
                                context: ctx,
                                initialDate:
                                    existing ??
                                    DateTime(DateTime.now().year - 25),
                                firstDate: DateTime(1940),
                                lastDate: DateTime.now(),
                              );
                              if (selected == null) return;
                              final value = _dateText(selected);
                              setState(() {
                                birthDateCtrl.text = value;
                                ageCtrl.text = _ageFromDate(
                                  selected,
                                ).toString();
                              });
                            },
                          ),
                          SizedBox(height: 1.5.h),
                          _buildDropdownInput(
                            context: context,
                            label: 'goal_req'.tr(context),
                            value: selectedGoal,
                            options: _goalOptions,
                            onChanged: (value) =>
                                setState(() => selectedGoal = value),
                          ),
                          SizedBox(height: 1.5.h),
                          _buildDropdownInput(
                            context: context,
                            label: 'experience_level_req'.tr(context),
                            value: selectedExperienceLevel,
                            options: _experienceOptions,
                            onChanged: (value) =>
                                setState(() => selectedExperienceLevel = value),
                          ),
                          SizedBox(height: 1.5.h),
                          _buildDropdownInput(
                            context: context,
                            label: 'gender_req'.tr(context),
                            value: selectedGender,
                            options: _genderOptions,
                            onChanged: (value) =>
                                setState(() => selectedGender = value),
                          ),
                          if (error.isNotEmpty) ...[
                            SizedBox(height: 1.5.h),
                            Text(
                              error,
                              style: TextStyle(
                                color: const Color(0xFFFF3B30),
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          SizedBox(height: 2.h),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final weight = double.tryParse(weightCtrl.text.trim());
                        final height = double.tryParse(heightCtrl.text.trim());
                        final bodyFat = double.tryParse(
                          bodyFatCtrl.text.trim(),
                        );
                        final muscleMass = double.tryParse(
                          muscleCtrl.text.trim(),
                        );
                        final age = int.tryParse(ageCtrl.text.trim());
                        final dateOfBirth = birthDateCtrl.text.trim();
                        final goal = selectedGoal;
                        final experienceLevel = selectedExperienceLevel;
                        final gender = selectedGender;

                        if (weight == null ||
                            weight <= 0 ||
                            height == null ||
                            height <= 0 ||
                            bodyFat == null ||
                            bodyFat <= 0 ||
                            muscleMass == null ||
                            muscleMass <= 0 ||
                            age == null ||
                            age <= 0 ||
                            DateTime.tryParse(dateOfBirth) == null ||
                            goal == null ||
                            experienceLevel == null ||
                            gender == null) {
                          setState(() {
                            error = 'fill_required_profile_fields'.tr(context);
                          });
                          return;
                        }
                        if (phoneChanged() && !phoneVerified) {
                          setState(() {
                            error = 'phone_verification_required'.tr(context);
                          });
                          return;
                        }

                        await ref
                            .read(authRepositoryProvider)
                            .updateCurrentUserProfile(
                              AuthProfileInput(
                                firstName: firstNameCtrl.text.trim(),
                                lastName: lastNameCtrl.text.trim(),
                                phone: _normalizePhone(phoneCtrl.text),
                              ),
                            );
                        await ref
                            .read(bodyMetricsProvider.notifier)
                            .updateProfileMetrics(
                              weight: weight,
                              height: height,
                              bodyFat: bodyFat,
                              muscleMass: muscleMass,
                              age: age,
                              dateOfBirth: dateOfBirth,
                              goal: goal,
                              gender: gender,
                              experienceLevel: experienceLevel,
                            );
                        ref.invalidate(profileUserProvider);
                        ref.invalidate(currentUserModelProvider);
                        ref.invalidate(bodyMetricsProvider);
                        if (ctx.mounted) ctx.pop();
                        if (context.mounted) {
                          _showSnack(context, 'profile_saved'.tr(context));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        padding: EdgeInsets.symmetric(vertical: 1.8.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(3.w),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'save_changes'.tr(context),
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          color: _surface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDropdownInput({
    required BuildContext context,
    required String label,
    required String? value,
    required Map<String, String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF8E8E93),
          ),
        ),
        SizedBox(height: 0.8.h),
        DropdownButtonFormField<String>(
          value: value,
          items: options.entries
              .map(
                (entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.key.tr(context)),
                ),
              )
              .toList(),
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: _primary,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: _bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3.w),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 4.w,
              vertical: 1.5.h,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextInput(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
    IconData? suffixIcon,
    ValueChanged<String>? onChanged,
  }) {
    return Builder(
      builder: (context) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: _secondary,
              ),
            ),
            SizedBox(height: 0.8.h),
            TextField(
              controller: controller,
              keyboardType: keyboardType,
              readOnly: readOnly,
              onTap: onTap,
              onChanged: onChanged,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: _primary,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: _bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(3.w),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 4.w,
                  vertical: 1.8.h,
                ),
                suffixIcon: suffixIcon == null
                    ? null
                    : Icon(
                        suffixIcon,
                        color: const Color(0xFF8E8E93),
                        size: 18.sp,
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  static const Map<String, String> _goalOptions = {
    'lose_fat': 'Lose Fat',
    'build_muscle': 'Build Muscle',
    'get_fit': 'Get Fit',
    'maintain': 'Maintain',
  };

  static const Map<String, String> _experienceOptions = {
    'beginner': 'Beginner',
    'intermediate': 'Intermediate',
    'advanced': 'Advanced',
  };

  static const Map<String, String> _genderOptions = {
    'male': 'Male',
    'female': 'Female',
    'other': 'Other',
  };

  String _displayChoice(BuildContext context, String? value) {
    final normalized = _normalizedChoice(value, [
      ..._goalOptions.keys,
      ..._experienceOptions.keys,
      ..._genderOptions.keys,
    ]);
    if (normalized == null) return 'required'.tr(context);
    return normalized.tr(context);
  }

  String _formatNumber(double value) {
    return value.truncateToDouble() == value
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  String _metricText(double value) => value <= 0 ? '' : _formatNumber(value);

  String _dateText(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  int _ageFromDate(DateTime date) {
    final now = DateTime.now();
    var age = now.year - date.year;
    final birthdayPassed =
        now.month > date.month ||
        (now.month == date.month && now.day >= date.day);
    if (!birthdayPassed) age -= 1;
    return age;
  }

  String? _normalizedChoice(String? value, Iterable<String> allowedValues) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value
        .trim()
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]}_${m[2]}')
        .replaceAll('-', '_')
        .replaceAll(' ', '_')
        .toLowerCase();
    if (allowedValues.contains(normalized)) return normalized;
    return null;
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

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
