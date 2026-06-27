package com.dentalcare.dto.ai;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

public record AnalysisDto(
        UUID id, UUID patientId, UUID documentId, String status,
        int detectionsCount, boolean needsReview, String reviewStatus,
        String resultBucket, String resultObjectKey, String annotatedObjectKey,
        String errorMessage, LocalDateTime createdAt, List<LabelDto> labels) {
}
