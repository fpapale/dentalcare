package com.dentalcare.service.ai;

import com.dentalcare.dto.ai.AiJobRequest;
import com.dentalcare.security.JwtService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.util.Map;
import java.util.UUID;

@Service
public class AiInferenceClient {

    private final RestClient http;
    private final JwtService jwtService;

    public AiInferenceClient(@Value("${app.ai.base-url}") String baseUrl, JwtService jwtService) {
        this.http = RestClient.builder().baseUrl(baseUrl).build();
        this.jwtService = jwtService;
    }

    private String currentBearer() {
        var attrs = RequestContextHolder.getRequestAttributes();
        if (attrs instanceof ServletRequestAttributes sra) {
            String header = sra.getRequest().getHeader("Authorization");
            if (header != null && !header.isEmpty()) return header;
        }
        String schema = com.dentalcare.security.TenantContext.getCurrentSchema();
        if (schema != null) {
            java.util.UUID sys = new java.util.UUID(0L, 0L);
            return "Bearer " + jwtService.generate(sys, sys, schema, "SYSTEM", "system");
        }
        return "";
    }

    @SuppressWarnings("unchecked")
    public String createJob(AiJobRequest req) {
        String bearer = currentBearer();
        var spec = http.post().uri("/api/v1/inference/jobs").body(req);
        if (!bearer.isEmpty()) spec = spec.header("Authorization", bearer);
        Map<String, Object> body = spec.retrieve().body(Map.class);
        return body != null ? (String) body.get("job_id") : null;
    }

    @SuppressWarnings("unchecked")
    public Map<String, Object> getJobStatus(String resultBucket, String jobId) {
        String bearer = currentBearer();
        var spec = http.get()
                .uri(uri -> uri.path("/api/v1/inference/jobs/{id}")
                        .queryParam("result_bucket", resultBucket).build(jobId));
        if (!bearer.isEmpty()) spec = spec.header("Authorization", bearer);
        Map<String, Object> body = spec.retrieve().body(Map.class);
        return body != null ? body : Map.of();
    }
}
