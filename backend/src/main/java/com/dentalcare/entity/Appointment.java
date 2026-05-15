package com.dentalcare.entity;

import java.time.ZonedDateTime;
import java.util.UUID;

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

    public Appointment() {}

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }
    public UUID getClinicId() { return clinicId; }
    public void setClinicId(UUID clinicId) { this.clinicId = clinicId; }
    public UUID getPatientId() { return patientId; }
    public void setPatientId(UUID patientId) { this.patientId = patientId; }
    public UUID getProviderId() { return providerId; }
    public void setProviderId(UUID providerId) { this.providerId = providerId; }
    public String getChairLabel() { return chairLabel; }
    public void setChairLabel(String chairLabel) { this.chairLabel = chairLabel; }
    public ZonedDateTime getStartsAt() { return startsAt; }
    public void setStartsAt(ZonedDateTime startsAt) { this.startsAt = startsAt; }
    public ZonedDateTime getEndsAt() { return endsAt; }
    public void setEndsAt(ZonedDateTime endsAt) { this.endsAt = endsAt; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public String getNotes() { return notes; }
    public void setNotes(String notes) { this.notes = notes; }
    public ZonedDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(ZonedDateTime createdAt) { this.createdAt = createdAt; }
}
