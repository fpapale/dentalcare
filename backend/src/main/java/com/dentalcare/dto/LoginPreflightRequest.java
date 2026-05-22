package com.dentalcare.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public record LoginPreflightRequest(
        @NotBlank @Email String email,
        @NotBlank String password
) {}
