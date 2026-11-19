import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/alert.dart';
import '../../domain/repositories/alerts_repository.dart';
import '../datasources/alerts_remote_datasource.dart';

class AlertsRepositoryImpl implements AlertsRepository {
  const AlertsRepositoryImpl(this._remote);

  final AlertsRemoteDataSource _remote;

  @override
  Future<AlertsPage> list({int page = 1}) async {
    try {
      return await _remote.list(page: page);
    } on DioException catch (e) {
      throw Failure.fromDio(e);
    } on FormatException {
      throw const Failure('Unexpected response from the server.');
    }
  }

  @override
  Future<void> markRead(String id) async {
    try {
      await _remote.markRead(id);
    } on DioException catch (e) {
      throw Failure.fromDio(e);
    }
  }
}
