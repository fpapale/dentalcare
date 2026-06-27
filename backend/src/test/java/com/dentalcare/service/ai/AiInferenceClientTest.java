package com.dentalcare.service.ai;

import com.dentalcare.dto.ai.AiJobRequest;
import okhttp3.mockwebserver.MockResponse;
import okhttp3.mockwebserver.MockWebServer;
import okhttp3.mockwebserver.RecordedRequest;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class AiInferenceClientTest {

    private MockWebServer server;

    @BeforeEach void setUp() throws Exception { server = new MockWebServer(); server.start(); }
    @AfterEach  void tearDown() throws Exception {
        RequestContextHolder.resetRequestAttributes();
        server.shutdown();
    }

    @Test
    void createJob_returnsJobIdFromResponse() throws Exception {
        server.enqueue(new MockResponse()
                .setHeader("Content-Type", "application/json")
                .setBody("{\"job_id\":\"ai-job-123\",\"status\":\"queued\"}"));

        MockHttpServletRequest servletReq = new MockHttpServletRequest();
        servletReq.addHeader("Authorization", "Bearer test-token");
        RequestContextHolder.setRequestAttributes(new ServletRequestAttributes(servletReq));

        AiInferenceClient client = new AiInferenceClient(server.url("/").toString(), new com.dentalcare.security.JwtService("test-secret-test-secret-test-secret-1234", 86400000L));
        String jobId = client.createJob(new AiJobRequest("P1", "D1", "A1", "t_x",
                "dc-t-x", "patients/P1/D1/p.png", "dc-t-x", "patients/P1/D1/ai/A1/",
                true, Map.of()));
        assertEquals("ai-job-123", jobId);

        RecordedRequest recorded = server.takeRequest();
        assertEquals("/api/v1/inference/jobs", recorded.getPath());
        assertEquals("Bearer test-token", recorded.getHeader("Authorization"));

        RequestContextHolder.resetRequestAttributes();
    }

    @Test
    void getJobStatus_buildsUrlWithResultBucketAndParsesBody() throws Exception {
        server.enqueue(new MockResponse()
                .setHeader("Content-Type", "application/json")
                .setBody("{\"job_id\":\"ai-job-1\",\"status\":\"completed\"}"));
        AiInferenceClient client = new AiInferenceClient(server.url("/").toString(), new com.dentalcare.security.JwtService("test-secret-test-secret-test-secret-1234", 86400000L));
        Map<String, Object> status = client.getJobStatus("dc-t-x", "ai-job-1");
        assertEquals("completed", status.get("status"));
        RecordedRequest recorded = server.takeRequest();
        assertTrue(recorded.getPath().startsWith("/api/v1/inference/jobs/ai-job-1"));
        assertTrue(recorded.getPath().contains("result_bucket=dc-t-x"));
    }
}
