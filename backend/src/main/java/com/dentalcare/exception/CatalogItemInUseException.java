package com.dentalcare.exception;

public class CatalogItemInUseException extends RuntimeException {
    public CatalogItemInUseException(String message) {
        super(message);
    }
}
