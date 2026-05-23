package com.dentalcare.controller;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.security.servlet.UserDetailsServiceAutoConfiguration;
import org.springframework.context.annotation.ComponentScan;

@SpringBootApplication(exclude = {UserDetailsServiceAutoConfiguration.class})
@ComponentScan(basePackages = {"com.dentalcare"})
public class DentalcareApiApplication {

	public static void main(String[] args) {
		SpringApplication.run(DentalcareApiApplication.class, args);
	}

}
