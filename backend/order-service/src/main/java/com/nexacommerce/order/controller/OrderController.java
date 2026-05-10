// ============================================================
// Order Controller — REST API endpoints
// ============================================================

package com.nexacommerce.order.controller;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/orders")
@RequiredArgsConstructor
@Slf4j
public class OrderController {

    @PostMapping("/checkout")
    public ResponseEntity<Map<String, Object>> checkout(@RequestBody Map<String, Object> request,
                                                         @RequestHeader("X-User-ID") String userId) {
        log.info("Checkout request from user: {}", userId);
        String orderId = "ORD-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
        return ResponseEntity.status(HttpStatus.CREATED).body(Map.of(
            "orderId", orderId,
            "status", "confirmed",
            "message", "Order placed successfully"
        ));
    }

    @GetMapping
    public ResponseEntity<Map<String, Object>> listOrders(
            @RequestHeader("X-User-ID") String userId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        log.info("Listing orders for user: {}", userId);
        return ResponseEntity.ok(Map.of(
            "items", java.util.List.of(),
            "total", 0,
            "page", page,
            "pageSize", size
        ));
    }

    @GetMapping("/{orderId}")
    public ResponseEntity<Map<String, Object>> getOrder(@PathVariable String orderId,
                                                         @RequestHeader("X-User-ID") String userId) {
        log.info("Getting order: {} for user: {}", orderId, userId);
        return ResponseEntity.ok(Map.of(
            "id", orderId,
            "userId", userId,
            "status", "confirmed"
        ));
    }

    @PostMapping("/{orderId}/cancel")
    public ResponseEntity<Map<String, Object>> cancelOrder(@PathVariable String orderId,
                                                            @RequestHeader("X-User-ID") String userId) {
        log.info("Cancelling order: {} for user: {}", orderId, userId);
        return ResponseEntity.ok(Map.of("orderId", orderId, "status", "cancelled"));
    }

    @GetMapping("/health/live")
    public ResponseEntity<String> liveness() {
        return ResponseEntity.ok("UP");
    }

    @GetMapping("/health/ready")
    public ResponseEntity<Object> readiness() {
        return ResponseEntity.ok(Map.of("status", "UP"));
    }
}
