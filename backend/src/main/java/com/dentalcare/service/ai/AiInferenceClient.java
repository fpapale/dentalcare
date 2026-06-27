package com.dentalcare.service.ai;

import com.dentalcare.dto.ai.AiJobRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.util.Map;

@Service
public class AiInferenceClient {

    private final RestClient http;

    public AiInferenceClient(@Value("${app.ai.base-url}") String baseUrl) {
        this.http = RestClient.builder().baseUrl(baseUrl).build();
    }

    private String currentBearer() {
        var attrs = RequestContextHolder.getRequestAttributes();
        if (attrs instanceof ServletRequestAttributes sra) {
            String header = sra.getRequest().getHeader("Authorization");
            if (header != null) return header;
        }
        return "";
    }

    @SuppressWarnings("unchecked")
    public String createJob(AiJobRequest req) {
        Map<String, Object> body = http.post()
                .uri("/api/v1/inference/jobs")
                .header("Authorization", currentBearer())
                .body(req)
                .retrieve()
                .body(Map.class);
        return body != null ? (String) body.get("job_id") : null;
    }

    @SuppressWarnings("unchecked")
    public Map<String, Object> getJobStatus(String resultBucket, String jobId) {
        return http.get()
                .uri(uri -> uri.path("/api/v1/inference/jobs/{id}")
                        .queryParam("result_bucket", resultBucket).build(jobId))
                .header("Authorization", currentBearer())
                .retrieve()
                .body(Map.class);
    }
}
