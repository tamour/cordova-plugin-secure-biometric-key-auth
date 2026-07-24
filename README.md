# cordova-plugin-secure-biometric-key-auth

<p align="center">
  <img src="assets/DeviceKey.png" alt="cordova-plugin-secure-biometric-key-auth logo" width="160" height="160">
</p>

<p align="center">
  <strong>Hardware-Backed Cryptographic Keys & Biometric Signing for Mobile Applications</strong>
</p>

<p align="center">
  <a href="https://cordova.apache.org/"><img src="https://img.shields.io/badge/Cordova-10.0%2B-blue.svg" alt="Cordova"></a>
  <a href="https://developer.apple.com/ios/"><img src="https://img.shields.io/badge/iOS-13.0%2B-lightgrey.svg" alt="iOS"></a>
  <a href="https://developer.android.com/"><img src="https://img.shields.io/badge/Android-API%2023%2B-green.svg" alt="Android"></a>
  <a href="https://www.outsystems.com/"><img src="https://img.shields.io/badge/OutSystems-Mobile-red.svg" alt="OutSystems"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License"></a>
</p>

---

## 🛠 Overview

`cordova-plugin-secure-biometric-key-auth` is a high-security Cordova plugin designed for iOS and Android (and optimized for **OutSystems Mobile**). 

It generates hardware-backed, non-exportable asymmetric Elliptic Curve key pairs (EC P-256) directly inside the **Secure Enclave** (iOS) and **Hardware TEE / StrongBox** (Android). These keys serve as digital device certificates for secure biometric enrollment and passwordless authentication flows.

Private keys are protected behind native biometrics (**Face ID**, **Touch ID**, or **BiometricPrompt**) and never leave the hardware coprocessor under any circumstances.

---

## ✨ Features

* 📜 **Digital Certificate Creation:** Generates 256-bit Elliptic Curve (`secp256r1`) key pairs bound directly to dedicated security chips.
* 🐁 **Biometric Protection:** Requires Face ID / Touch ID (iOS) or BiometricPrompt (Android) to authorize signing operations using the private key.
* ✍️ **Challenge Signing:** Signs one-time server nonces/challenges using `ECDSA with SHA-256` to prove device identity without transmitting sensitive secrets.
* 🛡 **Non-Exportable Hardware Keys:** Private keys are cryptographically isolated in hardware and cannot be extracted, copied, or backed up.
* ⚡️ **OutSystems Mobile Ready:** Promises-based JavaScript bridge designed for seamless integration into OutSystems client actions.

---

## 📦 Installation

### OutSystems Mobile App (GitHub URL)

Add the repository URL directly to your OutSystems Application Module **Extensibility Configurations**:

```json
{
    "plugin": {
        "url": "https://github.com/tamour/cordova-plugin-secure-biometric-key-auth.git"
    }
}
```

---

## 🚀 API Reference

The plugin exposes the cordova.plugins.SecureBiometricKeyAuth interface. All methods use standard success and error callbacks:

### 1. `createKeyPair(alias)`

Generates a hardware-backed EC key pair locked behind biometric access control. Returns the Base64-encoded public key upon success. Overwrites any existing key with the same alias.

* Input: **`alias`** *(String)*: Unique identifier for the key stored in the native device Keychain/KeyStore.
* Output: **`PublicKey`** *(String)*: The Base64-encoded public key generated or retrieved from the device (iOS outputs raw ANSI X9.63 uncompressed point format, while Android outputs DER SubjectPublicKeyInfo format).
* Output: **`IsSuccess`** *(Boolean)*: Set to `true` if the key operation completed successfully, or `false` if an error occurred.
* Output: **`ErrorMessage`** *(String)*: Contains a detailed description of the error if `IsSuccess` is `false` (e.g., key generation failed, access denied); remains an empty string (`""`) on success.

---

### 2. `getPublicKey(alias)`

Retrieves an existing public key previously generated and stored in the hardware keystore.

* Input: **`alias`** *(String)*: Unique identifier of the target key pair.
* Output: **`PublicKey`** *(String)*: The Base64-encoded public key generated or retrieved from the device (iOS outputs raw ANSI X9.63 uncompressed point format, while Android outputs DER SubjectPublicKeyInfo format).
* Output: **`IsSuccess`** *(Boolean)*: Set to `true` if the key operation completed successfully, or `false` if an error occurred.
* Output: **`ErrorMessage`** *(String)*: Contains a detailed description of the error if `IsSuccess` is `false` (e.g., key generation failed, access denied); remains an empty string (`""`) on success.

