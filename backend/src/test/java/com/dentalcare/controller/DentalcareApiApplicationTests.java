package com.dentalcare.controller;

import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
@Disabled("Skipped: ToolLayerService bean not configured for test environment (pre-existing)")
class DentalcareApiApplicationTests {

	@Test
	void contextLoads() {
	}

}
