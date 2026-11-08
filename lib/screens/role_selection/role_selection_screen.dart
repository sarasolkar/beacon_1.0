import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/beacon_card.dart';
import '../../models/hunt_room.dart';
import '../../services/service_locator.dart';
import '../hunt/create_hunt_screen.dart';
import '../hunt/join_hunt_screen.dart';
import '../auth/login_screen.dart';
import '../dashboard/hider_dashboard_screen.dart';
import '../hunt/hunt_mode_screen.dart';
import '../lobby/lobby_screen.dart';
import '../winner/winner_screen.dart';

final RouteObserver<ModalRoute<dynamic>> roleSelectionRouteObserver =
    RouteObserver<ModalRoute<dynamic>>();

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  void _signOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sign Out?', style: AppTextStyles.titleMedium),
        content: Text(
          'Are you sure you want to sign out of Beacon?',
          style: AppTextStyles.bodyMedium,
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
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ServiceLocator().authService.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: Text('Sign Out', style: AppTextStyles.labelMedium),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ServiceLocator().authService.currentUser;
    final displayName = user?.displayName ?? 'Explorer';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.explore_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Beacon',
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            displayName,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.mintLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.mint.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.mint,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Online',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.mintDark,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.logout_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        tooltip: 'Sign Out',
                        onPressed: () => _signOut(context),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Headline
              Text('Choose Your Path', style: AppTextStyles.displayMedium),

              const SizedBox(height: 8),

              Text(
                'Ready to venture outside? Hide a treasure for others or hunt for one nearby.',
                style: AppTextStyles.bodyMedium,
              ),

              const SizedBox(height: 32),

              // Card 1: Hide an Object (Treasure Chest)
              _RoleCard(
                title: 'Hide an Object',
                description:
                    'Drop a real-world cache. Pin your location, write progressive hints, and challenge fellow hunters.',
                accentColor: AppColors.primary,
                lightAccentColor: AppColors.primaryLight,
                iconData: Icons.inventory_2_rounded,
                badgeLabel: 'Creator Mode',
                tags: const ['GPS Coordinates', '3 Clue Tiers', 'Photo Clue'],
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateHuntScreen()),
                  );
                },
              ),

              const SizedBox(height: 20),

              // Card 2: Join a Hunt (Compass / Binoculars)
              _RoleCard(
                title: 'Join a Hunt',
                description:
                    'Have an adventure code? Enter it to unlock clues, track the distance, and claim the treasure.',
                accentColor: AppColors.mint,
                lightAccentColor: AppColors.mintLight,
                iconData: Icons.travel_explore_rounded,
                badgeLabel: 'Hunter Mode',
                tags: const ['Code Entry', 'Distance Radar', 'Unlock Clues'],
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const JoinHuntScreen()),
                  );
                },
              ),

              const SizedBox(height: 32),

              _CurrentHuntsSection(userId: user?.uid),

              const SizedBox(height: 32),

              // Quick Info Note
              BeaconCard(
                color: AppColors.surfaceMuted,
                borderRadius: 18,
                hasShadow: false,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.tips_and_updates_outlined,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Pro tip: You can create a hunt now and share the 5-character code with friends anytime.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentHuntsSection extends StatefulWidget {
  final String? userId;

  const _CurrentHuntsSection({required this.userId});

  @override
  State<_CurrentHuntsSection> createState() => _CurrentHuntsSectionState();
}

class _CurrentHuntsSectionState extends State<_CurrentHuntsSection>
    with RouteAware {
  Future<List<HuntRoom>>? _huntsFuture;
  ModalRoute<dynamic>? _route;

  String _huntsErrorMessage(Object error) {
    if (error is TimeoutException) {
      return 'Loading your hunts timed out. Check your internet connection and retry.';
    }
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return 'Permission denied loading your hunts. Your session may have expired — sign out and sign back in.';
      }
      if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
        return 'Firebase is temporarily unavailable. Check your connection and retry.';
      }
      return 'Firebase could not load your hunts (${error.code}): '
          '${error.message ?? 'No additional details were provided.'}';
    }
    return error.toString();
  }

  @override
  void initState() {
    super.initState();
    _loadHunts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _route) return;
    if (_route != null) roleSelectionRouteObserver.unsubscribe(this);
    _route = route;
    if (route != null) roleSelectionRouteObserver.subscribe(this, route);
  }

  @override
  void didPopNext() {
    setState(_loadHunts);
  }

  @override
  void dispose() {
    roleSelectionRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _CurrentHuntsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _loadHunts();
  }

  void _loadHunts() {
    final userId = widget.userId;
    _huntsFuture = userId == null
        ? Future.value(const <HuntRoom>[])
        : ServiceLocator().huntRepository
              .getCurrentHuntsForUser(userId)
              .timeout(
                const Duration(seconds: 15),
                onTimeout: () => throw TimeoutException(
                  'Loading your hunts timed out. Check your connection and retry.',
                ),
              );
  }

  void _resumeHunt(HuntRoom room, String userId) {
    if (room.status == RoomStatus.completed) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WinnerScreen(
            winnerName: room.winnerName,
            huntName: room.hunt.name,
            winnerRole: room.winnerRole,
          ),
        ),
      );
      return;
    }
    final isHider = room.hiderId == userId;
    final Widget destination;
    if (isHider && room.status == RoomStatus.active) {
      destination = HiderDashboardScreen(roomCode: room.roomCode);
    } else if (!isHider && room.status == RoomStatus.active) {
      destination = HuntModeScreen(roomCode: room.roomCode);
    } else {
      destination = LobbyScreen(roomCode: room.roomCode, isHider: isHider);
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => destination));
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.userId;
    if (userId == null) return const SizedBox.shrink();

    return FutureBuilder<List<HuntRoom>>(
      future: _huntsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return BeaconCard(
            color: AppColors.primaryLight,
            hasShadow: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Could not load your hunts',
                  style: AppTextStyles.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  _huntsErrorMessage(snapshot.error!),
                  style: AppTextStyles.bodySmall,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(_loadHunts),
                    child: const Text('Retry'),
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final hunts = snapshot.data ?? const <HuntRoom>[];
        if (hunts.isEmpty) {
          return BeaconCard(
            color: AppColors.surfaceMuted,
            hasShadow: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No hunts yet', style: AppTextStyles.titleSmall),
                const SizedBox(height: 6),
                Text(
                  'Create a hunt or join one with a room code to see it here.',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CreateHuntScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: const Text('Create Hunt'),
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const JoinHuntScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.travel_explore_rounded),
                      label: const Text('Join Hunt'),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Current Hunts', style: AppTextStyles.titleMedium),
            const SizedBox(height: 12),
            ...hunts.map((room) {
              final isHider = room.hiderId == userId;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: BeaconCard(
                  onTap: () => _resumeHunt(room, userId),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.travel_explore_rounded,
                        color: AppColors.primary,
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              room.hunt.name,
                              style: AppTextStyles.labelMedium,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${isHider ? 'Hider' : 'Hunter'} • ${room.status.label} • ${room.roomCode}',
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String description;
  final Color accentColor;
  final Color lightAccentColor;
  final IconData iconData;
  final String badgeLabel;
  final List<String> tags;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.description,
    required this.accentColor,
    required this.lightAccentColor,
    required this.iconData,
    required this.badgeLabel,
    required this.tags,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BeaconCard(
      onTap: onTap,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Styled Icon Box
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: lightAccentColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(iconData, color: accentColor, size: 32),
                ),
              ),

              const Spacer(),

              // Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: lightAccentColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeLabel,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Text(title, style: AppTextStyles.titleLarge.copyWith(fontSize: 21)),

          const SizedBox(height: 8),

          Text(
            description,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 16),

          // Feature chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tag,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Action arrow
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Get Started',
                style: AppTextStyles.labelMedium.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, size: 18, color: accentColor),
            ],
          ),
        ],
      ),
    );
  }
}