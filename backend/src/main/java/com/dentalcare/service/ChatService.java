package com.dentalcare.service;

import com.dentalcare.dto.ChatRequest;
import com.dentalcare.dto.ChatResponse;
import com.dentalcare.dto.ChatTurnDto;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.messages.AssistantMessage;
import org.springframework.ai.chat.messages.Message;
import org.springframework.ai.chat.messages.UserMessage;
import org.springframework.ai.openai.OpenAiChatOptions;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import reactor.core.publisher.Flux;

import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

@Service
public class ChatService {

    private static final String SYSTEM_PROMPT = """
            Sei SegretarIA, l'assistente AI dello Studio Dentistico DentalCare.
            Aiuti la segreteria a gestire il gestionale dello studio in modo rapido e naturale.
            Hai accesso ad appuntamenti, pazienti, preventivi, richiami, fatture e provider della clinica,
            e puoi creare, spostare e annullare appuntamenti e cercare slot liberi.
            Rispondi sempre in italiano.
            Quando hai dati, presentali in modo chiaro e strutturato (elenchi, tabelle testuali).
            Non inventare mai dati: usa solo le informazioni restituite dagli strumenti a disposizione.

            Contesto temporale (fuso Europe/Rome):
            - Adesso: %s, ore %s
            - Oggi: %s
            Interpreta espressioni come "domani", "lunedì prossimo", "tra due settimane" rispetto a questo contesto.

            Orari studio: Lun-Ven 09:00-13:00 e 14:00-19:00. No weekend, no festivi.
            Prima di proporre o creare un appuntamento, usa lo strumento per gli slot liberi.

            REGOLA OBBLIGATORIA per le azioni di scrittura (creazione/spostamento/annullamento appuntamenti):
            1. chiama lo strumento di anteprima (createAppointment/rescheduleAppointment/cancelAppointment):
               restituisce un'ANTEPRIMA e un CODICE di conferma, senza salvare nulla;
            2. mostra l'anteprima all'utente e chiedi conferma esplicita;
            3. SOLO dopo conferma, chiama confirmAction con quel codice per eseguire.
            Tratta come conferma qualsiasi assenso dell'utente: "sì", "ok", "confermo", "va bene",
            "procedi", "conferma", "certo", ecc. Tratta come annullamento "no", "annulla", "lascia stare".
            Non chiedere mai il codice all'utente: usalo internamente. Non eseguire azioni senza conferma.
            """;

    private static final DateTimeFormatter DAY_FMT =
            DateTimeFormatter.ofPattern("EEEE d MMMM yyyy", Locale.ITALIAN);
    private static final DateTimeFormatter TIME_FMT = DateTimeFormatter.ofPattern("HH:mm");

    private final ChatClient chatClient;
    private final DentalCareAiTools tools;

    @Value("${app.ai.model:gpt-4o}")
    private String model;

    public ChatService(ChatClient.Builder builder, DentalCareAiTools tools) {
        this.chatClient = builder.build();
        this.tools = tools;
    }

    public ChatResponse chat(ChatRequest request) {
        String response = chatClient.prompt()
                .options(OpenAiChatOptions.builder().model(model).build())
                .system(buildSystemPrompt())
                .messages(buildHistory(request.history()))
                .user(request.message())
                .tools(tools)
                .call()
                .content();

        return new ChatResponse(response != null ? response : "", null);
    }

    /**
     * Variante streaming: emette i token man mano. {@code contextCapture()} cattura i ThreadLocal
     * (tenant + security) al momento della sottoscrizione, così i tool eseguiti su thread reactor
     * mantengono l'isolamento per tenant (vedi ContextPropagationConfig).
     */
    public Flux<String> stream(ChatRequest request) {
        return chatClient.prompt()
                .options(OpenAiChatOptions.builder().model(model).build())
                .system(buildSystemPrompt())
                .messages(buildHistory(request.history()))
                .user(request.message())
                .tools(tools)
                .stream()
                .content();
    }

    private String buildSystemPrompt() {
        ZonedDateTime now = ZonedDateTime.now(ZoneId.of("Europe/Rome"));
        String day = now.format(DAY_FMT);
        return String.format(SYSTEM_PROMPT, day, now.format(TIME_FMT), day);
    }

    private List<Message> buildHistory(List<ChatTurnDto> history) {
        if (history == null || history.isEmpty()) return List.of();
        List<Message> messages = new ArrayList<>();
        for (ChatTurnDto turn : history) {
            if ("user".equals(turn.role())) {
                messages.add(new UserMessage(turn.content()));
            } else if ("assistant".equals(turn.role())) {
                messages.add(new AssistantMessage(turn.content()));
            }
        }
        return messages;
    }
}
