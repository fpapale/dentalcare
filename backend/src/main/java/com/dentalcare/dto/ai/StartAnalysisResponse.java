package com.dentalcare.dto.ai;

import java.util.UUID;

public record StartAnalysisResponse(UUID analysisId, String status, String jobId) {
}
