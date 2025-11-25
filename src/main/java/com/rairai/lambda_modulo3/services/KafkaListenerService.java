package com.rairai.lambda_modulo3.services;

import com.rairai.lambda_modulo3.dto.KafkaMessage;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.KafkaHeaders;
import org.springframework.messaging.handler.annotation.Header;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.stereotype.Service;

@Slf4j
@Service
public class KafkaListenerService {

    @KafkaListener(
        topics = "lambda-topic",
        groupId = "lambda-consumer-group",
        containerFactory = "kafkaListenerContainerFactory"
    )
    public void listen(
        @Payload KafkaMessage message,
        @Header(KafkaHeaders.RECEIVED_PARTITION) int partition,
        @Header(KafkaHeaders.OFFSET) long offset,
        @Header(KafkaHeaders.RECEIVED_TOPIC) String topic
    ) {
        log.info("=================================================");
        log.info("Mensagem recebida do Kafka:");
        log.info("Tópico: {}", topic);
        log.info("Partição: {}", partition);
        log.info("Offset: {}", offset);
        log.info("ID da Mensagem: {}", message.getId());
        log.info("Conteúdo: {}", message.getContent());
        log.info("Remetente: {}", message.getSender());
        log.info("Timestamp: {}", message.getTimestamp());
        log.info("=================================================");
        
        // Exibir no console
        System.out.println("\n>>> MENSAGEM KAFKA RECEBIDA <<<");
        System.out.println("ID: " + message.getId());
        System.out.println("Conteúdo: " + message.getContent());
        System.out.println("Remetente: " + message.getSender());
        System.out.println("Timestamp: " + message.getTimestamp());
        System.out.println(">>> ======================= <<<\n");
    }
}