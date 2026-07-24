import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/di/providers.dart';
import '../../../core/error/log.dart';
import '../../../core/network/api_client.dart';
import '../../subscription/application/entitlement_controller.dart';

@immutable
class AuthState {
  const AuthState({required this.signedIn, this.email});

  final bool signedIn;
  final String? email;
}

/// Optional Google Sign-In → backend token exchange (doc §4, user decision:
/// app fully functional anonymously; sign-in adds sync + cross-device
/// restore). Fails gracefully when unconfigured.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final email = ref.watch(settingsRepositoryProvider).authEmail;
    return AuthState(signedIn: email != null, email: email);
  }

  Future<bool> signIn() async {
    try {
      final signIn = GoogleSignIn.instance;
      await signIn.initialize();
      final account = await signIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) return false;

      final data = await ref.read(apiClientProvider).googleLogin(idToken);
      if (data == null) return false;
      final tokens = ref.read(secureTokenStoreProvider);
      await tokens.setTokens(
        access: data['access_token'] as String,
        refresh: data['refresh_token'] as String,
      );
      await ref.read(settingsRepositoryProvider).setAuthEmail(account.email);
      state = AuthState(signedIn: true, email: account.email);
      // Account linking may carry entitlements across (backend doc §5.2).
      await ref.read(entitlementProvider.notifier).refreshFromServer();
      return true;
    } catch (e) {
      Log.d('google sign-in unavailable: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await ref.read(apiClientProvider).logout();
    await ref.read(settingsRepositoryProvider).setAuthEmail(null);
    state = const AuthState(signedIn: false);
  }
}

final authProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
