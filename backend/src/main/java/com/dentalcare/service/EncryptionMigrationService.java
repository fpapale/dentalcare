package com.dentalcare.service;

import com.dentalcare.security.TenantContext;
import com.dentalcare.security.crypto.TenantEncryptionService;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/** Migrazione idempotente: cifra birth_date esistenti in birth_date_enc (plaintext lasciato per il cutover). */
@Service
public class EncryptionMigrationService {

    private final NamedParameterJdbcTemplate jdbc;
    private final TenantEncryptionService enc;

    public EncryptionMigrationService(NamedParameterJdbcTemplate jdbc, TenantEncryptionService enc) {
        this.jdbc = jdbc; this.enc = enc;
    }

    private String s() { return TenantContext.validatedSchema(); }

    @Transactional
    public int migrateBirthDate() {
        String schema = s();
        List<Row> rows = jdbc.query(
                "SELECT id, birth_date FROM " + schema + ".patients"
                        + " WHERE birth_date_enc IS NULL AND birth_date IS NOT NULL",
                (rs, n) -> new Row(rs.getObject("id", UUID.class),
                        rs.getObject("birth_date", LocalDate.class)));
        int migrated = 0;
        for (Row r : rows) {
            jdbc.update("UPDATE " + schema + ".patients SET birth_date_enc = :enc WHERE id = :id",
                    new MapSqlParameterSource()
                            .addValue("enc", enc.encrypt(r.birthDate().toString(), schema))
                            .addValue("id", r.id()));
            migrated++;
        }
        return migrated;
    }

    private record Row(UUID id, LocalDate birthDate) {}
}
