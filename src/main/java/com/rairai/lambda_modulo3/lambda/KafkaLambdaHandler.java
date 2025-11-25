package com.rairai.lambda_modulo3.lambda;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.rairai.lambda_modulo3.dto.KafkaMessage;
import lombok.extern.slf4j.Slf4j;

import java.time.LocalDateTime;
import java.util.Map;

@Slf4j
public class KafkaLambdaHandler implements RequestHandler<Map<String, Object>, String> {

    private final ObjectMapper objectMapper;

    public KafkaLambdaHandler() {
        this.objectMapper = new ObjectMapper();
        this.objectMapper.registerModule(new JavaTimeModule());
    }

    @Override
    public String handleRequest(Map<String, Object> event, Context context) {
        log.info("=================================================");
        log.info("Lambda Function iniciada");
        log.info("Request ID: {}", context.getAwsRequestId());
        log.info("Function Name: {}", context.getFunctionName());
        log.info("=================================================");

        try {
            // Processar o evento recebido
            log.info("Evento recebido: {}", objectMapper.writeValueAsString(event));

            // Extrair a mensagem do Kafka do evento
            KafkaMessage message = extractKafkaMessage(event);

            // Exibir no console
            displayMessageInConsole(message);

            // Log detalhado
            logMessageDetails(message, context);

            return "Mensagem processada com sucesso: " + message.getId();

        } catch (Exception e) {
            log.error("Erro ao processar mensagem do Kafka", e);
            System.err.println("ERRO: " + e.getMessage());
            throw new RuntimeException("Falha ao processar mensagem", e);
        }
    }

    private KafkaMessage extractKafkaMessage(Map<String, Object> event) {
        try {
            // Tentar extrair a mensagem do formato padrão de evento do Kafka
            if (event.containsKey("records")) {
                // Formato de evento do MSK (Managed Streaming for Kafka)
                return extractFromMskEvent(event);
            } else if (event.containsKey("body")) {
                // Formato simples com body
                String body = (String) event.get("body");
                return objectMapper.readValue(body, KafkaMessage.class);
            } else {
                // Tentar converter o evento diretamente para KafkaMessage
                return objectMapper.convertValue(event, KafkaMessage.class);
            }
        } catch (Exception e) {
            log.warn("Não foi possível extrair KafkaMessage estruturada, criando mensagem simples", e);
            // Fallback: criar uma mensagem simples com o conteúdo do evento
            KafkaMessage fallbackMessage = new KafkaMessage();
            fallbackMessage.setId(event.getOrDefault("id", "unknown").toString());
            fallbackMessage.setContent(event.toString());
            fallbackMessage.setTimestamp(LocalDateTime.now());
            return fallbackMessage;
        }
    }

    private KafkaMessage extractFromMskEvent(Map<String, Object> event) throws Exception {
        // Extrair do formato de evento MSK/Kafka
        Object records = event.get("records");
        if (records instanceof Map) {
            Map<String, Object> recordsMap = (Map<String, Object>) records;
            // Pegar o primeiro tópico
            for (Object topicRecords : recordsMap.values()) {
                if (topicRecords instanceof Iterable) {
                    for (Object record : (Iterable<?>) topicRecords) {
                        if (record instanceof Map) {
                            Map<String, Object> recordMap = (Map<String, Object>) record;
                            String value = (String) recordMap.get("value");
                            return objectMapper.readValue(value, KafkaMessage.class);
                        }
                    }
                }
            }
        }
        throw new IllegalArgumentException("Formato de evento MSK inválido");
    }

    private void displayMessageInConsole(KafkaMessage message) {
        System.out.println("\n");
        System.out.println("╔═══════════════════════════════════════════════════════════╗");
        System.out.println("║         MENSAGEM KAFKA RECEBIDA NA LAMBDA                 ║");
        System.out.println("╠═══════════════════════════════════════════════════════════╣");
        System.out.println("║  ID:        " + padRight(String.valueOf(message.getId()), 45) + "║");
        System.out.println("║  Conteúdo:  " + padRight(String.valueOf(message.getContent()), 45) + "║");
        System.out.println("║  Remetente: " + padRight(String.valueOf(message.getSender()), 45) + "║");
        System.out.println("║  Timestamp: " + padRight(String.valueOf(message.getTimestamp()), 45) + "║");
        System.out.println("╚═══════════════════════════════════════════════════════════╝");
        System.out.println("\n");
    }

    private void logMessageDetails(KafkaMessage message, Context context) {
        log.info("=================================================");
        log.info("Detalhes da Mensagem Processada:");
        log.info("  - ID da Mensagem: {}", message.getId());
        log.info("  - Conteúdo: {}", message.getContent());
        log.info("  - Remetente: {}", message.getSender());
        log.info("  - Timestamp: {}", message.getTimestamp());
        log.info("=================================================");
        log.info("Detalhes do Context Lambda:");
        log.info("  - Function Name: {}", context.getFunctionName());
        log.info("  - Function Version: {}", context.getFunctionVersion());
        log.info("  - Request ID: {}", context.getAwsRequestId());
        log.info("  - Memory Limit: {} MB", context.getMemoryLimitInMB());
        log.info("  - Remaining Time: {} ms", context.getRemainingTimeInMillis());
        log.info("=================================================");
    }

    private String padRight(String text, int length) {
        if (text == null) {
            text = "null";
        }
        if (text.length() >= length) {
            return text.substring(0, length);
        }
        return String.format("%-" + length + "s", text);
    }
}
