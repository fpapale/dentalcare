package com.dentalcare.entity;

import java.time.ZonedDateTime;
import java.util.UUID;

public class User {
    private UUID id;
    private String email;
    private String fullName;
    private boolean active = true;
    private ZonedDateTime createdAt = ZonedDateTime.now();

    public User() {}

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    public String getFullName() { return fullName; }
    public void setFullName(String fullName) { this.fullName = fullName; }
    public boolean isActive() { return active; }
    public void setActive(boolean active) { this.active = active; }
    public ZonedDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(ZonedDateTime createdAt) { this.createdAt = createdAt; }
}
