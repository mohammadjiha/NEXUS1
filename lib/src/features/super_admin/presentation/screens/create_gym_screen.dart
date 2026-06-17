import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';

import '../../../auth/data/auth_repository.dart';
import '../../data/super_admin_service.dart';

class CreateGymScreen extends ConsumerStatefulWidget {
  const CreateGymScreen({super.key});

  @override
  ConsumerState<CreateGymScreen> createState() => _CreateGymScreenState();
}

class _CreateGymScreenState extends ConsumerState<CreateGymScreen> {
  final _formKey = GlobalKey<FormState>();

  final _gymNameCtrl    = TextEditingController();
  final _gymCityCtrl    = TextEditingController();
  final _gymIdCtrl      = TextEditingController();
  final _firstNameCtrl  = TextEditingController();
  final _lastNameCtrl   = TextEditingController();
  final _emailCtrl      = TextEditingController();
  final _phoneCtrl      = TextEditingController();

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final service = ref.read(superAdminServiceProvider);
    _gymIdCtrl.text = service.generateGymId();
  }

  @override
  void dispose() {
    _gymNameCtrl.dispose();
    _gymCityCtrl.dispose();
    _gymIdCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final superAdminUid =
        ref.read(currentUserModelProvider).asData?.value?.uid ?? '';

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(superAdminServiceProvider);
      final password = service.generatePassword();

      final result = await service.createGym(
        gymName:       _gymNameCtrl.text.trim(),
        gymCity:       _gymCityCtrl.text.trim(),
        gymId:         _gymIdCtrl.text.trim(),
        adminFirstName: _firstNameCtrl.text.trim(),
        adminLastName:  _lastNameCtrl.text.trim(),
        adminEmail:    _emailCtrl.text.trim().toLowerCase(),
        adminPhone:    _phoneCtrl.text.trim(),
        adminPassword: password,
        superAdminUid: superAdminUid,
      );

      if (!mounted) return;
      _showSuccessDialog(result);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _showSuccessDialog(GymCreationResult result) {
    setState(() => _isLoading = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF34C759), size: 24),
            SizedBox(width: 2.w),
            Text(
              'تم إنشاء النادي ✅',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _credRow('اسم النادي', result.gymName),
            _credRow('معرّف النادي (ID)', result.gymId),
            _credRow('إيميل الأدمن', result.adminEmail),
            _credRow('كلمة المرور', result.adminPassword),
            SizedBox(height: 1.5.h),
            Text(
              '⚠️ احفظ كلمة المرور الآن — لن تظهر مجدداً',
              style: TextStyle(
                fontSize: 9.sp,
                color: const Color(0xFFFF9500),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              final text =
                  'نادي: ${result.gymName}\nID: ${result.gymId}\nإيميل: ${result.adminEmail}\nكلمة المرور: ${result.adminPassword}';
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم النسخ ✅'),
                  backgroundColor: Color(0xFF34C759),
                ),
              );
            },
            child: Text(
              'نسخ البيانات',
              style: TextStyle(
                color: const Color(0xFF5BA8FF),
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF34C759),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // back to dashboard
            },
            child: Text(
              'تم',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _credRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 8.sp,
              color: Colors.white38,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            margin: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 13.sp,
            ),
          ),
        ),
        title: Text(
          'إنشاء نادي جديد',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
          children: [
            // ── Gym Info ──────────────────────────────────────────────────
            _sectionLabel('🏋️ معلومات النادي'),
            SizedBox(height: 1.h),
            _field(
              controller: _gymNameCtrl,
              label: 'اسم النادي',
              hint: 'مثال: Iron Peak Gym',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'مطلوب' : null,
            ),
            SizedBox(height: 1.5.h),
            _field(
              controller: _gymCityCtrl,
              label: 'المدينة',
              hint: 'مثال: Amman, Jordan',
            ),
            SizedBox(height: 1.5.h),
            Row(
              children: [
                Expanded(
                  child: _field(
                    controller: _gymIdCtrl,
                    label: 'معرّف النادي (ID)',
                    hint: 'مثال: 1002',
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'مطلوب' : null,
                  ),
                ),
                SizedBox(width: 2.w),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _gymIdCtrl.text =
                          ref.read(superAdminServiceProvider).generateGymId();
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.only(top: 2.h),
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.refresh_rounded,
                      color: Colors.white54,
                      size: 14.sp,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 3.h),

            // ── Admin Info ────────────────────────────────────────────────
            _sectionLabel('👤 بيانات الأدمن'),
            SizedBox(height: 1.h),
            Row(
              children: [
                Expanded(
                  child: _field(
                    controller: _firstNameCtrl,
                    label: 'الاسم الأول',
                    hint: 'Ahmad',
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'مطلوب' : null,
                  ),
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: _field(
                    controller: _lastNameCtrl,
                    label: 'اسم العائلة',
                    hint: 'Hassan',
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'مطلوب' : null,
                  ),
                ),
              ],
            ),
            SizedBox(height: 1.5.h),
            _field(
              controller: _emailCtrl,
              label: 'الإيميل',
              hint: 'admin@gymname.com',
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'مطلوب';
                if (!v.contains('@') || !v.contains('.')) return 'إيميل غير صحيح';
                return null;
              },
            ),
            SizedBox(height: 1.5.h),
            _field(
              controller: _phoneCtrl,
              label: 'رقم الهاتف (للـ OTP)',
              hint: '+970XXXXXXXXX',
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'مطلوب' : null,
            ),

            SizedBox(height: 1.h),
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: const Color(0xFF34C759).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF34C759).withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: const Color(0xFF34C759),
                    size: 13.sp,
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Text(
                      'كلمة المرور ستُنشأ تلقائياً وتظهر لك بعد الإنشاء',
                      style: TextStyle(
                        fontSize: 9.sp,
                        color: const Color(0xFF34C759),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_error != null) ...[
              SizedBox(height: 2.h),
              Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(
                    fontSize: 9.sp,
                    color: const Color(0xFFFF3B30),
                  ),
                ),
              ),
            ],

            SizedBox(height: 4.h),

            GestureDetector(
              onTap: _isLoading ? null : _submit,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 2.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF3B30), Color(0xFFC0392B)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        'إنشاء النادي',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),

            SizedBox(height: 4.h),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w800,
          color: Colors.white70,
          letterSpacing: 0.3,
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 8.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white38,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: 0.5.h),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(
            fontSize: 11.sp,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.white24,
              fontSize: 11.sp,
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFFF3B30), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFFFF3B30), width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFFFF3B30), width: 1.5),
            ),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
            errorStyle: TextStyle(
              fontSize: 8.sp,
              color: const Color(0xFFFF3B30),
            ),
          ),
        ),
      ],
    );
  }
}
