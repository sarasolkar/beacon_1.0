import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/game_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/beacon_button.dart';
import '../../core/widgets/beacon_card.dart';
import '../../core/widgets/beacon_text_field.dart';
import '../../models/hunt.dart';
import '../../services/service_locator.dart';

class EvidenceSubmissionDialog extends StatefulWidget {
  final String roomCode;
  final double currentDistanceMeters;
  final List<String> questions;

  const EvidenceSubmissionDialog({
    super.key,
    required this.roomCode,
    required this.currentDistanceMeters,
    this.questions = const [],
  });

  @override
  State<EvidenceSubmissionDialog> createState() =>
      _EvidenceSubmissionDialogState();
}

class _EvidenceSubmissionDialogState extends State<EvidenceSubmissionDialog> {
  late final List<TextEditingController> _answerControllers;
  List<String> _questions = [];
  bool _isLoadingQuestions = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  final ImagePicker _picker = ImagePicker();
  Uint8List? _photoBytes;

  @override
  void initState() {
    super.initState();
    _answerControllers = [
      TextEditingController(),
      TextEditingController(),
      TextEditingController(),
    ];

    if (widget.questions.isNotEmpty) {
      _questions = widget.questions;
    } else {
      _loadQuestions();
    }
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoadingQuestions = true);
    try {
      final room = await ServiceLocator().huntRepository.getRoomByCode(
        widget.roomCode,
      );
      if (mounted) {
        setState(() {
          _questions = room?.hunt.locationQuestions ?? Hunt.defaultQuestions();
          _isLoadingQuestions = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _questions = Hunt.defaultQuestions();
          _isLoadingQuestions = false;
        });
      }
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      // Kept small so it fits inside a Firestore document (free plan).
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 900,
        maxHeight: 900,
        imageQuality: 60,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photoBytes = bytes;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Could not select photo: $error');
    }
  }

  @override
  void dispose() {
    for (final c in _answerControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submitAnswers() async {
    if (widget.currentDistanceMeters > GameConfig.searchZoneRadiusMeters) {
      setState(() {
        _errorMessage =
            'Move within ${GameConfig.searchZoneRadiusMeters.toInt()}m before submitting verification.';
      });
      return;
    }

    for (int i = 0; i < 3; i++) {
      if (_answerControllers[i].text.trim().isEmpty) {
        setState(() {
          _errorMessage =
              'Please answer all 3 questions before submitting verification.';
        });
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final hunter = ServiceLocator().authService.currentUser;
      final hunterId = hunter?.uid ?? 'hunter_01';
      final hunterName = hunter?.displayName ?? 'Hunter';

      final success = await ServiceLocator().huntRepository.submitEvidence(
        roomCode: widget.roomCode,
        hunterId: hunterId,
        hunterName: hunterName,
        currentDistanceMeters: widget.currentDistanceMeters,
        questions: _questions,
        answers: _answerControllers.map((c) => c.text.trim()).toList(),
        photoBytes: _photoBytes,
      );

      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Could not submit your answers. Please try again.';
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Verification submission failed: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWithinProximity =
        widget.currentDistanceMeters <= GameConfig.searchZoneRadiusMeters;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.quiz_rounded,
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
                        'Verify Location',
                        style: AppTextStyles.titleMedium,
                      ),
                      Text(
                        'Answer the 3 questions to verify you found the location.',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Proximity Status Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isWithinProximity
                    ? AppColors.mintLight
                    : const Color(0xFFFFF3E6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isWithinProximity ? AppColors.mint : AppColors.warning,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isWithinProximity
                        ? Icons.verified_rounded
                        : Icons.radar_rounded,
                    color: isWithinProximity
                        ? AppColors.mintDark
                        : AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isWithinProximity
                              ? 'Within 30m • Ready to Verify'
                              : 'Proximity Check Pending',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: isWithinProximity
                                ? AppColors.mintDark
                                : AppColors.primaryDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          isWithinProximity
                              ? 'Current distance: ${widget.currentDistanceMeters.toInt()}m • Hider will review your answers'
                              : 'Current distance: ${widget.currentDistanceMeters.toInt()}m • Move within 30m to submit',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (_isLoadingQuestions)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else
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
                              vertical: 3,
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
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        i < _questions.length
                            ? _questions[i]
                            : 'Question ${i + 1}',
                        style: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      BeaconTextField(
                        label: 'Your Answer',
                        hintText: 'Type your answer here...',
                        controller: _answerControllers[i],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

            // Optional photo evidence, shown to the hider during review.
            BeaconCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Photo Evidence (optional)',
                    style: AppTextStyles.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add a photo of the hidden object. The hider will see it when reviewing.',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  if (_photoBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _photoBytes!,
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () => setState(() => _photoBytes = null),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Remove photo'),
                    ),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: BeaconButton(
                            label: 'Take Photo',
                            variant: BeaconButtonVariant.secondary,
                            icon: const Icon(
                              Icons.photo_camera_rounded,
                              size: 20,
                            ),
                            onPressed: _isSubmitting
                                ? null
                                : () => _pickPhoto(ImageSource.camera),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: BeaconButton(
                            label: 'Gallery',
                            variant: BeaconButtonVariant.secondary,
                            icon: const Icon(
                              Icons.photo_library_rounded,
                              size: 20,
                            ),
                            onPressed: _isSubmitting
                                ? null
                                : () => _pickPhoto(ImageSource.gallery),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 20,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 12),

            BeaconButton(
              label: 'Submit Answers for Review',
              variant: BeaconButtonVariant.mint,
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _submitAnswers,
            ),

            const SizedBox(height: 12),

            BeaconButton(
              label: 'Cancel',
              variant: BeaconButtonVariant.ghost,
              onPressed: () => Navigator.of(context).pop(),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}