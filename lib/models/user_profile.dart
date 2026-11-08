class UserProfile {
  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final bool isAnonymous;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.isAnonymous = false,
  });

  static const defaultHunter = UserProfile(
    uid: 'hunter_01',
    displayName: 'Alex Hunter',
    email: 'alex.hunter@example.com',
    photoUrl: null,
  );

  static const defaultHider = UserProfile(
    uid: 'hider_01',
    displayName: 'Sam Beacon',
    email: 'sam.beacon@example.com',
    photoUrl: null,
  );
}