package com.dentalcare.entity;

import lombok.Data;
import lombok.NoArgsConstructor;
import java.util.UUID;

@Data
@NoArgsConstructor
public class TenantUser {
    private UUID id;
    private UUID clinicId;
    private UUID userId;
    private String role;
    private boolean active = true;
}
