package com.dentalcare.util;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit tests for TempPasswordGenerator
 */
class TempPasswordGeneratorTest {

    @Test
    void generate_returnsValidPasswordLength() {
        String password = TempPasswordGenerator.generate();
        assertEquals(6, password.length(), "Generated password should be exactly 6 characters");
    }

    @Test
    void generate_containsOnlyValidCharacters() {
        String password = TempPasswordGenerator.generate();
        String validChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        
        for (char c : password.toCharArray()) {
            assertTrue(validChars.indexOf(c) >= 0, 
                "Password should only contain alphanumeric uppercase characters");
        }
    }

    @Test
    void generate_returnsNonNull() {
        String password = TempPasswordGenerator.generate();
        assertNotNull(password, "Generated password should not be null");
    }

    @Test
    void generate_returnsNonEmpty() {
        String password = TempPasswordGenerator.generate();
        assertFalse(password.isEmpty(), "Generated password should not be empty");
    }

    @Test
    void generate_producesVariousPasswords() {
        // Generate multiple passwords and verify they are not all identical
        String password1 = TempPasswordGenerator.generate();
        String password2 = TempPasswordGenerator.generate();
        String password3 = TempPasswordGenerator.generate();
        
        // With 6 random characters from 36 possibilities, collisions are rare
        // Just verify at least one is different (statistically should have differences)
        boolean allIdentical = password1.equals(password2) && password2.equals(password3);
        assertFalse(allIdentical, 
            "Multiple generated passwords should not all be identical (extremely unlikely)");
    }

    @Test
    void generate_returnsUpperCaseOnly() {
        String password = TempPasswordGenerator.generate();
        String upperCase = password.toUpperCase();
        assertEquals(password, upperCase, "Generated password should be uppercase");
    }

    @Test
    void generate_isRepeatable() {
        // This tests that the method is deterministic (produces valid results on each call)
        for (int i = 0; i < 100; i++) {
            String password = TempPasswordGenerator.generate();
            assertEquals(6, password.length());
            assertNotNull(password);
            assertFalse(password.isEmpty());
        }
    }
}
