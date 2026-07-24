package com.dentalcare.security;

import java.util.Set;

/**
 * Fonte unica dei ruoli clinici (#42). Prima era duplicata 3 volte
 * (AppointmentService, DentalCareAiTools, user-context.service.ts lato FE) con
 * l'obbligo di tenerle allineate a mano. I valori sono i nomi dell'enum
 * {@code dentalcare.provider_role}; {@code doctor} è incluso come alias UI storico.
 */
public final class RoleConstants {

    private RoleConstants() {}

    public static final Set<String> MEDICAL_ROLES =
            Set.of("dentist", "hygienist", "orthodontist", "surgeon", "doctor");

    public static boolean isMedical(String role) {
        return role != null && MEDICAL_ROLES.contains(role);
    }
}
