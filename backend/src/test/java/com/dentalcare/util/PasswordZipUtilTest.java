package com.dentalcare.util;

import net.lingala.zip4j.ZipFile;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;

import static java.nio.charset.StandardCharsets.UTF_8;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class PasswordZipUtilTest {

    @Test
    void encrypt_producesArchiveOpenableOnlyWithCorrectPassword(@TempDir Path dir) throws Exception {
        byte[] content = "contenuto export riservato".getBytes(UTF_8);
        String password = PasswordZipUtil.generatePassword();

        byte[] archive = PasswordZipUtil.encrypt(content, "export.zip", password.toCharArray());

        File archiveFile = dir.resolve("archive.zip").toFile();
        Files.write(archiveFile.toPath(), archive);

        // Password sbagliata → estrazione fallisce
        assertThatThrownBy(() ->
                new ZipFile(archiveFile, "PasswordSbagliata".toCharArray())
                        .extractAll(dir.resolve("ko").toString()))
                .isInstanceOf(Exception.class);

        // Password corretta → estrae il contenuto originale
        new ZipFile(archiveFile, password.toCharArray()).extractAll(dir.resolve("ok").toString());
        byte[] extracted = Files.readAllBytes(dir.resolve("ok").resolve("export.zip"));
        assertThat(extracted).isEqualTo(content);
    }

    @Test
    void generatePassword_isRobustAndAvoidsAmbiguousChars() {
        String pwd = PasswordZipUtil.generatePassword();
        assertThat(pwd).hasSize(20);
        assertThat(pwd).doesNotContain("0", "O", "1", "l", "I");
    }
}
