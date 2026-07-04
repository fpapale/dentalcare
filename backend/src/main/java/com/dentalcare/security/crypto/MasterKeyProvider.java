package com.dentalcare.security.crypto;

/** Sorgente della master key di cifratura. Impl attuale: config; futura: Vault. */
public interface MasterKeyProvider {
    /** @return master key di 32 byte; l'impl deve fallire se assente/malformata. */
    byte[] masterKey();
}
