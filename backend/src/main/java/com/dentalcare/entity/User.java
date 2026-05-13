package com.dentalcare.entity;

import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.ZonedDateTime;
import java.util.UUID;

@Data
@NoArgsConstructor
public class User {
    private UUID id;
    private String email;
    private String fullName;
    private boolean active = true;
    private ZonedDateTime createdAt = ZonedDateTime.now();
}
