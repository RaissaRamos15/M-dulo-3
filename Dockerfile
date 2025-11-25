# Usar imagem base oficial da AWS Lambda para Java 21
FROM public.ecr.aws/lambda/java:21

# Copiar dependências para o runtime da Lambda
COPY target/lib/ ${LAMBDA_TASK_ROOT}/lib/

# Copiar classes compiladas da aplicação
COPY target/classes/ ${LAMBDA_TASK_ROOT}/

# Definir o handler da função Lambda
CMD ["com.rairai.lambda_modulo3.lambda.KafkaLambdaHandler::handleRequest"]