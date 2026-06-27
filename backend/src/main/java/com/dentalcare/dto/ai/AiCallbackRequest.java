package com.dentalcare.dto.ai;

import java.util.List;

public record AiCallbackRequest(
        String job_id, String status, String schema_name,
        String patient_id, String document_id, String analysis_id,
        String result_bucket, String result_object_key, String annotated_object_key,
        List<Detection> detections, String error) {

    public record Detection(
            String tooth, String disease,
            Double disease_confidence, Double fdi_confidence,
            List<Integer> bbox_xyxy, String matching_method,
            Double matching_score, Boolean needs_review) {
    }
}
