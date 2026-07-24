import Foundation
import Security
import LocalAuthentication

@objc(SecureBiometricKeyAuth) class SecureBiometricKeyAuth: CDVPlugin {
    
    @objc(createKeyPair:)
    func createKeyPair(command: CDVInvokedUrlCommand) {
        guard let alias = command.arguments.first as? String else {
            sendResult(command: command, isSuccess: false, key: "PublicKey", value: "", errorMessage: "Invalid alias.")
            return
        }
        
        let tag = alias.data(using: .utf8)!
        
        // Delete existing key if it exists
        let queryDelete: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag
        ]
        SecItemDelete(queryDelete as CFDictionary)
        
        var accessControlError: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.biometryCurrentSet, .privateKeyUsage],
            &accessControlError
        ) else {
            sendResult(command: command, isSuccess: false, key: "PublicKey", value: "", errorMessage: "Failed to create access control.")
            return
        }
        
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tag,
                kSecAttrAccessControl as String: accessControl
            ]
        ]
        
        var createError: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &createError),
              let publicKey = SecKeyCopyPublicKey(privateKey) else {
            sendResult(command: command, isSuccess: false, key: "PublicKey", value: "", errorMessage: "Failed to generate key pair.")
            return
        }
        
        var exportError: Unmanaged<CFError>?
        if let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &exportError) as Data? {
            let base64Public = publicKeyData.base64EncodedString()
            sendResult(command: command, isSuccess: true, key: "PublicKey", value: base64Public, errorMessage: "")
        } else {
            sendResult(command: command, isSuccess: false, key: "PublicKey", value: "", errorMessage: "Failed to export public key.")
        }
    }
    
    @objc(getPublicKey:)
    func getPublicKey(command: CDVInvokedUrlCommand) {
        guard let alias = command.arguments.first as? String else {
            sendResult(command: command, isSuccess: false, key: "PublicKey", value: "", errorMessage: "Invalid alias.")
            return
        }
        
        let tag = alias.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, let privateKey = item as! SecKey?, let publicKey = SecKeyCopyPublicKey(privateKey) else {
            sendResult(command: command, isSuccess: false, key: "PublicKey", value: "", errorMessage: "Key not found.")
            return
        }
        
        var exportError: Unmanaged<CFError>?
        if let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &exportError) as Data? {
            sendResult(command: command, isSuccess: true, key: "PublicKey", value: publicKeyData.base64EncodedString(), errorMessage: "")
        } else {
            sendResult(command: command, isSuccess: false, key: "PublicKey", value: "", errorMessage: "Failed to export public key.")
        }
    }
    
    @objc(signChallenge:)
    func signChallenge(command: CDVInvokedUrlCommand) {
        guard let alias = command.arguments[0] as? String,
              let challengeText = command.arguments[1] as? String else {
            sendResult(command: command, isSuccess: false, key: "Signature", value: "", errorMessage: "Invalid arguments.")
            return
        }
        
        let tag = alias.data(using: .utf8)!
        let challengeData = challengeText.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true,
            kSecUseOperationPrompt as String: command.arguments.count > 2 ? (command.arguments[2] as? String ?? "Authenticate to sign") : "Authenticate to sign"
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, let privateKey = item as! SecKey? else {
            sendResult(command: command, isSuccess: false, key: "Signature", value: "", errorMessage: "Key not found or biometrics failed.")
            return
        }
        
        let algorithm: SecKeyAlgorithm = .ecdsaSignatureMessageX962SHA256
        guard SecKeyIsAlgorithmSupported(privateKey, .sign, algorithm) else {
            sendResult(command: command, isSuccess: false, key: "Signature", value: "", errorMessage: "Algorithm not supported.")
            return
        }
        
        var signError: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(privateKey, algorithm, challengeData as CFData, &signError) as Data? else {
            sendResult(command: command, isSuccess: false, key: "Signature", value: "", errorMessage: "Failed to sign challenge.")
            return
        }
        
        sendResult(command: command, isSuccess: true, key: "Signature", value: signature.base64EncodedString(), errorMessage: "")
    }
    
    private func sendResult(command: CDVInvokedUrlCommand, isSuccess: Bool, key: String, value: String, errorMessage: String) {
        let resultDict: [String: Any] = [
            "IsSuccess": isSuccess,
            key: value,
            "ErrorMessage": errorMessage
        ]
        let pluginResult = CDVPluginResult(status: isSuccess ? CDVCommandStatus_OK : CDVCommandStatus_ERROR, messageAs: resultDict)
        self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
    }
}