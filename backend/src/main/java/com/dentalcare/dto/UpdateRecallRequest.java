package com.dentalcare.dto;

import java.time.LocalDate;

public record UpdateRecallRequest(
        String status,
        String priority,
        String recallType,
        LocalDate dueDate,
        String notes
) {}
