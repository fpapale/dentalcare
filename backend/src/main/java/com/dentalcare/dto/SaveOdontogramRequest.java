package com.dentalcare.dto;

import java.util.List;

public record SaveOdontogramRequest(
        List<ToothConditionDto> conditions,
        List<ToothRef> removedAi
) {
    public SaveOdontogramRequest {
        if (conditions == null) conditions = List.of();
        if (removedAi == null) removedAi = List.of();
    }

    /** Back-compat: callers that only set conditions. */
    public SaveOdontogramRequest(List<ToothConditionDto> conditions) {
        this(conditions, List.of());
    }

    /** A tooth/surface whose AI-sourced finding the clinician cleared (judged wrong). */
    public record ToothRef(int toothFdi, String surface) {}
}
