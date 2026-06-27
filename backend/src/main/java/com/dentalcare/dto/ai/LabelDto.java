package com.dentalcare.dto.ai;

import java.util.UUID;

public record LabelDto(
        UUID id, String toothFdi, String disease,
        Double diseaseConfidence, Double fdiConfidence,
        int bboxX1, int bboxY1, int bboxX2, int bboxY2,
        String matchingMethod, Double matchingScore,
        boolean needsReview, String source, String action) {
}
