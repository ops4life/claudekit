---
description: Structured postmortem template with timeline, RCA, and action items
---

# Incident Postmortem Command

You are helping create a comprehensive, blameless postmortem document to learn from incidents and prevent recurrence.

## Requirements

**User must provide:**
- Incident description and timeline
- Services/systems affected
- User impact and duration
- Root cause (if known)
- Responders involved

**Prerequisites:**
- Incident has been resolved
- Logs, metrics, and evidence collected
- Key responders available for input
- Timeline of events documented

## Postmortem Principles

**Blameless Culture:**
- Focus on systems and processes, not individuals
- Assume good intentions
- Encourage honest discussion
- Learn from failures
- Celebrate effective responses

**Goals:**
- Understand what happened and why
- Identify root causes and contributing factors
- Prevent recurrence through action items
- Share learnings across organization
- Improve incident response processes

## Postmortem Template

### Incident Summary

**Incident ID:** `INC-2025-001`

**Date:** `2025-01-15`

**Duration:** `2 hours 34 minutes (14:23 UTC - 16:57 UTC)`

**Severity:** `SEV-1 (Critical)` | `SEV-2 (High)` | `SEV-3 (Medium)`

**Status:** `Resolved` | `Monitoring` | `In Progress`

**Services Affected:**
- Checkout Service (complete outage)
- Product Catalog (degraded performance)
- User Authentication (intermittent failures)

**User Impact:**
- 100% of checkout attempts failed
- Estimated 15,000 affected users
- $125,000 in lost revenue
- 2,500 support tickets created

**Root Cause (Brief):**
Database connection pool exhaustion due to connection leak introduced in v2.5.3 deployment.

---

### Timeline

**All times in UTC. Key decision points in bold.**

| Time | Event | Actor/System |
|------|-------|--------------|
| 14:15 | Deploy v2.5.3 to production (10% canary) | CI/CD Pipeline |
| 14:23 | **First alerts: checkout error rate elevated** | Monitoring System |
| 14:25 | On-call engineer paged | PagerDuty |
| 14:28 | Engineer acknowledges alert, begins investigation | John Doe (SRE) |
| 14:32 | Error rate continues climbing, checkout success rate at 85% | Monitoring |
| 14:35 | **Incident declared SEV-2, war room opened** | John Doe |
| 14:37 | Checking recent deployments, suspect canary rollout | Incident Team |
| 14:40 | **Decision: Rollback v2.5.3 deployment** | Incident Commander |
| 14:42 | Rollback initiated | Jane Smith (Dev) |
| 14:47 | Rollback completed, but errors persist | CI/CD |
| 14:50 | **Elevated to SEV-1: Full checkout outage** | Incident Commander |
| 14:52 | Database team engaged, connection pool analysis begins | DB Team |
| 14:58 | Identified: DB connection pool exhausted (all 100 connections in use) | Alice Johnson (DBA) |
| 15:05 | Attempted connection pool expansion to 200 | DB Team |
| 15:08 | Expansion helped briefly, but pool exhausted again | Monitoring |
| 15:12 | **Root cause identified: Connection leak in v2.5.3 code** | Dev Team |
| 15:15 | Analysis: Rollback didn't help because leaked connections persisted | Incident Team |
| 15:18 | **Decision: Restart all checkout service pods to clear connections** | Incident Commander |
| 15:20 | Rolling restart initiated (3 pods at a time) | SRE Team |
| 15:35 | All pods restarted, connection count normalizing | Monitoring |
| 15:42 | Checkout success rate recovering: 50% → 75% → 95% | Monitoring |
| 15:55 | Checkout success rate stable at 99.5% | Monitoring |
| 16:05 | User-facing systems validated, no errors | Incident Team |
| 16:20 | Extended monitoring period (30 minutes) | Incident Commander |
| 16:50 | All metrics within normal ranges | Monitoring |
| 16:57 | **Incident resolved, SEV-1 closed** | Incident Commander |
| 17:30 | Hot-fix v2.5.4 with connection leak fix merged | Dev Team |

---

### Root Cause Analysis

**What Happened:**

On January 15, 2025, we deployed v2.5.3 of the checkout service which introduced a database connection leak. The leak caused connections to remain open after transactions completed, gradually exhausting the connection pool. Once exhausted, all new checkout requests failed, resulting in a complete outage.

