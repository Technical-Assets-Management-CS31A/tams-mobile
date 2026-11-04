import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tams_mobile/features/auth/data/models/datasources/auth_remote_datasource.dart';
import 'package:tams_mobile/features/auth/domain/repositories/auth_repository_impl.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/network/token_provider.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_usecase.dart';

// ---- dependency providers ----
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSource(ref.watch(dioProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(authRemoteDataSourceProvider)),
);

final loginUseCaseProvider = Provider<LoginUseCase>(
  (ref) => LoginUseCase(ref.watch(authRepositoryProvider)),
);

// ---- state ----
/// null = logged out, User = logged in.
class AuthController extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async => null; // TODO: restore saved session here

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await ref.read(loginUseCaseProvider)(email, password);
      ref.read(authTokenProvider.notifier).set(user.token);
      return user;
    });
  }

  void logout() {
    ref.read(authTokenProvider.notifier).clear();
    state = const AsyncData(null);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, User?>(AuthController.new);