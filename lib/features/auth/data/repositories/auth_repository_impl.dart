import 'package:dio/dio.dart';
import 'package:tams_mobile/features/auth/data/datasources/auth_remote_datasource.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  const AuthRepositoryImpl(this._remote);

  @override
  Future<User> login(String email, String password) async {
    try {
      return await _remote.login(email, password);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.badResponse) {
        switch (e.response?.statusCode) {
          // Wrong password or unknown user (InvalidCredentialsException).
          case 401:
            throw const Failure('Incorrect email or password.');
          // Blocked account (UserBlockedException). The backend's message
          // says until when and why, so show it.
          case 403:
            throw Failure(
              Failure.serverMessage(e) ??
                  'Your account is blocked. Please contact an administrator.',
            );
        }
      }
      throw Failure.fromDio(e);
    } on FormatException {
      // 2xx, but not the login-mobile shape (wrong URL or backend changed).
      throw const Failure('Unexpected response from the server.');
    }
  }
}
