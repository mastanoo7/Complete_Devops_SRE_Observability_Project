package com.nexacommerce.product.dto;

import java.util.List;

public record ProductPageDto(
        List<ProductDto> items,
        int page,
        int pageSize,
        long total
) {}

