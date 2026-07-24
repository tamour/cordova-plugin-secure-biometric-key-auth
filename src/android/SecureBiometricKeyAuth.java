package com.outsystems.biometrickey;

import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;

import androidx.annotation.NonNull;
import androidx.biometric.BiometricPrompt;
import androidx.core.content.ContextCompat;
import androidx.fragment.app.FragmentActivity;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.KeyStore;
import java.security.PrivateKey;
import java.security.PublicKey;
import java.security.Signature;
import java.util.concurrent.Executor;

public class SecureBiometricKeyAuth extends CordovaPlugin {

    private static final String ANDROID_KEYSTORE = "AndroidKeyStore";

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        if ("createKeyPair".equals(action)) {
            String alias = args.getString(0);
            cordova.getThreadPool().execute(() -> createKeyPair(alias, callbackContext));
            return true;
        } else if ("getPublicKey".equals(action)) {
            String alias = args.getString(0);
            cordova.getThreadPool().execute(() -> getPublicKey(alias, callbackContext));
            return true;
        } else if ("signChallenge".equals(action)) {
            String alias = args.getString(0);
            String challengeText = args.getString(1);
            String promptTitle = args.length() > 2 ? args.getString(2) : "Authenticate to Login";
            cordova.getActivity().runOnUiThread(() -> signChallenge(alias, challengeText, promptTitle, callbackContext));
            return true;
        }
        return false;
    }

    private void createKeyPair(String alias, CallbackContext callbackContext) {
        try {
            KeyPairGenerator keyPairGenerator = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, ANDROID_KEYSTORE);
            keyPairGenerator.initialize(
                    new KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_SIGN | KeyProperties.PURPOSE_VERIFY)
                            .setDigests(KeyProperties.DIGEST_SHA256)
                            .setUserAuthenticationRequired(true)
                            .build());

            KeyPair keyPair = keyPairGenerator.generateKeyPair();
            String base64PublicKey = Base64.encodeToString(keyPair.getPublic().getEncoded(), Base64.NO_WRAP);
            sendResult(callbackContext, true, "PublicKey", base64PublicKey, "");
        } catch (Exception e) {
            sendResult(callbackContext, false, "PublicKey", "", "Failed to generate key: " + e.getMessage());
        }
    }

    private void getPublicKey(String alias, CallbackContext callbackContext) {
        try {
            KeyStore keyStore = KeyStore.getInstance(ANDROID_KEYSTORE);
            keyStore.load(null);
            PublicKey publicKey = keyStore.getCertificate(alias).getPublicKey();
            String base64PublicKey = Base64.encodeToString(publicKey.getEncoded(), Base64.NO_WRAP);
            sendResult(callbackContext, true, "PublicKey", base64PublicKey, "");
        } catch (Exception e) {
            sendResult(callbackContext, false, "PublicKey", "", "Key not found: " + e.getMessage());
        }
    }

    private void signChallenge(String alias, String challengeText, String promptTitle, CallbackContext callbackContext) {
        try {
            KeyStore keyStore = KeyStore.getInstance(ANDROID_KEYSTORE);
            keyStore.load(null);
            PrivateKey privateKey = (PrivateKey) keyStore.getKey(alias, null);

            if (privateKey == null) {
                sendResult(callbackContext, false, "Signature", "", "Private key not found.");
                return;
            }

            Signature signature = Signature.getInstance("SHA256withECDSA");
            signature.initSign(privateKey);
            BiometricPrompt.CryptoObject cryptoObject = new BiometricPrompt.CryptoObject(signature);

            Executor executor = ContextCompat.getMainExecutor(cordova.getActivity());
            BiometricPrompt biometricPrompt = new BiometricPrompt((FragmentActivity) cordova.getActivity(), executor, new BiometricPrompt.AuthenticationCallback() {
                @Override
                public void onAuthenticationSucceeded(@NonNull BiometricPrompt.AuthenticationResult result) {
                    super.onAuthenticationSucceeded(result);
                    try {
                        Signature authSignature = result.getCryptoObject().getSignature();
                        authSignature.update(challengeText.getBytes());
                        byte[] sigBytes = authSignature.sign();
                        String base64Signature = Base64.encodeToString(sigBytes, Base64.NO_WRAP);
                        sendResult(callbackContext, true, "Signature", base64Signature, "");
                    } catch (Exception e) {
                        sendResult(callbackContext, false, "Signature", "", "Signing failed: " + e.getMessage());
                    }
                }

                @Override
                public void onAuthenticationError(int errorCode, @NonNull CharSequence errString) {
                    super.onAuthenticationError(errorCode, errString);
                    sendResult(callbackContext, false, "Signature", "", "Biometric Error: " + errString);
                }
            });

            BiometricPrompt.PromptInfo promptInfo = new BiometricPrompt.PromptInfo.Builder()
                    .setTitle(promptTitle)
                    .setNegativeButtonText("Cancel")
                    .build();

            biometricPrompt.authenticate(promptInfo, cryptoObject);

        } catch (Exception e) {
            sendResult(callbackContext, false, "Signature", "", "Failed to initialize signing: " + e.getMessage());
        }
    }

    private void sendResult(CallbackContext callbackContext, boolean isSuccess, String key, String value, String errorMessage) {
        try {
            JSONObject result = new JSONObject();
            result.put("IsSuccess", isSuccess);
            result.put(key, value);
            result.put("ErrorMessage", errorMessage);
            
            if (isSuccess) {
                callbackContext.success(result);
            } else {
                callbackContext.error(result);
            }
        } catch (JSONException e) {
            callbackContext.error("JSON formatting error.");
        }
    }
}