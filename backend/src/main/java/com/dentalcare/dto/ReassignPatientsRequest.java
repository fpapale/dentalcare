package com.dentalcare.dto;

import jakarta.validation.constraints.NotNull;

import java.util.UUID;

public record ReassignPatientsRequest(
        // null = reassign patients with no primary provider (orphans)
        UUID fromProviderId,
        @NotNull
        UUID toProviderId
) {}
