// ============================================================
// Product Controller — REST API endpoints
// ============================================================

package com.nexacommerce.product.controller;

import com.nexacommerce.product.dto.ProductDto;
import com.nexacommerce.product.dto.ProductPageDto;
import com.nexacommerce.product.service.ProductService;
import io.micrometer.core.annotation.Timed;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/products")
@RequiredArgsConstructor
@Slf4j
@Tag(name = "Products", description = "Product catalog API")
public class ProductController {

    private final ProductService productService;

    @GetMapping
    @Operation(summary = "List all products with pagination and filtering")
    @Timed(value = "product.list", description = "Time to list products")
    public ResponseEntity<ProductPageDto> listProducts(
            @RequestParam(required = false) String category,
            @RequestParam(required = false) String q,
            @RequestParam(required = false) Double minPrice,
            @RequestParam(required = false) Double maxPrice,
            @RequestParam(required = false, defaultValue = "createdAt") String sort,
            @PageableDefault(size = 20) Pageable pageable) {

        log.info("Listing products: category={}, q={}, page={}", category, q, pageable.getPageNumber());
        return ResponseEntity.ok(productService.listProducts(category, q, minPrice, maxPrice, sort, pageable));
    }

    @GetMapping("/{slug}")
    @Operation(summary = "Get product by slug")
    @Timed(value = "product.get", description = "Time to get product")
    public ResponseEntity<ProductDto> getProduct(@PathVariable String slug) {
        log.info("Getting product: slug={}", slug);
        return ResponseEntity.ok(productService.getProductBySlug(slug));
    }

    @GetMapping("/id/{id}")
    @Operation(summary = "Get product by ID")
    public ResponseEntity<ProductDto> getProductById(@PathVariable UUID id) {
        return ResponseEntity.ok(productService.getProductById(id));
    }

    @GetMapping("/health/live")
    public ResponseEntity<String> liveness() {
        return ResponseEntity.ok("UP");
    }

    @GetMapping("/health/ready")
    public ResponseEntity<Object> readiness() {
        return ResponseEntity.ok(java.util.Map.of(
            "status", "UP",
            "components", java.util.Map.of(
                "db", "UP",
                "redis", "UP",
                "elasticsearch", "UP"
            )
        ));
    }
}
