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
    void missingFiscalCodeIsAllowed() {
        // Il CF e' opzionale: i canali che non possono raccoglierlo (assistente vocale, per
        // minimizzazione) devono poter registrare il paziente. Si completa allo sportello.
        assertTrue(validator.isValid(req(null, LocalDate.of(1980,1,1), false), null));
        assertTrue(validator.isValid(req("  ", LocalDate.of(1980,1,1), false), null));
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
    void nullForeignWithoutFiscalCodeIsAllowed() {
        // e' il payload reale dell'assistente vocale: nome, cognome, recapito e nient'altro
        assertTrue(validator.isValid(req(null, LocalDate.of(1980,1,1), null), null));
    }

    @Test
    void presentFiscalCodeIsStillValidatedWhenForeignIsNull() {
        // opzionale non vuol dire non validato: se c'e', deve essere corretto
        assertFalse(validator.isValid(req("NOTAVALIDCF1234", LocalDate.of(1980,1,1), null), null));
        assertTrue(validator.isValid(req("RSSMRA80A01H501U", LocalDate.of(1980,1,1), null), null));
    }
}