---

### 3. `signChallenge(alias, challengeText, promptTitle)`

Prompts the system biometric dialog (Face ID / Fingerprint). Upon successful biometric verification, signs the provided server challenge string using the device's private key.

* Input: **`alias`** *(String)*: Unique identifier for the key stored in the native device Keychain/KeyStore.
* Input: **`challengeText`** *(String)*: The nonce or raw text payload sent by the server to be signed.
* Input: **`promptTitle`** *(String)*: The title displayed on the native system biometric dialog (e.g., `"Authenticate to Login"`).
* Output: **`Signature`** *(String)*: The Base64-encoded digital signature generated by the private key using `SHA256withECDSA` (ASN.1 DER format).
* Output: **`IsSuccess`** *(Boolean)*: Set to `true` if biometric authentication succeeded and the payload was signed, or `false` if the process failed or was canceled.
* Output: **`ErrorMessage`** *(String)*: Contains a detailed description of the error if `IsSuccess` is `false` (e.g., biometric prompt canceled by user, biometrics failed, key not found); remains an empty string (`""`) on success.

---

## 🔒 Security Specifications

| Platform | Key Storage Hardware | Signature Algorithm | Access Control |
| :--- | :--- | :--- | :--- |
| **iOS** | Secure Enclave (`kSecAttrTokenIDSecureEnclave`) | `ecdsaSignatureMessageX962SHA256` | `kSecAccessControlBiometryCurrentSet` |
| **Android** | AndroidKeyStore (TEE / StrongBox) | `SHA256withECDSA` | `setUserAuthenticationRequired(true)` |

---

## ⚙️ Platform Permissions

### iOS
Ensure your iOS app's `*-Info.plist` file includes the `NSFaceIDUsageDescription` key explaining why the app requests Face ID access:

```xml
<key>NSFaceIDUsageDescription</key>
<string>Authenticate using Face ID to unlock your secure key certificate and log in.</string>
```

### Android
Android requires biometric permissions declared in `AndroidManifest.xml` (handled automatically by `plugin.xml` during build):

```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
<uses-permission android:name="android.permission.USE_FINGERPRINT" />
```

## Important Note on Server-Side Verification

Because this plugin utilizes hardware-enforced **Elliptic Curve (EC)** keys (NIST P-256), the standard OutSystems `CryptoAPI` component cannot verify the signatures directly (as it primarily supports RSA).

To verify signatures on an OutSystems backend, you must build an **Integration Studio C# Extension** exposing a Server Action (`MssVerifyECDSASignature`).

### What the Server Action Does
1. **Inputs:** Takes the Base64-encoded `ssPublicKey`, `ssChallengeText` (nonce), and `ssSignature` sent from the mobile application.
2. **Signature Conversion (`ConvertDerToIeeeP1363`):** Parses the variable-length ASN.1 DER signature generated by iOS/Android and converts it into the fixed 64-byte IEEE P1363 format ($r$ and $s$ values) required by .NET Framework.
3. **Public Key Parsing (`ParseEcPublicKey`):** Extracts the 32-byte $X$ and $Y$ coordinates from both iOS (ANSI X9.63 point) and Android (DER SubjectPublicKeyInfo) public key formats into .NET `ECParameters`.
4. **Verification:** Imports the parameters into .NET's `ECDsa.Create()` engine and performs a SHA-256 verification against the challenge text, returning `ssIsValid = true` if the signature is valid.

### Platform Handled Differences
* **iOS Public Keys:** Outputs public keys as raw **ANSI X9.63** uncompressed points (65 bytes starting with `0x04`).
* **Android Public Keys:** Outputs public keys wrapped in **ASN.1 DER SubjectPublicKeyInfo** structure (typically 91 bytes).
* **Signatures (Both Platforms):** Both iOS and Android output signatures in **ASN.1 DER** format, which must be converted to **IEEE P1363** (raw 64-byte $r$ and $s$ values) before being passed to the .NET Framework verification engine.

---

## 📄 License

This project is licensed under the MIT License.