# Post-Mortem Template — NexaCommerce

**Instructions**: Complete this template within 48 hours of incident resolution. Focus on systemic issues, not individual blame. Share with all stakeholders.

---

## Incident Summary

| Field | Value |
|-------|-------|
| **Incident ID** | INC-YYYY-NNN |
| **Title** | [Brief description of what happened] |
| **Date** | YYYY-MM-DD |
| **Duration** | X hours Y minutes |
| **Severity** | P1 / P2 / P3 |
| **Services Affected** | [List services] |
| **Users Affected** | [Estimated count / percentage] |
| **Revenue Impact** | $X (estimated) |
| **Incident Commander** | @name |
| **Author(s)** | @name, @name |
| **Reviewers** | @name, @name |

---

## Impact

### User Impact
- [Describe what users experienced]
- [Quantify: X% of users could not complete checkout]
- [Geographic scope: US, EU, APAC]

### Business Impact
- Orders lost: ~X
- Revenue impact: ~$X
- SLA breach: Yes / No
- Error budget consumed: X% of monthly budget

### Technical Impact
- Services down: [list]
- Error rate peak: X%
- Latency P99 peak: Xms
- Data loss: None / [describe if any]

---

## Timeline

| Time (UTC) | Event |
|-----------|-------|
| HH:MM | Alert fired: [alert name] |
| HH:MM | On-call engineer acknowledged |
| HH:MM | Incident declared P[1/2] |
| HH:MM | [Key investigation step] |
| HH:MM | Root cause identified |
| HH:MM | Mitigation applied: [describe] |
| HH:MM | Service restored |
| HH:MM | Incident resolved |
| HH:MM | Post-mortem scheduled |

---

## Root Cause Analysis

### What Happened
[Describe the technical root cause in detail. Be specific about what failed and why.]

### Why It Happened (5 Whys)

1. **Why** did users experience errors?
   → [Answer]

2. **Why** did [answer 1] happen?
   → [Answer]

3. **Why** did [answer 2] happen?
   → [Answer]

4. **Why** did [answer 3] happen?
   → [Answer]

5. **Why** did [answer 4] happen?
   → [Root cause]

### Contributing Factors
- [Factor 1: e.g., "Insufficient load testing before deployment"]
- [Factor 2: e.g., "Alert threshold too high, delayed detection"]
- [Factor 3: e.g., "Runbook not updated with new architecture"]

---

## Detection

| Question | Answer |
|----------|--------|
| How was the incident detected? | [Alert / Customer report / Internal monitoring] |
| Time from start to detection | X minutes |
| Was alerting adequate? | Yes / No — [explain] |
| Were there earlier warning signs? | Yes / No — [explain] |

---

## Response

| Question | Answer |
|----------|--------|
| Was the runbook helpful? | Yes / No — [explain] |
| Were the right people paged? | Yes / No — [explain] |
| Was communication effective? | Yes / No — [explain] |
| Was the status page updated promptly? | Yes / No |

---

## Resolution

### What Fixed It
[Describe the exact steps taken to resolve the incident]

### Why This Fix Worked
[Explain the technical reason the fix resolved the issue]

---

## What Went Well ✅

- [e.g., "Alert fired within 2 minutes of issue start"]
- [e.g., "Team assembled quickly on incident bridge"]
- [e.g., "Rollback completed in under 5 minutes"]
- [e.g., "Status page was updated promptly"]

---

## What Could Be Improved ⚠️

- [e.g., "Alert threshold was too conservative, delayed detection by 10 minutes"]
- [e.g., "Runbook for this scenario was missing"]
- [e.g., "No automated rollback triggered"]
- [e.g., "Database failover took longer than expected"]

---

## Action Items

| # | Action | Owner | Priority | Due Date | Status |
|---|--------|-------|----------|----------|--------|
| 1 | [Specific action to prevent recurrence] | @name | P1 | YYYY-MM-DD | Open |
| 2 | [Improve alerting/monitoring] | @name | P2 | YYYY-MM-DD | Open |
| 3 | [Update runbook] | @name | P2 | YYYY-MM-DD | Open |
| 4 | [Add automated test/chaos experiment] | @name | P3 | YYYY-MM-DD | Open |
| 5 | [Infrastructure improvement] | @name | P3 | YYYY-MM-DD | Open |

---

## Lessons Learned

### For Engineering
- [Technical lesson 1]
- [Technical lesson 2]

### For SRE/Operations
- [Operational lesson 1]
- [Operational lesson 2]

### For Process
- [Process lesson 1]
- [Process lesson 2]

---

## Appendix

### Relevant Metrics
```
# Paste key Prometheus queries and results here
# Include screenshots from Grafana if helpful
```

### Relevant Logs
```
# Paste key log excerpts here (redact sensitive data)
```

### Related Incidents
- [Link to similar past incidents]

### References
- [Link to relevant documentation]
- [Link to code changes]
- [Link to Jira/Linear tickets]

---

*This post-mortem follows a blameless culture. The goal is to improve systems and processes, not to assign blame to individuals.*
