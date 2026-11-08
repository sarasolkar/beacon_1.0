import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/game_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/beacon_button.dart';
import '../../core/widgets/beacon_card.dart';
import '../../core/widgets/beacon_compass_widget.dart';
import '../../core/widgets/beacon_hint_card.dart';
import '../../models/evidence_submission.dart';
import '../../models/hint_progress.dart';
import '../../models/hunt_room.dart';
import '../../models/participant.dart';
import '../../services/service_locator.dart';
import '../../services/location_service.dart';
import '../../services/geolocator_location_service.dart';
import '../role_selection/role_selection_screen.dart';
import '../winner/winner_screen.dart';
import 'evidence_submission_dialog.dart';

class HuntModeScreen extends StatefulWidget {
  final String roomCode;

  const HuntModeScreen({super.key, required this.roomCode});

  @override
  State<HuntModeScreen> createState() => _HuntModeScreenState();
}

class _HuntModeScreenState extends State<HuntModeScreen> {
  // ── Distance / compass state ───────────────────────────────────────────────
  // Placeholders only. They are NEVER shown until a real fix arrives
  // (see _hasCurrentPosition).
  double _currentDistance = 300.0;
  double _bearing = 0.0;
  double? _gpsAccuracy;
  LocationPermissionStatus? _permissionStatus;
  PositionData? _lastPosition;
  int _heartbeatTicks = 0;
  Future<Uint8List?>? _photoFuture;
  String? _hintsMessage;
  bool _isUpdatingPosition = false;
  String? _locationMessage;
  bool _hasCurrentPosition = false;
  PositionData? _pendingPosition;
  List<String> _unlockedHintTexts = [];

  // ── Location service ───────────────────────────────────────────────────────
  final LocationService _locationService = GeolocatorLocationService();
  StreamSubscription<PositionData>? _positionSubscription;

  // ── Room / submission streams ──────────────────────────────────────────────
  HuntRoom? _room;
  StreamSubscription<HuntRoom?>? _roomSubscription;
  EvidenceSubmission? _mySubmission;
  StreamSubscription<EvidenceSubmission?>? _submissionSubscription;

  // ── Time-based hint state ──────────────────────────────────────────────────
  /// Number of hints currently unlocked (0–3).
  int _hintsUnlocked = 0;

  /// Countdown until the next hint unlocks. null when all hints are unlocked.
  Duration? _nextHintIn;

  Timer? _hintTimer;
  bool _isRefreshingHints = false;
  DateTime? _lastHintRefreshAt;
  bool _didNavigateToResult = false;

  // ── Helpers ────────────────────────────────────────────────────────────────
  String get _hunterId =>
      ServiceLocator().authService.currentUser?.uid ?? 'hunter_01';

  // ── Proximity label ────────────────────────────────────────────────────────
  bool get _needsLocationPermission =>
      _permissionStatus != null &&
      _permissionStatus != LocationPermissionStatus.granted;

  bool get _isAccurateFix =>
      _gpsAccuracy != null &&
      _gpsAccuracy! <= GameConfig.searchZoneMinAccuracyMeters;

  // The search zone only counts when the GPS fix is accurate enough to trust.
  bool get _isInSearchZone =>
      _hasCurrentPosition &&
      _isAccurateFix &&
      HintProgress.isWithinSearchZone(_currentDistance);

  String get _proximityLabel {
    if (!_hasCurrentPosition) return '📡 Waiting for a GPS fix…';
    if (!_isAccurateFix) {
      return '📍 Approximate distance only. Better GPS accuracy is needed to verify.';
    }
    if (_isInSearchZone) return '🎯 You are in the search zone! Look around.';
    if (_currentDistance <= GameConfig.gettingCloserThresholdMeters) {
      return '🔥 Getting closer! Keep going.';
    }
    return '❄️ Far. Keep moving toward the beacon.';
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final room = await ServiceLocator().huntRepository.getRoomByCode(
      widget.roomCode,
    );
    if (!mounted) return;

    setState(() {
      _room = room;
      if (room != null && room.participants.isNotEmpty) {
        final p = room.participants.firstWhere(
          (p) => p.id == _hunterId,
          orElse: () => HunterParticipant(
            id: _hunterId,
            name:
                ServiceLocator().authService.currentUser?.displayName ??
                'Hunter',
          ),
        );
        _currentDistance = p.distanceMeters;
        _hintsUnlocked = p.hintsUnlocked;
      }
    });

    if (room?.status == RoomStatus.completed) _showCompletedResult(room!);
    if (room?.isActive == true) _startHintTimer();

    _roomSubscription = ServiceLocator().huntRepository
        .streamRoom(widget.roomCode)
        .listen((r) {
          if (!mounted || r == null) return;
          setState(() {
            _room = r;
            final participants = r.participants.where((p) => p.id == _hunterId);
            if (participants.isNotEmpty &&
                participants.first.hintsUnlocked > _hintsUnlocked) {
              _hintsUnlocked = participants.first.hintsUnlocked;
            }
          });
          if (r.status == RoomStatus.completed) _showCompletedResult(r);
          if (r.isActive && _hintTimer == null) _startHintTimer();
        });

    _submissionSubscription = ServiceLocator().huntRepository
        .streamHunterSubmission(widget.roomCode, _hunterId)
        .listen((sub) {
          if (!mounted) return;
          setState(() => _mySubmission = sub);
        });

    _initGps();
  }

