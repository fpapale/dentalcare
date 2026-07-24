package com.dentalcare.exception;

/**
 * Violazione di un vincolo semantico di scheduling che non è un conflitto di risorsa
 * (poltrona/medico già occupati, mappati su {@link AppointmentConflictException} → 409) ma una
 * regola di business sullo slot richiesto (es. paziente con severità anamnestica 'severa' deve
 * essere offerto solo l'ultimo slot della giornata). Mappata su 422 Unprocessable Entity da
 * {@link GlobalExceptionHandler}.
 */
public class SchedulingConstraintException extends RuntimeException {

    private final String code;

    public SchedulingConstraintException(String code, String message) {
        super(message);
        this.code = code;
    }

    public String getCode() {
        return code;
    }
}
