enum UserRole { waiter, admin, chef }

class AppUser {
  final String id;
  final String email;
  final String password;
  final UserRole role;
  final String? displayName;

  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    required this.password,
    this.displayName,
  });

  bool get isAdmin => role == UserRole.admin;

  factory AppUser.fromDoc(String id, Map<String, dynamic> m) {
    final roleStr = (m['role'] ?? 'waiter').toString().toLowerCase().trim();
    final role = switch (roleStr) {
      'admin' => UserRole.admin,
      'chef'  => UserRole.chef,
      _       => UserRole.waiter,
    };
    return AppUser(
      id: id,
      email: (m['email'] ?? '') as String,
      displayName: m['displayName'] as String?,
      role: role,
      password: (m['password'] ?? '') as String,
    );
  }
}


