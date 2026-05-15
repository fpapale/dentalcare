package com.dentalcare.entity;

import java.time.ZonedDateTime;
import java.util.UUID;

public class Clinic {
    private UUID id;
    private String name;
    private ZonedDateTime createdAt = ZonedDateTime.now();

    public Clinic() {}

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public ZonedDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(ZonedDateTime createdAt) { this.createdAt = createdAt; }
}
