package com.dentalcare.domain;

import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDate;
import java.time.ZonedDateTime;
import java.util.UUID;

@Data
@NoArgsConstructor
public class Patient {
    private UUID id;
    private UUID clinicId;
    private String firstName;
    private String lastName;
    private String phone;
    private String email;
    private LocalDate birthDate;
    private String fiscalCode;
    private ZonedDateTime createdAt = ZonedDateTime.now();
}
