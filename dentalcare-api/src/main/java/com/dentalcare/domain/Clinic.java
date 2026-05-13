package com.dentalcare.domain;

import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.ZonedDateTime;
import java.util.UUID;

@Data
@NoArgsConstructor
public class Clinic {
    private UUID id;
    private String name;
    private ZonedDateTime createdAt = ZonedDateTime.now();
}
