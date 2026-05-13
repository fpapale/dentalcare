package com.dentalcare.entity;

import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.ZonedDateTime;
import java.util.UUID;

@Data
@NoArgsConstructor
public class Appointment {
    private UUID id;
    private UUID clinicId;
    private UUID patientId;
    private UUID providerId;
    private String chairLabel;
    private ZonedDateTime startsAt;
    private ZonedDateTime endsAt;
    private String status;
    private String notes;
    private ZonedDateTime createdAt = ZonedDateTime.now();
}
