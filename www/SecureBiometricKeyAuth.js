var exec = require('cordova/exec');

var SecureBiometricKeyAuth = {
    
    /**
     * Creates a new biometric-backed key pair.
     * @param {string} alias - The unique tag/alias for the key.
     * @param {function} successCallback - Receives { IsSuccess: true, PublicKey: "...", ErrorMessage: "" }
     * @param {function} errorCallback - Receives { IsSuccess: false, PublicKey: "", ErrorMessage: "..." }
     */
    createKeyPair: function(alias, successCallback, errorCallback) {
        if (!alias) {
            errorCallback({ IsSuccess: false, PublicKey: "", ErrorMessage: "Alias is required." });
            return;
        }
        exec(successCallback, errorCallback, 'SecureBiometricKeyAuth', 'createKeyPair', [alias]);
    },

    /**
     * Retrieves the public key for an existing alias.
     * @param {string} alias - The unique tag/alias for the key.
     * @param {function} successCallback - Receives { IsSuccess: true, PublicKey: "...", ErrorMessage: "" }
     * @param {function} errorCallback - Receives { IsSuccess: false, PublicKey: "", ErrorMessage: "..." }
     */
    getPublicKey: function(alias, successCallback, errorCallback) {
        if (!alias) {
            errorCallback({ IsSuccess: false, PublicKey: "", ErrorMessage: "Alias is required." });
            return;
        }
        exec(successCallback, errorCallback, 'SecureBiometricKeyAuth', 'getPublicKey', [alias]);
    },

    /**
     * Signs a challenge string using the private key protected by biometrics.
     * @param {string} alias - The unique tag/alias for the key.
     * @param {string} challengeText - The challenge string to sign.
     * @param {string} promptTitle - The title shown on the OS biometric prompt.
     * @param {function} successCallback - Receives { IsSuccess: true, Signature: "...", ErrorMessage: "" }
     * @param {function} errorCallback - Receives { IsSuccess: false, Signature: "", ErrorMessage: "..." }
     */
    signChallenge: function(alias, challengeText, promptTitle, successCallback, errorCallback) {
        if (!alias || !challengeText) {
            errorCallback({ IsSuccess: false, Signature: "", ErrorMessage: "Alias and ChallengeText are required." });
            return;
        }
        promptTitle = promptTitle || "Authenticate to Login";
        exec(successCallback, errorCallback, 'SecureBiometricKeyAuth', 'signChallenge', [alias, challengeText, promptTitle]);
    }
};

module.exports = SecureBiometricKeyAuth;