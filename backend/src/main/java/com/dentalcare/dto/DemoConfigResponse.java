package com.dentalcare.dto;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record DemoConfigResponse(boolean enabled, String email, String password) {}
