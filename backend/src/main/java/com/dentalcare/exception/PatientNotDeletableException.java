package com.dentalcare.exception;

public class PatientNotDeletableException extends RuntimeException {
    public PatientNotDeletableException(String message) {
        super(message);
    }
}
