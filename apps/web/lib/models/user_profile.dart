class UserProfile {
  final int userId;
  final String fullName;
  final String email;
  final String role;
  final String? skinType;

  const UserProfile({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    this.skinType,
  });

  bool get isAdmin => role == 'ADMIN';

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: (json['userId'] as num).toInt(),
      fullName: json['fullName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'CUSTOMER',
      skinType: json['skinType']?.toString(),
    );
  }
}

class AuthSession {
  final String accessToken;
  final UserProfile user;

  const AuthSession({required this.accessToken, required this.user});

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['accessToken']?.toString() ?? '',
      user: UserProfile.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
