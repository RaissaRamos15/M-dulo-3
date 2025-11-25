package com.rairai.lambda_modulo3.lambda;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;

import java.util.Map;

/**
 * Handler simplificado compatível com Spring Boot JAR.
 * Este handler delega para o KafkaLambdaHandler.
 */
public class LambdaHandler implements RequestHandler<Map<String, Object>, String> {

    private final KafkaLambdaHandler kafkaLambdaHandler;

    public LambdaHandler() {
        this.kafkaLambdaHandler = new KafkaLambdaHandler();
    }

    @Override
    public String handleRequest(Map<String, Object> event, Context context) {
        return kafkaLambdaHandler.handleRequest(event, context);
    }
}