import 'dart:math';
import 'hint_item.dart';

enum HuntDifficulty {
  easy('Easy', '🟢'),
  medium('Medium', '🟡'),
  hard('Hard', '🔴');

  final String label;
  final String icon;
  const HuntDifficulty(this.label, this.icon);
}

class Hunt {
  final String id;
  final String code;
  final String name;
  final String locationCoordinates;
  final HuntDifficulty difficulty;
  final String? reward;
  final String? imagePath;
  final String? referenceImageUrl;
  final List<HintItem> hints;
  final List<String> locationQuestions;
  final List<String> locationAnswers;
  final DateTime createdAt;

  Hunt({
    required this.id,
    required this.code,
    required this.name,
    required this.locationCoordinates,
    required this.difficulty,
    this.reward,
    this.imagePath,
    this.referenceImageUrl,
    required this.hints,
    List<String>? locationQuestions,
    List<String>? locationAnswers,
    DateTime? createdAt,
  }) : locationQuestions = locationQuestions ?? defaultQuestions(),
       locationAnswers = locationAnswers ?? defaultAnswers(),
       createdAt = createdAt ?? DateTime.now();

  static List<String> defaultQuestions() => [
    'What colour is the gate near this location?',
    'What is the name written on the nearby signboard?',
    'What is the nearest landmark or shop?',
  ];

  static List<String> defaultAnswers() => [
    'Green',
    'Park Entrance',
    'Coffee Shop',
  ];

  Hunt copyWith({
    String? id,
    String? code,
    String? name,
    String? locationCoordinates,
    HuntDifficulty? difficulty,
    String? reward,
    String? imagePath,
    String? referenceImageUrl,
    List<HintItem>? hints,
    List<String>? locationQuestions,
    List<String>? locationAnswers,
    DateTime? createdAt,
  }) {
    return Hunt(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      locationCoordinates: locationCoordinates ?? this.locationCoordinates,
      difficulty: difficulty ?? this.difficulty,
      reward: reward ?? this.reward,
      imagePath: imagePath ?? this.imagePath,
      referenceImageUrl: referenceImageUrl ?? this.referenceImageUrl,
      hints: hints ?? this.hints,
      locationQuestions: locationQuestions ?? this.locationQuestions,
      locationAnswers: locationAnswers ?? this.locationAnswers,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static String generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(5, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  /// Kept for backward compatibility with Phase 1 mock code.
  static String generateSampleCode() => '7K3P9';
}
