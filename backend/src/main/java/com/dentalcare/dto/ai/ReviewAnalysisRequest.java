package com.dentalcare.dto.ai;

import jakarta.validation.constraints.NotBlank;
import java.util.List;

public record ReviewAnalysisRequest(
        @NotBlank String reviewStatus,   // reviewed | approved_for_training | excluded
        List<LabelDto> labels) {          // dentist-corrected labels (source human_corrected)
}
