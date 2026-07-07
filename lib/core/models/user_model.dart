class UserModel {
  final int id;
  final String username;
  final String displayName;
  final String email;
  final String? avatarUrl;
  final List<String> roles;

  const UserModel({
    required this.id,
    required this.username,
    required this.displayName,
    required this.email,
    this.avatarUrl,
    required this.roles,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // API wraps user fields under a 'user' key (login + me endpoints).
    final d = (json['user'] as Map<String, dynamic>?) ?? json;
    return UserModel(
      id: int.tryParse(d['id']?.toString() ?? '0') ?? 0,
      username: (d['user_login'] as String?)
          ?? (d['username'] as String?)
          ?? (d['display_name'] as String?)
          ?? '',
      displayName: d['display_name'] as String? ?? '',
      email: d['email'] as String? ?? '',
      avatarUrl: d['avatar_url'] as String?,
      roles: (d['roles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'display_name': displayName,
        'email': email,
        'avatar_url': avatarUrl,
        'roles': roles,
      };
}
