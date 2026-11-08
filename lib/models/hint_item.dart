class HintItem {
  final String id;
  final String title;
  final String label; // alias for distanceLabel
  final String distanceLabel;
  final double unlockDistanceMeters; // double for distance comparison
  final int distanceMeters; // kept for backward compat
  String text;

  HintItem({
    String? id,
    String? title,
    String? label,
    String? distanceLabel,
    double? unlockDistanceMeters,
    int? distanceMeters,
    this.text = '',
  }) : id =
           id ??
           (title != null ? title.toLowerCase().replaceAll(' ', '_') : 'hint'),
       title = title ?? (label ?? 'Hint'),
       distanceLabel =
           distanceLabel ??
           (label ??
               '${(unlockDistanceMeters ?? distanceMeters ?? 100).toInt()}m away'),
       label =
           label ??
           (distanceLabel ??
               '${(unlockDistanceMeters ?? distanceMeters ?? 100).toInt()}m away'),
       distanceMeters =
           distanceMeters ?? (unlockDistanceMeters?.toInt() ?? 100),
       unlockDistanceMeters =
           unlockDistanceMeters ?? (distanceMeters?.toDouble() ?? 100.0);

  HintItem copyWith({
    String? id,
    String? title,
    String? label,
    String? distanceLabel,
    double? unlockDistanceMeters,
    int? distanceMeters,
    String? text,
  }) {
    return HintItem(
      id: id ?? this.id,
      title: title ?? this.title,
      label: label ?? this.label,
      distanceLabel: distanceLabel ?? this.distanceLabel,
      unlockDistanceMeters: unlockDistanceMeters ?? this.unlockDistanceMeters,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      text: text ?? this.text,
    );
  }

  static List<HintItem> defaultHints() {
    return [
      HintItem(
        id: 'hint_1',
        title: 'Hint 1',
        distanceLabel: 'After 1 minute',
        distanceMeters: 30,
        unlockDistanceMeters: 30.0,
        text: '',
      ),
      HintItem(
        id: 'hint_2',
        title: 'Hint 2',
        distanceLabel: 'After 2 minutes',
        distanceMeters: 30,
        unlockDistanceMeters: 30.0,
        text: '',
      ),
      HintItem(
        id: 'hint_3',
        title: 'Hint 3',
        distanceLabel: 'After 3 minutes',
        distanceMeters: 30,
        unlockDistanceMeters: 30.0,
        text: '',
      ),
    ];
  }
}
