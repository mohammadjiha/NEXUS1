import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth_repository.dart';

final authControllerProvider =
    NotifierProvider<AuthController, AsyncValue<void>>(() {
      return AuthController();
    });

class LoginPasswordVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void toggle() => state = !state;
}

final loginPasswordVisibilityProvider =
    NotifierProvider<LoginPasswordVisibilityNotifier, bool>(
      () => LoginPasswordVisibilityNotifier(),
    );

class AuthController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<void> signIn(
    String email,
    String password, {
    String? requiredGymId,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .signInWithEmail(email, password, requiredGymId: requiredGymId),
    );
  }

  Future<void> signInWithGoogle({String? requiredGymId}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .signInWithGoogle(requiredGymId: requiredGymId),
    );
  }

  Future<void> signInWithApple({String? requiredGymId}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .signInWithApple(requiredGymId: requiredGymId),
    );
  }

  Future<void> signUp(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signUpWithEmail(email, password),
    );
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signOut(),
    );
  }
}
