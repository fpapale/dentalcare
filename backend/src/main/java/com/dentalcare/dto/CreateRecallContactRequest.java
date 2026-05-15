package com.dentalcare.dto;

import java.util.UUID;

public record CreateRecallContactRequest(
        String contactType,
        String outcome,
        String notes,
        UUID createdByProviderId
) {}
