package com.dentalcare.security.crypto;

import com.dentalcare.exception.EncryptionException;
import org.springframework.stereotype.Service;

import javax.crypto.Cipher;
import javax.crypto.Mac;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.Arrays;
import java.util.Base64;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Cifratura campo-per-campo con chiave derivata per-tenant.
 * enc_key = HKDF-SHA256(masterKey, salt=schema, info="dental-enc-v1", 32).
 * Formato: Base64(iv[12] || ciphertext || tag[16]) via AES/GCM/NoPadding.
 */
@Service
public class TenantEncryptionService {

    private static final String INFO_ENC = "dental-enc-v1";
    private static final int GCM_IV_BYTES = 12;
    private static final int GCM_TAG_BITS = 128;

    private final byte[] masterKey;
    private final SecureRandom random = new SecureRandom();
    private final Map<String, SecretKeySpec> encKeyCache = new ConcurrentHashMap<>();

    public TenantEncryptionService(MasterKeyProvider keyProvider) {
        this.masterKey = keyProvider.masterKey(); // fail-fast già nel provider
    }

    public String encrypt(String plaintext, String schema) {
        if (plaintext == null) return null;
        try {
            byte[] iv = new byte[GCM_IV_BYTES];
            random.nextBytes(iv);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, encKey(schema), new GCMParameterSpec(GCM_TAG_BITS, iv));
            byte[] ct = cipher.doFinal(plaintext.getBytes(StandardCharsets.UTF_8));
            byte[] out = new byte[iv.length + ct.length];
            System.arraycopy(iv, 0, out, 0, iv.length);
            System.arraycopy(ct, 0, out, iv.length, ct.length);
            return Base64.getEncoder().encodeToString(out);
        } catch (Exception e) {
            throw new EncryptionException("encrypt failed", e);
        }
    }

    public String decrypt(String ciphertext, String schema) {
        if (ciphertext == null) return null;
        try {
            byte[] raw = Base64.getDecoder().decode(ciphertext);
            byte[] iv = Arrays.copyOfRange(raw, 0, GCM_IV_BYTES);
            byte[] ct = Arrays.copyOfRange(raw, GCM_IV_BYTES, raw.length);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, encKey(schema), new GCMParameterSpec(GCM_TAG_BITS, iv));
            return new String(cipher.doFinal(ct), StandardCharsets.UTF_8);
        } catch (Exception e) {
            // tag invalido = chiave sbagliata o manomissione; nessun plaintext nel messaggio
            throw new EncryptionException("decrypt failed for schema " + schema, e);
        }
    }

    private SecretKeySpec encKey(String schema) {
        return encKeyCache.computeIfAbsent(schema,
                s -> new SecretKeySpec(hkdfSha256(masterKey, s.getBytes(StandardCharsets.UTF_8),
                        INFO_ENC.getBytes(StandardCharsets.UTF_8), 32), "AES"));
    }

    // HKDF-SHA256 (RFC 5869): extract + expand
    private static byte[] hkdfSha256(byte[] ikm, byte[] salt, byte[] info, int length) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            // extract
            mac.init(new SecretKeySpec(salt.length == 0 ? new byte[32] : salt, "HmacSHA256"));
            byte[] prk = mac.doFinal(ikm);
            // expand
            mac.init(new SecretKeySpec(prk, "HmacSHA256"));
            byte[] okm = new byte[length];
            byte[] t = new byte[0];
            int pos = 0;
            for (int i = 1; pos < length; i++) {
                mac.reset();
                mac.update(t);
                mac.update(info);
                mac.update((byte) i);
                t = mac.doFinal();
                int n = Math.min(t.length, length - pos);
                System.arraycopy(t, 0, okm, pos, n);
                pos += n;
            }
            return okm;
        } catch (Exception e) {
            throw new EncryptionException("hkdf failed", e);
        }
    }
}
