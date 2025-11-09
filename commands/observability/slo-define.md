---
description: Calculate and define SLOs/SLIs with error budgets and monitoring
---

# Define SLO/SLI Command

You are helping define Service Level Objectives (SLOs), Service Level Indicators (SLIs), and error budgets for reliable service management.

## Requirements

**User must provide:**
- Service/application name
- Service type (user-facing, internal API, batch process, etc.)
- Business criticality (critical, important, standard)
- User expectations for availability and performance

**Prerequisites:**
- Understanding of service architecture
- Access to historical performance data
- Metrics collection infrastructure in place
- Stakeholder alignment on targets

## SLO Fundamentals

**Key Concepts:**

- **SLI (Service Level Indicator):** Quantitative measure of service level
  - Examples: Availability %, Request latency, Error rate

- **SLO (Service Level Objective):** Target value or range for an SLI
  - Example: 99.9% availability over 30 days

- **Error Budget:** Allowed failure within SLO period
  - Example: 99.9% SLO = 0.1% error budget = 43.2 minutes/month downtime

- **SLA (Service Level Agreement):** Contract with consequences
  - Typically more lenient than internal SLOs

## SLI Selection Guide

### 1. Availability SLI (Uptime)

**Definition:** Percentage of successful requests

**Measurement:**
```
Availability = (Successful Requests / Total Requests) × 100%
```

**PromQL Example:**
```promql
# Availability (success rate)
sum(rate(http_requests_total{status=~"2.."}[30d]))
/
sum(rate(http_requests_total[30d]))

# Or inverted (failure rate)
1 - (
  sum(rate(http_requests_total{status=~"[45].."}[30d]))
  /
  sum(rate(http_requests_total[30d]))
)
```

**Use for:**
- User-facing web services
- APIs
- Critical backend services

**Common Targets:**
- Critical services: 99.99% (52.6 min/year downtime)
- Important services: 99.9% (8.76 hours/year)
- Standard services: 99.5% (1.83 days/year)
- Internal tools: 99% (3.65 days/year)

### 2. Latency SLI (Performance)

**Definition:** Percentage of requests completed within target time

**Measurement:**
```
Latency SLI = (Requests under threshold / Total Requests) × 100%
```

**PromQL Example:**
```promql
# P95 latency under 500ms
histogram_quantile(0.95,
  sum(rate(http_request_duration_seconds_bucket[30d])) by (le)
) < 0.5

# Or percentage of requests under threshold
sum(rate(http_request_duration_seconds_bucket{le="0.5"}[30d]))
/
sum(rate(http_request_duration_seconds_count[30d]))
```

**Use for:**
- User-facing applications
- Real-time APIs
- Interactive services

**Common Targets:**
- API endpoints: 95% of requests < 200ms
- Web pages: 95% of requests < 1s
- Background jobs: 95% complete within 10s

### 3. Quality SLI (Correctness)

**Definition:** Percentage of valid/correct responses

**Measurement:**
```
Quality = (Valid Responses / Total Responses) × 100%
```

**Examples:**
- Data pipeline: % of records processed correctly
- Search: % of queries returning relevant results
- Recommendations: % of successful recommendations

**PromQL Example:**
```promql
# Data quality
sum(rate(records_processed_success[30d]))
/
sum(rate(records_processed_total[30d]))
```

### 4. Durability SLI (Data Protection)

**Definition:** Percentage of data retained without loss

**Measurement:**
```
Durability = (Data Retained / Data Stored) × 100%
```

**Use for:**
- Storage systems
- Databases
- Backup systems

**Common Targets:**
- Critical data: 99.999999999% (11 nines)
- Important data: 99.99%
- Standard data: 99.9%

## SLO Definition Framework

### Step 1: Identify User Journey

**Map critical user flows:**
1. User authentication
2. Search/browse products
3. Add to cart
4. Checkout process
5. Order confirmation

**For each flow, identify:**
- Key interactions
- Performance expectations
- Acceptable failure rate
- Impact of degradation

### Step 2: Define SLIs

**Example: E-commerce Checkout Service**

**SLI 1: Availability**
```yaml
name: checkout_availability
description: Percentage of successful checkout requests
measurement: |
  sum(rate(checkout_requests_total{status="success"}[30d]))
  /
  sum(rate(checkout_requests_total[30d]))
target: 99.95%  # 21.6 minutes/month downtime
```

