---
description: Create monitoring alerts with SLO-based thresholds and best practices
---

# Create Monitoring Alert Command

You are helping create production-ready monitoring alerts based on SLOs, best practices, and actionable thresholds.

## Requirements

**User must provide:**
- Service/application to monitor
- Monitoring platform (Prometheus, Datadog, CloudWatch, Stackdriver, Azure Monitor)
- Alert type (availability, latency, errors, saturation, custom)
- Notification channels (Slack, PagerDuty, email, etc.)

**Prerequisites:**
- Monitoring infrastructure in place
- Metrics being collected
- Alert routing configured
- On-call rotation defined (for critical alerts)

## Alert Design Principles

**Good Alerts:**
- Indicate real problems affecting users
- Actionable (clear what to do)
- Not too noisy (appropriate thresholds)
- Properly prioritized (severity levels)
- Include context for responders

**Alert Fatigue Prevention:**
- Alert on symptoms, not causes
- Use SLO-based alerting when possible
- Implement alert aggregation
- Set appropriate evaluation periods
- Regular alert review and tuning

## Alert Categories

### 1. Availability Alerts (Uptime)

**Metric:** Success rate of requests

**Prometheus Alert:**

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: service-availability
  namespace: monitoring
spec:
  groups:
  - name: availability
    interval: 30s
    rules:
    # Critical: Service availability below SLO
    - alert: ServiceAvailabilityCritical
      expr: |
        (
          sum(rate(http_requests_total{job="myapp",status=~"2.."}[5m]))
          /
          sum(rate(http_requests_total{job="myapp"}[5m]))
        ) < 0.99
      for: 5m
      labels:
        severity: critical
        team: platform
        service: myapp
      annotations:
        summary: "Service {{ $labels.job }} availability below SLO"
        description: |
          Service {{ $labels.job }} availability is {{ $value | humanizePercentage }}.
          SLO: 99%, Current: {{ $value | humanizePercentage }}
          Error budget at risk.
        runbook_url: "https://wiki.example.com/runbooks/availability"
        dashboard_url: "https://grafana.example.com/d/service-overview"

    # Warning: Service availability degraded
    - alert: ServiceAvailabilityWarning
      expr: |
        (
          sum(rate(http_requests_total{job="myapp",status=~"2.."}[5m]))
          /
          sum(rate(http_requests_total{job="myapp"}[5m]))
        ) < 0.995
      for: 10m
      labels:
        severity: warning
        team: platform
      annotations:
        summary: "Service {{ $labels.job }} availability degraded"
        description: |
          Availability: {{ $value | humanizePercentage }}
          Target: 99.5%
          Monitor closely, approaching SLO threshold.

    # Error Budget Burn Rate (Fast Burn)
    - alert: ErrorBudgetFastBurn
      expr: |
        (
          sum(rate(http_requests_total{job="myapp",status=~"5.."}[1h]))
          /
          sum(rate(http_requests_total{job="myapp"}[1h]))
        ) > (14.4 * 0.01)  # Burning 30d budget in 2 days
      labels:
        severity: critical
      annotations:
        summary: "Fast error budget burn detected"
        description: "Error budget will be exhausted in < 2 days at current rate"
```

**AWS CloudWatch (ALB Availability):**

```json
{
  "AlarmName": "ALB-Availability-Critical",
  "AlarmDescription": "ALB 5xx error rate above threshold",
  "MetricName": "HTTPCode_Target_5XX_Count",
  "Namespace": "AWS/ApplicationELB",
  "Statistic": "Sum",
  "Period": 300,
  "EvaluationPeriods": 2,
  "Threshold": 10,
  "ComparisonOperator": "GreaterThanThreshold",
  "Dimensions": [
    {
      "Name": "LoadBalancer",
      "Value": "app/myapp-lb/abc123"
    }
  ],
  "TreatMissingData": "notBreaching",
  "ActionsEnabled": true,
  "AlarmActions": [
    "arn:aws:sns:us-east-1:123456789:critical-alerts"
  ]
}
```

### 2. Latency Alerts (Performance)

**Prometheus Alert (P95 Latency):**

```yaml
- alert: HighLatencyP95
  expr: |
    histogram_quantile(0.95,
      sum(rate(http_request_duration_seconds_bucket{job="myapp"}[5m])) by (le)
    ) > 0.5
  for: 10m
  labels:
    severity: warning
    team: platform
  annotations:
    summary: "High P95 latency detected"
    description: |
      P95 latency: {{ $value | humanizeDuration }}
      SLO: 500ms
      Investigate performance degradation.
    dashboard: "https://grafana.example.com/d/latency"

