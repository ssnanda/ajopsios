/// GET /ops/staff — administrators + aj_ops_user role members, used to
/// populate the Assignee dropdown on a service request.
class StaffModel {
  final int id;
  final String displayName;
  final String username;
  final String email;

  const StaffModel({
    required this.id,
    required this.displayName,
    required this.username,
    required this.email,
  });

  factory StaffModel.fromJson(Map<String, dynamic> json) {
    return StaffModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      displayName: json['display_name'] as String? ?? '',
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }
}
