package com.dentalcare.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

@Service
public class EmailService {

    private static final Logger log = LoggerFactory.getLogger(EmailService.class);
    private static final DateTimeFormatter TS = DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss_SSS");

    private final JavaMailSender mailSender;

    @Value("${app.mail.from:noreply@dentalcare.it}")
    private String fromAddress;

    @Value("${app.mail.send-real-emails:true}")
    private boolean sendRealEmails;

    public EmailService(JavaMailSender mailSender) {
        this.mailSender = mailSender;
    }

    public void sendTempPassword(String toEmail, String firstName, String tempPassword) {
        String subject = "DentalCare Pro — Credenziali di accesso";
        String text = """
                Gentile %s,

                Il tuo account DentalCare Pro è stato creato.

                Password temporanea: %s

                Al primo accesso ti verrà chiesto di scegliere una nuova password.

                DentalCare Pro
                """.formatted(firstName, tempPassword);
        send(toEmail, subject, text);
    }

    public void sendStudioWelcome(String toEmail, String firstName, String studioName, String loginUrl) {
        String subject = "DentalCare Pro — Studio attivato";
        String text = """
                Gentile %s,

                Lo studio "%s" è stato creato con successo su DentalCare Pro.

                Puoi accedere subito con l'email e la password che hai scelto in fase di registrazione:
                %s

                Per sicurezza non riportiamo la password in questa email.

                DentalCare Pro
                """.formatted(firstName, studioName, loginUrl);
        send(toEmail, subject, text);
    }

    public void sendPasswordResetCode(String toEmail, String firstName, String resetCode) {
        String subject = "DentalCare Pro — Reset password";
        String text = """
                Gentile %s,

                Hai richiesto il reset della password.

                Codice temporaneo: %s

                Usa questo codice per accedere, poi scegli una nuova password.
                Il codice è valido per una singola sessione.

                Se non hai richiesto il reset, ignora questa email.

                DentalCare Pro
                """.formatted(firstName, resetCode);
        send(toEmail, subject, text);
    }

    private void send(String to, String subject, String text) {
        if (!sendRealEmails) {
            writeToFakeSmtp(to, subject, text);
            return;
        }
        try {
            SimpleMailMessage msg = new SimpleMailMessage();
            msg.setFrom(fromAddress);
            msg.setTo(to);
            msg.setSubject(subject);
            msg.setText(text);
            mailSender.send(msg);
            log.info("Email sent to {}: {}", to, subject);
        } catch (Exception e) {
            log.error("Failed to send email to {}: {}", to, e.getMessage());
        }
    }

    private void writeToFakeSmtp(String to, String subject, String text) {
        try {
            Path dir = Path.of("fakesmtp");
            Files.createDirectories(dir);
            String safe = to.replaceAll("[^a-zA-Z0-9@._-]", "_");
            String filename = TS.format(LocalDateTime.now()) + "_" + safe + ".mhtml";
            String htmlBody = text
                    .replace("&", "&amp;")
                    .replace("<", "&lt;")
                    .replace(">", "&gt;")
                    .replace("\n", "<br>\n");
            String mhtml = "MIME-Version: 1.0\r\n" +
                    "Content-Type: multipart/related; boundary=\"fakesmtp_boundary\"\r\n" +
                    "From: " + fromAddress + "\r\n" +
                    "To: " + to + "\r\n" +
                    "Subject: " + subject + "\r\n" +
                    "\r\n" +
                    "--fakesmtp_boundary\r\n" +
                    "Content-Type: text/html; charset=\"UTF-8\"\r\n" +
                    "Content-Transfer-Encoding: quoted-printable\r\n" +
                    "\r\n" +
                    "<!DOCTYPE html>\r\n" +
                    "<html><head><meta charset=\"UTF-8\">" +
                    "<style>body{font-family:sans-serif;max-width:600px;margin:40px auto;padding:20px}" +
                    ".header{background:#0f766e;color:#fff;padding:16px 20px;border-radius:8px 8px 0 0}" +
                    ".body{border:1px solid #e2e8f0;border-top:none;padding:20px;border-radius:0 0 8px 8px}" +
                    ".meta{color:#64748b;font-size:12px;margin-bottom:16px}" +
                    "pre{background:#f8fafc;border:1px solid #e2e8f0;border-radius:6px;padding:16px;white-space:pre-wrap;word-break:break-word}" +
                    "</style></head><body>\r\n" +
                    "<div class=\"header\"><strong>DentalCare Pro — FakeSMTP</strong></div>\r\n" +
                    "<div class=\"body\">\r\n" +
                    "<div class=\"meta\"><strong>A:</strong> " + to + "<br><strong>Oggetto:</strong> " + subject + "</div>\r\n" +
                    "<pre>" + htmlBody + "</pre>\r\n" +
                    "</div></body></html>\r\n" +
                    "\r\n" +
                    "--fakesmtp_boundary--\r\n";
            Files.writeString(dir.resolve(filename), mhtml, StandardCharsets.UTF_8);
            log.info("FakeSMTP: written fakesmtp/{}", filename);
        } catch (IOException e) {
            log.error("FakeSMTP: failed to write file for {}: {}", to, e.getMessage());
        }
    }
}
