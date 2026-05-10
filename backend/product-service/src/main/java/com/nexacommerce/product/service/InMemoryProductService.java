package com.nexacommerce.product.service;

import com.nexacommerce.product.dto.ProductDto;
import com.nexacommerce.product.dto.ProductPageDto;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.*;
import java.util.stream.Collectors;
import java.util.stream.Stream;

@Service
public class InMemoryProductService implements ProductService {

    private final List<ProductDto> catalog;

    public InMemoryProductService() {
        Instant now = Instant.now();
        this.catalog = List.of(
                new ProductDto(UUID.randomUUID(), "nexa-hoodie", "Nexa Hoodie", "apparel", 59.00, "USD", true, now),
                new ProductDto(UUID.randomUUID(), "nexa-mug", "Nexa Mug", "accessories", 14.99, "USD", true, now),
                new ProductDto(UUID.randomUUID(), "nexa-keyboard", "Nexa Mechanical Keyboard", "electronics", 129.00, "USD", false, now)
        );
    }

    @Override
    public ProductPageDto listProducts(String category, String q, Double minPrice, Double maxPrice, String sort, Pageable pageable) {
        Stream<ProductDto> s = catalog.stream();

        if (category != null && !category.isBlank()) {
            s = s.filter(p -> p.category() != null && p.category().equalsIgnoreCase(category));
        }
        if (q != null && !q.isBlank()) {
            String qq = q.toLowerCase(Locale.ROOT);
            s = s.filter(p -> (p.name() != null && p.name().toLowerCase(Locale.ROOT).contains(qq))
                    || (p.slug() != null && p.slug().toLowerCase(Locale.ROOT).contains(qq)));
        }
        if (minPrice != null) {
            s = s.filter(p -> p.price() >= minPrice);
        }
        if (maxPrice != null) {
            s = s.filter(p -> p.price() <= maxPrice);
        }

        Comparator<ProductDto> comparator = Comparator.comparing(ProductDto::createdAt).reversed();
        if (sort != null) {
            comparator = switch (sort) {
                case "priceAsc" -> Comparator.comparing(ProductDto::price);
                case "priceDesc" -> Comparator.comparing(ProductDto::price).reversed();
                case "nameAsc" -> Comparator.comparing(ProductDto::name, Comparator.nullsLast(String::compareToIgnoreCase));
                case "nameDesc" -> Comparator.comparing(ProductDto::name, Comparator.nullsLast(String::compareToIgnoreCase)).reversed();
                default -> comparator;
            };
        }

        List<ProductDto> filtered = s.sorted(comparator).collect(Collectors.toList());

        int page = Math.max(0, pageable.getPageNumber());
        int size = Math.max(1, pageable.getPageSize());
        int from = Math.min(filtered.size(), page * size);
        int to = Math.min(filtered.size(), from + size);

        return new ProductPageDto(filtered.subList(from, to), page, size, filtered.size());
    }

    @Override
    public ProductDto getProductBySlug(String slug) {
        return catalog.stream()
                .filter(p -> Objects.equals(p.slug(), slug))
                .findFirst()
                .orElseThrow(() -> new NoSuchElementException("Product not found"));
    }

    @Override
    public ProductDto getProductById(UUID id) {
        return catalog.stream()
                .filter(p -> Objects.equals(p.id(), id))
                .findFirst()
                .orElseThrow(() -> new NoSuchElementException("Product not found"));
    }
}

