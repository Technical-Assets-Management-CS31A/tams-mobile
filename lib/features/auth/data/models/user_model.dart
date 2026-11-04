import '../../domain/entities/user.dart';

class UserModel extends User {
  const UserModel({required super.email, required super.token});

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        email: json['email'] as String,
        token: json['token'] as String,
      );

  Map<String, dynamic> toJson() => {'email': email, 'token': token};
}