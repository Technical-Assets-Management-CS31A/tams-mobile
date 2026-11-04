import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository _repo;
  const LoginUseCase(this._repo);

  Future<User> call(String email, String password) =>
      _repo.login(email, password);
}