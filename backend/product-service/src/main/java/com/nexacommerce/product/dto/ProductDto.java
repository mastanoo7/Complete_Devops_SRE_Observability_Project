package com.nexacommerce.product.dto;

import java.time.Instant;
import java.util.UUID;

public record ProductDto(
        UUID id,
        String slug,
        String name,
        String category,
        double price,
        String currency,
        boolean inStock,
        Instant createdAt
) {}

