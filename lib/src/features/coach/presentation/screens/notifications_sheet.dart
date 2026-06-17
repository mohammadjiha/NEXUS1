import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../features/coach/providers/notifications_provider.dart';

class NotificationsSheet extends ConsumerWidget {
  const NotificationsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Container(
      padding: EdgeInsets.all(4.w),
      constraints: BoxConstraints(maxHeight: 70.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'coach_notifications'.tr(context),
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Expanded(
            child: notificationsAsync.when(
              data: (notifications) {
                if (notifications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 40.sp, color: const Color(0xFFC7C7CC)),
                        SizedBox(height: 2.h),
                        Text('coach_no_notifications_yet'.tr(context), style: TextStyle(fontSize: 14.sp, color: const Color(0xFF8E8E93))),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: notifications.length,
                  separatorBuilder: (context, index) => Divider(color: const Color(0xFFE5E5EA), height: 3.h),
                  itemBuilder: (context, index) {
                    final note = notifications[index];
                    return GestureDetector(
                      onTap: () {
                        if (!note.read) {
                          ref.read(markNotificationReadProvider)(note.id);
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.all(3.w),
                        decoration: BoxDecoration(
                          color: note.read ? Colors.transparent : const Color(0xFF007AFF).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(2.w),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.all(2.w),
                              decoration: BoxDecoration(
                                color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.notifications_active, color: Color(0xFF007AFF), size: 20),
                            ),
                            SizedBox(width: 3.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          note.title,
                                          style: TextStyle(
                                            fontSize: 14.sp,
                                            fontWeight: note.read ? FontWeight.w600 : FontWeight.w800,
                                            color: const Color(0xFF1C1C1E),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        DateFormat('MMM d, h:mm a').format(note.createdAt),
                                        style: TextStyle(fontSize: 14.sp, color: const Color(0xFF8E8E93)),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 0.5.h),
                                  Text(
                                    note.body,
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: const Color(0xFF6E6E73),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!note.read)
                              Container(
                                margin: EdgeInsetsDirectional.only(start: 2.w, top: 1.h),
                                width: 2.w,
                                height: 2.w,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF007AFF),
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('${'error_prefix'.tr(context)}$err')),
            ),
          ),
        ],
      ),
    );
  }
}

