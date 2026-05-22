package com.dentalcare.dto;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.util.List;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record LoginPreflightResponse(
        String type,
        String email,
        String token,
        String providerId,
        String clinicId,
        String role,
        String firstName,
        String lastName,
        String schemaName,
        String tenantName,
        List<ClinicOption> options
) {

    public static LoginPreflightResponse direct(
            String email,
            String token,
            String providerId,
            String clinicId,
            String role,
            String firstName,
            String lastName,
            String schemaName,
            String tenantName) {
        return new LoginPreflightResponse(
                "direct", email, token, providerId, clinicId, role,
                firstName, lastName, schemaName, tenantName, null);
    }

    public static LoginPreflightResponse choose(String email, List<ClinicOption> options) {
        return new LoginPreflightResponse(
                "choose", email, null, null, null, null,
                null, null, null, null, options);
    }
}
