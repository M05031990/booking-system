enum UserRole { customer, rider }

class AppUser {
  const AppUser({required this.uid, required this.name, required this.role});

  final String uid;
  final String name;
  final UserRole role;

  bool get isRider => role == UserRole.rider;

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) => AppUser(
    uid: uid,
    name: data['name'] as String? ?? '',
    role: data['role'] == 'rider' ? UserRole.rider : UserRole.customer,
  );

  Map<String, dynamic> toMap() => {'name': name, 'role': role.name};
}
