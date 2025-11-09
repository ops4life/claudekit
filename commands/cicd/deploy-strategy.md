---
description: Design deployment strategies (blue/green, canary, rolling) with implementation
---

# Deployment Strategy Design Command

You are helping design and implement a safe deployment strategy to minimize downtime and risk during releases.

## Requirements

**User must provide:**
- Application type and architecture
- Traffic patterns and scale
- Downtime tolerance (zero, minimal, acceptable)
- Rollback requirements
- Target platform (Kubernetes, AWS, GCP, Azure, serverless)

**Prerequisites:**
- Understanding of current deployment process
- Infrastructure requirements and constraints
- Monitoring and observability in place
- Health check endpoints implemented

## Deployment Strategies

### 1. Rolling Deployment (Default)

**Description:** Gradually replace old versions with new versions, instance by instance.

**How it works:**
1. Deploy new version to a subset of instances
2. Wait for health checks to pass
3. Continue rolling out to next subset
4. Repeat until all instances updated

**Pros:**
- Simple to implement
- No additional infrastructure required
- Gradual rollout reduces risk
- Easy rollback by reversing process

**Cons:**
- Two versions run simultaneously during rollout
- Can't easily control traffic split
- Slower than recreate strategy
- Database migrations can be complex

**Best for:**
- Stateless applications
- Backward-compatible changes
- Resource-constrained environments
- Gradual rollouts with monitoring

**Kubernetes Implementation:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: production
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2        # Max 2 extra pods during update
      maxUnavailable: 1  # Max 1 pod unavailable at a time
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
        version: v2.0.0
    spec:
      containers:
      - name: myapp
        image: myapp:v2.0.0
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /health/live
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10

---
# Deployment command
kubectl apply -f deployment.yaml
kubectl rollout status deployment/myapp -n production

# Monitor rollout
kubectl get pods -n production -w

# Rollback if needed
kubectl rollout undo deployment/myapp -n production
```

**AWS ECS Implementation:**

```json
{
  "deploymentConfiguration": {
    "maximumPercent": 200,
    "minimumHealthyPercent": 100,
    "deploymentCircuitBreaker": {
      "enable": true,
      "rollback": true
    }
  }
}
```

### 2. Blue/Green Deployment

**Description:** Run two identical environments (blue=current, green=new). Switch traffic all at once.

**How it works:**
1. Blue environment serves production traffic
2. Deploy new version to green environment
3. Test green environment thoroughly
4. Switch all traffic from blue to green
5. Keep blue for quick rollback
6. After validation, decommission blue

**Pros:**
- Zero downtime deployment
- Instant rollback capability
- Full testing before switch
- Only one version serves traffic
- Database migrations easier

**Cons:**
- Requires double infrastructure (costly)
- Database migrations can be complex
- All-or-nothing traffic switch

**Best for:**
- Mission-critical applications
- When zero downtime is required
- Applications with complex state
- When full pre-production testing is needed

**Kubernetes Implementation:**

```yaml
# Blue Deployment (current production)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-blue
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: blue
  template:
    metadata:
      labels:
        app: myapp
        version: blue
    spec:
      containers:
      - name: myapp
        image: myapp:v1.0.0
        ports:
        - containerPort: 8080

---
# Green Deployment (new version)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-green
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: green
  template:
    metadata:
      labels:
        app: myapp
        version: green
    spec:
      containers:
      - name: myapp
        image: myapp:v2.0.0
        ports:
        - containerPort: 8080

---
# Service (controls traffic routing)
apiVersion: v1
kind: Service
metadata:
  name: myapp
  namespace: production
spec:
  selector:
    app: myapp
    version: blue  # Currently pointing to blue
  ports:
  - port: 80
    targetPort: 8080
  type: LoadBalancer

---
# Deployment Script
# 1. Deploy green
kubectl apply -f myapp-green-deployment.yaml
kubectl rollout status deployment/myapp-green -n production

# 2. Test green environment
kubectl port-forward deployment/myapp-green 8080:8080 -n production
# Run tests against localhost:8080

# 3. Switch traffic to green
kubectl patch service myapp -n production \
  -p '{"spec":{"selector":{"version":"green"}}}'

# 4. Monitor for issues (wait 10-15 minutes)
kubectl logs -f deployment/myapp-green -n production
# Check metrics, errors, performance

# 5a. If successful, scale down blue
kubectl scale deployment/myapp-blue -n production --replicas=0

