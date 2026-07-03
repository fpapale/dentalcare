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

import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;

@Service
public class ChatService {

    /** Chiave del prompt di sistema nel PromptService (valore reale gestito in DB/risorse). */
    private static final String SYSTEM_PROMPT_KEY = "chat.system";

    /** Fallback minimale usato solo se il prompt non è recuperabile (DB e risorsa assenti). */
    private static final String SYSTEM_PROMPT_FALLBACK =
            "Sei SegretarIA, l'assistente AI dello Studio Dentistico DentalCare. Rispondi in italiano. "
            + "Per creare/spostare/annullare usa gli strumenti di anteprima e poi confirmAction dopo conferma.";

    private static final DateTimeFormatter DAY_FMT =
            DateTimeFormatter.ofPattern("EEEE d MMMM yyyy", Locale.ITALIAN);
    private static final DateTimeFormatter DAY_FMT_EN =
            DateTimeFormatter.ofPattern("EEEE d MMMM yyyy", Locale.ENGLISH);
    private static final DateTimeFormatter TIME_FMT = DateTimeFormatter.ofPattern("HH:mm");

    private final ChatClient chatClient;
    private final DentalCareAiTools tools;
    private final PromptService promptService;

    @Value("${app.ai.model:gpt-4o}")
    private String model;

    @Value("${app.ai.default-locale:it}")
    private String defaultLocale;

    public ChatService(ChatClient.Builder builder, DentalCareAiTools tools, PromptService promptService) {
        this.chatClient = builder.build();
        this.tools = tools;
        this.promptService = promptService;
    }

    public ChatResponse chat(ChatRequest request) {
        String response = chatClient.prompt()
                .options(OpenAiChatOptions.builder().model(model).build())
                .system(buildSystemPrompt(request.locale(), request.context()))
                .messages(buildHistory(request.history()))
                .user(request.message())
                .tools(tools)
                .call()
                .content();

        return new ChatResponse(response != null ? response : "", null);
    }

    private String buildSystemPrompt(String requestLocale, ChatRequest.ChatContext ctx) {
        String locale = (requestLocale == null || requestLocale.isBlank()) ? defaultLocale : requestLocale;
        ZonedDateTime now = ZonedDateTime.now(ZoneId.of("Europe/Rome"));
        DateTimeFormatter dayFmt = "en".equals(locale) ? DAY_FMT_EN : DAY_FMT;
        Map<String, String> vars = Map.of(
                "oggi", now.format(dayFmt),
                "ora", now.format(TIME_FMT));
        String rendered = promptService.render(SYSTEM_PROMPT_KEY, locale, vars);
        String base = rendered != null ? rendered : SYSTEM_PROMPT_FALLBACK;

        if (ctx == null) {
            return base;
        }
        StringBuilder sb = new StringBuilder(base);
        if (ctx.patientId() != null) {
            sb.append("\n\n[CONTESTO UI] L'utente sta guardando il paziente ")
              .append(ctx.patientName() != null ? ctx.patientName() : "")
              .append(" (patientId=").append(ctx.patientId())
              .append("). Quando dice \"questo paziente\" usa questo UUID senza ricerca.");
        }
        if (ctx.view() != null && !ctx.view().isBlank()) {
            sb.append("\n[CONTESTO UI] Vista corrente: ").append(ctx.view()).append(".");
        }
        return sb.toString();
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
