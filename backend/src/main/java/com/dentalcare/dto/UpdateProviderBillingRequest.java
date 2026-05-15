package com.dentalcare.dto;

public record UpdateProviderBillingRequest(
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
        String invoicePrefix
) {}