# 5b. If issues, rollback to blue immediately
kubectl patch service myapp -n production \
  -p '{"spec":{"selector":{"version":"blue"}}}'
```

**AWS with ALB:**

```bash
# Using AWS ALB with target groups
# Blue target group: myapp-blue-tg
# Green target group: myapp-green-tg

# 1. Deploy to green target group
aws ecs update-service \
  --cluster production \
  --service myapp-green \
  --task-definition myapp:2 \
  --force-new-deployment

# 2. Wait for green to be healthy
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:...:myapp-green-tg

# 3. Switch traffic (update listener rule)
aws elbv2 modify-listener \
  --listener-arn arn:aws:elasticloadbalancing:...:listener/... \
  --default-actions Type=forward,TargetGroupArn=arn:...:myapp-green-tg

# 4. Rollback if needed
aws elbv2 modify-listener \
  --listener-arn arn:aws:elasticloadbalancing:...:listener/... \
  --default-actions Type=forward,TargetGroupArn=arn:...:myapp-blue-tg
```

### 3. Canary Deployment

**Description:** Gradually shift traffic from old to new version using percentage-based routing.

**How it works:**
1. Deploy new version alongside old version
2. Route small percentage of traffic to new version (e.g., 5%)
3. Monitor metrics (errors, latency, business KPIs)
4. Gradually increase traffic (10%, 25%, 50%, 100%)
5. Rollback at any stage if issues detected

**Pros:**
- Minimal blast radius (limits impact)
- Real production testing with real users
- Data-driven rollout decisions
- Gradual confidence building

**Cons:**
- Requires advanced traffic routing
- More complex monitoring required
- Longer deployment time
- Two versions in production simultaneously

**Best for:**
- High-traffic applications
- Risk-averse deployments
- When A/B testing is valuable
- User-facing applications

**Kubernetes with Istio:**

```yaml
# Deployment v1 (stable)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-v1
spec:
  replicas: 5
  selector:
    matchLabels:
      app: myapp
      version: v1
  template:
    metadata:
      labels:
        app: myapp
        version: v1
    spec:
      containers:
      - name: myapp
        image: myapp:v1.0.0

---
# Deployment v2 (canary)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-v2
spec:
  replicas: 2  # Fewer replicas initially
  selector:
    matchLabels:
      app: myapp
      version: v2
  template:
    metadata:
      labels:
        app: myapp
        version: v2
    spec:
      containers:
      - name: myapp
        image: myapp:v2.0.0

---
# Service (selects both versions)
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  selector:
    app: myapp  # Selects both v1 and v2
  ports:
  - port: 80
    targetPort: 8080

---
# Istio VirtualService for traffic splitting
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: myapp
spec:
  hosts:
  - myapp
  http:
  - match:
    - headers:
        canary-user:
          exact: "true"  # Route specific users to canary
    route:
    - destination:
        host: myapp
        subset: v2
      weight: 100
  - route:
    - destination:
        host: myapp
        subset: v1
      weight: 95  # 95% to stable
    - destination:
        host: myapp
        subset: v2
      weight: 5   # 5% to canary

---
# DestinationRule to define subsets
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: myapp
spec:
  host: myapp
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2

---
# Gradual Rollout Script
# Step 1: 5% canary
kubectl apply -f canary-5percent.yaml

# Step 2: Monitor metrics for 30 minutes
# Check error rates, latency, business metrics

# Step 3: Increase to 25%
kubectl patch virtualservice myapp -n production --type merge -p '
{
  "spec": {
    "http": [{
      "route": [
        {"destination": {"host": "myapp", "subset": "v1"}, "weight": 75},
        {"destination": {"host": "myapp", "subset": "v2"}, "weight": 25}
      ]
    }]
  }
}'

# Step 4: Continue increasing: 50%, 75%, 100%
# Monitor at each stage

# Step 5: Full rollout (100% to v2)
kubectl patch virtualservice myapp -n production --type merge -p '
{
  "spec": {
    "http": [{
      "route": [
        {"destination": {"host": "myapp", "subset": "v2"}, "weight": 100}
      ]
    }]
  }
}'

