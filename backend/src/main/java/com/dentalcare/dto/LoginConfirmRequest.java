package com.dentalcare.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public record LoginConfirmRequest(
        @NotBlank @Email String email,
        @NotBlank String password,
        @NotBlank String clinicId
) {}
