class UserModel {
  UserModel({
    this.id,
    required this.name,
    required this.email,
    required this.password,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final int? id;
  final String name;
  final String email;
  final String password;
  final DateTime createdAt;

  String get passwordHash => password;

  factory UserModel.fromMap(Map<String, Object?> map) {
    return UserModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      email: map['email'] as String,
      password: map['password'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    final map = <String, Object?>{
      'id': id,
      'name': name,
      'email': email,
      'password': password,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
    if (id == null) {
      map.remove('id');
    }
    return map;
  }

  UserModel copyWith({
    int? id,
    String? name,
    String? email,
    String? password,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
