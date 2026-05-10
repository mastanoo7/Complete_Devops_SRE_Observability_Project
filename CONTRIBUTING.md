# Contributing to NexaCommerce

Thank you for contributing to NexaCommerce! This document outlines the development workflow, coding standards, and PR process.

---

## Table of Contents
- [Development Setup](#development-setup)
- [Branching Strategy](#branching-strategy)
- [Commit Convention](#commit-convention)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Testing Requirements](#testing-requirements)
- [Documentation](#documentation)

---

## Development Setup

```bash
# 1. Fork and clone
git clone https://github.com/your-org/nexacommerce.git
cd nexacommerce

# 2. Install prerequisites
# See docs/setup/prerequisites.md

# 3. Start local environment
cp .env.example .env.local
make dev-up

# 4. Verify everything works
cd frontend && npm run type-check && npm run build
cd ../backend/product-service && mvn -q -DskipTests package
cd ../order-service && mvn -q -DskipTests package
```

---

## Branching Strategy

We use **trunk-based development** with short-lived feature branches.

```
main                    ← Production-ready code
├── feature/NEX-123-add-wishlist
├── fix/NEX-456-cart-race-condition
├── chore/update-dependencies
└── release/v1.2.0      ← Release branches (optional)
```

### Branch Naming

| Type | Pattern | Example |
|------|---------|---------|
| Feature | `feature/TICKET-description` | `feature/NEX-123-add-wishlist` |
| Bug fix | `fix/TICKET-description` | `fix/NEX-456-cart-bug` |
| Chore | `chore/description` | `chore/update-go-deps` |
| Hotfix | `hotfix/TICKET-description` | `hotfix/NEX-789-payment-crash` |
| Release | `release/vX.Y.Z` | `release/v1.2.0` |

---

## Commit Convention

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Types

| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `style` | Formatting, no logic change |
| `refactor` | Code refactor |
| `test` | Adding/updating tests |
| `chore` | Build process, dependencies |
| `perf` | Performance improvement |
| `ci` | CI/CD changes |
| `security` | Security fix |

### Examples

```bash
feat(cart): add bulk add-to-cart endpoint
fix(payment): handle Stripe webhook timeout correctly
docs(sre): update SLO targets for payment service
chore(deps): upgrade Go to 1.22
security(auth): rotate JWT signing key
```

---

## Pull Request Process

### Before Opening a PR

```bash
# 1. Ensure core checks pass
cd frontend && npm run type-check && npm run build
cd ../backend/product-service && mvn -q -DskipTests package
cd ../order-service && mvn -q -DskipTests package

# 2. Lint your code
make lint

# 3. Run security scan
make security-scan

# 4. Update documentation if needed
```

### PR Requirements

- [ ] **Title** follows conventional commit format
- [ ] **Description** explains what and why (not how)
- [ ] **Tests** added/updated for all changes
- [ ] **Documentation** updated if needed
- [ ] **No secrets** committed (GitLeaks passes)
- [ ] **CI passes** — all checks green
- [ ] **Linked ticket** — references Jira/Linear issue

### PR Template

```markdown
## Summary
Brief description of what this PR does.

## Motivation
Why is this change needed? Link to issue: NEX-XXX

## Changes
- Added X
- Modified Y
- Removed Z

## Testing
How was this tested? What scenarios were covered?

## Screenshots (if UI change)

## Checklist
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] No breaking changes (or migration guide provided)
- [ ] Security implications considered
```

### Review Requirements

| Branch | Required Approvals | Required Checks |
|--------|-------------------|-----------------|
| `main` | 2 engineers | All CI checks |
| `release/*` | 2 engineers + SRE | All CI + security scan |
| Feature branches | 1 engineer | Lint + tests |

### Merge Strategy
- **Squash merge** for feature branches (clean history)
- **Merge commit** for release branches (preserve history)

---

## Coding Standards

### Go Services (auth-service, payment-service)

```go
// ✅ Good: exported functions have godoc comments
// AuthenticateUser validates credentials and returns a JWT token.
func AuthenticateUser(ctx context.Context, req *AuthRequest) (*AuthResponse, error) {
    // ...
}

// ✅ Good: errors wrapped with context
if err != nil {
    return nil, fmt.Errorf("authenticating user %s: %w", req.Email, err)
}

// ✅ Good: structured logging
logger.Info("user authenticated",
    zap.String("user_id", user.ID),
    zap.Duration("duration", time.Since(start)),
)
```

### Java Services (product-service, order-service)

```java
// ✅ Good: use constructor injection
@Service
@RequiredArgsConstructor
public class ProductService {
    private final ProductRepository productRepository;
    private final CacheManager cacheManager;
}

// ✅ Good: structured logging with MDC
MDC.put("productId", productId);
log.info("Fetching product from database");
```

### Node.js Services (cart-service, api-gateway)

```typescript
// ✅ Good: typed interfaces
interface CartItem {
  productId: string;
  quantity: number;
  price: number;
}

// ✅ Good: async/await with error handling
async function addToCart(userId: string, item: CartItem): Promise<Cart> {
  try {
    return await cartRepository.addItem(userId, item);
  } catch (error) {
    logger.error('Failed to add item to cart', { userId, item, error });
    throw new CartServiceError('Failed to add item', { cause: error });
  }
}
```

### Python Services (inventory-service, recommendation-service)

```python
# ✅ Good: type hints everywhere
async def reserve_stock(
    product_id: str,
    quantity: int,
    order_id: str,
) -> ReservationResult:
    """Reserve stock for an order.
    
    Args:
        product_id: The product to reserve
        quantity: Number of units to reserve
        order_id: The order making the reservation
        
    Returns:
        ReservationResult with success status and reservation ID
    """
```

---

## Testing Requirements

| Layer | Minimum Coverage | Tools |
|-------|-----------------|-------|
| Unit tests | 80% | Go test, JUnit, Jest, pytest |
| Integration tests | Key flows | Testcontainers, Docker Compose |
| E2E tests | Critical paths | Playwright |
| Load tests | Before major releases | k6 |

### Running Tests

```bash
# Frontend checks
cd frontend && npm run type-check && npm run lint && npm run build

# Unit tests only
make test-unit

# Service builds
cd backend/product-service && mvn -q -DskipTests package
cd ../order-service && mvn -q -DskipTests package

# E2E tests
make test-e2e

# Load tests
make test-load
```

---

## Documentation

- **Code changes** → Update inline comments and README
- **API changes** → Update OpenAPI spec in `backend/<service>/api/`
- **Architecture changes** → Update `docs/architecture/`
- **Runbook changes** → Update `runbooks/`
- **New service** → Add K8s manifests, Helm values, Terraform IAM role

---

## Getting Help

- **Slack**: `#platform-engineering` for infrastructure questions
- **Slack**: `#dev-help` for general development questions
- **Wiki**: https://wiki.nexacommerce.com
- **On-call**: See PagerDuty for current on-call engineer

---

*By contributing, you agree to follow our [Code of Conduct](CODE_OF_CONDUCT.md).*
