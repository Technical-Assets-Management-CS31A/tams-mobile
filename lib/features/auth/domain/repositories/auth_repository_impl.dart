import 'package:dio/dio.dart';
import 'package:tams_mobile/features/auth/data/models/datasources/auth_remote_datasource.dart';

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
      throw Failure.fromDio(e);
    }
  }
}