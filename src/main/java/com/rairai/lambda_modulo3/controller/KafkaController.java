package com.rairai.lambda_modulo3.controller;

import com.rairai.lambda_modulo3.dto.KafkaMessage;
import com.rairai.lambda_modulo3.services.KafkaProducerService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.Map;
import java.util.UUID;

@Slf4j
@RestController
@RequestMapping("/api/kafka")
@RequiredArgsConstructor
public class KafkaController {

    private final KafkaProducerService kafkaProducerService;

    @PostMapping("/send")
    public ResponseEntity<Map<String, String>> sendMessage(@RequestBody KafkaMessage message) {
        log.info("Recebida requisição para enviar mensagem: {}", message);
        
        if (message.getId() == null) {
            message.setId(UUID.randomUUID().toString());
        }
        if (message.getTimestamp() == null) {
            message.setTimestamp(LocalDateTime.now());
        }
        
        kafkaProducerService.sendMessage(message);
        
        return ResponseEntity.ok(Map.of(
            "status", "success",
            "message", "Mensagem enviada para o Kafka",
            "messageId", message.getId()
        ));
    }

    @PostMapping("/send/simple")
    public ResponseEntity<Map<String, String>> sendSimpleMessage(@RequestBody Map<String, String> payload) {
        String content = payload.getOrDefault("content", "Mensagem de teste");
        
        log.info("Recebida requisição para enviar mensagem simples: {}", content);
        
        KafkaMessage message = new KafkaMessage();
        message.setId(UUID.randomUUID().toString());
        message.setContent(content);
        message.setSender(payload.getOrDefault("sender", "API REST"));
        message.setTimestamp(LocalDateTime.now());
        
        kafkaProducerService.sendMessage(message);
        
        return ResponseEntity.ok(Map.of(
            "status", "success",
            "message", "Mensagem simples enviada para o Kafka",
            "messageId", message.getId(),
            "content", content
        ));
    }

    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        return ResponseEntity.ok(Map.of(
            "status", "UP",
            "service", "Kafka Producer/Consumer",
            "timestamp", LocalDateTime.now().toString()
        ));
    }
}