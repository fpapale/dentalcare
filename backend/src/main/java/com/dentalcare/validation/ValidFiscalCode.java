package com.dentalcare.validation;

import jakarta.validation.Constraint;
import jakarta.validation.Payload;
import java.lang.annotation.*;

@Documented
@Constraint(validatedBy = FiscalCodeValidator.class)
@Target({ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
public @interface ValidFiscalCode {
    String message() default "Codice fiscale non valido o non coerente con la data di nascita";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}
