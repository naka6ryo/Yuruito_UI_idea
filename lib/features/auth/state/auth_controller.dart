import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

	void clearError() {
		if (state.errorMessage != null) {
			state = state.copyWith(errorMessage: null);
		}
	}

	String _japaneseMessageForAuthError(Object error) {
		if (error is FirebaseAuthException) {
			switch (error.code) {
				case 'invalid-email':
					return 'メールアドレスの形式が正しくありません。';
				case 'user-disabled':
					return 'このアカウントは無効化されています。';
				case 'user-not-found':
					return 'ユーザーが見つかりません。メールアドレスをご確認ください。';
				case 'wrong-password':
					return 'パスワードが正しくありません。';
				case 'too-many-requests':
					return '試行回数が多すぎます。しばらくしてから再度お試しください。';
				case 'network-request-failed':
					return 'ネットワークエラーが発生しました。通信環境をご確認ください。';
				case 'email-already-in-use':
					return 'このメールアドレスは既に使用されています。';
				case 'weak-password':
					return 'パスワードが安全ではありません。より複雑なパスワードを設定してください。';
				case 'operation-not-allowed':
					return 'この操作は現在許可されていません。管理者にお問い合わせください。';
				case 'invalid-credential':
					return '認証情報が無効です。メールアドレスとパスワードをご確認ください。';
				default:
					return 'エラーが発生しました（${error.code}）。しばらくしてから再度お試しください。';
			}
		}
		return '不明なエラーが発生しました。しばらくしてから再度お試しください。';
	}

	Future<void> login(String id, String password) async {
		// ローディング開始とエラーメッセージクリア
		state = state.copyWith(loading: true, errorMessage: null);
		final repo = ref.read(authRepositoryProvider);
		try {
			final user = await repo.login(id: id, password: password);
			state = AuthState(user: user, loading: false);
		} on FirebaseAuthException catch (e) {
			state = AuthState(user: null, loading: false, errorMessage: _japaneseMessageForAuthError(e));
		} catch (e) {
			// その他エラー
			state = AuthState(user: null, loading: false, errorMessage: _japaneseMessageForAuthError(e));
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
		} on FirebaseAuthException catch (e) {
			state = AuthState(user: null, loading: false, errorMessage: _japaneseMessageForAuthError(e));
		} catch (e) {
			state = AuthState(user: null, loading: false, errorMessage: _japaneseMessageForAuthError(e));
		}
	}

	Future<void> logout() async {
		state = state.copyWith(loading: true);
		final repo = ref.read(authRepositoryProvider);
		await repo.logout();
		state = const AuthState(user: null, loading: false);
	}
}