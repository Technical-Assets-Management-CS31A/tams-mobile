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
      // Backend rejects bad credentials with a 4xx (usually 401; some
      // frameworks use 400/422). Show a friendly message instead of a code.
      final status = e.response?.statusCode;
      if (e.type == DioExceptionType.badResponse &&
          (status == 400 || status == 401 || status == 422)) {
        throw const Failure('Incorrect email or password.');
      }
      throw Failure.fromDio(e);
    }
  }
}