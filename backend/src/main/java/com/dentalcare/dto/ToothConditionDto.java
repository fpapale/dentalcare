package com.dentalcare.dto;

public record ToothConditionDto(
        int toothFdi,
        String surface,
        String condition,
        String notes
) {}
