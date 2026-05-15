package com.dentalcare.dto;

import java.time.OffsetDateTime;
import java.util.UUID;

public record RecallContactDto(
        UUID contactId,
        UUID recallId,
        String contactType,
        OffsetDateTime contactAt,
        String outcome,
        String notes,
        UUID createdByProviderId,
        OffsetDateTime createdAt
) {}
