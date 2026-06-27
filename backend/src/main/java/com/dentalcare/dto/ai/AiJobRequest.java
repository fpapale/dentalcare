package com.dentalcare.dto.ai;

import java.util.Map;

public record AiJobRequest(
        String patient_id, String document_id, String analysis_id, String schema_name,
        String image_bucket, String image_object_key,
        String output_bucket, String output_prefix,
        boolean save_annotated_image, Map<String, Object> metadata) {
}
