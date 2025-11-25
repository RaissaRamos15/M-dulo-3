package com.rairai.lambda_modulo3.services;

import com.rairai.lambda_modulo3.dto.KafkaMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.support.SendResult;
import org.springframework.stereotype.Service;

import java.util.UUID;
import java.util.concurrent.CompletableFuture;

@Slf4j
@Service
@RequiredArgsConstructor
public class KafkaProducerService {

    private final KafkaTemplate<String, KafkaMessage> kafkaTemplate;
    
    private static final String TOPIC = "lambda-topic";

    public void sendMessage(KafkaMessage message) {
        if (message.getId() == null) {
            message.setId(UUID.randomUUID().toString());
        }
        
        log.info("Enviando mensagem para o tópico {}: {}", TOPIC, message);
        
        CompletableFuture<SendResult<String, KafkaMessage>> future = 
            kafkaTemplate.send(TOPIC, message.getId(), message);
        
        future.whenComplete((result, ex) -> {
            if (ex == null) {
                log.info("Mensagem enviada com sucesso: [{}] com offset: [{}]", 
                    message.getId(), 
                    result.getRecordMetadata().offset());
            } else {
                log.error("Erro ao enviar mensagem: [{}] devido a: {}", 
                    message.getId(), 
                    ex.getMessage());
            }
        });
    }
    
    public void sendMessage(String content) {
        KafkaMessage message = new KafkaMessage(content);
        sendMessage(message);
    }
}