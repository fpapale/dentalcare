package com.dentalcare.security.crypto;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class ConfigMasterKeyProviderTest {

    private static final String VALID_HEX = "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff"; // 32 byte

    @Test
    void validHexProvides32Bytes() {
        ConfigMasterKeyProvider p = new ConfigMasterKeyProvider(VALID_HEX);
        assertEquals(32, p.masterKey().length);
    }

    @Test
    void blankKeyFailsFast() {
        assertThrows(IllegalStateException.class, () -> new ConfigMasterKeyProvider("  "));
    }

    @Test
    void wrongLengthFailsFast() {
        assertThrows(IllegalStateException.class, () -> new ConfigMasterKeyProvider("00112233")); // 4 byte
    }

    @Test
    void nonHexFailsFast() {
        assertThrows(IllegalStateException.class,
                () -> new ConfigMasterKeyProvider("zz".repeat(32)));
    }

    @Test
    void masterKeyReturnsDefensiveCopy() {
        ConfigMasterKeyProvider p = new ConfigMasterKeyProvider(VALID_HEX);
        byte[] a = p.masterKey();
        a[0] = 99;
        assertNotEquals(99, p.masterKey()[0]); // mutare il risultato non intacca lo stato
    }
}