- alert: HighLatencyP99
  expr: |
    histogram_quantile(0.99,
      sum(rate(http_request_duration_seconds_bucket{job="myapp"}[5m])) by (le)
    ) > 1.0
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Critical P99 latency spike"
    description: "P99 latency: {{ $value | humanizeDuration }}, SLO: 1s"
```

**Datadog Monitor (API Latency):**

```json
{
  "name": "API Latency P95 High",
  "type": "query alert",
  "query": "avg(last_10m):avg:http.request.duration{service:myapp} by {endpoint}.as_rate() > 0.5",
  "message": "@slack-platform @pagerduty\n\nAPI latency is above SLO.\n\n**Current P95**: {{value}}s\n**SLO**: 500ms\n**Endpoint**: {{endpoint.name}}\n\n[Dashboard](https://app.datadoghq.com/dashboard/abc123)",
  "tags": ["service:myapp", "team:platform"],
  "options": {
    "notify_no_data": false,
    "notify_audit": true,
    "require_full_window": false,
    "include_tags": true,
    "thresholds": {
      "critical": 0.5,
      "warning": 0.3
    },
    "evaluation_delay": 60
  }
}
```

### 3. Error Rate Alerts

**Prometheus (4xx/5xx Errors):**

```yaml
- alert: HighErrorRate
  expr: |
    (
      sum(rate(http_requests_total{job="myapp",status=~"[45].."}[5m]))
      /
      sum(rate(http_requests_total{job="myapp"}[5m]))
    ) > 0.05
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "High error rate: {{ $value | humanizePercentage }}"
    description: |
      Error rate is above 5% threshold.
      Check application logs and recent deployments.

- alert: High5xxErrors
  expr: |
    sum(rate(http_requests_total{job="myapp",status=~"5.."}[5m])) > 10
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "Server errors detected"
    description: "5xx errors: {{ $value | humanize }}/s"
```

### 4. Saturation Alerts (Resource Utilization)

**CPU Saturation:**

```yaml
- alert: HighCPUUsage
  expr: |
    (
      sum(rate(container_cpu_usage_seconds_total{pod=~"myapp-.*"}[5m]))
      by (pod)
      /
      sum(container_spec_cpu_quota{pod=~"myapp-.*"}/container_spec_cpu_period{pod=~"myapp-.*"})
      by (pod)
    ) > 0.8
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "Pod {{ $labels.pod }} CPU usage high"
    description: "CPU usage: {{ $value | humanizePercentage }}"

- alert: CPUThrottling
  expr: |
    rate(container_cpu_cfs_throttled_seconds_total{pod=~"myapp-.*"}[5m]) > 0.1
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "CPU throttling detected on {{ $labels.pod }}"
    description: "Consider increasing CPU limits"
```

**Memory Saturation:**

```yaml
- alert: HighMemoryUsage
  expr: |
    (
      container_memory_usage_bytes{pod=~"myapp-.*"}
      /
      container_spec_memory_limit_bytes{pod=~"myapp-.*"}
    ) > 0.9
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Pod {{ $labels.pod }} memory usage critical"
    description: |
      Memory usage: {{ $value | humanizePercentage }}
      Risk of OOMKill.
```

**Disk Saturation:**

```yaml
- alert: DiskSpaceLow
  expr: |
    (
      node_filesystem_avail_bytes{mountpoint="/"}
      /
      node_filesystem_size_bytes{mountpoint="/"}
    ) < 0.1
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "Disk space low on {{ $labels.instance }}"
    description: "Available: {{ $value | humanizePercentage }}"
```

### 5. Database Alerts

**Connection Pool Exhaustion:**

```yaml
- alert: DatabaseConnectionPoolHigh
  expr: |
    (
      db_connections_active
      /
      db_connections_max
    ) > 0.8
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Database connection pool utilization high"
    description: "{{ $value | humanizePercentage }} of connections in use"

