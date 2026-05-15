package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record UpdatePlanNameRequest(
        @NotBlank @Size(max = 200)
        String name
) {}
