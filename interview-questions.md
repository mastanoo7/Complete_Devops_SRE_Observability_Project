# NexaCommerce — Interview Questions

> **Platform**: Enterprise multi-cloud ecommerce platform (AWS + Azure + GCP) with Kubernetes, Istio, ArgoCD, Terraform, Prometheus/Grafana/Loki/Jaeger, HashiCorp Vault, Falco, Kyverno, and full SRE practices.

---

## Table of Contents

1. [Architecture & System Design](#1-architecture--system-design)
2. [Real-Time Issues & Operational Challenges](#2-real-time-issues--operational-challenges)
3. [SRE & Observability](#3-sre--observability)
4. [Cost Optimization](#4-cost-optimization)
5. [Security & Compliance](#5-security--compliance)
6. [Disaster Recovery & Business Continuity](#6-disaster-recovery--business-continuity)
7. [Advanced Cross-Cutting Questions](#7-advanced-cross-cutting-questions)

---

## 1. Architecture & System Design

### 1.1 Multi-Cloud & Global Architecture

1. This platform runs active-active across AWS (40%), Azure (35%), and GCP (25%). What are the key trade-offs of active-active multi-cloud versus active-passive, and how do you handle data consistency when writes can land on any cloud?

2. CloudFlare is used as the global edge with dynamic latency-based routing and cookie-based session affinity (30-minute TTL). What happens to a user's shopping cart session if CloudFlare routes them to a different cloud mid-session? How would you design around this?

3. The platform uses different primary databases per cloud — Aurora PostgreSQL (AWS), CosmosDB (Azure), and Cloud Spanner (GCP). How do you handle cross-cloud transactions, for example an order placed via Azure that needs to debit inventory managed on AWS?

4. Traffic is distributed 40/35/25 across three clouds. If AWS goes down and traffic redistributes to Azure (60%) and GCP (40%), what capacity planning considerations must you have pre-provisioned to absorb that surge without SLO breach?

5. The architecture uses Kafka MirrorMaker 2 for cross-cloud event replication with a target lag of under 1 second. What failure modes exist in this replication pipeline, and how would you detect and recover from a replication lag spike?

6. The platform uses both Kong API Gateway and Istio service mesh. Explain the distinct responsibilities of each layer. Where does Kong's rate limiting end and Istio's traffic management begin?

7. The product-service uses Java/Spring Boot with PostgreSQL and Elasticsearch. When a product is updated, how do you keep PostgreSQL and Elasticsearch in sync? What happens if the Elasticsearch index update fails after the DB write succeeds?

8. Cart service uses Redis as its primary store. What is your strategy for cart data durability if the Redis cluster fails? How does the system degrade gracefully, and what is the acceptable data loss?

9. The recommendation-service uses MongoDB Atlas. How do you handle the eventual consistency of recommendations when a user's purchase history is replicated from Aurora to MongoDB with a potential lag?

10. The platform has 9 microservices written in 4 different languages (Go, Java, Node.js, Python). What are the operational challenges of maintaining a polyglot microservices architecture, and how does this platform address them?

### 1.2 Kubernetes & Container Platform

11. The platform runs EKS 1.29, AKS, and GKE simultaneously. What are the key differences in managed Kubernetes offerings across these three clouds that affect your operational procedures?

12. The payment-service is scheduled exclusively on nodes labeled `workload-type: payment-pci` using node affinity and taints. Walk through what happens if all PCI-scoped nodes become unavailable — will the payment-service pods be rescheduled elsewhere, and why or why not?

13. HPA is configured with three metrics simultaneously: CPU utilization (70%), memory utilization (80%), and custom metric `http_requests_per_second` (1000). When these metrics conflict — CPU is at 50% but RPS is at 1500 — how does Kubernetes decide the target replica count?

14. VPA is set to `updateMode: "Off"` in production (recommendations only). Why is this the recommended approach for production, and what risks would `updateMode: "Auto"` introduce in a live environment?

15. Pod Disruption Budgets are set to `minAvailable: 2` for all production services. If a service has exactly 2 replicas and a node drain is triggered, what happens? How does this interact with the cluster autoscaler?

16. The Kustomize overlay structure has `base/` and `overlays/dev|staging|prod`. What are the specific risks of applying a `kubectl apply -k overlays/prod` directly without going through ArgoCD, and how does the GitOps model prevent this?

17. The ArgoCD production application has `automated: null` (manual sync only) while dev/staging use automated sync. What is the rationale for this difference, and what approval workflow should exist before a production sync is triggered?

18. The Helm chart uses `imagePullPolicy: Always` in production. What are the performance implications of this setting, and under what circumstances could it cause a deployment to fail even when the image hasn't changed?

19. The platform uses `terminationGracePeriodSeconds: 60` and Istio `drainDuration: 45s`. Explain the sequence of events when a pod receives SIGTERM, and why the grace period must be longer than the drain duration.

20. Resource quotas for the production namespace cap pods at 200 and CPU at 100 cores. If a flash sale causes HPA to attempt scaling beyond these quotas, what is the observable symptom, and how would you detect and respond to it?

### 1.3 Service Mesh & Networking

21. Istio is configured in `STRICT` mTLS mode across all production namespaces. What happens when a new service is deployed without a proper sidecar injection, and how does Istio's admission webhook handle this?

22. The platform uses Istio AuthorizationPolicy to restrict that only `order-service` can call `payment-service`. If a compromised `product-service` pod attempts to call `payment-service` directly, walk through exactly how Istio blocks this at the network level.

23. Circuit breakers are implemented via Istio DestinationRules. When the circuit breaker opens on the order→payment path due to 2-second network latency injection during a chaos experiment, what is the user-facing behavior, and how does the order-service handle the open circuit?

24. The network policy uses default-deny with explicit allow rules. A new microservice is deployed but its NetworkPolicy allow rules are missing. Describe the exact failure mode — which calls succeed, which fail, and what error messages would appear in logs?

25. Istio certificate rotation happens every 24 hours via Citadel. What is the impact on in-flight requests during certificate rotation, and how does Istio ensure zero-downtime rotation?

### 1.4 CI/CD & GitOps

26. The Jenkins pipeline has a `SKIP_TESTS` boolean parameter described as "emergency deploys only." What governance controls should exist around this parameter to prevent misuse, and what audit trail should be maintained when it's used?

27. The GitLab CI pipeline has 7 stages: validate → test → security → build → scan → deploy-dev → deploy-staging → deploy-prod. If a CRITICAL CVE is found by Trivy in the container scan stage, the build blocks. How do you handle a zero-day CVE in a base image that has no fix available yet?

28. The canary deployment uses Argo Rollouts with automatic rollback if error rate exceeds 1% or P99 latency exceeds 500ms. What is the minimum traffic volume needed for these metrics to be statistically meaningful during the initial 5% canary phase?

29. Blue/green deployment keeps the blue environment for 30 minutes after the green switch. What specific scenarios justify keeping blue longer, and what is the cost implication of running two full production environments simultaneously?

30. The database migration strategy requires backward-compatible migrations first (add column, don't remove). Walk through a scenario where you need to rename a column that is actively used by a running service — what is the exact multi-step migration sequence?

---

## 2. Real-Time Issues & Operational Challenges

### 2.1 Incident Scenarios

31. At 2 AM, PagerDuty fires: `PaymentServiceAvailabilitySLOBreach` — payment service availability dropped to 99.95% (SLO: 99.99%). The on-call engineer has 5 minutes to acknowledge. Walk through your exact first 10 minutes of investigation using the tools available in this platform.

32. The `OrderFailureRateHigh` alert fires: order failure rate is at 8% (threshold: 5%). Simultaneously, `AuroraHighConnections` shows 920 connections (limit: 1000). How do you determine if these are causally related, and what is your mitigation sequence?

33. A pod is in `CrashLoopBackOff` with restart count 47. The logs show `connection refused` to `postgres:5432`. The postgres pod is Running and Ready. List all possible root causes in order of likelihood and the diagnostic command for each.

34. During a peak sale event, the product-service HPA is at maxReplicas (20) and CPU is at 95%. New pods are Pending because the cluster autoscaler hasn't provisioned new nodes yet. The autoscaler scale-up trigger is CPU > 70% for 3 minutes. What is the user impact during those 3 minutes, and how would you pre-empt this for known peak events?

35. A developer accidentally pushed a commit that included a hardcoded AWS access key. GitLeaks should have caught this in the pre-commit hook and CI pipeline. Walk through the incident response: what do you do in the first 15 minutes assuming the key was already pushed to the public GitHub repository?

36. Grafana shows the `CheckoutConversionDropped` alert firing — conversion rate fell from 45% to 22% in the last 15 minutes. No deployment has happened. No infrastructure alerts are firing. How do you distinguish between a technical issue and a business/UX issue, and what data sources do you use?

37. The `ErrorBudgetFastBurn` alert fires: 14.4x burn rate detected over 1 hour. The payment service error budget is only 4.38 minutes/month. You have already consumed 3.5 minutes this month. What immediate actions do you take, and who do you notify?

38. An Istio sidecar upgrade is being rolled out across the cluster. Halfway through, some pods have the new sidecar version and some have the old. A service-to-service call between a new-sidecar pod and an old-sidecar pod starts failing with TLS handshake errors. How do you diagnose and resolve this?

39. The Kafka consumer lag for the `order.created` topic suddenly spikes to 500,000 messages. The notification-service (consumer) is Running and healthy. What are the possible causes, and how do you determine if this is a consumer-side or producer-side issue?

40. During a routine node drain for maintenance, a pod with `minAvailable: 2` PDB cannot be evicted because only 2 replicas are running. The drain hangs indefinitely. What are your options, and what are the risks of each?

### 2.2 Performance & Scalability Challenges

41. The search-service has a P99 SLO of 500ms. During a product catalog update that re-indexes 2 million products in Elasticsearch, search P99 spikes to 2.3 seconds. How do you isolate the indexing workload from the search query workload in Elasticsearch?

42. The cart-service uses Redis with `maxmemory-policy: allkeys-lru` and 512MB limit. During a flash sale, Redis memory hits 100% and starts evicting cart data. Users lose their carts. How would you redesign the Redis configuration and eviction strategy to prevent this?

43. The auth-service token validation P99 SLO is 50ms. A new feature requires calling an external OAuth provider for token validation. The external provider has P99 of 200ms. How do you meet the 50ms SLO while integrating this external dependency?

44. The platform handles 5,000 RPS currently with a growth rate of 15% per month. At what point does the current Aurora PostgreSQL setup (1 writer, 2 readers, 1000 connection limit) become a bottleneck, and what architectural changes are needed before reaching that point?

45. The recommendation-service uses 1-4 CPU cores and 2-8GB memory per pod, with only 2-8 replicas. During ML model inference, a single request can spike CPU to 400%. How does this affect other pods on the same node, and what scheduling strategies prevent noisy-neighbor problems?

### 2.3 Deployment & Configuration Challenges

46. A production deployment of order-service is in progress (canary at 25%). The new version has a bug that only manifests when processing orders over $10,000 (rare edge case). The canary analysis metrics (error rate, latency) look green. How would you catch this type of business-logic regression before full rollout?

47. The ArgoCD production app has `ignoreDifferences` for `/spec/replicas` because HPA manages replica counts. A runaway HPA bug scales the product-service to 20 replicas (max). ArgoCD won't revert this because replicas are ignored. How do you detect and remediate this situation?

48. A Terraform `apply` in production partially fails — 3 of 12 security group rules were created before the apply errored out. The Terraform state is now inconsistent with reality. Walk through your recovery procedure without causing additional downtime.

49. The Vault dynamic secret for the product-service database has a 1-hour TTL. The product-service pod has been running for 59 minutes and is about to get a new DB credential. What happens to in-flight database connections using the old credential when Vault revokes it?

50. A Kyverno policy `require-signed-images` is set to `Enforce` mode. A critical hotfix needs to be deployed immediately, but the CI pipeline that signs images is down. How do you deploy the hotfix while maintaining security posture, and what compensating controls do you put in place?

---

## 3. SRE & Observability

### 3.1 SLIs, SLOs & Error Budgets

51. The payment-service has a 99.99% availability SLO with only 4.38 minutes of error budget per month. In a 30-day month, if you have a 2-minute outage on day 5, how does this affect your deployment velocity for the remaining 25 days according to the error budget policy?

52. The platform uses multi-window burn rate alerts: fast burn (14.4x over 1h) and slow burn (6x over 6h). Explain why using only a single-window alert (e.g., error rate > 1% for 5 minutes) is insufficient for SLO-based alerting, and what failure modes each window is designed to catch.

53. The SLO for order-service availability is 99.95% but the SLA committed to enterprise customers is 99.95%. There is no buffer between SLO and SLA. What is the risk of this design, and how would you restructure the SLO/SLA relationship?

54. The search-service has a lower SLO (99.5%) than other services. How do you communicate to product teams that degraded search is "acceptable" from an SLO perspective, and what business metrics would indicate the SLO target is set too low?

55. The error budget policy freezes all deployments when budget falls below 10%. A critical security patch needs to be deployed during a freeze. How do you handle this conflict between reliability and security obligations?

56. The platform tracks `cache hit rate > 80%` as an SLI for the product-service. Cache hit rate drops to 55% after a Redis restart (cold cache). Is this an SLO breach? How do you differentiate between expected transient degradation and a genuine reliability problem?

57. How would you calculate the composite SLO for the end-to-end checkout flow, which depends on auth-service (99.9%), product-service (99.9%), cart-service (99.9%), order-service (99.95%), and payment-service (99.99%)?

58. The SLO dashboard shows 30-day rolling availability at 99.91% against a 99.9% target. A new deployment is scheduled that historically causes 2 minutes of elevated errors. Should you proceed? Walk through the error budget math.

### 3.2 Monitoring, Alerting & Observability

59. The observability stack uses both Loki (for log querying) and Elasticsearch (for full-text search) as parallel log pipelines. What are the operational costs of maintaining two log pipelines, and under what query patterns does each excel?

60. Distributed tracing uses tail-based sampling: 10% for normal traffic, 100% for errors and slow requests (>1s), 100% for payment-service. A performance regression causes P99 to jump from 400ms to 900ms — just under the 1-second threshold for 100% sampling. How does this affect your ability to diagnose the regression?

61. The platform uses Thanos for long-term Prometheus metric storage. What are the query performance implications of querying 90-day metrics through Thanos Store versus querying 7-day metrics from local Prometheus, and how does this affect your SLO calculation queries?

62. AlertManager is configured with inhibition rules: suppress warning alerts if a critical alert is already firing for the same service. During a major incident, the critical alert fires but the warning alerts (which contain more specific diagnostic information) are suppressed. How do you balance alert noise reduction with diagnostic completeness?

63. The Grafana SLO dashboard shows error budget remaining as a gauge. A product manager asks: "Why did our error budget drop 30% last Tuesday?" How do you use the available observability tools to reconstruct the timeline of events that caused the budget consumption?

64. The platform emits business metrics: `orders_total`, `payments_total`, `checkout_started_total`, `checkout_completed_total`. The `CheckoutConversionDropped` alert fires when conversion falls below 30% for 15 minutes. What is the risk of a 15-minute `for` duration on a business-critical alert, and what would you change?

65. OpenTelemetry Collector is used as a unified telemetry pipeline. If the OTel Collector pod crashes, what telemetry data is lost, what is buffered, and what continues to flow? How do you make the telemetry pipeline resilient?

66. The platform has 7 Grafana dashboards for different audiences (SRE, engineers, business, security). A new on-call engineer joins. What is the minimum set of dashboards and metrics they need to understand to effectively respond to a P1 incident at 3 AM?

67. Prometheus scrapes metrics every 15 seconds. A transient spike in payment errors lasts exactly 12 seconds. Will this spike appear in your SLO calculations? What are the implications of scrape interval on SLO accuracy?

68. The platform uses structured JSON logging with `traceId` and `spanId` fields. A customer reports a failed order at 14:32:07 UTC. Walk through the exact sequence of queries across Loki, Jaeger/Tempo, and Prometheus to reconstruct what happened to that specific request.

### 3.3 Chaos Engineering & Resilience

69. The chaos engineering maturity model shows Level 5 (multi-cloud failure simulation) as "Planned." What are the specific technical and organizational challenges of simulating a full cloud provider failure without actually taking down production traffic?

70. A chaos experiment deletes 33% of product-service pods. The hypothesis is that HPA will replace pods within 30 seconds and SLO will be maintained. The experiment fails — error rate spikes to 3% for 45 seconds. What does this tell you about the system, and what are the three most likely root causes?

71. The pre-experiment checklist requires error budget > 20% remaining. You are on day 28 of the month with 15% budget remaining. A weekly automated chaos experiment is scheduled. What do you do, and how do you communicate this to the team?

72. Network latency injection of 2 seconds is applied to the order→payment path. The circuit breaker is expected to open. Instead, the order-service starts queuing requests and eventually OOMs. What does this reveal about the circuit breaker configuration, and how do you fix it?

73. During a quarterly DR drill simulating full AWS failure, the team discovers that the GCP cluster cannot handle 100% traffic because the recommendation-service has a hard dependency on an AWS-only service (Rekognition for image analysis). How do you handle this undiscovered dependency, and how do you prevent similar surprises?

---

## 4. Cost Optimization

### 4.1 Infrastructure Cost Management

74. The production EKS cluster has four node groups: system (on-demand m5.xlarge), app-general (on-demand m5.2xlarge), app-memory (on-demand r5.2xlarge), and app-spot (SPOT m5.2xlarge/m5a.2xlarge/m4.2xlarge). The spot node group has 0 desired nodes. What workloads are appropriate for spot instances in this architecture, and what safeguards must be in place before moving stateless services to spot?

75. The capacity planning document shows current AWS spend at $12,000/month growing to $24,000/month in 6 months. Reserved instances save $2,400/month and are already active. What is the risk of purchasing 3-year Savings Plans at this growth rate, and how do you balance commitment discounts against flexibility?

76. The ECR lifecycle policy keeps only the last 10 production images (tagged with `v`) and removes untagged images after 7 days. A rollback to a version from 3 months ago is needed. What is the impact of this lifecycle policy on rollback capabilities, and how would you redesign it?

77. VPA is used in dev/staging with `updateMode: "Auto"` for right-sizing recommendations. The VPA recommends reducing the search-service memory request from 1Gi to 512Mi based on 7-day usage data. What risks exist in applying this recommendation, and what additional data would you want before acting on it?

78. The platform uses S3 Intelligent-Tiering saving $300/month. Audit logs must be retained for 7 years (compliance). Walk through the complete data lifecycle strategy for audit logs from hot storage (Loki/ES) through S3 Standard → S3 Glacier → S3 Glacier Deep Archive, including the cost implications at each tier.

79. The Terraform production environment uses `db.r6g.2xlarge` Aurora instances (memory-optimized, Graviton2). The capacity planning shows Aurora connections at 400 avg / 800 peak against a 1000 limit. At what connection count would you add PgBouncer connection pooling, and what are the trade-offs of adding a connection pooler in front of Aurora?

80. The platform runs 45 nodes across three clouds (18 EKS + 15 AKS + 12 GKE) at 55-65% average utilization. What is the target utilization range for a production Kubernetes cluster, and what are the risks of pushing utilization above 80%?

81. The notification-service has only 2 minimum replicas (vs. 3 for all other services). What is the cost justification for this difference, and what availability risk does it introduce given the `minAvailable: 2` PDB?

82. The platform uses Graviton3 nodes saving $600/month. The auth-service is written in Go and the product-service in Java. Are there any compatibility considerations when migrating workloads to ARM64 (Graviton) architecture, and how do you validate compatibility before production rollout?

83. Multi-cloud data transfer costs are often overlooked. The Kafka MirrorMaker 2 replicates events from AWS MSK to Azure Event Hubs and GCP Pub/Sub continuously. Estimate the data transfer cost implications and identify which event topics could be excluded from cross-cloud replication to reduce costs without impacting DR capability.

### 4.2 FinOps & Cost Governance

84. The Terraform resources use a `CostCenter: engineering` tag. How would you implement a chargeback model to attribute cloud costs to individual microservice teams, and what Terraform/tagging changes would be required?

85. The platform has no mention of cost alerting or budget alarms. Design a cost governance framework for this platform: what budget thresholds, anomaly detection, and escalation paths would you implement?

86. The dev environment uses Aurora Serverless (saving $400/month). What are the cold-start implications of Aurora Serverless for developer experience, and at what usage pattern does Aurora Serverless become more expensive than a provisioned instance?

---

## 5. Security & Compliance

### 5.1 Zero-Trust & Identity

87. The platform uses IRSA (IAM Roles for Service Accounts) on AWS, Workload Identity on Azure, and Workload Identity Federation on GCP. If a pod's service account is compromised (e.g., via a container escape), what is the blast radius of the compromise given the least-privilege IAM policies defined for each service?

88. The payment-service IAM role has `SecretsManager: GetSecretValue` and `KMS: Decrypt` permissions. A developer requests adding `S3: PutObject` to the payment-service role to store payment receipts. How do you evaluate this request from a least-privilege perspective, and what alternative architecture would you propose?

89. GitHub Actions uses OIDC for AWS authentication with no static credentials. The trust policy restricts to `repo:your-org/nexacommerce:environment:production`. What happens if a fork of the repository tries to trigger a workflow that assumes this role? How does the OIDC trust policy prevent this?

90. The IAM strategy requires hardware security keys (WebAuthn) for SRE and Platform Engineers accessing production. A production incident occurs at 2 AM and the on-call engineer's hardware key is at the office. What break-glass procedures should exist, and how do you audit and review break-glass access?

91. Vault uses Kubernetes auth method for pod-level authentication. The Vault role for `product-service` is bound to the `nexacommerce-prod` namespace and `product-service` service account. If an attacker gains exec access to a product-service pod, what Vault secrets can they access, and what can they NOT access?

### 5.2 Container & Runtime Security

92. The Kyverno policy `require-signed-images` uses keyless signing via Sigstore/Rekor with the GitHub Actions OIDC issuer. What is the trust chain from a container image in ECR to the Kyverno admission webhook verifying its signature? What happens if the Rekor transparency log is unavailable?

93. A Falco alert fires: `Shell Spawned in Container` for the auth-service pod. The alert shows `proc.pname = entrypoint.sh` which is in the allowed parents list. Why did the alert fire, and how do you tune the Falco rule to reduce false positives without reducing detection coverage?

94. The Falco rule `Unexpected Outbound Connection from Payment Service` monitors for connections outside of `api.stripe.com` and `api.braintreegateway.com`. A new payment provider (PayPal) is being integrated. Walk through the change management process to update this security rule safely.

95. OPA Gatekeeper enforces `K8sAllowedRepos` — only images from ECR, ACR, and GCR are allowed. A third-party monitoring agent needs to be deployed using an image from Docker Hub. What is the process to add an exception, and what security review should accompany it?

96. The Kyverno policy `require-readonly-rootfs` enforces `readOnlyRootFilesystem: true`. The notification-service needs to write temporary files to disk for email attachment processing. How do you satisfy both the security policy and the application requirement?

### 5.3 Network Security & mTLS

97. Istio enforces STRICT mTLS in the production namespace. A legacy internal tool needs to call the product-service API without a sidecar. How do you allow this specific exception without weakening the overall mTLS posture for the namespace?

98. The WAF is configured with rate limiting at 1000 req/min per IP. During a legitimate flash sale, a corporate customer behind a NAT gateway (single IP) has 500 employees simultaneously browsing the site. How do you handle this false-positive rate limiting scenario?

99. The platform uses TLS 1.3 minimum for external traffic and mTLS for internal traffic. A compliance audit requires demonstrating that no TLS 1.0 or 1.1 traffic is possible. How do you provide evidence of this, and what monitoring would you put in place to detect TLS downgrade attempts?

100. Network policies use default-deny with explicit allow rules. The monitoring namespace needs to scrape metrics from all service pods (port 9090). Rather than adding individual allow rules for each service, a developer proposes a single allow rule from monitoring namespace to all namespaces. What are the security implications of this approach?

### 5.4 Compliance & Audit

101. The payment-service runs on dedicated PCI-scoped nodes with node affinity and taints. During a PCI-DSS QSA audit, the auditor asks: "How do you ensure that non-PCI workloads can never be scheduled on PCI nodes?" Walk through the technical controls (taints, node affinity, Kyverno policies) that enforce this isolation.

102. GDPR requires the right to erasure — a user requests deletion of all their data. The user's data exists in: Aurora PostgreSQL (orders, payments), MongoDB (notifications), Elasticsearch (search history), Redis (session), Kafka (event log), S3 (receipts), and Loki/Elasticsearch (logs containing user IDs). How do you implement a complete data deletion workflow across all these stores?

103. The compliance document states audit logs are retained for 1 year hot and 7 years cold. A security incident investigation requires log data from 18 months ago. Walk through the process of retrieving logs from S3 Glacier and the time/cost implications.

104. PCI-DSS Requirement 10 mandates monitoring of all access to cardholder data. The platform uses CloudTrail, Kubernetes audit logs, and Vault audit logs. How do you correlate an event across all three audit sources to reconstruct a complete access timeline for a specific payment transaction?

105. The platform is described as "ISO 27001 in progress." What are the key gaps between the current security controls and ISO 27001 certification requirements, and what would be the highest-priority items to address?

---

## 6. Disaster Recovery & Business Continuity

### 6.1 RTO/RPO & Failover

106. The DR strategy defines RTO < 15 minutes and RPO < 30 seconds for a full cloud failure. The manual steps for a full cloud outage include scaling up GCP cluster, updating CloudFlare routing, and promoting Cloud Spanner. Walk through the exact sequence of commands and estimated time for each step — is the 15-minute RTO achievable?

107. Aurora PostgreSQL has PITR (Point-in-Time Recovery) with 35-day retention. An engineer accidentally runs `DELETE FROM orders WHERE created_at < '2024-01-01'` without a WHERE clause, deleting all orders. The mistake is discovered 4 hours later. Walk through the PITR recovery process and the impact on the running application during recovery.

108. The DR testing schedule includes monthly AZ failover drills, quarterly region failover drills, and annual full DR drills. A quarterly region failover drill is scheduled for next Tuesday. What is the pre-drill checklist, and how do you ensure the drill doesn't accidentally impact production traffic?

109. Cross-cloud data sync uses Debezium CDC → Kafka → MirrorMaker 2 → Azure Event Hubs/GCP Pub/Sub. The replication lag target is under 1 second. If the Kafka MirrorMaker 2 process crashes and is down for 30 minutes before being detected, what is the state of data in Azure CosmosDB and GCP Cloud Spanner, and how do you recover consistency?

110. The failover strategy for a single AZ failure is "fully automatic in < 30 seconds." The mechanism relies on CloudFlare health checks with a 30-second interval and 2 consecutive failure threshold. What is the actual worst-case detection time, and what is the user impact during that window?

111. Redis failure is listed as "acceptable loss" for RPO. The cart-service stores shopping carts in Redis. During a Redis cluster failure, users lose their carts. What is the business impact of this design decision, and what alternative architectures would provide cart durability without sacrificing the performance characteristics of Redis?

112. The database failover runbook requires restarting all application connection pools after an Aurora failover. With 5 services each doing a rolling restart of 3 pods, estimate the total time for connection pool recovery and the error rate users experience during this window.

113. The DR communication plan states: "Enterprise customer notification < 15 minutes for P1." The incident management process has a 5-minute acknowledgment SLA and a 15-minute triage phase. Is the 15-minute customer notification target achievable, and what automation would you build to meet it?

### 6.2 Backup & Recovery

114. The backup strategy retains Aurora snapshots for 35 days (daily automated) and 1 year (weekly manual). A compliance requirement mandates that financial transaction data be recoverable for 7 years. The current backup strategy does not cover this. How would you extend the backup strategy to meet this requirement cost-effectively?

115. S3 cross-region replication has a lag of up to 15 minutes for the assets bucket. If the primary region (us-east-1) fails and the DR region (us-west-2) is activated, what is the maximum data loss for product images and user-uploaded content, and how does this affect the user experience in DR mode?

116. Terraform state is stored in S3 with versioning enabled. A `terraform apply` in production partially fails — 3 of 12 security group rules were created before the error. The state file now reflects partial reality. Walk through the exact recovery steps using `terraform state` commands and S3 version history without causing additional downtime.

117. The platform has no mention of database backup testing (restore drills). A backup that has never been tested is not a backup. Design a monthly automated restore drill for Aurora PostgreSQL that validates backup integrity without impacting production, and define the success criteria.

118. CosmosDB is configured with multi-region write (westeurope + eastus2) and automatic failover enabled. If a network partition occurs between the two write regions, CosmosDB must choose between consistency and availability. Given that payments use "Strong" consistency and product catalog uses "Session" consistency, what happens to each workload during the partition?

### 6.3 Multi-Region Operational Challenges

119. The multi-region deployment process deploys to AWS first (canary 5%), then Azure, then GCP sequentially. If a bug is discovered after the Azure deployment but before GCP, you now have AWS (100% new version) and Azure (100% new version) running the buggy code. What is your rollback strategy across two clouds simultaneously?

120. The platform uses cookie-based session affinity with a 30-minute TTL at CloudFlare. During a planned maintenance window for the AWS region, CloudFlare will route existing sessions to Azure. What happens to users who have active sessions (JWT tokens, Redis sessions) that were created on AWS, and how does the auth-service handle cross-cloud session validation?

121. Geo-routing sends APAC users to GCP asia-east1 with a P99 latency target of 200ms. The current P99 is 120ms. A new feature adds a synchronous call to the recommendation-service (hosted only in AWS us-east-1) from the product-service. What is the latency impact for APAC users, and how would you architect this to maintain the 200ms target?

122. The platform targets < 100ms P99 latency for US East users (currently ~45ms). A database schema migration requires a table lock on the orders table for approximately 8 seconds. How do you execute this migration with zero user-visible latency impact?

---

## 7. Advanced Cross-Cutting Questions

### 7.1 Architecture Trade-offs & Design Decisions

123. The platform chose microservices over a monolith. Given that the cart-service (Node.js/Redis), order-service (Java/PostgreSQL), and payment-service (Go/PostgreSQL) must coordinate for a single checkout transaction, how do you handle distributed transaction consistency without two-phase commit? What pattern does this platform use, and what are its failure modes?

124. The search-service is a separate microservice wrapping Elasticsearch, while the product-service also connects to Elasticsearch for product indexing. This creates two services with knowledge of the same Elasticsearch cluster. What are the coupling risks, and how would you redesign the boundary between product-service and search-service?

125. The platform uses both Kafka (for async events) and direct HTTP calls (via Istio) for service-to-service communication. What is the decision framework for choosing between synchronous HTTP and asynchronous Kafka for a new inter-service integration?

126. The Makefile provides developer shortcuts like `make dev-up`. In a team of 50 engineers across 3 time zones, how do you ensure local development environment parity with production, and what are the risks when `docker-compose.yml` diverges from the Kubernetes manifests?

127. The platform has 9 services but the Kubernetes base manifests only define deployments for 5 services (frontend, auth, cart, notification, search). What are the operational risks of having incomplete Kubernetes manifests in the repository, and how does this affect the GitOps model?

### 7.2 Organizational & Process Questions

128. The error budget policy requires "executive notification" when budget falls below 10%. How do you present error budget status to non-technical executives in a way that drives the right business decisions about deployment velocity versus reliability investment?

129. The platform has both GitHub Actions and Jenkins pipelines, plus GitLab CI. This is three CI/CD systems for one platform. What are the organizational and technical risks of this multi-CI approach, and under what circumstances is it justified?

130. The postmortem process requires completion within 48 hours of incident resolution. A P1 incident occurs on Friday at 11 PM and is resolved by Saturday 2 AM. The 48-hour deadline falls on Sunday 2 AM. How do you ensure postmortem quality while respecting engineer well-being, and what is the minimum viable postmortem for a weekend incident?

131. The on-call rotation is 1-week rotations for all senior engineers. A new engineer joins the team. What is the minimum onboarding period and competency checklist before they should be added to the on-call rotation for this platform?

132. The chaos engineering program requires error budget > 20% before running experiments. The SRE team wants to run a chaos experiment but the product team is pushing for a feature deployment that will consume approximately 15% of the remaining budget. How do you facilitate the decision between the SRE team and product team, and what data do you bring to the conversation?

### 7.3 Emerging Challenges & Future State

133. The capacity planning document projects 100,000 RPS in 18 months and recommends "full database sharding." The current Aurora PostgreSQL is a single logical database serving 5 services (auth, product, order, payment, inventory). What is the migration path from a shared database to per-service databases, and what is the biggest risk during the transition?

134. The platform currently has no mention of a service catalog or API versioning strategy. As the platform grows from 9 to 30+ microservices, what governance mechanisms are needed to prevent API incompatibilities between services, and how does this affect the CI/CD pipeline?

135. The recommendation-service uses Python for ML inference. As the model grows in complexity, inference latency increases. At what point would you consider moving ML inference to a dedicated serving infrastructure (e.g., TensorFlow Serving, Triton), and how would this affect the Kubernetes resource configuration?

136. The platform uses Kafka with Zookeeper (Confluent 7.5.0). Kafka is deprecating Zookeeper in favor of KRaft mode. What is the migration path from Zookeeper-based Kafka to KRaft, and what are the risks of this migration in a production environment with active event replication across clouds?

137. The security/runtime-security.md mentions eBPF monitoring. Falco currently uses kernel module-based syscall interception. What are the advantages of migrating Falco to eBPF-based detection, and what Kubernetes version and kernel version requirements must be met across EKS, AKS, and GKE?

---

*Total: 137 interview questions covering Architecture & System Design, Real-Time Issues & Operational Challenges, SRE & Observability, Cost Optimization, Security & Compliance, Disaster Recovery & Business Continuity, and Advanced Cross-Cutting topics.*