**Root Cause:**

A code change in the payment processing module (PR #1234) failed to properly close database connections in error-handling paths. Specifically:

```python
# Problematic code in v2.5.3
def process_payment(payment_data):
    conn = get_db_connection()
    try:
        result = execute_payment(conn, payment_data)
        return result
    except PaymentError as e:
        log_error(e)
        return None
    # Connection not closed on error path!
```

**Why It Wasn't Caught:**

1. **Testing Gap:** Integration tests didn't verify connection cleanup
2. **Code Review Miss:** Reviewers focused on business logic, not resource management
3. **Canary Too Fast:** 10% canary rolled to 100% in 8 minutes (should be slower)
4. **Monitoring Gap:** No alert for connection pool utilization
5. **Deployment Process:** No load testing in staging with realistic traffic patterns

**Contributing Factors:**

1. **Time Pressure:** Feature rushed to meet deadline
2. **Context Switch:** Changes made during on-call rotation handoff
3. **Library Update:** New ORM version changed connection handling behavior
4. **Documentation:** Connection management best practices not documented

---

### What Went Well

**Strengths in Response:**

1. **Fast Detection:** Automated monitoring alerted within 8 minutes of deployment
2. **Clear Communication:** War room established quickly, stakeholders informed
3. **Team Coordination:** Cross-functional team assembled and worked effectively
4. **Quick Diagnosis:** DB team identified connection pool issue within 20 minutes
5. **Decisive Action:** Incident commander made clear decisions under pressure
6. **Documentation:** Timeline documented in real-time during incident

**Effective Tools/Processes:**

- PagerDuty escalation worked correctly
- Grafana dashboards provided quick visibility
- Slack war room kept everyone aligned
- Runbooks for rollback were accurate
- Database monitoring tools essential for diagnosis

---

### What Went Wrong

**Gaps and Issues:**

1. **Slow Rollback Decision:** Took 17 minutes to decide on rollback (should be faster)
2. **Rollback Ineffective:** Didn't realize leaked connections would persist after rollback
3. **Inadequate Canary:** Canary rollout too fast to catch gradual leak
4. **Missing Monitoring:** No alerts for DB connection pool utilization
5. **Test Coverage:** Integration tests didn't validate resource cleanup
6. **Load Testing:** Staging environment didn't simulate production load

**Process Failures:**

- Code review didn't catch resource leak
- PR template missing "resource management" checklist
- No requirement for load testing before production
- Canary deployment policy not enforced (should be slower)

---

### Lessons Learned

**Technical Insights:**

1. Connection pools are a critical resource requiring explicit monitoring
2. Resource leaks may not manifest immediately (gradual exhaustion)
3. Rollback doesn't fix resource exhaustion without process restart
4. Error paths in code require equal scrutiny as success paths
5. ORM behavior changes can have subtle, dangerous effects

**Process Insights:**

1. Faster canary rollouts increase risk without proportional speed benefit
2. Code review checklists should include resource management
3. Load testing in staging is essential for database-intensive changes
4. Connection pool monitoring must trigger alerts before exhaustion
5. Runbooks should account for stateful resource issues (not just code rollback)

---

### Action Items

**Immediate (This Week):**

| ID | Action | Owner | Due Date | Status |
|----|--------|-------|----------|--------|
| 1 | Add DB connection pool monitoring and alerting (alert at 75%) | Alice (DBA) | 2025-01-17 | ✅ Complete |
| 2 | Deploy hot-fix v2.5.4 with connection leak fix | Jane (Dev) | 2025-01-16 | ✅ Complete |
| 3 | Add integration test for connection cleanup | Dev Team | 2025-01-19 | 🟡 In Progress |
| 4 | Update code review checklist to include resource management | John (SRE) | 2025-01-18 | ✅ Complete |

**Short-Term (This Month):**

| ID | Action | Owner | Due Date | Status |
|----|--------|-------|----------|--------|
| 5 | Implement automated load testing in CI pipeline | QA Team | 2025-01-30 | 🟡 In Progress |
| 6 | Slow down canary rollout policy (10% for 30 min minimum) | Platform Team | 2025-01-25 | ⚪ Not Started |
| 7 | Add connection pool metrics to all service dashboards | SRE Team | 2025-01-28 | 🟡 In Progress |
| 8 | Document connection management best practices | Tech Leads | 2025-02-05 | ⚪ Not Started |
| 9 | Implement circuit breaker pattern for database connections | Dev Team | 2025-02-10 | ⚪ Not Started |

**Long-Term (This Quarter):**

| ID | Action | Owner | Due Date | Status |
|----|--------|-------|----------|--------|
| 10 | Upgrade staging environment to match production scale | Infra Team | 2025-03-15 | ⚪ Not Started |
| 11 | Implement automated resource leak detection in CI | Platform Team | 2025-03-30 | ⚪ Not Started |
| 12 | Chaos engineering: Test connection pool exhaustion scenarios | SRE Team | 2025-04-01 | ⚪ Not Started |
| 13 | Training: Resource management and connection pooling | Engineering | 2025-04-15 | ⚪ Not Started |

---

### Metrics and Impact

**Business Impact:**

- Revenue Loss: $125,000 (estimated)
- Affected Users: ~15,000
- Support Tickets: 2,500
- Customer Satisfaction Score: Dropped from 4.5 to 3.2 (temporary)

**SLO Impact:**

- Availability SLO (99.9%): Violated (99.64% for the month)
- Error Budget: Fully exhausted (used 100% in single incident)
- Recovery: 1 week of error budget freeze (no risky deployments)

**Technical Metrics:**

- Time to Detect (TTD): 8 minutes
- Time to Engage (TTE): 5 minutes
- Time to Mitigate (TTM): 92 minutes (from alert to resolution)
- Time to Resolve (TTR): 154 minutes (from alert to incident close)
- Mean Time to Recovery (MTTR): 154 minutes

**Response Effectiveness:**

- Responders: 12 engineers across 4 teams
- Escalations: 2 (SEV-2 → SEV-1, then to VP Engineering)
- War Room Participants: Average 8 concurrent participants
- Communication Channels: Slack (primary), Zoom (secondary)

---

### Appendices

**A. Related Links:**

- Incident Slack Channel: #incident-2025-001
- Monitoring Dashboard: https://grafana.example.com/d/incident-001
- Code Change (PR #1234): https://github.com/org/repo/pull/1234
- Hot-fix (PR #1250): https://github.com/org/repo/pull/1250
- Database Metrics: https://datadog.com/dashboard/db-connections

**B. Key Graphs/Screenshots:**

- Checkout error rate spike graph
- Database connection pool utilization
- Service deployment timeline
- Customer impact heatmap

**C. Communication Timeline:**

- 14:35 - Internal: Engineering team notified
- 14:50 - External: Status page updated (investigating)
- 15:20 - External: Status page updated (implementing fix)
- 16:57 - External: Status page updated (resolved)
- 18:00 - External: Customer email with explanation and apology

**D. SQL Queries for Analysis:**

```sql
-- Identify leaked connections
SELECT
  pid,
  state,
  state_change,
  query_start,
  NOW() - query_start AS duration
FROM pg_stat_activity
WHERE state != 'idle'
  AND NOW() - query_start > INTERVAL '5 minutes';
```

---

## Postmortem Best Practices

**Writing:**
- Complete within 48 hours of incident resolution
- Be specific and factual, not vague
- Include exact times and metrics
- Explain technical details clearly for all audiences
- Use "we" not "they" (collective responsibility)

**Review Process:**
- Share draft with all incident responders
- Collect feedback and incorporate
- Review with leadership for action item resourcing
- Publish to entire engineering organization
- Present in engineering all-hands (for SEV-1)

**Follow-up:**
- Weekly check-ins on action item progress
- Update status publicly (wiki, dashboard)
- Celebrate completed action items
- Retrospective after all items complete
- Share learnings in engineering blog

**Distribution:**
- Engineering wiki (searchable)
- Slack #postmortems channel
- Engineering all-hands (presentation)
- External blog (optional, for transparency)
- Customer communication (if user-facing)

**Avoid:**
- Blaming individuals
- Vague language ("poor communication")
- Action items without owners or dates
- Focusing on "what" without "why"
- Leaving action items incomplete
