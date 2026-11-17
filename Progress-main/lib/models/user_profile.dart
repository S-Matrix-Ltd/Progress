/// User-er registration/profile info.
/// Login-er por HomeScreen-er top header-e ei data dekhano hobe.
class UserProfile {
  String name;
  String employeeId;
  String company;
  String address;
  String username;
  String passwordHash;

  UserProfile({
    required this.name,
    required this.employeeId,
    required this.company,
    required this.address,
    required this.username,
    required this.passwordHash,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'employeeId': employeeId,
        'company': company,
        'address': address,
        'username': username,
        'passwordHash': passwordHash,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'] as String? ?? '',
        employeeId: json['employeeId'] as String? ?? '',
        company: json['company'] as String? ?? '',
        address: json['address'] as String? ?? '',
        username: json['username'] as String? ?? '',
        passwordHash: json['passwordHash'] as String? ?? '',
      );
}
