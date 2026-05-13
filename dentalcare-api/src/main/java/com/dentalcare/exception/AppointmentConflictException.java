package com.dentalcare.exception;

public class AppointmentConflictException extends RuntimeException {

    private final String conflictType;

    public AppointmentConflictException(String conflictType, String message) {
        super(message);
        this.conflictType = conflictType;
    }

    public String getConflictType() {
        return conflictType;
    }
}
