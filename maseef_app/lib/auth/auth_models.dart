class AuthException implements Exception {
  const AuthException(this.code);

  final String code;
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.phone,
  });

  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String role;

  bool get isOwner => role == 'owner';

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final role = json['role'];
    final email = json['email'];
    final fullName = json['fullName'];
    final id = json['id'];
    if (id == null ||
        role is! String ||
        email is! String ||
        fullName is! String) {
      throw const AuthException('invalid_response');
    }
    if (role != 'customer' && role != 'owner' && role != 'admin') {
      throw const AuthException('invalid_response');
    }
    final phone = json['phone'];
    return AuthUser(
      id: id.toString(),
      fullName: fullName,
      email: email,
      phone: phone is String && phone.isNotEmpty ? phone : null,
      role: role,
    );
  }
}

class AuthSessionResult {
  const AuthSessionResult({required this.token, required this.user});

  final String token;
  final AuthUser user;
}
