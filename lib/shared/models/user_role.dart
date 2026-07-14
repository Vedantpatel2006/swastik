/// User role enumeration for role-based access control
enum UserRole {
  user('user'),
  admin('admin');

  const UserRole(this.value);

  final String value;

  /// Create UserRole from string value
  static UserRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'user':
      default:
        return UserRole.user;
    }
  }

  /// Check if this role has admin privileges
  bool get isAdmin => this == UserRole.admin;

  /// Check if this role is a regular user
  bool get isUser => this == UserRole.user;

  /// Get display name for the role
  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.user:
        return 'User';
    }
  }

  @override
  String toString() => value;
}
