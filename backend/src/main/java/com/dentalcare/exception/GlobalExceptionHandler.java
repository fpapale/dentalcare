package com.dentalcare.exception;

import com.dentalcare.dto.ErrorResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.stream.Stream;

@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(ResourceNotFoundException.class)
    @ResponseStatus(HttpStatus.NOT_FOUND)
    public ErrorResponse handleNotFound(ResourceNotFoundException ex) {
        return new ErrorResponse("RESOURCE_NOT_FOUND", ex.getMessage());
    }

    @ExceptionHandler(PatientNotDeletableException.class)
    @ResponseStatus(HttpStatus.CONFLICT)
    public ErrorResponse handlePatientNotDeletable(PatientNotDeletableException ex) {
        return new ErrorResponse("PATIENT_NOT_DELETABLE", ex.getMessage());
    }

    @ExceptionHandler(CatalogItemInUseException.class)
    @ResponseStatus(HttpStatus.CONFLICT)
    public ErrorResponse handleCatalogItemInUse(CatalogItemInUseException ex) {
        return new ErrorResponse("CATALOG_ITEM_IN_USE", ex.getMessage());
    }

    @ExceptionHandler(AppointmentConflictException.class)
    @ResponseStatus(HttpStatus.CONFLICT)
    public ErrorResponse handleAppointmentConflict(AppointmentConflictException ex) {
        return new ErrorResponse(ex.getConflictType(), ex.getMessage());
    }

    @ExceptionHandler(BadCredentialsException.class)
    @ResponseStatus(HttpStatus.UNAUTHORIZED)
    public ErrorResponse handleBadCredentials(BadCredentialsException ex) {
        return new ErrorResponse("INVALID_CREDENTIALS", "Invalid credentials");
    }

    @ExceptionHandler(IllegalStateException.class)
    @ResponseStatus(HttpStatus.CONFLICT)
    public ErrorResponse handleIllegalState(IllegalStateException ex) {
        return new ErrorResponse("CONFLICT", ex.getMessage());
    }

    @ExceptionHandler(IllegalArgumentException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ErrorResponse handleIllegalArgument(IllegalArgumentException ex) {
        return new ErrorResponse("BAD_REQUEST", ex.getMessage());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ErrorResponse handleValidation(MethodArgumentNotValidException ex) {
        // I vincoli di classe (es. @ValidFiscalCode su CreatePatientRequest) non producono un
        // FieldError ma un errore globale: senza i global errors il chiamante riceve solo
        // "Dati non validi" e non ha modo di sapere cosa correggere.
        String message = Stream.concat(
                        ex.getBindingResult().getFieldErrors().stream()
                                .map(e -> e.getField() + ": " + e.getDefaultMessage()),
                        ex.getBindingResult().getGlobalErrors().stream()
                                .map(e -> e.getDefaultMessage()))
                .findFirst()
                .orElse("Dati non validi");
        return new ErrorResponse("VALIDATION_ERROR", message);
    }

    @ExceptionHandler(org.springframework.web.multipart.MaxUploadSizeExceededException.class)
    @ResponseStatus(HttpStatus.PAYLOAD_TOO_LARGE)
    public ErrorResponse handleMaxUploadSize(org.springframework.web.multipart.MaxUploadSizeExceededException ex) {
        return new ErrorResponse("FILE_TOO_LARGE", "Il file supera il limite di 50 MB");
    }

    @ExceptionHandler(Exception.class)
    @ResponseStatus(HttpStatus.INTERNAL_SERVER_ERROR)
    public ErrorResponse handleGeneric(Exception ex) {
        log.error("Unhandled exception", ex);
        return new ErrorResponse("INTERNAL_ERROR", ex.getMessage());
    }
}
