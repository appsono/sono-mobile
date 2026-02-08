import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/services/settings/developer_settings_service.dart';
import 'package:sono/services/settings/library_settings_service.dart';
import 'package:file_picker/file_picker.dart';

/// Setup flow page
class SetupFlowPage extends StatefulWidget {
  final VoidCallback onSetupComplete;

  const SetupFlowPage({super.key, required this.onSetupComplete});

  @override
  State<SetupFlowPage> createState() => _SetupFlowPageState();
}

class _SetupFlowPageState extends State<SetupFlowPage>
    with TickerProviderStateMixin {
  int _currentPage = 0;
  late final int _totalSteps;
  bool _isTransitioning = false;

  late AnimationController _contentController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  //permission states
  bool _mediaPermissionGranted = false;
  bool _allFilesPermissionGranted = false;
  bool _notificationPermissionGranted = false;
  bool _alarmPermissionGranted = false;
  bool _batteryOptimizationDisabled = false;
  bool _installPermissionGranted = false;

  //excluded folders
  List<String> _excludedFolders = [];

  @override
  void initState() {
    super.initState();
    //iOS: 4 relevant steps (Welcome, Media, Excluded Folders, Notifications, All Set)
    //Android: 8 steps (all pages)
    _totalSteps = Platform.isIOS ? 4 : 8;
    _setupAnimations();
    _checkInitialPermissions();
  }

  void _setupAnimations() {
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOutCubic),
    );

    _contentController.forward();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _checkInitialPermissions() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;

      if (androidInfo.version.sdkInt >= 33) {
        _mediaPermissionGranted = await Permission.audio.isGranted;
      } else {
        _mediaPermissionGranted = await Permission.storage.isGranted;
      }

      if (androidInfo.version.sdkInt >= 30) {
        _allFilesPermissionGranted =
            await Permission.manageExternalStorage.isGranted;
      } else {
        _allFilesPermissionGranted = true;
      }

      _notificationPermissionGranted = await Permission.notification.isGranted;

      if (androidInfo.version.sdkInt >= 31) {
        _alarmPermissionGranted = await Permission.scheduleExactAlarm.isGranted;
      } else {
        _alarmPermissionGranted = true;
      }

      _batteryOptimizationDisabled =
          await Permission.ignoreBatteryOptimizations.isGranted;

      _installPermissionGranted =
          await Permission.requestInstallPackages.isGranted;
    } else {
      //iOS: check media library permission via on_audio_query
      _mediaPermissionGranted = await OnAudioQuery().permissionsStatus();
      _allFilesPermissionGranted = true;
      _notificationPermissionGranted = await Permission.notification.isGranted;
      _alarmPermissionGranted = true;
      _batteryOptimizationDisabled = true;
      _installPermissionGranted = true;
    }

    _excludedFolders =
        await LibrarySettingsService.instance.getExcludedFolders();

    if (mounted) setState(() {});
  }

  Future<void> _navigateToPage(int newPage) async {
    if (_isTransitioning || newPage == _currentPage) return;
    if (newPage < 0 || newPage > 8) return;

    _isTransitioning = true;

    await _contentController.reverse();

    setState(() => _currentPage = newPage);

    await _contentController.forward();

    _isTransitioning = false;
  }

  int _getDisplayStep() {
    if (Platform.isAndroid) return _currentPage;

    //iOS: map page number to display step (skipping Android-only pages)
    //Page 0 -> Step 0, Page 1 -> Step 1, Page 3 -> Step 2, Page 4 -> Step 3, Page 8 -> Step 4
    switch (_currentPage) {
      case 0:
        return 0;
      case 1:
        return 1;
      case 3:
        return 2;
      case 4:
        return 3;
      case 8:
        return 4;
      default:
        return _currentPage;
    }
  }

  void _nextPage() {
    int nextPage = _currentPage + 1;
    //iOS: skip Android-only pages (2, 5, 6, 7)
    if (Platform.isIOS) {
      while (nextPage == 2 || nextPage == 5 || nextPage == 6 || nextPage == 7) {
        nextPage++;
      }
    }
    _navigateToPage(nextPage);
  }

  void _previousPage() {
    int prevPage = _currentPage - 1;
    //iOS: skip Android-only pages (2, 5, 6, 7)
    if (Platform.isIOS) {
      while (prevPage == 2 || prevPage == 5 || prevPage == 6 || prevPage == 7) {
        prevPage--;
      }
    }
    _navigateToPage(prevPage);
  }

  Future<void> _completeSetup() async {
    await DeveloperSettingsService.instance.setSetupCompleted(true);
    widget.onSetupComplete();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[SetupFlow] build() page=$_currentPage');
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _buildCurrentPage(),
                ),
              ),
            ),

            if (_currentPage > 0)
              _ProgressIndicator(
                currentStep: _getDisplayStep(),
                totalSteps: _totalSteps,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPage() {
    //iOS: skip Android-only pages
    if (Platform.isIOS) {
      if (_currentPage == 2 ||
          _currentPage == 5 ||
          _currentPage == 6 ||
          _currentPage == 7) {
        //auto-skip All Files Access, Alarms, Battery, Install Updates on iOS
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _navigateToPage(_currentPage + 1));
        return const Center(child: CircularProgressIndicator());
      }
    }

    switch (_currentPage) {
      case 0:
        return _WelcomePage(onNext: _nextPage);
      case 1:
        return _PermissionPage(
          title: 'Media Permission',
          description:
              'Sono needs access to your audio files to display them in your music library.',
          icon: Icons.library_music_rounded,
          isGranted: _mediaPermissionGranted,
          onRequestPermission: () async {
            if (Platform.isAndroid) {
              final androidInfo = await DeviceInfoPlugin().androidInfo;
              PermissionStatus status;
              if (androidInfo.version.sdkInt >= 33) {
                status = await Permission.audio.request();
              } else {
                status = await Permission.storage.request();
              }
              setState(() => _mediaPermissionGranted = status.isGranted);
            } else {
              //iOS: request media library permission via on_audio_query
              final granted = await OnAudioQuery().permissionsRequest();
              setState(() => _mediaPermissionGranted = granted);
            }
          },
          onNext: _nextPage,
          onBack: _previousPage,
        );
      case 2:
        return _PermissionPage(
          title: 'All Files Access',
          description:
              'For some older Android versions, Sono needs broader file access to find all music files.',
          icon: Icons.folder_rounded,
          isGranted: _allFilesPermissionGranted,
          onRequestPermission: () async {
            if (Platform.isAndroid) {
              final androidInfo = await DeviceInfoPlugin().androidInfo;
              if (androidInfo.version.sdkInt >= 30) {
                final status = await Permission.manageExternalStorage.request();
                setState(() => _allFilesPermissionGranted = status.isGranted);
              }
            }
          },
          onNext: _nextPage,
          onBack: _previousPage,
        );
      case 3:
        return _ExcludedFoldersPage(
          excludedFolders: _excludedFolders,
          onFoldersChanged:
              (folders) => setState(() => _excludedFolders = folders),
          onNext: _nextPage,
          onBack: _previousPage,
        );
      case 4:
        return _PermissionPage(
          title: 'Notifications',
          description:
              'Enable notifications to control your music from the lock screen and notification center.',
          icon: Icons.notifications_rounded,
          isGranted: _notificationPermissionGranted,
          onRequestPermission: () async {
            final status = await Permission.notification.request();
            setState(() => _notificationPermissionGranted = status.isGranted);
          },
          onNext: _nextPage,
          onBack: _previousPage,
        );
      case 5:
        return _PermissionPage(
          title: 'Alarms & Reminders',
          description:
              'To ensure Sleep Timers work reliably and pause music exactly when you want, Sono needs permission to schedule exact alarms.',
          icon: Icons.alarm_rounded,
          isGranted: _alarmPermissionGranted,
          onRequestPermission: () async {
            if (Platform.isAndroid) {
              final androidInfo = await DeviceInfoPlugin().androidInfo;
              if (androidInfo.version.sdkInt >= 31) {
                final status = await Permission.scheduleExactAlarm.request();
                setState(() => _alarmPermissionGranted = status.isGranted);
              }
            }
          },
          onNext: _nextPage,
          onBack: _previousPage,
        );
      case 6:
        return _PermissionPage(
          title: 'Battery Optimization',
          description:
              'Some Android devices aggressively kill background apps. Disable battery optimization for Sono to prevent this.',
          icon: Icons.battery_charging_full_rounded,
          isGranted: _batteryOptimizationDisabled,
          onRequestPermission: () async {
            final status =
                await Permission.ignoreBatteryOptimizations.request();
            setState(() => _batteryOptimizationDisabled = status.isGranted);
          },
          onNext: _nextPage,
          onBack: _previousPage,
        );
      case 7:
        return _PermissionPage(
          title: 'Install Updates',
          description:
              'To install app updates directly, Sono needs permission to install apps from unknown sources.',
          icon: Icons.system_update_rounded,
          isGranted: _installPermissionGranted,
          onRequestPermission: () async {
            if (Platform.isAndroid) {
              final status = await Permission.requestInstallPackages.request();
              setState(() => _installPermissionGranted = status.isGranted);
            }
          },
          onNext: _nextPage,
          onBack: _previousPage,
        );
      case 8:
        return _AllSetPage(onFinish: _completeSetup, onBack: _previousPage);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _ProgressIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _ProgressIndicator({
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 4,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    color: AppTheme.surfaceDark,
                  ),
                  AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    widthFactor: currentStep / totalSteps,
                    child: Container(color: AppTheme.brandPink),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              'Step $currentStep of $totalSteps',
              key: ValueKey(currentStep),
              style: TextStyle(
                color: AppTheme.textTertiaryDark,
                fontSize: AppTheme.fontSm,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedFractionallySizedBox extends ImplicitlyAnimatedWidget {
  final double widthFactor;
  final Widget child;

  const AnimatedFractionallySizedBox({
    super.key,
    required this.widthFactor,
    required this.child,
    required super.duration,
    super.curve,
  });

  @override
  AnimatedWidgetBaseState<AnimatedFractionallySizedBox> createState() =>
      _AnimatedFractionallySizedBoxState();
}

class _AnimatedFractionallySizedBoxState
    extends AnimatedWidgetBaseState<AnimatedFractionallySizedBox> {
  Tween<double>? _widthFactor;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _widthFactor =
        visitor(
              _widthFactor,
              widget.widthFactor,
              (dynamic value) => Tween<double>(begin: value as double),
            )
            as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: _widthFactor?.evaluate(animation) ?? widget.widthFactor,
      child: widget.child,
    );
  }
}

// ============ PAGE WIDGETS ============

class _WelcomePage extends StatelessWidget {
  final VoidCallback onNext;

  const _WelcomePage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 48),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                  child: Icon(
                    Icons.music_note_rounded,
                    size: 80,
                    color: AppTheme.brandPink,
                  ),
                ),
                const SizedBox(height: 48),

                Text(
                  'Welcome to Sono',
                  style: TextStyle(
                    color: AppTheme.textPrimaryDark,
                    fontSize: AppTheme.fontDisplay,
                    fontWeight: FontWeight.bold,
                    fontFamily: AppTheme.fontFamily,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                Text(
                  "Let's get everything ready for you.",
                  style: TextStyle(
                    color: AppTheme.textSecondaryDark,
                    fontSize: AppTheme.fontSubtitle,
                    fontFamily: AppTheme.fontFamily,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          _PrimaryButton(label: 'Get Started', onPressed: onNext),
        ],
      ),
    );
  }
}

