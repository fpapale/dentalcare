package com.dentalcare.validation;

import com.dentalcare.dto.CreatePatientRequest;
import org.junit.jupiter.api.Test;
import java.time.LocalDate;
import static org.junit.jupiter.api.Assertions.*;

class FiscalCodeValidatorTest {

    private final FiscalCodeValidator validator = new FiscalCodeValidator();

    private CreatePatientRequest req(String cf, LocalDate birth, Boolean foreign) {
        return new CreatePatientRequest("Mario", "Rossi", cf, birth,
                null, null, null, null, null, null, null, null, foreign);
    }

    @Test
    void foreignPatientSkipsAllValidation() {
        assertTrue(validator.isValid(req("XYZ", LocalDate.of(1980,1,1), true), null));
        assertTrue(validator.isValid(req(null, null, true), null));
    }

    @Test
    void italianRequiresFiscalCode() {
        assertFalse(validator.isValid(req(null, LocalDate.of(1980,1,1), false), null));
        assertFalse(validator.isValid(req("  ", LocalDate.of(1980,1,1), false), null));
    }

    @Test
    void invalidFormatRejected() {
        assertFalse(validator.isValid(req("NOTAVALIDCF1234", LocalDate.of(1980,1,1), false), null));
    }

    @Test
    void validFormatWithMatchingDateAccepted() {
        // RSSMRA80A01H501U → uomo, 1980, gennaio(A), giorno 01
        assertTrue(validator.isValid(req("RSSMRA80A01H501U", LocalDate.of(1980,1,1), false), null));
    }

    @Test
    void dateMismatchRejected() {
        // CF dice 1980-01-01, birthDate 1990 → mismatch
        assertFalse(validator.isValid(req("RSSMRA80A01H501U", LocalDate.of(1990,1,1), false), null));
    }

    @Test
    void nullForeignTreatedAsItalian() {
        assertFalse(validator.isValid(req(null, LocalDate.of(1980,1,1), null), null));
    }
}
