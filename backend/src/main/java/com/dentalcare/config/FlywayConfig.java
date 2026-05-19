package com.dentalcare.config;

import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.output.MigrateResult;
import org.flywaydb.core.api.output.RepairResult;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import javax.sql.DataSource;

@Configuration
public class FlywayConfig {

    private static final Logger log = LoggerFactory.getLogger(FlywayConfig.class);

    @Bean
    public ApplicationRunner flywayRepairAndMigrate(
            DataSource dataSource,
            @Value("${app.flyway.schemas:dentalcare}") String schemas,
            @Value("${app.flyway.baseline-version:4}") String baselineVersion,
            @Value("${app.flyway.locations:classpath:db/migration}") String locations) {
        return args -> {
            Flyway flyway = Flyway.configure()
                    .dataSource(dataSource)
                    .schemas(schemas.split(","))
                    .baselineOnMigrate(true)
                    .baselineVersion(baselineVersion)
                    .locations(locations.split(","))
                    .load();

            log.info("Flyway: calling repair()");
            RepairResult repair = flyway.repair();
            log.info("Flyway: repair done — actions={}", repair.repairActions);

            log.info("Flyway: calling migrate()");
            MigrateResult migrate = flyway.migrate();
            log.info("Flyway: migrate done — applied={} success={}", migrate.migrationsExecuted, migrate.success);
        };
    }
}