- alert: DatabaseSlowQueries
  expr: |
    rate(mysql_global_status_slow_queries[5m]) > 10
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "High rate of slow database queries"
    description: "{{ $value }} slow queries/second"
```

### 6. Application-Specific Alerts

**Queue Depth:**

```yaml
- alert: QueueDepthHigh
  expr: |
    queue_depth{queue="orders"} > 1000
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "Orders queue depth high: {{ $value }}"
    description: "Check worker capacity and processing rate"

- alert: QueueProcessingStalled
  expr: |
    rate(queue_messages_processed[5m]) == 0 and queue_depth > 0
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Queue processing stalled"
    description: "Messages in queue but no processing activity"
```

**Background Job Failures:**

```yaml
- alert: HighJobFailureRate
  expr: |
    (
      sum(rate(background_jobs_failed_total[5m]))
      /
      sum(rate(background_jobs_total[5m]))
    ) > 0.05
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "High background job failure rate"
    description: "{{ $value | humanizePercentage }} of jobs failing"
```

## Alert Configuration Best Practices

**Severity Levels:**

- **Critical (Page):** Immediate action required, user impact
  - Service down
  - Error budget depleting rapidly
  - Data loss risk
  - Security breach

- **Warning (Notify):** Attention needed, potential future impact
  - Resource utilization high
  - Approaching SLO threshold
  - Performance degradation

- **Info (Log):** Informational, no action needed
  - Deployment completed
  - Scaling event occurred

**Alert Tuning:**

```yaml
# Use appropriate evaluation periods
for: 5m  # Don't alert on brief spikes

# Set realistic thresholds
threshold: 0.99  # Based on SLO, not arbitrary

# Include context
annotations:
  summary: "Clear, concise summary"
  description: |
    - What is wrong
    - Current value vs threshold
    - Potential impact
    - Where to look
  runbook_url: "Link to investigation steps"
  dashboard_url: "Link to relevant dashboard"
```

**Alert Routing (AlertManager):**

```yaml
route:
  receiver: 'default'
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  routes:
  # Critical alerts -> PagerDuty
  - match:
      severity: critical
    receiver: pagerduty
    continue: true
  # Critical alerts -> Slack
  - match:
      severity: critical
    receiver: slack-critical
  # Warnings -> Slack only
  - match:
      severity: warning
    receiver: slack-warnings

receivers:
- name: 'pagerduty'
  pagerduty_configs:
  - service_key: '<key>'
    description: '{{ .GroupLabels.alertname }}'

- name: 'slack-critical'
  slack_configs:
  - api_url: '<webhook>'
    channel: '#alerts-critical'
    title: '{{ .GroupLabels.alertname }}'
    text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'

- name: 'slack-warnings'
  slack_configs:
  - api_url: '<webhook>'
    channel: '#alerts-warnings'
```

## Alert Template

```yaml
- alert: <AlertName>
  expr: |
    <PromQL expression>
  for: <duration>
  labels:
    severity: <critical|warning|info>
    team: <owning-team>
    service: <service-name>
    component: <component>
  annotations:
    summary: "Brief description"
    description: |
      **Problem:** What is wrong
      **Current Value:** {{ $value }}
      **Threshold:** <threshold>
      **Impact:** User/system impact
      **Action:** What to do next
    runbook_url: "https://runbook.example.com/<alert-name>"
    dashboard_url: "https://grafana.example.com/<dashboard>"
    playbook: |
      1. Check dashboard for context
      2. Review recent deployments
      3. Check application logs
      4. Investigate root cause
      5. Escalate if needed
```

## Best Practices

**Alert Design:**
- Base alerts on user impact (not internal metrics alone)
- Use SLO-based alerting when possible
- Alert on symptoms, monitor causes
- Make alerts actionable
- Include investigation context

**Noise Reduction:**
- Appropriate evaluation periods (`for: 5m`)
- Realistic thresholds (not too sensitive)
- Alert aggregation and grouping
- Maintenance windows/silences
- Regular alert review and tuning

**On-Call Friendly:**
- Clear, descriptive alert names
- Runbook links for investigation steps
- Dashboard links for visualization
- Severity correctly assigned
- Team ownership clear

**Continuous Improvement:**
- Track alert response times
- Measure false positive rate
- Regular alert retrospectives
- Update thresholds based on data
- Remove noisy or unused alerts
