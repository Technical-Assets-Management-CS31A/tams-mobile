import 'package:dio/dio.dart';
import 'package:tams_mobile/core/constants/api_constants.dart';
import 'package:tams_mobile/features/auth/data/models/user_model.dart';


class AuthRemoteDataSource {
  final Dio _dio;
  const AuthRemoteDataSource(this._dio);

  Future<UserModel> login(String email, String password) async {
    final res = await _dio.post(
      ApiConstants.loginPath,
      data: {'email': email, 'password': password},
    );
    // TODO: replace with your real response parsing, e.g.
    // return UserModel.fromJson(res.data as Map<String, dynamic>);
    return UserModel.fromJson({
      'email': email,
      'token': 'fake-token-${res.data['id']}',
    });
  }
}