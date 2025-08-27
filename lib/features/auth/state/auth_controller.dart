import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/entities/user.dart';
import '../../../data/repositories/auth_repository_stub.dart';


final authRepositoryProvider = Provider<AuthRepository>((ref) => StubAuthRepository());


class AuthState {
final UserEntity? user;
final bool loading;
const AuthState({this.user, this.loading = false});


AuthState copyWith({UserEntity? user, bool? loading}) =>
AuthState(user: user ?? this.user, loading: loading ?? this.loading);
}


final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
	return AuthController(ref);
});


class AuthController extends StateNotifier<AuthState> {
	final Ref ref;
	AuthController(this.ref) : super(const AuthState());

	Future<void> login(String id, String password) async {
		state = state.copyWith(loading: true);
		final repo = ref.read(authRepositoryProvider);
		final user = await repo.login(id: id, password: password);
		state = AuthState(user: user, loading: false);
	}

	Future<void> logout() async {
		state = state.copyWith(loading: true);
		final repo = ref.read(authRepositoryProvider);
		await repo.logout();
		state = const AuthState(user: null, loading: false);
	}
}