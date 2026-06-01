package com.dentalcare.dto;

import java.util.UUID;

public record ProviderDto(
        UUID providerId,
        UUID clinicId,
        String firstName,
        String lastName,
        String fullName,
        String role,
        String phone,
        String email,
        boolean active,
        // billing fields (added by V7 migration)
        String vatNumber,
        String fiscalCode,
        String professionalRegister,
        String registerNumber,
        String billingAddressStreet,
        String billingAddressZip,
        String billingAddressCity,
        String billingAddressProvince,
        String billingPec,
        String billingIban,
        String billingSdiCode,
        String invoicePrefix,
        String photoUrl,
        int assignedPatientCount
) {}