# Step 6: Remove old version
kubectl delete deployment myapp-v1 -n production
```

**Automated Canary with Flagger:**

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: myapp
  namespace: production
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  service:
    port: 80
    targetPort: 8080
  analysis:
    interval: 1m
    threshold: 10
    maxWeight: 50
    stepWeight: 5
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
      interval: 1m
    - name: request-duration
      thresholdRange:
        max: 500
      interval: 1m
    webhooks:
    - name: load-test
      url: http://flagger-loadtester/
      timeout: 5s
      metadata:
        cmd: "hey -z 1m -q 10 -c 2 http://myapp-canary/api/health"
  # Automated rollback on failure
  rollbackOnFailure: true
```

### 4. Recreate Deployment

**Description:** Terminate all old versions before starting new versions.

**How it works:**
1. Stop all instances of old version
2. Wait for termination
3. Deploy new version
4. Wait for new instances to be ready

**Pros:**
- Simplest strategy
- No version overlap
- No resource doubling
- Clear cutover point

**Cons:**
- Downtime during deployment
- No gradual rollout
- Higher risk (all-or-nothing)
- Slower rollback

**Best for:**
- Development environments
- Maintenance windows acceptable
- Applications that can't run multiple versions
- Resource-constrained environments

**Kubernetes Implementation:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  strategy:
    type: Recreate  # All pods killed before new ones created
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: myapp:v2.0.0
```

### 5. Feature Flags / Dark Launch

**Description:** Deploy new code but hide features behind toggles.

**How it works:**
1. Deploy new code to production (feature disabled)
2. Gradually enable feature for user segments
3. Monitor and gather feedback
4. Fully enable or rollback feature

**Pros:**
- Decouple deployment from release
- Test in production with real data
- Instant enable/disable without deployment
- A/B testing capabilities
- Gradual user rollout

**Cons:**
- Code complexity (conditional logic)
- Technical debt if flags not removed
- Requires feature flag infrastructure
- Testing complexity increases

**Best for:**
- Continuous deployment environments
- Major feature releases
- A/B testing scenarios
- Risk mitigation for new features

**Implementation Example:**

```typescript
// Feature flag service
import { FeatureFlagClient } from '@flagsmith/flagsmith-nodejs';

const flagsmith = new FeatureFlagClient({
  environmentKey: process.env.FLAGSMITH_KEY
});

async function handleRequest(userId: string) {
  const flags = await flagsmith.getIdentityFlags(userId);

  if (flags.isFeatureEnabled('new_checkout_flow')) {
    return newCheckoutFlow();
  } else {
    return legacyCheckoutFlow();
  }
}

// Gradual rollout configuration
{
  "new_checkout_flow": {
    "enabled": true,
    "percentage_rollout": 10,  // 10% of users
    "targeting": {
      "rules": [
        {
          "attribute": "user_tier",
          "operator": "equals",
          "value": "beta"
        }
      ]
    }
  }
}
```

## Deployment Strategy Decision Matrix

| Requirement | Recommended Strategy |
|------------|---------------------|
| Zero downtime required | Blue/Green, Canary |
| High traffic, risk-averse | Canary |
| Fast rollback essential | Blue/Green |
| Limited resources | Rolling, Recreate |
| Complex state/data migration | Blue/Green |
| A/B testing needed | Canary, Feature Flags |
| Gradual user rollout | Canary, Feature Flags |
| Simple apps, dev environments | Rolling, Recreate |
| Microservices | Rolling, Canary |
| Monolithic apps | Blue/Green |

## Best Practices

**Pre-Deployment:**
- Comprehensive testing in staging
- Database migration strategy
- Rollback plan documented
- Monitoring and alerting configured
- Health checks implemented
- Team communication

**During Deployment:**
- Monitor key metrics continuously
- Watch for error spikes
- Track business KPIs
- Be ready to rollback quickly
- Document any issues

**Post-Deployment:**
- Verify functionality
- Check monitoring dashboards
- Review logs for errors
- Gather user feedback
- Document lessons learned
- Clean up old resources

**Monitoring Metrics:**
- Request success rate (>99%)
- Response time (p50, p95, p99)
- Error rates
- CPU/Memory utilization
- Database query performance
- Business metrics (conversions, revenue)

**Rollback Criteria:**
- Error rate > 1%
- Response time increase > 50%
- Critical business metric degradation
- Security vulnerability discovered
- Data corruption detected

**Database Migrations:**
- Backward-compatible changes
- Separate migration from code deploy
- Test rollback scenarios
- Use migration tools (Flyway, Liquibase)
- Zero-downtime migration strategies
