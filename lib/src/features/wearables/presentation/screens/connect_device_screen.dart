import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../providers/wearables_provider.dart';
import '../../services/health_service.dart';
import 'wearables_dashboard_screen.dart';

class ConnectDeviceScreen extends ConsumerWidget {
  const ConnectDeviceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectedWatch = ref.watch(connectedWearableProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F7),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: const Color(0xFF1C1C1E),
            size: 16.sp,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'connect_device'.tr(context),
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1C1C1E),
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Column(
              children: [
                _buildHero(context),
                _buildDeviceList(context, ref, connectedWatch),
                SizedBox(height: 4.h),
              ],
            ),
          ),
          if (connectedWatch != null)
            PositionedDirectional(
              bottom: 0,
              start: 0,
              end: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(4.4.w, 2.h, 4.4.w, 4.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      const Color(0xFFF5F5F7),
                      const Color(0xFFF5F5F7).withValues(alpha: 0.9),
                      const Color(0xFFF5F5F7).withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WearablesDashboardScreen(),
                      ),
                    );
                  },
                  icon: Icon(Icons.check, color: Colors.white, size: 24.sp),
                  label: Text(
                    '$connectedWatch ${'connected'.tr(context)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C1C1E),
                    padding: EdgeInsets.symmetric(
                      vertical: 2.8.h,
                      horizontal: 2.w,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3.5.w),
                    ),
                    textStyle: TextStyle(fontSize: 16.sp),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.4.w, vertical: 2.h),
      child: Column(
        children: [
          Text(
            'connect_your_wearable'.tr(context),
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1C1C1E),
              letterSpacing: -0.4,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 0.5.h),
          Text(
            'wearable_connect_desc'.tr(context),
            style: TextStyle(
              fontSize: 15.sp,
              color: const Color(0xFF6E6E73),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList(
    BuildContext context,
    WidgetRef ref,
    String? connectedWatch,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.4.w),
      child: Column(
        children: [
          _buildDeviceCard(
            context,
            ref,
            name: 'Apple Watch',
            sub: 'Series 8 · HR, HRV, Sleep, SpO2',
            iconWidget: Container(
              color: Colors.black,
              child: const Icon(Icons.watch, color: Colors.white),
            ),
            badgeText: connectedWatch == 'Apple Watch'
                ? 'Connected ✓'
                : 'Connect',
            badgeBg: connectedWatch == 'Apple Watch'
                ? const Color(0xFFE8FFF0)
                : const Color(0xFFE8F5FF),
            badgeColor: connectedWatch == 'Apple Watch'
                ? const Color(0xFF1A7A30)
                : const Color(0xFF007AFF),
            isConnected: connectedWatch == 'Apple Watch',
          ),
          _buildDeviceCard(
            context,
            ref,
            name: 'Samsung Galaxy Watch',
            sub: 'HR, Sleep, Stress, Body Comp',
            iconWidget: Container(
              color: const Color(0xFF1428A0),
              child: const Icon(Icons.watch_rounded, color: Colors.white),
            ),
            badgeText: connectedWatch == 'Samsung Galaxy Watch'
                ? 'Connected ✓'
                : 'Connect',
            badgeBg: connectedWatch == 'Samsung Galaxy Watch'
                ? const Color(0xFFE8FFF0)
                : const Color(0xFFE8F5FF),
            badgeColor: connectedWatch == 'Samsung Galaxy Watch'
                ? const Color(0xFF1A7A30)
                : const Color(0xFF007AFF),
            isConnected: connectedWatch == 'Samsung Galaxy Watch',
          ),
          _buildDeviceCard(
            context,
            ref,
            name: 'Garmin',
            sub: 'HR, HRV, VO2 Max, Training Load',
            iconWidget: Container(
              color: const Color(0xFF007CC3),
              child: const Icon(Icons.watch_outlined, color: Colors.white),
            ),
            badgeText: connectedWatch == 'Garmin' ? 'Connected ✓' : 'Connect',
            badgeBg: connectedWatch == 'Garmin'
                ? const Color(0xFFE8FFF0)
                : const Color(0xFFE8F5FF),
            badgeColor: connectedWatch == 'Garmin'
                ? const Color(0xFF1A7A30)
                : const Color(0xFF007AFF),
            isConnected: connectedWatch == 'Garmin',
          ),
          _buildDeviceCard(
            context,
            ref,
            name: 'Whoop 4.0',
            sub: 'HRV, Recovery, Strain, Sleep',
            iconWidget: Container(
              color: Colors.black,
              child: const Icon(Icons.waves, color: Colors.white),
            ),
            badgeText: connectedWatch == 'Whoop 4.0'
                ? 'Connected ✓'
                : 'Connect',
            badgeBg: connectedWatch == 'Whoop 4.0'
                ? const Color(0xFFE8FFF0)
                : const Color(0xFFE8F5FF),
            badgeColor: connectedWatch == 'Whoop 4.0'
                ? const Color(0xFF1A7A30)
                : const Color(0xFF007AFF),
            isConnected: connectedWatch == 'Whoop 4.0',
          ),
          _buildDeviceCard(
            context,
            ref,
            name: 'Fitbit',
            sub: 'HR, Sleep, Steps, Calories',
            iconWidget: Container(
              color: const Color(0xFF00B0B9),
              child: const Icon(
                Icons.watch_later_outlined,
                color: Colors.white,
              ),
            ),
            badgeText: connectedWatch == 'Fitbit' ? 'Connected ✓' : 'Connect',
            badgeBg: connectedWatch == 'Fitbit'
                ? const Color(0xFFE8FFF0)
                : const Color(0xFFE8F5FF),
            badgeColor: connectedWatch == 'Fitbit'
                ? const Color(0xFF1A7A30)
                : const Color(0xFF007AFF),
            isConnected: connectedWatch == 'Fitbit',
          ),
          _buildDeviceCard(
            context,
            ref,
            name: 'Google Fit',
            sub: 'HR, Activity, Sleep (Android)',
            iconWidget: Container(
              color: const Color(0xFFF5F5F7),
              child: const Icon(Icons.directions_run, color: Color(0xFF4285F4)),
            ),
            badgeText: connectedWatch == 'Google Fit'
                ? 'Connected ✓'
                : 'Connect',
            badgeBg: connectedWatch == 'Google Fit'
                ? const Color(0xFFE8FFF0)
                : const Color(0xFFE8F5FF),
            badgeColor: connectedWatch == 'Google Fit'
                ? const Color(0xFF1A7A30)
                : const Color(0xFF007AFF),
            isConnected: connectedWatch == 'Google Fit',
          ),
          _buildDeviceCard(
            context,
            ref,
            name: 'Huawei Watch',
            sub: 'HR, TruSleep, Stress, SpO2',
            iconWidget: Container(
              color: const Color(0xFFCF0A2C),
              child: const Icon(Icons.watch_rounded, color: Colors.white),
            ),
            badgeText: connectedWatch == 'Huawei Watch'
                ? 'Connected ✓'
                : 'Connect',
            badgeBg: connectedWatch == 'Huawei Watch'
                ? const Color(0xFFE8FFF0)
                : const Color(0xFFE8F5FF),
            badgeColor: connectedWatch == 'Huawei Watch'
                ? const Color(0xFF1A7A30)
                : const Color(0xFF007AFF),
            isConnected: connectedWatch == 'Huawei Watch',
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(
    BuildContext context,
    WidgetRef ref, {
    required String name,
    required String sub,
    required Widget iconWidget,
    required String badgeText,
    Color badgeBg = const Color(0xFFE8F5FF),
    Color badgeColor = const Color(0xFF007AFF),
    bool isConnected = false,
  }) {
    return GestureDetector(
      onTap: () async {
        if (!isConnected) {
          if (name == 'Huawei Watch' || name == 'Apple Watch') {
            // Ask for permissions first
            await Permission.bluetoothScan.request();
            await Permission.bluetoothConnect.request();
            await Permission.location.request();

            if (await Permission.bluetoothScan.isDenied ||
                await Permission.bluetoothConnect.isDenied ||
                await Permission.location.isDenied) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('permissions_required_to_scan'.tr(context)),
                  ),
                );
              }
              return;
            }

            // Check if Bluetooth is on
            if (await FlutterBluePlus.adapterState.first ==
                BluetoothAdapterState.off) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('please_turn_on_bluetooth'.tr(context)),
                  ),
                );
              }
              try {
                await FlutterBluePlus.turnOn();
              } catch (e) {
                return;
              }
            }

            // Wait for it to be on
            await FlutterBluePlus.adapterState
                .where((val) => val == BluetoothAdapterState.on)
                .first;
          }
          if (context.mounted) {
            _showConnectingDialog(context, ref, name, iconWidget);
          }
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 1.5.h),
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        decoration: BoxDecoration(
          color: isConnected ? const Color(0xFFFDFFFE) : Colors.white,
          borderRadius: BorderRadius.circular(4.5.w),
          border: Border.all(
            color: isConnected
                ? const Color(0xFF34C759)
                : const Color(0xFFE5E5EA),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 14.w,
              height: 14.w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3.5.w),
              ),
              clipBehavior: Clip.hardEdge,
              child: iconWidget,
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                  ),
                  SizedBox(height: 0.3.h),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      sub,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: const Color(0xFF6E6E73),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(2.w),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConnectingDialog(
    BuildContext context,
    WidgetRef ref,
    String name,
    Widget iconWidget,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return BleScanDialog(name: name, iconWidget: iconWidget);
      },
    );
  }
}

