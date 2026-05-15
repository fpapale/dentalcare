package com.dentalcare.dto;

public record CreateSupplierRequest(
        String name,
        String contactPerson,
        String phone,
        String email,
        String notes
) {}
