package com.rairai.lambda_modulo3.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class KafkaMessage {
    private String id;
    private String content;
    private String sender;
    private LocalDateTime timestamp;
    
    public KafkaMessage(String content) {
        this.content = content;
        this.timestamp = LocalDateTime.now();
    }
}