class BleScanDialog extends ConsumerStatefulWidget {
  final String name;
  final Widget iconWidget;

  const BleScanDialog({
    super.key,
    required this.name,
    required this.iconWidget,
  });

  @override
  ConsumerState<BleScanDialog> createState() => _BleScanDialogState();
}

class _BleScanDialogState extends ConsumerState<BleScanDialog> {
  bool _isScanning = false;
  bool _hasConnected = false;
  bool _hasFailed = false;
  String _statusText = 'Initializing Bluetooth...';
  List<ScanResult> _devices = [];

  @override
  void initState() {
    super.initState();
    _startBleFlow();
  }

  Future<void> _startBleFlow() async {
    if (mounted) {
      setState(() {
        _isScanning = true;
        _statusText = 'Scanning for ${widget.name}...';
      });
    }

    FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          _devices = results
              .where((r) => r.device.platformName.isNotEmpty)
              .toList();
        });
      }
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    if (mounted) {
      setState(() {
        _isScanning = false;
        if (_devices.isEmpty) {
          _statusText = 'No devices found. Ensure it is paired.';
        } else {
          _statusText = 'Select your device to connect.';
        }
      });
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    FlutterBluePlus.stopScan();
    setState(() {
      _isScanning = false;
      _statusText = 'Connecting to ${device.platformName}...';
    });

    try {
      await device.connect(timeout: const Duration(seconds: 10));

      setState(() {
        _statusText = 'Authenticating Data...';
      });

      final granted = await healthService.requestPermissions();
      if (granted) {
        setState(() {
          _hasConnected = true;
          _hasFailed = false;
          _statusText = 'Successfully Connected!';
        });

        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.pop(context);
            ref.read(connectedWearableProvider.notifier).state = widget.name;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const WearablesDashboardScreen(),
              ),
            );
          }
        });
      } else {
        await device.disconnect();
        setState(() {
          _hasFailed = true;
          _statusText = 'Health Permissions Denied';
        });
      }
    } catch (e) {
      setState(() {
        _hasFailed = true;
        _statusText = 'Failed to connect. Make sure it is nearby.';
      });
    }
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.w)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 3.h, horizontal: 5.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 15.w,
              height: 15.w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3.w),
              ),
              clipBehavior: Clip.hardEdge,
              child: _hasConnected
                  ? Container(
                      color: const Color(0xFF34C759),
                      child: Icon(Icons.check, color: Colors.white, size: 8.w),
                    )
                  : _hasFailed
                  ? Container(
                      color: const Color(0xFFFF3B30),
                      child: Icon(Icons.close, color: Colors.white, size: 8.w),
                    )
                  : widget.iconWidget,
            ),
            SizedBox(height: 2.h),
            Text(
              _statusText,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1C1C1E),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 2.h),
            if (_isScanning)
              const CircularProgressIndicator(color: Color(0xFF1C1C1E)),
            if (!_hasConnected && !_hasFailed && _devices.isNotEmpty)
              Container(
                height: 30.h,
                margin: EdgeInsets.only(top: 2.h),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE5E5EA)),
                  borderRadius: BorderRadius.circular(2.w),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _devices.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final d = _devices[index];
                    return ListTile(
                      leading: Icon(
                        Icons.watch,
                        color: const Color(0xFF0C447C),
                        size: 6.w,
                      ),
                      title: Text(
                        d.device.platformName,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        d.device.remoteId.str,
                        style: TextStyle(fontSize: 9.sp),
                      ),
                      onTap: () => _connectToDevice(d.device),
                    );
                  },
                ),
              ),
            if (_hasFailed) ...[
              SizedBox(height: 2.h),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(
                  'close'.tr(context),
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: const Color(0xFF0C447C),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
