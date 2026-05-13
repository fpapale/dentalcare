package com.dentalcare.entity;

import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.ZonedDateTime;
import java.util.UUID;

@Data
@NoArgsConstructor
public class Provider {
    private UUID id;
    private UUID clinicId;
    private String firstName;
    private String lastName;
    private String role;
    private boolean active = true;
    private ZonedDateTime createdAt = ZonedDateTime.now();
}
