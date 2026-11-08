import 'package:dio/dio.dart';
import 'package:tams_mobile/core/constants/api_constants.dart';
import 'package:tams_mobile/features/auth/data/models/user_model.dart';

class AuthRemoteDataSource {
  final Dio _dio;
  const AuthRemoteDataSource(this._dio);

  /// [identifier] can be the user's email or username; the backend matches
  /// either, case-insensitively.
  Future<UserModel> login(String identifier, String password) async {
    final res = await _dio.post(
      ApiConstants.loginPath,
      data: {'identifier': identifier, 'password': password},
    );
    return UserModel.fromLoginResponse(res.data);
  }
}