**SLI 2: Latency**
```yaml
name: checkout_latency_p95
description: 95th percentile checkout completion time
measurement: |
  histogram_quantile(0.95,
    sum(rate(checkout_duration_seconds_bucket[30d])) by (le)
  )
target: < 2 seconds for 95% of requests
```

**SLI 3: Quality**
```yaml
name: payment_success_rate
description: Percentage of valid payment attempts that succeed
measurement: |
  sum(rate(payment_attempts_success[30d]))
  /
  sum(rate(payment_attempts_valid[30d]))
target: 99.9%
```

### Step 3: Calculate Error Budgets

**Error Budget Formula:**
```
Error Budget = 100% - SLO Target
```

**30-Day Error Budget Examples:**

| SLO | Error Budget | Downtime Allowed |
|-----|--------------|------------------|
| 99.99% | 0.01% | 4.32 minutes |
| 99.95% | 0.05% | 21.6 minutes |
| 99.9% | 0.1% | 43.2 minutes |
| 99.5% | 0.5% | 3.6 hours |
| 99% | 1% | 7.2 hours |

**Error Budget Tracking:**
```promql
# Current error budget consumption
100 * (1 - (
  sum(rate(http_requests_total{status=~"2.."}[30d]))
  /
  sum(rate(http_requests_total[30d]))
))

# Error budget remaining (%)
(
  0.05  # Error budget (for 99.95% SLO)
  -
  100 * (1 - (
    sum(rate(http_requests_total{status=~"2.."}[30d]))
    /
    sum(rate(http_requests_total[30d]))
  ))
) / 0.05 * 100
```

### Step 4: Set Alert Thresholds

**Multi-window, Multi-burn-rate Alerting:**

**Fast Burn (Page immediately):**
- Window: 1 hour
- Burn rate: 14.4x (exhausts 30-day budget in 2 days)
- Alert if: Error budget burning too fast

```yaml
- alert: ErrorBudgetFastBurn
  expr: |
    (
      1 - (
        sum(rate(http_requests_total{status=~"2.."}[1h]))
        /
        sum(rate(http_requests_total[1h]))
      )
    ) > (14.4 * (100 - 99.95) / 100)  # 14.4x burn rate
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Error budget burning fast"
    description: "Will exhaust in < 2 days at current rate"
```

