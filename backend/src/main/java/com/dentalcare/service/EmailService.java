package com.dentalcare.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

@Service
public class EmailService {

    private static final Logger log = LoggerFactory.getLogger(EmailService.class);

    private final JavaMailSender mailSender;

    @Value("${app.mail.from:noreply@dentalcare.it}")
    private String fromAddress;

    @Value("${app.mail.enabled:true}")
    private boolean enabled;

    public EmailService(JavaMailSender mailSender) {
        this.mailSender = mailSender;
    }

    public void sendTempPassword(String toEmail, String firstName, String tempPassword) {
        if (!enabled) {
            log.info("Mail disabled. Would send temp password to {}", toEmail);
            return;
        }
        try {
            SimpleMailMessage msg = new SimpleMailMessage();
            msg.setFrom(fromAddress);
            msg.setTo(toEmail);
            msg.setSubject("DentalCare Pro — Credenziali di accesso");
            msg.setText("""
                    Gentile %s,

                    Il tuo account DentalCare Pro è stato creato.

                    Password temporanea: %s

                    Al primo accesso ti verrà chiesto di scegliere una nuova password.

                    DentalCare Pro
                    """.formatted(firstName, tempPassword));
            mailSender.send(msg);
            log.info("Temp password email sent to {}", toEmail);
        } catch (Exception e) {
            log.error("Failed to send temp password email to {}: {}", toEmail, e.getMessage());
        }
    }

    public void sendPasswordResetCode(String toEmail, String firstName, String resetCode) {
        if (!enabled) {
            log.info("Mail disabled. Would send reset code to {}", toEmail);
            return;
        }
        try {
            SimpleMailMessage msg = new SimpleMailMessage();
            msg.setFrom(fromAddress);
            msg.setTo(toEmail);
            msg.setSubject("DentalCare Pro — Reset password");
            msg.setText("""
                    Gentile %s,

                    Hai richiesto il reset della password.

                    Codice temporaneo: %s

                    Usa questo codice per accedere, poi scegli una nuova password.
                    Il codice è valido per una singola sessione.

                    Se non hai richiesto il reset, ignora questa email.

                    DentalCare Pro
                    """.formatted(firstName, resetCode));
            mailSender.send(msg);
            log.info("Password reset email sent to {}", toEmail);
        } catch (Exception e) {
            log.error("Failed to send reset email to {}: {}", toEmail, e.getMessage());
        }
    }
}
