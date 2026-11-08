import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/beacon_button.dart';
import '../../core/widgets/beacon_card.dart';
import '../../core/widgets/beacon_step_indicator.dart';
import '../../core/widgets/beacon_text_field.dart';
import '../../models/hint_item.dart';
import '../../models/hunt.dart';
import '../../services/location_service.dart';
import '../../services/service_locator.dart';
import 'hunt_created_screen.dart';

class CreateHuntScreen extends StatefulWidget {
  const CreateHuntScreen({super.key});

  @override
  State<CreateHuntScreen> createState() => _CreateHuntScreenState();
}

class _CreateHuntScreenState extends State<CreateHuntScreen> {
  int _currentStep = 0;

  // Step 1: Location state
  String _coordinates = '';
  final String _altitude = 'Unavailable';
  String _accuracy = 'Not captured';
  bool _isRefreshingLocation = false;
  bool _isCreatingHunt = false;
  String? _createError;

  // Step 2: Details state
  final TextEditingController _nameController = TextEditingController();
  HuntDifficulty _selectedDifficulty = HuntDifficulty.medium;
  final TextEditingController _rewardController = TextEditingController();

  // Step 2: Photo of the hidden object (shown to hunters)
  final ImagePicker _picker = ImagePicker();
  Uint8List? _photoBytes;
  static const bool _photoRequired = false;

  // Step 2: Location Questions & Expected Answers
  final List<TextEditingController> _questionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  final List<TextEditingController> _answerControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  // Step 3: Hints state
  final List<HintItem> _hints = HintItem.defaultHints();
  late final List<TextEditingController> _hintControllers;

