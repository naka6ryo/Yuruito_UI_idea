import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/entities/user.dart';
import '../../../data/repositories/firebase_auth_repository.dart';


final authRepositoryProvider = Provider<AuthRepository>((ref) => FirebaseAuthRepository());


class AuthState {
final UserEntity? user;
final bool loading;
final String? errorMessage;
const AuthState({this.user, this.loading = false, this.errorMessage});


AuthState copyWith({UserEntity? user, bool? loading, String? errorMessage}) =>
AuthState(
user: user ?? this.user,
loading: loading ?? this.loading,
errorMessage: errorMessage,
);
}


final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
	return AuthController(ref);
});


class AuthController extends StateNotifier<AuthState> {
	final Ref ref;
	AuthController(this.ref) : super(const AuthState());

	Future<void> login(String id, String password) async {
		// ローディング開始とエラーメッセージクリア
		state = state.copyWith(loading: true, errorMessage: null);
		final repo = ref.read(authRepositoryProvider);
		try {
			final user = await repo.login(id: id, password: password);
			state = AuthState(user: user, loading: false);
		} catch (e) {
			// エラー時はメッセージを表示
			state = AuthState(user: null, loading: false, errorMessage: e.toString());
		}
	}

	Future<void> signup({
		required String email,
		required String password,
		required String name,
		String? avatarUrl,
	}) async {
		state = state.copyWith(loading: true, errorMessage: null);
		final repo = ref.read(authRepositoryProvider);
		try {
			final user = await repo.signup(email: email, password: password, name: name, avatarUrl: avatarUrl);
			state = AuthState(user: user, loading: false);
		} catch (e) {
			state = AuthState(user: null, loading: false, errorMessage: e.toString());
		}
	}

	Future<void> logout() async {
		state = state.copyWith(loading: true);
		final repo = ref.read(authRepositoryProvider);
		await repo.logout();
		state = const AuthState(user: null, loading: false);
	}
}