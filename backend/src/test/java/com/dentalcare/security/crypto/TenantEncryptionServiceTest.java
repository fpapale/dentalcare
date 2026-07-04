package com.dentalcare.security.crypto;

import com.dentalcare.exception.EncryptionException;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class TenantEncryptionServiceTest {

    // master key fissa per i test
    private final MasterKeyProvider mk = () -> new byte[]{
            1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,
            17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32};
    private final TenantEncryptionService enc = new TenantEncryptionService(mk);

    @Test
    void roundTrip() {
        String c = enc.encrypt("1980-01-31", "t_9d754153");
        assertNotEquals("1980-01-31", c);
        assertEquals("1980-01-31", enc.decrypt(c, "t_9d754153"));
    }

    @Test
    void nullAndBlankPassThrough() {
        assertNull(enc.encrypt(null, "t_9d754153"));
        assertNull(enc.decrypt(null, "t_9d754153"));
    }

    @Test
    void randomIvGivesDifferentCiphertextSamePlaintext() {
        String a = enc.encrypt("same", "t_9d754153");
        String b = enc.encrypt("same", "t_9d754153");
        assertNotEquals(a, b);                      // IV casuale
        assertEquals("same", enc.decrypt(a, "t_9d754153"));
        assertEquals("same", enc.decrypt(b, "t_9d754153"));
    }

    @Test
    void differentSchemaCannotDecrypt() {
        String c = enc.encrypt("secret", "t_9d754153");
        assertThrows(EncryptionException.class, () -> enc.decrypt(c, "t_abcdef12"));
    }

    @Test
    void tamperedCiphertextThrows() {
        String c = enc.encrypt("secret", "t_9d754153");
        String tampered = c.substring(0, c.length() - 2) + (c.endsWith("A") ? "B" : "A");
        assertThrows(EncryptionException.class, () -> enc.decrypt(tampered, "t_9d754153"));
    }
}
