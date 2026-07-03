package com.dentalcare.validation;

import com.dentalcare.dto.CreatePatientRequest;
import com.dentalcare.dto.UpdatePatientRequest;
import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;
import java.time.LocalDate;
import java.util.regex.Pattern;

public class FiscalCodeValidator implements ConstraintValidator<ValidFiscalCode, Object> {

    private static final Pattern CF = Pattern.compile(
            "^[A-Z]{6}[0-9]{2}[ABCDEHLMPRST][0-9]{2}[A-Z][0-9]{3}[A-Z]$");
    // Lettera mese CF → mese calendario
    private static final String MONTH_LETTERS = "ABCDEHLMPRST"; // Gen..Dic

    public boolean isValid(CreatePatientRequest r, ConstraintValidatorContext ctx) {
        return check(r.foreignPatient(), r.fiscalCode(), r.birthDate());
    }
    public boolean isValid(UpdatePatientRequest r, ConstraintValidatorContext ctx) {
        return check(r.foreignPatient(), r.fiscalCode(), r.birthDate());
    }

    @Override
    public boolean isValid(Object value, ConstraintValidatorContext ctx) {
        if (value instanceof CreatePatientRequest c) return isValid(c, ctx);
        if (value instanceof UpdatePatientRequest u) return isValid(u, ctx);
        return true;
    }

    private boolean check(Boolean foreign, String fiscalCode, LocalDate birthDate) {
        if (Boolean.TRUE.equals(foreign)) return true;          // straniero: skip
        if (fiscalCode == null || fiscalCode.isBlank()) return false; // italiano: obbligatorio
        String cf = fiscalCode.trim().toUpperCase();
        if (!CF.matcher(cf).matches()) return false;
        if (birthDate == null) return true;                     // formato ok, niente cross-check
        return matchesBirthDate(cf, birthDate);
    }

    private boolean matchesBirthDate(String cf, LocalDate birth) {
        int cfYear2 = Integer.parseInt(cf.substring(6, 8));
        char monthLetter = cf.charAt(8);
        int cfDay = Integer.parseInt(cf.substring(9, 11));
        int month = MONTH_LETTERS.indexOf(monthLetter) + 1;     // 1..12
        if (cfDay > 40) cfDay -= 40;                            // femmine +40
        if (month != birth.getMonthValue()) return false;
        if (cfDay != birth.getDayOfMonth()) return false;
        return cfYear2 == (birth.getYear() % 100);
    }
}