**Slow Burn (Notify, don't page):**
- Window: 6 hours
- Burn rate: 6x (exhausts 30-day budget in 5 days)

```yaml
- alert: ErrorBudgetSlowBurn
  expr: |
    (
      1 - (
        sum(rate(http_requests_total{status=~"2.."}[6h]))
        /
        sum(rate(http_requests_total[6h]))
      )
    ) > (6 * (100 - 99.95) / 100)
  for: 30m
  labels:
    severity: warning
```

### Step 5: Implementation Example

**Complete SLO Configuration (Prometheus):**

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: checkout-slo
  namespace: monitoring
spec:
  groups:
  - name: checkout_slo
    interval: 30s
    rules:
    # SLI: Availability
    - record: sli:checkout_availability:ratio
      expr: |
        sum(rate(checkout_requests_total{status="success"}[30d]))
        /
        sum(rate(checkout_requests_total[30d]))

    # SLI: Latency
    - record: sli:checkout_latency_p95:seconds
      expr: |
        histogram_quantile(0.95,
          sum(rate(checkout_duration_seconds_bucket[30d])) by (le)
        )

    # Error Budget Remaining (30-day window)
    - record: slo:checkout:error_budget_remaining:ratio
      expr: |
        (
          0.0005  # Error budget for 99.95% SLO
          -
          (1 - sli:checkout_availability:ratio)
        ) / 0.0005

    # Fast burn alert (1 hour, 14.4x)
    - alert: CheckoutErrorBudgetFastBurn
      expr: |
        (
          1 - (
            sum(rate(checkout_requests_total{status="success"}[1h]))
            /
            sum(rate(checkout_requests_total[1h]))
          )
        ) > (14.4 * 0.0005)
        and
        (
          1 - (
            sum(rate(checkout_requests_total{status="success"}[5m]))
            /
            sum(rate(checkout_requests_total[5m]))
          )
        ) > (14.4 * 0.0005)
      labels:
        severity: critical
        slo: checkout_availability
      annotations:
        summary: "Checkout error budget burning fast"
        description: |
          Error budget will be exhausted in < 2 days
          Current availability: {{ $value | humanizePercentage }}
          Target: 99.95%

    # Slow burn alert (6 hours, 6x)
    - alert: CheckoutErrorBudgetSlowBurn
      expr: |
        (
          1 - (
            sum(rate(checkout_requests_total{status="success"}[6h]))
            /
            sum(rate(checkout_requests_total[6h]))
          )
        ) > (6 * 0.0005)
      for: 30m
      labels:
        severity: warning
        slo: checkout_availability
      annotations:
        summary: "Checkout error budget burning slowly"
        description: "Monitor closely, budget will exhaust in < 5 days"

    # Budget exhausted
    - alert: CheckoutErrorBudgetExhausted
      expr: slo:checkout:error_budget_remaining:ratio < 0
      labels:
        severity: critical
      annotations:
        summary: "Checkout SLO violated - error budget exhausted"
        description: "Stop risky changes, focus on reliability"
```

## SLO Dashboarding

**Key Metrics to Display:**

1. **Current SLI Value**
   - Real-time availability
   - Current latency (P50, P95, P99)
   - Error rate

2. **SLO Target**
   - Visual threshold line
   - Color coding (green/yellow/red)

3. **Error Budget**
   - Remaining budget (%)
   - Burn rate
   - Projected exhaustion date

4. **Historical Compliance**
   - SLO compliance over time
   - Rolling 30-day window
   - Incident markers

**Grafana Dashboard Example:**

```json
{
  "dashboard": {
    "title": "Checkout Service SLO",
    "panels": [
      {
        "title": "Availability (30d SLI)",
        "targets": [
          {
            "expr": "sli:checkout_availability:ratio * 100"
          }
        ],
        "thresholds": [
          { "value": 99.95, "color": "green" },
          { "value": 99.9, "color": "yellow" },
          { "value": 0, "color": "red" }
        ]
      },
      {
        "title": "Error Budget Remaining",
        "targets": [
          {
            "expr": "slo:checkout:error_budget_remaining:ratio * 100"
          }
        ]
      },
      {
        "title": "P95 Latency",
        "targets": [
          {
            "expr": "sli:checkout_latency_p95:seconds"
          }
        ]
      }
    ]
  }
}
```

## Best Practices

**SLO Selection:**
- Start with 1-3 key SLOs (availability, latency)
- Focus on user-facing metrics
- Base targets on historical data + improvement
- Align with business requirements
- Make SLOs achievable (leave room for growth)

**Target Setting:**
- Avoid "100%" or "nine nines" unless truly needed
- Higher SLOs = higher cost (redundancy, complexity)
- Balance reliability with innovation velocity
- Review and adjust quarterly

**Error Budget Policy:**
- **Budget available:** Normal velocity, accept risk
- **Budget low (<25%):** Slow down, increase caution
- **Budget exhausted:** Feature freeze, focus on reliability

**Measurement:**
- Use consistent time windows (28-day, 30-day)
- Measure from user perspective (not server-side only)
- Exclude planned maintenance from SLO calc
- Include dependency failures in SLO

**Communication:**
- Share SLO dashboards widely
- Regular SLO review meetings
- Celebrate SLO achievements
- Learn from SLO misses (blameless postmortems)

**Common Pitfalls to Avoid:**
- Too many SLOs (focus on critical ones)
- Unrealistic targets (99.999% without justification)
- Internal metrics vs user-experienced metrics
- Ignoring error budget (not using it for decisions)
- Static SLOs (should evolve with service)

## SLO Templates by Service Type

### User-Facing Web Application
```yaml
slos:
  - name: availability
    target: 99.9%
    window: 30d
  - name: latency_p95
    target: 1s
    window: 30d
  - name: latency_p99
    target: 3s
    window: 30d
```

### Internal API
```yaml
slos:
  - name: availability
    target: 99.5%
    window: 30d
  - name: latency_p95
    target: 500ms
    window: 30d
```

### Batch Processing
```yaml
slos:
  - name: completion_rate
    target: 99.9%
    window: 30d
  - name: processing_time
    target: 95% complete within 1 hour
    window: 30d
```

### Data Storage
```yaml
slos:
  - name: durability
    target: 99.999999999%
    window: 365d
  - name: availability
    target: 99.95%
    window: 30d
  - name: latency_p99
    target: 100ms
    window: 30d
```
