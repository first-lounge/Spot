package com.example.Spot.payments.infrastructure.client;

import java.util.Map;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

import com.example.Spot.payments.domain.gateway.PaymentGateway;
import com.example.Spot.payments.infrastructure.dto.TossPaymentResponse;

import io.github.resilience4j.bulkhead.annotation.Bulkhead;
import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;
import lombok.RequiredArgsConstructor;

@Component
@RequiredArgsConstructor
public class TossPaymentClient implements PaymentGateway {

  private final RestTemplate restTemplate;

  @Value("${toss.payments.secret-key}")
  private String secretKey;

  @Value("${toss.payments.base-url:https://api.tosspayments.com}")
  private String baseUrl;

  // *** //
  // 결제 //
  // *** //
  @Override
  @CircuitBreaker(name = "toss_billing_payment")
  @Bulkhead(name = "toss_billing_payment", type = Bulkhead.Type.SEMAPHORE)
  @Retry(name = "toss_billing_payment")
  public TossPaymentResponse requestBillingPayment(
      String billingKey,
      Long amount,
      UUID orderId,
      String orderName,
      String customerKey,
      Integer timeout) {
    String url = baseUrl + "/v1/billing/" + billingKey;

    Map<String, Object> requestBody = Map.of(
        "amount", amount,
        "orderId", orderId,
        "orderName", orderName,
        "customerKey", customerKey);

    HttpHeaders headers = createHeaders();
    HttpEntity<Map<String, Object>> request = new HttpEntity<>(requestBody, headers);

    try {
      ResponseEntity<TossPaymentResponse> response = restTemplate.postForEntity(url, request,
          TossPaymentResponse.class);

      return response.getBody();
    } catch (HttpClientErrorException e) {
      throw new RuntimeException("[TossPayment] 자동결제 실패 HttpClientErrorException: " + e.getMessage());
    } catch (Exception e) {
      e.printStackTrace();
      throw new RuntimeException("[TossPayment] 자동결제 실패: " + e.getMessage());
    }
  }

  // *** //
  // 취소 //
  // *** //
  @Override
  @CircuitBreaker(name = "toss_payment_cancel")
  @Bulkhead(name = "toss_payment_cancel", type = Bulkhead.Type.SEMAPHORE)
  @Retry(name = "toss_payment_cancel")
  public TossPaymentResponse cancelPayment(
      String paymentKey, String cancelReason, Integer timeout) {
    String url = baseUrl + "/v1/payments/" + paymentKey + "/cancel";

    Map<String, Object> requestBody = Map.of("cancelReason", cancelReason);

    HttpHeaders headers = createHeaders();
    HttpEntity<Map<String, Object>> request = new HttpEntity<>(requestBody, headers);

    try {
      ResponseEntity<TossPaymentResponse> response = restTemplate.postForEntity(url, request,
          TossPaymentResponse.class);
      return response.getBody();
    } catch (HttpClientErrorException e) {
      throw new RuntimeException("[TossPayment] 결제 취소 실패: " + e.getMessage());
    }
  }

  @Override
  @CircuitBreaker(name = "toss_payment_partial_cancel")
  @Bulkhead(name = "toss_payment_partial_cancel", type = Bulkhead.Type.SEMAPHORE)
  @Retry(name = "toss_payment_partial_cancel")
  public TossPaymentResponse cancelPaymentPartial(
      String paymentKey, Long cancelAmount, String cancelReason) {
    String url = baseUrl + "/v1/payments/" + paymentKey + "/cancel";

    Map<String, Object> requestBody = Map.of(
        "cancelAmount", cancelAmount,
        "cancelReason", cancelReason);

    HttpHeaders headers = createHeaders();
    HttpEntity<Map<String, Object>> request = new HttpEntity<>(requestBody, headers);

    try {
      ResponseEntity<TossPaymentResponse> response = restTemplate.postForEntity(url, request,
          TossPaymentResponse.class);
      return response.getBody();
    } catch (HttpClientErrorException e) {
      throw new RuntimeException("[TossPayment] 결제 부분 취소 실패: " + e.getMessage());
    }
  }

  // ************** //
  // BillingKey 발급 //
  // ************** //
  @Override
  @CircuitBreaker(name = "toss_billing_key_issue")
  @Bulkhead(name = "toss_billing_key_issue", type = Bulkhead.Type.SEMAPHORE)
  @Retry(name = "toss_billing_key_issue")
  public TossPaymentResponse issueBillingKey(String authKey, String customerKey) {
    String url = baseUrl + "/v1/billing/authorizations/issue";

    Map<String, Object> requestBody = Map.of(
        "authKey", authKey,
        "customerKey", customerKey);

    HttpHeaders headers = createHeaders();
    HttpEntity<Map<String, Object>> request = new HttpEntity<>(requestBody, headers);

    try {
      ResponseEntity<TossPaymentResponse> response = restTemplate.postForEntity(url, request,
          TossPaymentResponse.class);
      return response.getBody();

    } catch (HttpClientErrorException e) {

      throw new RuntimeException("[TossPayment] 빌링키 발급 실패: " + e.getMessage());
    }
  }

  private HttpHeaders createHeaders() {
    HttpHeaders headers = new HttpHeaders();
    headers.setContentType(MediaType.APPLICATION_JSON);
    // String testKey = secretKey + "_INVALID";
    // headers.setBasicAuth(testKey, "");
    headers.setBasicAuth(secretKey, "");
    return headers;
  }
}
