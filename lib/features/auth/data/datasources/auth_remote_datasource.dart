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
    return UserModel.fromLoginResponse(res.data, fallbackEmail: email);
  }
}
