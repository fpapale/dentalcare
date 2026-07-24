package com.dentalcare.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Esegue il DROP reale dei tenant in soft-delete la cui finestra di grazia è scaduta (#47).
 * Gira una volta al giorno; il lavoro effettivo è in {@link TenantDeletionService#dropExpiredTenants()}.
 */
@Component
public class TenantDeletionScheduler {

    private static final Logger log = LoggerFactory.getLogger(TenantDeletionScheduler.class);

    private final TenantDeletionService deletionService;

    public TenantDeletionScheduler(TenantDeletionService deletionService) {
        this.deletionService = deletionService;
    }

    @Scheduled(cron = "0 0 3 * * *", zone = "Europe/Rome")
    public void dropExpiredTenants() {
        try {
            deletionService.dropExpiredTenants();
        } catch (Exception e) {
            log.error("TenantDeletionScheduler run failed", e);
        }
    }
}
