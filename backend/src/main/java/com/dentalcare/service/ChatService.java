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

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@Service
public class ChatService {

    private static final String SYSTEM_PROMPT = """
            Sei SegretarIA, l'assistente AI dello Studio Dentistico DentalCare.
            Aiuti la segreteria a interrogare il gestionale dello studio in modo rapido e naturale.
            Hai accesso agli appuntamenti, ai pazienti, ai preventivi, ai richiami, alle fatture e ai provider della clinica.
            Rispondi sempre in italiano.
            Quando hai dati, presentali in modo chiaro e strutturato (elenchi, tabelle testuali).
            Non inventare mai dati: usa solo le informazioni restituite dagli strumenti a disposizione.
            Data odierna: %s
            """;

    private final ChatClient chatClient;
    private final DentalCareAiTools tools;

    @Value("${app.ai.model:gpt-4o}")
    private String model;

    public ChatService(ChatClient.Builder builder, DentalCareAiTools tools) {
        this.chatClient = builder.build();
        this.tools = tools;
    }

    public ChatResponse chat(ChatRequest request) {
        List<Message> history = buildHistory(request.history());

        String systemPrompt = String.format(SYSTEM_PROMPT, LocalDate.now());

        String response = chatClient.prompt()
                .options(OpenAiChatOptions.builder().model(model).build())
                .system(systemPrompt)
                .messages(history)
                .user(request.message())
                .tools(tools)
                .call()
                .content();

        return new ChatResponse(response != null ? response : "", null);
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