class _PermissionPage extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isGranted;
  final VoidCallback onRequestPermission;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _PermissionPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.isGranted,
    required this.onRequestPermission,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _BackButton(onPressed: onBack),
          ),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      ),
                      child: Icon(
                        icon,
                        size: 80,
                        color:
                            isGranted ? AppTheme.success : AppTheme.brandPink,
                      ),
                    ),

                    if (isGranted)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.success,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMd,
                            ),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 48),

                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textPrimaryDark,
                    fontSize: AppTheme.fontHeading,
                    fontWeight: FontWeight.bold,
                    fontFamily: AppTheme.fontFamily,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                Text(
                  description,
                  style: TextStyle(
                    color: AppTheme.textSecondaryDark,
                    fontSize: AppTheme.font,
                    fontFamily: AppTheme.fontFamily,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Permission button
          _PermissionButton(
            isGranted: isGranted,
            onPressed: onRequestPermission,
          ),
          const SizedBox(height: 12),

          /*// Skip button
          _SecondaryButton(
            label: 'Skip for now',
            onPressed: onNext,
          ),*/
          const SizedBox(height: 16),

          Align(
            alignment: Alignment.centerRight,
            child: _ContinueArrow(onPressed: onNext),
          ),
        ],
      ),
    );
  }
}

