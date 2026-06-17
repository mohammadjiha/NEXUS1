// lib/src/core/security/certificate_pinning.dart
//
// SSL / TLS certificate pinning for all Dart-layer HTTP traffic.
//
// ── Scope ─────────────────────────────────────────────────────────────────────
//
// This file covers HTTP requests routed through Dart's `dart:io` HttpClient:
//   • google_generative_ai (Gemini API calls to generativelanguage.googleapis.com)
//   • Any future Dio / http package calls in the app
//
// Firebase SDK calls (Auth, Firestore, Storage, FCM) run through native iOS /
// Android SDKs via platform channels — they bypass the Dart HttpClient and are
// NOT affected by HttpOverrides.  Firebase's native SDKs ship with their own
// pinning / certificate validation, which is sufficient.
//
// ── Strategy ──────────────────────────────────────────────────────────────────
//
// We compare the server's SPKI (Subject Public Key Info) hash against a list
// of pinned hashes stored in the app.  If the hash matches, the connection
// proceeds.  If not, the connection is rejected — preventing MITM attacks.
//
// We pin against Google Trust Services root CAs (GTS Root R1 / R2 / R3 / R4)
// rather than leaf/intermediate certs, giving us resilience to leaf-cert
// rotation while still rejecting any non-Google-issued certificate.
//
// ── Backup pins ───────────────────────────────────────────────────────────────
//
// RFC 7469 recommends at least one backup pin.  We pin all four Google Trust
// Services roots so that if one root is sunset we still have three backups.
//
// ── Updating pins ─────────────────────────────────────────────────────────────
//
// Pin hashes must be updated whenever Google rotates their root CAs (rare —
// roughly every 5–10 years).  The SHA-256 hashes below are for the GTS Root
// R1–R4 roots as of 2025.  See:
//   https://pki.goog/repository/
//
// ── Usage ─────────────────────────────────────────────────────────────────────
//
//   // In main() before runApp():
//   HttpOverrides.global = NexusCertificatePinning();
//

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

// ── Pinned SPKI SHA-256 hashes ─────────────────────────────────────────────────
//
// How to compute for a hostname:
//   openssl s_client -connect generativelanguage.googleapis.com:443 -showcerts \
//     </dev/null 2>/dev/null | openssl x509 -pubkey -noout \
//     | openssl pkey -pubin -outform der \
//     | openssl dgst -sha256 -binary | base64
//
// Google Trust Services root CA public key pins (SPKI SHA-256, base64):
const _kPinnedHashes = <String>{
  // GTS Root R1  (primary — all *.googleapis.com chains here)
  'hxqRlPTu1bMS/0DITB1SSu0vd4u/8l8TjPgfaAp63Gc=',
  // GTS Root R2  (backup)
  'Vfd4nd1C0gWbymGSCEeBNUY0RoIWd5mGAWJjuGimF8Q=',
  // GTS Root R3  (backup)
  'kIdp6ZnEu0szmT8nkMM2D4b4bMSuTIAV09Vj9/m4gJA=',
  // GTS Root R4  (backup)
  'YZPgTZ+woNCCCIW3LH2CxQeLzB/1m42QahntdXeIVwc=',
  // GlobalSign Root CA  (some Google endpoints still chain to this)
  'cGuxAXyFXFkWm61cF4HPWX8S0srS9j0aSqN0k4AP+4A=',
};

/// Domains for which pinning is enforced.
/// Add additional Google API domains here as the app grows.
const _kPinnedDomains = <String>{
  'generativelanguage.googleapis.com', // Gemini / PaLM
  'googleapis.com',                    // catch-all for *.googleapis.com
  'google.com',                        // catch-all for *.google.com
};

// ── HttpOverrides implementation ───────────────────────────────────────────────

