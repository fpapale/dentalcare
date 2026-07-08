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

    /** Migrazione idempotente: cifra fiscal_code dei pazienti (+ blind index) e lo snapshot storico in invoices. */
    @Transactional
    public int migrateFiscalCode() {
        String schema = s();
        // pazienti: cifra fiscal_code + calcola blind index
        List<Object[]> pats = jdbc.query(
                "SELECT id, fiscal_code FROM " + schema + ".patients"
                        + " WHERE fiscal_code_enc IS NULL AND fiscal_code IS NOT NULL",
                (rs, n) -> new Object[]{ rs.getObject("id", UUID.class), rs.getString("fiscal_code") });
        for (Object[] p : pats) {
            String cf = (String) p[1];
            jdbc.update("UPDATE " + schema + ".patients SET fiscal_code_enc = :enc, fiscal_code_idx = :idx WHERE id = :id",
                    new MapSqlParameterSource()
                            .addValue("enc", enc.encrypt(cf, schema))
                            .addValue("idx", enc.blindIndex(cf, schema))
                            .addValue("id", p[0]));
        }
        // snapshot invoices: cifra il valore storico di ciascuna fattura
        List<Object[]> invs = jdbc.query(
                "SELECT id, patient_fiscal_code FROM " + schema + ".invoices"
                        + " WHERE patient_fiscal_code_enc IS NULL AND patient_fiscal_code IS NOT NULL",
                (rs, n) -> new Object[]{ rs.getObject("id", UUID.class), rs.getString("patient_fiscal_code") });
        for (Object[] iv : invs) {
            jdbc.update("UPDATE " + schema + ".invoices SET patient_fiscal_code_enc = :enc WHERE id = :id",
                    new MapSqlParameterSource()
                            .addValue("enc", enc.encrypt((String) iv[1], schema))
                            .addValue("id", iv[0]));
        }
        return pats.size();
    }

    private record Row(UUID id, LocalDate birthDate) {}
}