class _PermissionButton extends StatelessWidget {
  final bool isGranted;
  final VoidCallback onPressed;

  const _PermissionButton({required this.isGranted, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isGranted ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isGranted
                  ? AppTheme.success.withValues(alpha: 0.2)
                  : AppTheme.brandPink,
          foregroundColor: isGranted ? AppTheme.success : Colors.white,
          disabledBackgroundColor: AppTheme.success.withValues(alpha: 0.2),
          disabledForegroundColor: AppTheme.success,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isGranted) ...[
              const Icon(Icons.check_rounded, size: 20),
              const SizedBox(width: 8),
              Text(
                'Permission Granted',
                style: TextStyle(
                  fontSize: AppTheme.font,
                  fontWeight: FontWeight.w600,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ] else ...[
              Text(
                'Allow Permission',
                style: TextStyle(
                  fontSize: AppTheme.font,
                  fontWeight: FontWeight.w600,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExcludedFoldersPage extends StatefulWidget {
  final List<String> excludedFolders;
  final ValueChanged<List<String>> onFoldersChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _ExcludedFoldersPage({
    required this.excludedFolders,
    required this.onFoldersChanged,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<_ExcludedFoldersPage> createState() => _ExcludedFoldersPageState();
}

class _ExcludedFoldersPageState extends State<_ExcludedFoldersPage> {
  late List<String> _folders;

  @override
  void initState() {
    super.initState();
    _folders = List.from(widget.excludedFolders);
  }

  Future<void> _pickFolder() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null && !_folders.contains(result)) {
      setState(() => _folders.add(result));
      await LibrarySettingsService.instance.addExcludedFolder(result);
      widget.onFoldersChanged(_folders);
    }
  }

  Future<void> _removeFolder(int index) async {
    final folder = _folders[index];
    setState(() => _folders.removeAt(index));
    await LibrarySettingsService.instance.removeExcludedFolder(folder);
    widget.onFoldersChanged(_folders);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _BackButton(onPressed: widget.onBack),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    ),
                    child: Icon(
                      Icons.folder_off_rounded,
                      size: 80,
                      color: AppTheme.brandPink,
                    ),
                  ),
                  const SizedBox(height: 32),

                  Text(
                    'Excluded Folders',
                    style: TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontSize: AppTheme.fontHeading,
                      fontWeight: FontWeight.bold,
                      fontFamily: AppTheme.fontFamily,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'All folders are scanned by default. Pick any locations that you want to be ignored when loading your library.',
                    style: TextStyle(
                      color: AppTheme.textSecondaryDark,
                      fontSize: AppTheme.font,
                      fontFamily: AppTheme.fontFamily,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  if (_folders.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 150),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _folders.length,
                        itemBuilder: (context, index) {
                          final folder = _folders[index];
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              Icons.folder_rounded,
                              color: AppTheme.textSecondaryDark,
                            ),
                            title: Text(
                              folder.split('/').last,
                              style: TextStyle(
                                color: AppTheme.textPrimaryDark,
                                fontFamily: AppTheme.fontFamily,
                              ),
                            ),
                            subtitle: Text(
                              folder,
                              style: TextStyle(
                                color: AppTheme.textTertiaryDark,
                                fontSize: AppTheme.fontSm,
                                fontFamily: AppTheme.fontFamily,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                color: AppTheme.error,
                              ),
                              onPressed: () => _removeFolder(index),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          _PrimaryButton(
            label: 'Choose Excluded Folders',
            onPressed: _pickFolder,
            icon: Icons.folder_open_rounded,
          ),
          const SizedBox(height: 12),

          /*
          _SecondaryButton(
            label: _folders.isEmpty ? 'Skip for now' : 'Continue',
            onPressed: widget.onNext,
          ),*/
          const SizedBox(height: 16),

          Align(
            alignment: Alignment.centerRight,
            child: _ContinueArrow(onPressed: widget.onNext),
          ),
        ],
      ),
    );
  }
}

class _AllSetPage extends StatelessWidget {
  final VoidCallback onFinish;
  final VoidCallback onBack;

  const _AllSetPage({required this.onFinish, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _BackButton(onPressed: onBack),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 100,
                    color: AppTheme.success,
                  ),
                ),
                const SizedBox(height: 48),

                Text(
                  'All Set!',
                  style: TextStyle(
                    color: AppTheme.textPrimaryDark,
                    fontSize: AppTheme.fontDisplay,
                    fontWeight: FontWeight.bold,
                    fontFamily: AppTheme.fontFamily,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                Text(
                  "You're ready to enjoy Sono now!",
                  style: TextStyle(
                    color: AppTheme.textSecondaryDark,
                    fontSize: AppTheme.fontSubtitle,
                    fontFamily: AppTheme.fontFamily,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          _PrimaryButton(label: "Let's Go!", onPressed: onFinish),
        ],
      ),
    );
  }
}

// ============ UI COMPONENTS ============

class _BackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _BackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_back_rounded,
                color: AppTheme.textSecondaryDark,
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(
                'Back',
                style: TextStyle(
                  color: AppTheme.textSecondaryDark,
                  fontSize: AppTheme.font,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContinueArrow extends StatelessWidget {
  final VoidCallback onPressed;

  const _ContinueArrow({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Continue',
                style: TextStyle(
                  color: AppTheme.textSecondaryDark,
                  fontSize: AppTheme.font,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppTheme.textSecondaryDark,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.brandPink,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: AppTheme.font,
                fontWeight: FontWeight.w600,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/*
class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _SecondaryButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          color: AppTheme.textSecondaryDark,
          fontSize: AppTheme.font,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    );
  }
}*/
