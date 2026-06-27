package com.dentalcare.security;

import org.junit.jupiter.api.Test;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;

import static org.junit.jupiter.api.Assertions.*;

class HmacVerifierTest {

    private String sign(byte[] body, String secret) throws Exception {
        Mac mac = Mac.getInstance("HmacSHA256");
        mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
        byte[] raw = mac.doFinal(body);
        StringBuilder sb = new StringBuilder();
        for (byte b : raw) sb.append(String.format("%02x", b));
        return sb.toString();
    }

    @Test
    void verify_acceptsValidSignature() throws Exception {
        HmacVerifier v = new HmacVerifier("secret");
        byte[] body = "{\"job_id\":\"j1\"}".getBytes(StandardCharsets.UTF_8);
        assertTrue(v.verify(body, sign(body, "secret")));
    }

    @Test
    void verify_rejectsTamperedSignature() {
        HmacVerifier v = new HmacVerifier("secret");
        byte[] body = "{\"job_id\":\"j1\"}".getBytes(StandardCharsets.UTF_8);
        assertFalse(v.verify(body, "deadbeef"));
    }

    @Test
    void verify_rejectsWrongKeySignature() throws Exception {
        HmacVerifier v = new HmacVerifier("secret");
        byte[] body = "{\"job_id\":\"j1\"}".getBytes(java.nio.charset.StandardCharsets.UTF_8);
        assertFalse(v.verify(body, sign(body, "wrong-secret")));
    }

    @Test
    void verify_acceptsUppercaseHexSignature() throws Exception {
        HmacVerifier v = new HmacVerifier("secret");
        byte[] body = "{\"job_id\":\"j1\"}".getBytes(java.nio.charset.StandardCharsets.UTF_8);
        assertTrue(v.verify(body, sign(body, "secret").toUpperCase()));
    }
}