  void _showCompletedResult(HuntRoom room) {
    if (_didNavigateToResult) return;
    _didNavigateToResult = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WinnerScreen(
            winnerName: room.winnerName,
            winnerRole: room.winnerRole,
            huntName: room.hunt.name,
          ),
        ),
      );
    });
  }

  Future<void> _initGps() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    try {
      final status = await _locationService.checkPermission();
      if (status == LocationPermissionStatus.denied) {
        await _locationService.requestPermission();
      }
      final currentStatus = await _locationService.checkPermission();
      if (mounted) setState(() => _permissionStatus = currentStatus);
      if (currentStatus == LocationPermissionStatus.granted) {
        _positionSubscription = _locationService.positionStream.listen(
          (pos) {
            if (!mounted) return;
            // Poor-accuracy fixes are still used to show an approximate
            // distance; they just can't count as "in the search zone".
            _onPositionUpdate(pos);
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() => _locationMessage = 'GPS update failed: $error');
          },
        );
      } else {
        setState(() {
          _locationMessage = switch (currentStatus) {
            LocationPermissionStatus.denied =>
              'Location permission is required to calculate your distance.',
            LocationPermissionStatus.deniedForever =>
              'Enable location permission in your device settings to hunt.',
            LocationPermissionStatus.serviceDisabled =>
              'Turn on your device location services to hunt.',
            LocationPermissionStatus.granted => null,
          };
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _locationMessage = 'Could not start GPS updates: $error',
        );
      }
    }
  }

  Future<void> _requestLocationPermission() async {
    try {
      await _locationService.requestPermission();
    } catch (error) {
      debugPrint('Location permission request failed: $error');
    }
    if (mounted) await _initGps();
  }

  void _onPositionUpdate(PositionData pos) {
    if (_isUpdatingPosition) {
      _pendingPosition = pos;
      return;
    }
    _isUpdatingPosition = true;
    _lastPosition = pos;
    final accuracy = pos.accuracy;
    ServiceLocator().huntRepository
        .updateHunterPosition(
          roomCode: widget.roomCode,
          hunterId: _hunterId,
          latitude: pos.latitude,
          longitude: pos.longitude,
        )
        .then((proximity) {
          if (!mounted) return;
          setState(() {
            _currentDistance = proximity.distanceMeters;
            _bearing = proximity.bearingDegrees;
            _hasCurrentPosition = true;
            _gpsAccuracy = accuracy;
            _locationMessage = _isAccurateFix
                ? null
                : 'Low GPS accuracy (±${accuracy.round()}m), so this distance is approximate. '
                      'You need ±${GameConfig.searchZoneMinAccuracyMeters.round()}m or better to verify. '
                      'Laptops usually cannot do this; try a phone outdoors.';
            _unlockedHintTexts = proximity.unlockedHints;
            if (proximity.unlockedHints.length > _hintsUnlocked) {
              _hintsUnlocked = proximity.unlockedHints.length;
            }
          });
          _recomputeHints();
        })
        .catchError((Object error) {
          // Technical details go to the console, not the player's screen.
          debugPrint('updateHunterPosition failed: $error');
        })
        .whenComplete(() {
          _isUpdatingPosition = false;
          final pendingPosition = _pendingPosition;
          _pendingPosition = null;
          if (mounted && pendingPosition != null) {
            _onPositionUpdate(pendingPosition);
          }
        });
  }

  /// Ticks the persisted hunt-start schedule without writing on each tick.
  void _startHintTimer() {
    if (_hintTimer != null || _room?.isActive != true) return;
    _hintTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _recomputeHints();
      // Heartbeat: the GPS stream is silent while you stand still, but the
      // evidence rules need a recent lastActive (under 2 minutes).
      final last = _lastPosition;
      if (last != null) {
        _heartbeatTicks++;
        if (_heartbeatTicks >= 45) {
          _heartbeatTicks = 0;
          _onPositionUpdate(last);
        }
      }
    });
    // Compute immediately so the UI is correct before the first tick.
    _recomputeHints();
  }

  /// Recalculates timed and proximity unlocks from persisted room state.
  void _recomputeHints() {
    final progress = HintProgress.calculate(
      startedAt: _room?.startedAt,
      isWithinSearchZone: _isInSearchZone,
      totalHints: _room?.hunt.hints.length ?? 3,
      alreadyUnlocked: _hintsUnlocked,
    );
    if (progress.unlockedCount > _unlockedHintTexts.length) {
      _refreshUnlockedHints();
    }

    setState(() {
      _hintsUnlocked = progress.unlockedCount
          .clamp(0, _room?.hunt.hints.length ?? 3)
          .toInt();
      _nextHintIn = progress.timeUntilNextHint;
    });
  }

  Future<void> _refreshUnlockedHints() async {
    final now = DateTime.now();
    if (_isRefreshingHints ||
        (_lastHintRefreshAt != null &&
            now.difference(_lastHintRefreshAt!) <
                const Duration(seconds: 15))) {
      return;
    }
    _isRefreshingHints = true;
    _lastHintRefreshAt = now;
    try {
      final hints = await ServiceLocator().huntRepository.getUnlockedHints(
        roomCode: widget.roomCode,
        hunterId: _hunterId,
      );
      if (!mounted) return;
      setState(() {
        _unlockedHintTexts = hints;
        _hintsMessage = null;
        if (hints.length > _hintsUnlocked) _hintsUnlocked = hints.length;
      });
    } catch (error) {
      if (mounted) {
        debugPrint('Could not load unlocked hints: $error');
      }
    } finally {
      _isRefreshingHints = false;
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _hintTimer?.cancel();
    _roomSubscription?.cancel();
    _submissionSubscription?.cancel();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _openEvidenceSubmission() {
    if (!_hasCurrentPosition || !_isAccurateFix) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Waiting for an accurate GPS fix before you can verify the location.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EvidenceSubmissionDialog(
        roomCode: widget.roomCode,
        currentDistanceMeters: _currentDistance,
        questions: _room?.hunt.locationQuestions ?? const [],
      ),
    );
  }

  void _confirmExit() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Exit Hunt?', style: AppTextStyles.titleMedium),
        content: Text(
          'Are you sure you want to exit the active hunt? Your current distance progress will be saved.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Keep Hunting', style: AppTextStyles.labelMedium),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                (route) => false,
              );
            },
            child: Text('Exit', style: AppTextStyles.labelMedium),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hunt = _room?.hunt;
    final photoUrl = hunt?.referenceImageUrl;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmExit();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, size: 22),
            onPressed: _confirmExit,
          ),
          title: Column(
            children: [
              Text(
                hunt?.name ?? 'Active Hunt',
                style: AppTextStyles.titleSmall,
              ),
              Text(
                'Room: ${widget.roomCode}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _isInSearchZone
                    ? AppColors.mintLight
                    : AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _isInSearchZone
                        ? Icons.near_me_rounded
                        : Icons.explore_rounded,
                    size: 14,
                    color: _isInSearchZone
                        ? AppColors.mintDark
                        : AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isInSearchZone ? 'Search Zone' : 'Navigating',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: _isInSearchZone
                          ? AppColors.mintDark
                          : AppColors.primaryDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Animated Compass
                BeaconCompassWidget(
                  bearingDegrees: _bearing,
                  distanceMeters: _currentDistance,
                  size: 210,
                ),

                const SizedBox(height: 16),

                // Distance Readout Banner
                Center(
                  child: Column(
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: _hasCurrentPosition
                                  ? '${_currentDistance.toInt()}'
                                  : '—',
                              style: AppTextStyles.displayLarge.copyWith(
                                fontSize: 48,
                                fontWeight: FontWeight.w800,
                                color: _isInSearchZone
                                    ? AppColors.mint
                                    : AppColors.textPrimary,
                              ),
                            ),
                            TextSpan(
                              text: _hasCurrentPosition ? ' m' : '',
                              style: AppTextStyles.titleMedium.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_hasCurrentPosition && _gpsAccuracy != null)
                        Text(
                          '±${_gpsAccuracy!.round()}m GPS accuracy',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: _isAccurateFix
                                ? AppColors.mintDark
                                : AppColors.warning,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        _proximityLabel,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: _isInSearchZone
                              ? AppColors.mintDark
                              : AppColors.textSecondary,
                          fontWeight: _isInSearchZone
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                if (_needsLocationPermission) ...[
                  BeaconCard(
                    color: AppColors.primaryLight,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.location_searching_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Location access needed',
                              style: AppTextStyles.labelMedium.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          switch (_permissionStatus) {
                            LocationPermissionStatus.deniedForever =>
                              'Location is blocked. Click the location icon in your browser’s address bar '
                                  '(or enable it in your device settings), choose Allow, then tap the button below.',
                            LocationPermissionStatus.serviceDisabled =>
                              'Location services are turned off. Turn them on, then tap the button below.',
                            _ =>
                              'Allow location so Beacon can measure how far you are from the treasure.',
                          },
                          style: AppTextStyles.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        BeaconButton(
                          label: 'Allow Location',
                          variant: BeaconButtonVariant.primary,
                          icon: const Icon(
                            Icons.my_location_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: _requestLocationPermission,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else if (_locationMessage != null) ...[
                  BeaconCard(
                    color: AppColors.primaryLight,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_off_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _locationMessage!,
                            style: AppTextStyles.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                const SizedBox(height: 8),

                // Photo clue: what the hidden object looks like
                if (photoUrl != null && photoUrl.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Photo Clue', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    'This is what the hidden object looks like.',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  _buildPhotoClue(),
                  const SizedBox(height: 20),
                ],

                // Submission Status & Action Button
                if (_mySubmission != null && _mySubmission!.isPending) ...[
                  BeaconCard(
                    color: AppColors.primaryLight,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Answers Submitted for Review',
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Waiting for Hider to review your answers...',
                                style: AppTextStyles.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_mySubmission != null &&
                    _mySubmission!.isApproved) ...[
                  BeaconCard(
                    color: AppColors.mintLight,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              color: AppColors.mint,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Treasure Found & Verified! 🏆',
                                    style: AppTextStyles.labelMedium.copyWith(
                                      color: AppColors.mintDark,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Your answers have been approved by the Hider.',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        BeaconButton(
                          label: 'See Results 🏆',
                          variant: BeaconButtonVariant.mint,
                          onPressed: () {
                            final userName =
                                ServiceLocator()
                                    .authService
                                    .currentUser
                                    ?.displayName ??
                                'Hunter';
                            final huntName = hunt?.name ?? 'the hunt';
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => WinnerScreen(
                                  winnerName: userName,
                                  winnerRole: 'hunter',
                                  huntName: huntName,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ] else if (_mySubmission != null &&
                    _mySubmission!.isRejected) ...[
                  BeaconCard(
                    color: const Color(0xFFFFEBEE),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.cancel_rounded,
                              color: AppColors.error,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Answers Rejected by Hider',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Feedback: ${_mySubmission!.rejectionReason ?? "Some answers were not correct. Please try again."}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        BeaconButton(
                          label: 'Try Again 🎯',
                          variant: BeaconButtonVariant.primary,
                          onPressed: _openEvidenceSubmission,
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  BeaconButton(
                    label: _isInSearchZone
                        ? 'I Found It! Verify Location 🎯'
                        : 'Verify Location 🎯',
                    variant: _isInSearchZone
                        ? BeaconButtonVariant.mint
                        : BeaconButtonVariant.primary,
                    icon: const Icon(
                      Icons.quiz_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: _openEvidenceSubmission,
                  ),
                ],

                const SizedBox(height: 28),

                // Progressive Hints Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Progressive Hints', style: AppTextStyles.titleMedium),
                    if (_nextHintIn != null)
                      Text(
                        'Next in ${_formatDuration(_nextHintIn!)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Hints unlock at 1, 2, and 3 minutes after the hunt starts. '
                  'Within 30m, all remaining hints unlock immediately.',
                  style: AppTextStyles.bodySmall,
                ),
                if (_hintsMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _hintsMessage!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                if (hunt != null && hunt.hints.isNotEmpty) ...[
                  ...List.generate(hunt.hints.length, (index) {
                    final hint = hunt.hints[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: BeaconHintCard(
                        hint: hint,
                        tierNumber: index + 1,
                        isUnlocked:
                            index < _hintsUnlocked &&
                            index < _unlockedHintTexts.length,
                        currentDistanceMeters: _currentDistance,
                        revealedText: index < _unlockedHintTexts.length
                            ? _unlockedHintTexts[index]
                            : null,
                      ),
                    );
                  }),
                ] else ...[
                  const BeaconCard(
                    padding: EdgeInsets.all(16),
                    child: Text('No hints configured for this hunt.'),
                  ),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Widget _buildPhotoClue() {
    _photoFuture ??= ServiceLocator().huntRepository.getReferenceImage(
      widget.roomCode,
    );
    return FutureBuilder<Uint8List?>(
      future: _photoFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final bytes = snapshot.data;
        if (bytes == null) {
          return BeaconCard(
            color: AppColors.surfaceMuted,
            hasShadow: false,
            padding: const EdgeInsets.all(16),
            child: Text(
              'The photo clue could not be loaded.',
              style: AppTextStyles.bodySmall,
            ),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            bytes,
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

}