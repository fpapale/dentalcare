package com.dentalcare.service.ai;

import com.dentalcare.dto.ai.AiJobRequest;
import okhttp3.mockwebserver.MockResponse;
import okhttp3.mockwebserver.MockWebServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;

class AiInferenceClientTest {

    private MockWebServer server;

    @BeforeEach void setUp() throws Exception { server = new MockWebServer(); server.start(); }
    @AfterEach  void tearDown() throws Exception { server.shutdown(); }

    @Test
    void createJob_returnsJobIdFromResponse() {
        server.enqueue(new MockResponse()
                .setHeader("Content-Type", "application/json")
                .setBody("{\"job_id\":\"ai-job-123\",\"status\":\"queued\"}"));
        AiInferenceClient client = new AiInferenceClient(server.url("/").toString());
        String jobId = client.createJob(new AiJobRequest("P1", "D1", "A1", "t_x",
                "dc-t-x", "patients/P1/D1/p.png", "dc-t-x", "patients/P1/D1/ai/A1/",
                true, Map.of()));
        assertEquals("ai-job-123", jobId);
    }
}
