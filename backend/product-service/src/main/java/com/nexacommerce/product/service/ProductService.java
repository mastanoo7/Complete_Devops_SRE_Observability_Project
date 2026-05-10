package com.nexacommerce.product.service;

import com.nexacommerce.product.dto.ProductDto;
import com.nexacommerce.product.dto.ProductPageDto;
import org.springframework.data.domain.Pageable;

import java.util.UUID;

public interface ProductService {
    ProductPageDto listProducts(String category, String q, Double minPrice, Double maxPrice, String sort, Pageable pageable);

    ProductDto getProductBySlug(String slug);

    ProductDto getProductById(UUID id);
}

