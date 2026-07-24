import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../application/entitlement_state.dart';

/// Backend-signed offline entitlement token — the local premium trust root
/// (doc §11.2 / backend doc §8.4). Format: `bv1.<b64url payload>.<b64url sig>`,
/// Ed25519 over `bv1.<payload>`.
///
/// TODO(deploy): replace with the real backend verifying key before launch.
/// With this placeholder no token verifies, which fails safe (= free tier).
const String kEntitlementPublicKeyHex =
    '0000000000000000000000000000000000000000000000000000000000000000';

class OfflineEntitlement {
  const OfflineEntitlement({
    required this.status,
    required this.products,
    required this.expiresAt,
  });

  final EntitlementStatus status;
  final List<String> products;
  final DateTime expiresAt;

  bool isValid(DateTime now) => now.isBefore(expiresAt);
}

List<int> _hexToBytes(String hex) => [
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ];

String _padB64(String s) => s.padRight((s.length + 3) & ~3, '=');

/// Returns the verified claim or null (bad format / bad signature / expired
/// handled by the caller via [OfflineEntitlement.isValid]).
Future<OfflineEntitlement?> verifyOfflineToken(String token) async {
  try {
    final parts = token.split('.');
    if (parts.length != 3 || parts[0] != 'bv1') return null;

    final message = utf8.encode('${parts[0]}.${parts[1]}');
    final signatureBytes = base64Url.decode(_padB64(parts[2]));
    final publicKey = SimplePublicKey(
      _hexToBytes(kEntitlementPublicKeyHex),
      type: KeyPairType.ed25519,
    );
    final ok = await Ed25519().verify(
      message,
      signature: Signature(signatureBytes, publicKey: publicKey),
    );
    if (!ok) return null;

    final payload = jsonDecode(utf8.decode(base64Url.decode(_padB64(parts[1]))))
        as Map<String, dynamic>;
    return OfflineEntitlement(
      status: EntitlementStatus.fromId(payload['status'] as String? ?? 'free'),
      products: (payload['products'] as List?)?.cast<String>() ?? const [],
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
          ((payload['exp'] as num?)?.toInt() ?? 0) * 1000),
    );
  } catch (_) {
    return null;
  }
}