  @override
  void initState() {
    super.initState();
    _hintControllers = [
      TextEditingController(),
      TextEditingController(),
      TextEditingController(),
    ];
    for (int i = 0; i < _hints.length; i++) {
      _hints[i].text = _hintControllers[i].text;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rewardController.dispose();
    for (final c in _hintControllers) {
      c.dispose();
    }
    for (final c in _questionControllers) {
      c.dispose();
    }
    for (final c in _answerControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // =================== PHOTO PICKING ===================
  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 900,
        maxHeight: 900,
        imageQuality: 60,
      );
      if (picked == null) return;
      final photoBytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => _photoBytes = photoBytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not select photo: $e')),
      );
    }
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_camera_rounded,
                color: AppColors.primary,
              ),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: AppColors.primary,
              ),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // =================== LOCATION ===================
  Future<void> _refreshLocation() async {
    setState(() => _isRefreshingLocation = true);

    late double lat;
    late double lng;
    late double accuracy;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() => _isRefreshingLocation = false);
        _showGpsError(
          'GPS service is disabled. Please enable Location in your device settings.',
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() => _isRefreshingLocation = false);
          _showGpsError('Location permission was denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _isRefreshingLocation = false);
        _showGpsError(
          'Location permission is permanently denied. Please enable it in app settings.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      lat = position.latitude;
      lng = position.longitude;
      accuracy = position.accuracy;
    } catch (error) {
      if (!mounted) return;
      setState(() => _isRefreshingLocation = false);
      _showGpsError('Could not get your location: $error');
      return;
    }

    if (!mounted) return;
    setState(() => _isRefreshingLocation = false);

    _showConfirmLocationDialog(lat, lng, accuracy);
  }

  void _showConfirmLocationDialog(double lat, double lng, double accuracy) {
    final isAccurate = accuracy <= 25.0;
    final latStr = '${lat.abs().toStringAsFixed(4)}° ${lat >= 0 ? "N" : "S"}';
    final lngStr = '${lng.abs().toStringAsFixed(4)}° ${lng >= 0 ? "E" : "W"}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Icons.gps_fixed_rounded,
              color: AppColors.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text('Set Treasure Location', style: AppTextStyles.titleMedium),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stand directly beside the hidden object before confirming:',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COORDINATES',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$latStr, $lngStr',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ACCURACY',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '± ${accuracy.toStringAsFixed(1)}m ${isAccurate ? "✅ Good signal" : "⚠️ Weak reading"}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isAccurate ? AppColors.mintDark : AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (!isAccurate) ...[
              const SizedBox(height: 10),
              Text(
                'Tip: High accuracy error detected. Ensure open view of the sky.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: AppTextStyles.labelMedium),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _coordinates = '$latStr, $lngStr';
                _accuracy = '± ${accuracy.toStringAsFixed(1)}m';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.mintDark,
                  content: Text(
                    'Confirmed Target Coordinates: $_coordinates',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            child: Text('Confirm Location', style: AppTextStyles.labelMedium),
          ),
        ],
      ),
    );
  }

  void _showGpsError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // =================== CREATE ===================
  Future<void> _onFinishCreate() async {
    if (_isCreatingHunt) return;

    // Sync hint controller values
    for (int i = 0; i < _hints.length; i++) {
      _hints[i].text = _hintControllers[i].text.trim();
    }

    if (LocationService.parseCoordinates(_coordinates) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capture a valid target location first.')),
      );
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      setState(() => _currentStep = 1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please give your treasure a name.')),
      );
      return;
    }

    for (int i = 0; i < _hints.length; i++) {
      if (_hints[i].text.isEmpty) {
        setState(() => _currentStep = 2);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please write Hint ${i + 1}.')),
        );
        return;
      }
    }

    if (_photoRequired && _photoBytes == null) {
      setState(() => _currentStep = 1); // jump back to Details
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a photo of the hidden object.'),
        ),
      );
      return;
    }

    // Validate all 3 questions and answers
    for (int i = 0; i < 3; i++) {
      if (_questionControllers[i].text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter Question ${i + 1}.')),
        );
        return;
      }
      if (_answerControllers[i].text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please enter the expected answer for Question ${i + 1}.',
            ),
          ),
        );
        return;
      }
    }

    final hunt = Hunt(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      code: Hunt.generateCode(),
      name: _nameController.text.trim().isEmpty
          ? 'Secret Treasure'
          : _nameController.text.trim(),
      locationCoordinates: _coordinates,
      difficulty: _selectedDifficulty,
      reward: _rewardController.text.trim().isEmpty
          ? null
          : _rewardController.text.trim(),
      hints: _hints,
      locationQuestions:
          _questionControllers.map((c) => c.text.trim()).toList(),
      locationAnswers:
          _answerControllers.map((c) => c.text.trim()).toList(),
    );

    final hider = ServiceLocator().authService.currentUser;
    final hiderId =
        hider?.uid ?? 'hider_${DateTime.now().millisecondsSinceEpoch}';
    final hiderName = hider?.displayName ?? 'Anonymous Hider';

    setState(() {
      _isCreatingHunt = true;
      _createError = null;
    });
    try {
      final room = await ServiceLocator().huntRepository.createHuntRoom(
        hunt: hunt,
        hiderId: hiderId,
        hiderName: hiderName,
        referenceImageBytes: _photoBytes,
      );

      if (!mounted) return;
      if (_photoBytes != null && room.hunt.referenceImageUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Hunt created, but your photo could not be saved (it may be too '
              'large), so hunters will not see it. Try a smaller photo next time.',
            ),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 10),
          ),
        );
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HuntCreatedScreen(hunt: room.hunt)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _createError = _describeCreateError(error));
    } finally {
      if (mounted) setState(() => _isCreatingHunt = false);
    }
  }

  String _describeCreateError(Object error) {
    final details = error.toString();
    final normalized = details.toLowerCase();
    if (normalized.contains('database') && normalized.contains('not found')) {
      return 'This Firebase project does not have a Cloud Firestore database yet. '
          'In Firebase Console, open project beacon-407bc → Firestore Database → '
          'Create database (Native mode). After it is created, deploy the app’s '
          'Firestore rules, then retry. No hunt was created.';
    }
    if (error is FirebaseException && error.plugin == 'firebase_storage') {
      return 'The photo could not be uploaded to Firebase Storage. In '
          'Firebase Console, confirm Storage is set up for project beacon-407bc '
          'and deploy storage.rules, then retry. Details: $details';
    }
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'Firebase denied the write. Deploy firestore.rules for project '
          'beacon-407bc and make sure you are signed in as the Hider. Details: $details';
    }
    if (error is FirebaseException && error.code == 'unavailable') {
      return 'Firestore is unavailable. Check your internet connection and that '
          'the default database exists in Firebase Console. Details: $details';
    }
    return 'Could not create the hunt: $details';
  }

  @override
  Widget build(BuildContext context) {
    const steps = [
      StepItem(title: 'Location', icon: Icons.my_location_rounded),
      StepItem(title: 'Details', icon: Icons.edit_note_rounded),
      StepItem(title: 'Hints', icon: Icons.lightbulb_outline_rounded),
      StepItem(title: 'Publish', icon: Icons.rocket_launch_rounded),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: const Text('Create a Hunt'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: BeaconStepIndicator(
                currentStep: _currentStep,
                steps: steps,
                onStepTapped: (stepIndex) {
                  setState(() => _currentStep = stepIndex);
                },
              ),
            ),

            // Step Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: _buildStepContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildLocationStep();
      case 1:
        return _buildDetailsStep();
      case 2:
        return _buildHintsStep();
      case 3:
      default:
        return _buildPublishStep();
    }
  }

  // =================== STEP 1: LOCATION ===================
  Widget _buildLocationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 1: Set Location', style: AppTextStyles.titleLarge),
        const SizedBox(height: 6),
        Text(
          'Stand where you plan to hide the cache and lock down the target coordinates.',
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: 20),

        // Location Captured Card
        BeaconCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Target Coordinates',
                            style: AppTextStyles.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.mintLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.gps_fixed_rounded,
                          size: 12,
                          color: AppColors.mintDark,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _coordinates.isEmpty ? 'Not Set' : _accuracy,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.mintDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Coordinates Value Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'COORDINATES',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textMuted,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _coordinates,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontFamily: 'monospace',
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Metadata row
              Row(
                children: [
                  Expanded(
                    child: _coordinateMetaItem(
                      Icons.radar_rounded,
                      'Accuracy',
                      _accuracy,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _coordinateMetaItem(
                      Icons.terrain_rounded,
                      'Altitude',
                      _altitude,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              BeaconButton(
                label: 'Use Current Location',
                variant: BeaconButtonVariant.secondary,
                isLoading: _isRefreshingLocation,
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                onPressed: _refreshLocation,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        BeaconCard(
          color: AppColors.mintLight.withValues(alpha: 0.5),
          hasShadow: false,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: AppColors.mintDark,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Hunters receive three timed hints after 1, 5, and 10 minutes. '
                  'Entering the 30m radius unlocks all remaining hints.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        BeaconButton(
          label: 'Continue to Details',
          icon: const Icon(
            Icons.arrow_forward_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => setState(() => _currentStep = 1),
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _coordinateMetaItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.labelSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =================== STEP 2: DETAILS ===================
  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 2: Treasure Details', style: AppTextStyles.titleLarge),
        const SizedBox(height: 6),
        Text(
          'Describe your treasure, add a photo of it, set the difficulty and an optional reward.',
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: 24),

        // Treasure Name Field
        BeaconTextField(
          label: 'Treasure Name',
          hintText: 'e.g. Whispering Pine Cache',
          controller: _nameController,
          prefixIcon: const Icon(
            Icons.inventory_2_outlined,
            color: AppColors.primary,
          ),
        ),

        const SizedBox(height: 24),

        // Photo of the hidden object
        _buildPhotoSection(),

        const SizedBox(height: 24),

        // Difficulty Section
        Text(
          'Difficulty Level',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),

        Row(
          children: HuntDifficulty.values.map((difficulty) {
            final isSelected = _selectedDifficulty == difficulty;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => setState(() => _selectedDifficulty = difficulty),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryLight
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          difficulty.icon,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          difficulty.label,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: isSelected
                                ? AppColors.primaryDark
                                : AppColors.textPrimary,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),

        // Optional Reward Field
        BeaconTextField(
          label: 'Optional Reward (or Message)',
          hintText: 'e.g. Handmade wooden coin or congratulatory note',
          controller: _rewardController,
          prefixIcon: const Icon(
            Icons.card_giftcard_rounded,
            color: AppColors.mint,
          ),
        ),

        const SizedBox(height: 24),

        // Location Verification Questions Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Location Verification Questions',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.mintLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '3 Required',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.mintDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Set 3 questions and correct answers about the physical surroundings. '
          'Hunters must answer all 3 when they reach the target location to verify their find.',
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: 14),

        for (int i = 0; i < 3; i++) ...[
          BeaconCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Question ${i + 1}',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        i == 0
                            ? 'e.g. Colour of a gate or fence'
                            : (i == 1
                                ? 'e.g. Text on a nearby sign'
                                : 'e.g. Nearest shop or landmark'),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                BeaconTextField(
                  label: 'Question',
                  hintText: i == 0
                      ? 'e.g. What colour is the gate near this location?'
                      : (i == 1
                            ? 'e.g. What is written on the nearby signboard?'
                            : 'e.g. What is the nearest landmark or shop?'),
                  controller: _questionControllers[i],
                ),
                const SizedBox(height: 10),
                BeaconTextField(
                  label: 'Correct Expected Answer (Hidden from Hunters)',
                  hintText: i == 0
                      ? 'e.g. Green'
                      : (i == 1 ? 'e.g. Park Entrance' : 'e.g. Coffee Shop'),
                  controller: _answerControllers[i],
                  prefixIcon: const Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.mintDark,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        const SizedBox(height: 32),

        // Step Navigation
        Row(
          children: [
            Expanded(
              child: BeaconButton(
                label: 'Back',
                variant: BeaconButtonVariant.secondary,
                onPressed: () => setState(() => _currentStep = 0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BeaconButton(
                label: 'Continue to Hints',
                onPressed: () => setState(() => _currentStep = 2),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Photo of the Hidden Object',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.mintLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _photoRequired ? 'Required' : 'Optional',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.mintDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Show hunters what they are looking for. Photograph the object only, '
          'not its hiding spot.',
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: 12),
        if (_photoBytes == null)
          InkWell(
            onTap: _showPhotoSourceSheet,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.add_a_photo_rounded,
                    size: 36,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 8),
                  Text('Tap to add photo', style: AppTextStyles.labelMedium),
                ],
              ),
            ),
          )
        else
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  _photoBytes!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  children: [
                    _photoActionButton(
                      Icons.edit_rounded,
                      _showPhotoSourceSheet,
                    ),
                    const SizedBox(width: 8),
                    _photoActionButton(
                      Icons.delete_outline_rounded,
                      () => setState(() => _photoBytes = null),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _photoActionButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  // =================== STEP 3: HINTS ===================
  Widget _buildHintsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 3: Timed Hints', style: AppTextStyles.titleLarge),
        const SizedBox(height: 6),
        Text(
          'Provide three hints. They unlock after 1, 5, and 10 minutes, or all at '
          'once when the Hunter enters the 30m radius.',
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: 20),

        _buildHintCard(
          index: 0,
          title: 'Hint 1',
          distanceLabel: 'After 1 minute',
          badgeColor: AppColors.mint,
          badgeBg: AppColors.mintLight,
          icon: Icons.filter_1_rounded,
          controller: _hintControllers[0],
          hintPlaceholder: 'Describe the general area or approach...',
        ),

        const SizedBox(height: 16),

        _buildHintCard(
          index: 1,
          title: 'Hint 2',
          distanceLabel: 'After 5 minutes',
          badgeColor: const Color(0xFFF77F00),
          badgeBg: const Color(0xFFFFF3E6),
          icon: Icons.filter_2_rounded,
          controller: _hintControllers[1],
          hintPlaceholder: 'Describe landmarks or nearby objects...',
        ),

        const SizedBox(height: 16),

        _buildHintCard(
          index: 2,
          title: 'Hint 3',
          distanceLabel: 'After 10 minutes',
          badgeColor: AppColors.primary,
          badgeBg: AppColors.primaryLight,
          icon: Icons.filter_3_rounded,
          controller: _hintControllers[2],
          hintPlaceholder:
              'Describe the precise hiding crevice or container...',
        ),

        const SizedBox(height: 32),

        Row(
          children: [
            Expanded(
              child: BeaconButton(
                label: 'Back',
                variant: BeaconButtonVariant.secondary,
                onPressed: () => setState(() => _currentStep = 1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BeaconButton(
                label: 'Review & Publish',
                onPressed: () => setState(() => _currentStep = 3),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildHintCard({
    required int index,
    required String title,
    required String distanceLabel,
    required Color badgeColor,
    required Color badgeBg,
    required IconData icon,
    required TextEditingController controller,
    required String hintPlaceholder,
  }) {
    return BeaconCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: badgeColor, size: 22),
                  const SizedBox(width: 8),
                  Text(title, style: AppTextStyles.titleSmall),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  distanceLabel,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: badgeColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          BeaconTextField(
            controller: controller,
            hintText: hintPlaceholder,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  // =================== STEP 4: PUBLISH ===================
  Widget _buildPublishStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 4: Ready to Publish', style: AppTextStyles.titleLarge),
        const SizedBox(height: 6),
        Text(
          'Double check your hunt details before publishing to your local world.',
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: 20),

        // Summary Card
        BeaconCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.inventory_2_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nameController.text.trim().isEmpty
                              ? 'Unnamed Treasure'
                              : _nameController.text.trim(),
                          style: AppTextStyles.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_selectedDifficulty.icon} ${_selectedDifficulty.label}',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Divider(height: 28, color: AppColors.borderLight),

              _reviewItem(Icons.pin_drop_rounded, 'Coordinates', _coordinates),
              const SizedBox(height: 10),
              _reviewItem(
                Icons.card_giftcard_rounded,
                'Reward',
                _rewardController.text.trim().isEmpty
                    ? 'No reward set (honor system)'
                    : _rewardController.text.trim(),
              ),
              const SizedBox(height: 10),
              _reviewItem(
                Icons.lightbulb_outline_rounded,
                'Clues Provided',
                '3 timed hints (1, 5, 10 minutes)',
              ),
              const SizedBox(height: 10),
              _reviewItem(
                Icons.photo_rounded,
                'Object Photo',
                _photoBytes == null ? 'Not added' : 'Added',
              ),

              if (_photoBytes != null) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _photoBytes!,
                    width: double.infinity,
                    height: 140,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        if (_createError != null) ...[
          BeaconCard(
            color: AppColors.primaryLight,
            hasShadow: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _createError!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Clues Preview Card
        BeaconCard(
          color: AppColors.surfaceMuted,
          hasShadow: false,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CLUE SNAPSHOT', style: AppTextStyles.labelSmall),
              const SizedBox(height: 10),
              _clueBullet('Hint 1 • 1 minute', _hintControllers[0].text),
              const SizedBox(height: 6),
              _clueBullet('Hint 2 • 5 minutes', _hintControllers[1].text),
              const SizedBox(height: 6),
              _clueBullet('Hint 3 • 10 minutes', _hintControllers[2].text),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Questions Preview Card
        BeaconCard(
          color: AppColors.surfaceMuted,
          hasShadow: false,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LOCATION QUESTIONS & ANSWERS (REVIEW)',
                style: AppTextStyles.labelSmall,
              ),
              const SizedBox(height: 10),
              for (int i = 0; i < 3; i++) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Q${i + 1}: ${_questionControllers[i].text}',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: AppColors.mintDark,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Expected: ${_answerControllers[i].text}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.mintDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 32),

        BeaconButton(
          label: _isCreatingHunt ? 'Creating Hunt...' : 'Create Hunt',
          isLoading: _isCreatingHunt,
          icon: const Icon(
            Icons.rocket_launch_rounded,
            color: Colors.white,
            size: 22,
          ),
          onPressed: _isCreatingHunt ? null : _onFinishCreate,
        ),

        const SizedBox(height: 12),

        BeaconButton(
          label: 'Back to Edit',
          variant: BeaconButtonVariant.ghost,
          onPressed: () => setState(() => _currentStep = 2),
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _reviewItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(label, style: AppTextStyles.bodyMedium),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _clueBullet(String distance, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            distance,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text.isEmpty ? 'No text' : text,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}