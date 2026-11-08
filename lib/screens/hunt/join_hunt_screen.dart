import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/beacon_button.dart';
import '../../core/widgets/beacon_card.dart';
import '../../core/widgets/beacon_text_field.dart';
import '../../services/service_locator.dart';
import '../../models/participant.dart';
import '../../models/hunt_room.dart';
import '../lobby/lobby_screen.dart';

class JoinHuntScreen extends StatefulWidget {
  const JoinHuntScreen({super.key});

  @override
  State<JoinHuntScreen> createState() => _JoinHuntScreenState();
}

class _JoinHuntScreenState extends State<JoinHuntScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _hasError = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _onJoinPressed() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Please enter a hunt code';
      });
      return;
    }

    if (code.length < 4) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Hunt code must be at least 4 characters';
      });
      return;
    }

    final room = await ServiceLocator().huntRepository.getRoomByCode(code);
    if (room == null) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = 'No active hunt found with code "$code".';
      });
      return;
    }

    if (room.status == RoomStatus.completed) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = 'This hunt has already concluded.';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _hasError = false;
      _errorMessage = null;
    });

    _showFoundHuntModal(room.roomCode, room.hunt.name, '${room.hunt.difficulty.label} ${room.hunt.difficulty.icon}');
  }

  void _showFoundHuntModal(String code, String huntName, String difficulty) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
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
                    color: AppColors.mintLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.check_circle_outline_rounded,
                      color: AppColors.mint, size: 28),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hunt Located!', style: AppTextStyles.titleMedium),
                    Text('Code: $code',
                        style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            BeaconCard(
              color: AppColors.surfaceMuted,
              hasShadow: false,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _infoRow(Icons.inventory_2_outlined, 'Cache Name', huntName),
                  const Divider(height: 16, color: AppColors.borderLight),
                  _infoRow(Icons.speed_rounded, 'Difficulty', difficulty),
                  const Divider(height: 16, color: AppColors.borderLight),
                  _infoRow(Icons.lock_clock_outlined, 'Available Hints', '3 distance clues'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            BeaconButton(
              label: 'Join Hunt Lobby 🚀',
              variant: BeaconButtonVariant.mint,
              onPressed: () async {
                final user = ServiceLocator().authService.currentUser;
                final participant = HunterParticipant(
                  id: user?.uid ?? 'guest_${DateTime.now().millisecondsSinceEpoch}',
                  name: user?.displayName ?? 'Guest Hunter',
                  avatarUrl: user?.photoUrl,
                  distanceMeters: 300.0,
                  status: ParticipantStatus.waiting,
                );
                await ServiceLocator().huntRepository.joinRoom(
                  roomCode: code,
                  participant: participant,
                );
                if (!context.mounted) return;
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LobbyScreen(roomCode: code, isHider: false),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            BeaconButton(
              label: 'Close',
              variant: BeaconButtonVariant.ghost,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(title, style: AppTextStyles.bodyMedium),
        const Spacer(),
        Text(
          value,
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Join a Hunt'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Icon
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.mintLight,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.mint.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.travel_explore_rounded,
                      size: 40,
                      color: AppColors.mint,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Title
              Center(
                child: Text(
                  'Enter Hunt Code',
                  style: AppTextStyles.displayMedium.copyWith(fontSize: 26),
                ),
              ),

              const SizedBox(height: 8),

              Center(
                child: Text(
                  'Enter the secret 5-character code shared by the hunt creator to track down the treasure.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium,
                ),
              ),

              const SizedBox(height: 36),

              // Hunt Code Card
              BeaconCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HUNT CODE',
                      style: AppTextStyles.labelSmall.copyWith(
                        letterSpacing: 1.2,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    BeaconTextField(
                      controller: _codeController,
                      hintText: 'e.g. 7K3P9',
                      textCapitalization: TextCapitalization.characters,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.codeSnippet,
                      prefixIcon: const Icon(Icons.tag_rounded, color: AppColors.mint),
                      onChanged: (val) {
                        if (_hasError) {
                          setState(() {
                            _hasError = false;
                            _errorMessage = null;
                          });
                        }
                      },
                    ),
                    if (_hasError && _errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    BeaconButton(
                      label: 'Join Hunt',
                      variant: BeaconButtonVariant.mint,
                      icon: const Icon(Icons.radar_rounded, color: Colors.white, size: 20),
                      onPressed: _onJoinPressed,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}