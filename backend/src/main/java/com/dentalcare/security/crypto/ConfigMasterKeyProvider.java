package com.dentalcare.security.crypto;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Condition;
import org.springframework.stereotype.Component;

import java.util.HexFormat;

/**
 * Legge la master key (hex, 32 byte) da {@code app.encryption.master-key}.
 * Attivo di default ({@code app.encryption.key-source=config}). Fail-fast alla costruzione
 * se la chiave è assente o non decodifica a 32 byte, così l'app non parte senza cifratura valida.
 */
@Component
@org.springframework.boot.autoconfigure.condition.ConditionalOnProperty(
        name = "app.encryption.key-source", havingValue = "config", matchIfMissing = true)
public class ConfigMasterKeyProvider implements MasterKeyProvider {

    private final byte[] key;

    public ConfigMasterKeyProvider(@Value("${app.encryption.master-key:}") String hex) {
        if (hex == null || hex.isBlank()) {
            throw new IllegalStateException("app.encryption.master-key mancante");
        }
        byte[] decoded;
        try {
            decoded = HexFormat.of().parseHex(hex.trim());
        } catch (IllegalArgumentException e) {
            throw new IllegalStateException("app.encryption.master-key non è hex valido", e);
        }
        if (decoded.length != 32) {
            throw new IllegalStateException(
                    "app.encryption.master-key deve essere 32 byte (64 hex), trovati " + decoded.length);
        }
        this.key = decoded;
    }

    @Override
    public byte[] masterKey() {
        return key.clone(); // copia difensiva: il chiamante non può mutare lo stato interno
    }
}
