package com.dentalcare.dto;

import java.util.List;

public record SaveOdontogramRequest(List<ToothConditionDto> conditions) {}
