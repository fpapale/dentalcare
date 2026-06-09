package com.dentalcare.exception;

import com.dentalcare.dto.ErrorResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.web.bind.MethodArgumentNotValidException;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for GlobalExceptionHandler
 */
class GlobalExceptionHandlerTest {

    private GlobalExceptionHandler handler;

    @BeforeEach
    void setUp() {
        handler = new GlobalExceptionHandler();
    }

    @Test
    void handleNotFound_returnsCorrectErrorResponse() {
        // Arrange
        String message = "Patient not found";
        ResourceNotFoundException exception = new ResourceNotFoundException(message);

        // Act
        ErrorResponse response = handler.handleNotFound(exception);

        // Assert
        assertNotNull(response);
        assertEquals("RESOURCE_NOT_FOUND", response.code());
        assertEquals(message, response.message());
    }

    @Test
    void handleAppointmentConflict_returnsCorrectErrorResponse() {
        // Arrange
        String conflictType = "APPOINTMENT_OVERLAP";
        String message = "Appointment overlaps with existing booking";
        AppointmentConflictException exception = new AppointmentConflictException(
            conflictType, message
        );

        // Act
        ErrorResponse response = handler.handleAppointmentConflict(exception);

        // Assert
        assertNotNull(response);
        assertEquals(conflictType, response.code());
        assertEquals(message, response.message());
    }

    @Test
    void handleBadCredentials_returnsUnauthorizedResponse() {
        // Arrange
        BadCredentialsException exception = new BadCredentialsException("Wrong password");

        // Act
        ErrorResponse response = handler.handleBadCredentials(exception);

        // Assert
        assertNotNull(response);
        assertEquals("INVALID_CREDENTIALS", response.code());
        assertEquals("Invalid credentials", response.message());
    }

    @Test
    void handleIllegalState_returnsConflictResponse() {
        // Arrange
        String message = "Cannot modify archived record";
        IllegalStateException exception = new IllegalStateException(message);

        // Act
        ErrorResponse response = handler.handleIllegalState(exception);

        // Assert
        assertNotNull(response);
        assertEquals("CONFLICT", response.code());
        assertEquals(message, response.message());
    }

    @Test
    void handleIllegalArgument_returnsBadRequestResponse() {
        // Arrange
        String message = "Invalid phone number format";
        IllegalArgumentException exception = new IllegalArgumentException(message);

        // Act
        ErrorResponse response = handler.handleIllegalArgument(exception);

        // Assert
        assertNotNull(response);
        assertEquals("BAD_REQUEST", response.code());
        assertEquals(message, response.message());
    }

    @Test
    void handleValidation_returnsValidationErrorResponse() {
        // Arrange
        MethodArgumentNotValidException exception = mock(MethodArgumentNotValidException.class);
        var bindingResult = mock(org.springframework.validation.BindingResult.class);
        var fieldError = mock(org.springframework.validation.FieldError.class);
        
        when(exception.getBindingResult()).thenReturn(bindingResult);
        when(bindingResult.getFieldErrors()).thenReturn(java.util.List.of(fieldError));
        when(fieldError.getField()).thenReturn("email");
        when(fieldError.getDefaultMessage()).thenReturn("Invalid email format");

        // Act
        ErrorResponse response = handler.handleValidation(exception);

        // Assert
        assertNotNull(response);
        assertEquals("VALIDATION_ERROR", response.code());
        assertTrue(response.message().contains("email"));
    }

    @Test
    void handleGeneric_returnsInternalServerErrorResponse() {
        // Arrange
        String message = "Unexpected error occurred";
        Exception exception = new Exception(message);

        // Act
        ErrorResponse response = handler.handleGeneric(exception);

        // Assert
        assertNotNull(response);
        assertEquals("INTERNAL_ERROR", response.code());
        assertEquals(message, response.message());
    }
}