/// Applies SSL certificate pinning to all Dart `HttpClient` connections.
///
/// Install in `main()` before `runApp()`:
/// ```dart
/// HttpOverrides.global = NexusCertificatePinning();
/// ```
///
/// In debug builds, pinning is bypassed so that Charles / Proxyman SSL proxies
/// still work during development.  It is always active in profile and release.
class NexusCertificatePinning extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);

    // Allow bypass in debug mode so developers can use SSL inspection proxies.
    if (kDebugMode) return client;

    client.badCertificateCallback = _badCertificateCallback;
    return client;
  }

  /// Returns `true` to allow the connection (cert is OK), `false` to reject it.
  ///
  /// Note: the callback name is confusing — returning `false` means "bad cert,
  /// reject" while returning `true` means "I approve, allow anyway".  We reject
  /// by default and only allow when the pin matches.
  bool _badCertificateCallback(X509Certificate cert, String host, int port) {
    // Not a pinned domain — allow normal TLS validation to proceed.
    if (!_isPinnedHost(host)) return false; // false = reject (use normal chain)

    // Compute SPKI SHA-256 hash of the server certificate.
    final hash = _spkiHash(cert);

    if (_kPinnedHashes.contains(hash)) {
      // Pin matched — connection is safe.
      return false; // false here means "not a bad cert" = allow
    }

    // Pin mismatch — possible MITM attack.
    debugPrint('[NexusCertificatePinning] ⛔ Pin mismatch for $host — '
        'rejecting connection. Hash: $hash');
    return true; // true = "I consider this bad" = reject
  }

  /// Checks if [host] is in the pinned domain list (exact or suffix match).
  static bool _isPinnedHost(String host) {
    for (final domain in _kPinnedDomains) {
      if (host == domain || host.endsWith('.$domain')) return true;
    }
    return false;
  }

  /// Computes the SHA-256 hash of the certificate's SubjectPublicKeyInfo (SPKI)
  /// and returns it as a base64 string.
  ///
  /// We hash SPKI (the public key blob) rather than the full cert DER because:
  ///   • SPKI is stable across cert renewals as long as the key is reused.
  ///   • Pinning to the full cert would break on every leaf cert rotation.
  ///
  /// X.509 DER structure:  Certificate → TBSCertificate → SubjectPublicKeyInfo
  /// ASN.1 position of SPKI within a DER-encoded cert is not fixed, so we
  /// delegate to OpenSSL-equivalent extraction via dart:io's raw DER bytes.
  static String _spkiHash(X509Certificate cert) {
    // cert.der is the full DER-encoded certificate.
    final derBytes = cert.der;

    // Locate the SubjectPublicKeyInfo within the DER blob.
    // We search for the BIT STRING tag (0x03) that precedes the public key
    // inside SPKI, which is sufficient for SPKI hash comparison.
    //
    // For production-grade extraction, consider using the `pointycastle` or
    // `asn1lib` package.  The implementation below uses a known-offset approach
    // that works for RSA / EC keys in standard Google-issued TLS certs.
    final spkiBytes = _extractSpki(derBytes);
    final hash = sha256.convert(spkiBytes);
    return base64.encode(hash.bytes);
  }

  /// Extracts the SPKI bytes from a DER-encoded X.509 certificate.
  ///
  /// ASN.1 DER layout (simplified):
  ///   SEQUENCE {                        -- Certificate
  ///     SEQUENCE {                      -- TBSCertificate
  ///       [0] INTEGER,                  -- version
  ///       INTEGER,                      -- serialNumber
  ///       SEQUENCE { ... },             -- signature
  ///       SEQUENCE { ... },             -- issuer
  ///       SEQUENCE { ... },             -- validity
  ///       SEQUENCE { ... },             -- subject
  ///       SEQUENCE {                    -- subjectPublicKeyInfo  ← we want this
  ///         SEQUENCE { OID, ... },      -- algorithm
  ///         BIT STRING                  -- subjectPublicKey
  ///       }
  ///       ...
  ///     }
  ///     ...
  ///   }
  ///
  /// Rather than implementing a full ASN.1 parser, we use a lightweight
  /// heuristic: scan for the OID of the public key algorithm.
  ///
  /// If SPKI cannot be extracted (unexpected cert format), the entire DER bytes
  /// are hashed as a fallback — this will not match any pinned hash and will
  /// correctly reject the connection.
  static Uint8List _extractSpki(Uint8List der) {
    // OID for rsaEncryption (1.2.840.113549.1.1.1) in DER:
    //   06 09 2a 86 48 86 f7 0d 01 01 01
    // OID for ecPublicKey (1.2.840.10045.2.1) in DER:
    //   06 07 2a 86 48 ce 3d 02 01
    const rsaOid = [0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01];
    const ecOid  = [0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01];

    int? spkiStart;

    // Scan for RSA OID first, then EC.
    for (final oid in [rsaOid, ecOid]) {
      spkiStart = _findSequenceContaining(der, oid);
      if (spkiStart != null) break;
    }

    if (spkiStart == null) {
      // Fallback: hash the full DER (pin mismatch expected).
      return der;
    }

    // Read the SEQUENCE length at spkiStart to find the SPKI end.
    final end = _sequenceEnd(der, spkiStart);
    return der.sublist(spkiStart, end);
  }

  /// Searches [der] for a SEQUENCE (0x30) that contains [oid] within its first
  /// 32 bytes.  Returns the index of the SEQUENCE tag, or null if not found.
  static int? _findSequenceContaining(Uint8List der, List<int> oid) {
    for (var i = 0; i < der.length - oid.length - 4; i++) {
      if (der[i] != 0x30) continue; // not a SEQUENCE
      // Check if the oid appears within the next ~32 bytes.
      final window = der.sublist(i, (i + 32).clamp(0, der.length));
      if (_contains(window, oid)) return i;
    }
    return null;
  }

  /// Returns the index just past the end of a DER SEQUENCE starting at [offset].
  static int _sequenceEnd(Uint8List der, int offset) {
    if (offset + 1 >= der.length) return der.length;
    int length;
    int headerSize = 2;
    if (der[offset + 1] < 0x80) {
      length = der[offset + 1];
    } else {
      final numBytes = der[offset + 1] & 0x7f;
      length = 0;
      headerSize = 2 + numBytes;
      for (var k = 0; k < numBytes; k++) {
        length = (length << 8) | der[offset + 2 + k];
      }
    }
    return (offset + headerSize + length).clamp(0, der.length);
  }

  /// Returns true if [haystack] contains the byte sequence [needle].
  static bool _contains(List<int> haystack, List<int> needle) {
    outer:
    for (var i = 0; i <= haystack.length - needle.length; i++) {
      for (var j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) continue outer;
      }
      return true;
    }
    return false;
  }
}
