package com.dentalcare.util;

import net.lingala.zip4j.io.outputstream.ZipOutputStream;
import net.lingala.zip4j.model.ZipParameters;
import net.lingala.zip4j.model.enums.AesKeyStrength;
import net.lingala.zip4j.model.enums.CompressionMethod;
import net.lingala.zip4j.model.enums.EncryptionMethod;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.security.SecureRandom;

/**
 * Crea un archivio ZIP cifrato AES-256 protetto da password (#47 Slice B).
 *
 * <p>Usato per proteggere l'export pre-cancellazione una volta sul disco dell'utente:
 * il file scaricato resta cifrato e apribile solo con la password monouso mostrata una
 * sola volta all'operatore. Apribile con qualsiasi client ZIP standard (7-Zip, WinRAR…).
 */
public final class PasswordZipUtil {

    private static final SecureRandom RANDOM = new SecureRandom();
    // Alfabeto senza caratteri ambigui (0/O, 1/l/I) per una password digitabile.
    private static final String PWD_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789";
    private static final int PWD_LENGTH = 20;

    private PasswordZipUtil() {}

    /** Password monouso robusta per l'archivio (20 caratteri, no caratteri ambigui). */
    public static String generatePassword() {
        StringBuilder sb = new StringBuilder(PWD_LENGTH);
        for (int i = 0; i < PWD_LENGTH; i++) {
            sb.append(PWD_CHARS.charAt(RANDOM.nextInt(PWD_CHARS.length())));
        }
        return sb.toString();
    }

    /**
     * Avvolge {@code content} in un archivio ZIP cifrato AES-256 protetto da {@code password},
     * come singola voce {@code entryName}.
     */
    public static byte[] encrypt(byte[] content, String entryName, char[] password) throws IOException {
        ZipParameters params = new ZipParameters();
        params.setEncryptFiles(true);
        params.setEncryptionMethod(EncryptionMethod.AES);
        params.setAesKeyStrength(AesKeyStrength.KEY_STRENGTH_256);
        params.setCompressionMethod(CompressionMethod.DEFLATE);
        params.setFileNameInZip(entryName);

        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        try (ZipOutputStream zos = new ZipOutputStream(baos, password)) {
            zos.putNextEntry(params);
            zos.write(content);
            zos.closeEntry();
        }
        return baos.toByteArray();
    }
}
