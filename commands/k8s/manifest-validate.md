---
description: Validate Kubernetes YAML manifests for syntax, security, and best practices
---

# Kubernetes Manifest Validation Command

You are helping validate Kubernetes manifests to ensure they follow best practices, security standards, and are production-ready.

## Requirements

**User must provide:**
- Path to Kubernetes manifest files (YAML)
- Target environment (dev/staging/production)
- Optionally: specific compliance standards (PCI, HIPAA, SOC2)

**Prerequisites:**
- Access to manifest files
- kubectl for syntax validation
- Optionally: Additional validation tools (kube-score, kubeval, polaris, OPA)

## Validation Workflow

### 1. Syntax Validation

**Basic YAML Syntax:**
```bash
# Validate YAML syntax
kubectl apply -f <manifest> --dry-run=client -o yaml

# Server-side validation
kubectl apply -f <manifest> --dry-run=server

# Check for API deprecations
kubectl apply -f <manifest> --dry-run=client --validate=true
```

**Check for common syntax errors:**
- Proper YAML indentation
- Valid Kubernetes API versions
- Correct resource kind names
- Required fields present
- Valid label and annotation formats

### 2. Security Validation

**Security Context Analysis:**

Check each container for:

**A. User and Privilege Configuration:**
- [ ] `runAsNonRoot: true` - Container runs as non-root user
- [ ] `runAsUser: <UID>` - Specific non-root UID defined (e.g., 1000)
- [ ] `allowPrivilegeEscalation: false` - Prevents privilege escalation
- [ ] `privileged: false` - Not running in privileged mode
- [ ] `readOnlyRootFilesystem: true` - Root filesystem is read-only

**B. Capability Management:**
- [ ] `capabilities.drop: [ALL]` - All capabilities dropped
- [ ] Minimal required capabilities added (if needed)
- [ ] No dangerous capabilities (SYS_ADMIN, NET_ADMIN, etc.)

**C. Security Standards:**
```yaml
# Example secure security context
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 3000
  fsGroup: 2000
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true
  seccompProfile:
    type: RuntimeDefault
```

**Secret and Sensitive Data:**
- [ ] No hardcoded passwords, API keys, or tokens
- [ ] Secrets referenced from Secret resources
- [ ] ConfigMaps used for non-sensitive config only
- [ ] Consider using external secret management (AWS Secrets Manager, Vault, etc.)
- [ ] Environment variables from secrets use `secretKeyRef`

**Image Security:**
- [ ] Images use specific tags (not `latest`)
- [ ] Images pulled from trusted registries
- [ ] Private registries use `imagePullSecrets`
- [ ] Consider image digest for immutability
- [ ] Recommend scanning images for vulnerabilities

**Network Security:**
- [ ] Network policies defined for pod-to-pod traffic
- [ ] Ingress and egress rules are restrictive
- [ ] Only necessary ports exposed
- [ ] Service types appropriate (avoid NodePort in production)

### 3. Resource Configuration Validation

**Resource Requests and Limits:**

**Every container must define:**
```yaml
resources:
  requests:
    cpu: "100m"      # Minimum CPU (millicores)
    memory: "128Mi"  # Minimum memory
  limits:
    cpu: "500m"      # Maximum CPU
    memory: "512Mi"  # Maximum memory
```

**Validation checks:**
- [ ] Both requests and limits defined for CPU and memory
- [ ] Requests ≤ limits
- [ ] Values appropriate for workload (not too small/large)
- [ ] No missing resource specifications
- [ ] Consider using LimitRanges and ResourceQuotas at namespace level

**Quality of Service (QoS) Classes:**
- **Guaranteed:** requests = limits (recommended for critical workloads)
- **Burstable:** requests < limits (common for variable workloads)
- **BestEffort:** No requests/limits (not recommended for production)

### 4. High Availability Configuration

**Replica and Scaling:**
- [ ] Multiple replicas for production (minimum 2-3)
- [ ] Pod Disruption Budget (PDB) configured
- [ ] HorizontalPodAutoscaler (HPA) for dynamic scaling (optional)
- [ ] Topology spread constraints or pod anti-affinity for distribution

**Example PDB:**
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: myapp-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: myapp
```

**Pod Anti-Affinity:**
```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchLabels:
            app: myapp
        topologyKey: kubernetes.io/hostname
```

### 5. Health Check Configuration

**Liveness and Readiness Probes:**

**Every container should have:**

**Liveness Probe** (restart if unhealthy):
```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

**Readiness Probe** (remove from service if not ready):
```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3
```

**Startup Probe** (for slow-starting containers):
```yaml
startupProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 0
  periodSeconds: 10
  failureThreshold: 30  # 5 minutes for startup
```

**Validation checks:**
- [ ] At minimum readiness probe is configured
- [ ] Probe endpoints exist and are implemented
- [ ] Timing values are appropriate (not too aggressive)
- [ ] Probe type matches application (HTTP, TCP, exec)

### 6. Label and Annotation Standards

**Required Labels:**
```yaml
metadata:
  labels:
    app.kubernetes.io/name: myapp
    app.kubernetes.io/instance: myapp-prod
    app.kubernetes.io/version: "1.0.0"
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: myplatform
    app.kubernetes.io/managed-by: helm
    environment: production
```

**Validation checks:**
- [ ] Standard Kubernetes labels present
- [ ] Environment label defined
- [ ] Version/release tracking labels
- [ ] Labels match selectors in Services
- [ ] No label value exceeds 63 characters
- [ ] Labels follow DNS subdomain format

**Useful Annotations:**
- Deployment strategy annotations
- Prometheus scraping annotations
- Ingress configuration annotations
- Cloud-specific annotations (AWS ALB, GCP NEG, etc.)

### 7. Service and Networking Validation

**Service Configuration:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  type: ClusterIP  # Default, most secure
  selector:
    app: myapp
  ports:
  - name: http
    port: 80
    targetPort: 8080
    protocol: TCP
```

**Validation checks:**
- [ ] Service selector matches pod labels
- [ ] Port names are descriptive
- [ ] Target ports match container ports
- [ ] Service type appropriate (ClusterIP for internal, LoadBalancer for external)
- [ ] For production, avoid NodePort
- [ ] Session affinity configured if needed

**Ingress Best Practices:**
- [ ] TLS configured for HTTPS
- [ ] Host and path routing defined
- [ ] Ingress class specified
- [ ] Rate limiting annotations (if supported)
- [ ] Authentication/authorization configured

### 8. Storage and Volume Validation

**Persistent Volume Claims:**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: myapp-data
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: fast-ssd
  resources:
    requests:
      storage: 10Gi
```

**Validation checks:**
- [ ] Storage class defined and available
- [ ] Access modes appropriate for use case
- [ ] Storage size sufficient
- [ ] Volume mounts in pods reference correct PVCs
- [ ] Consider backup strategies

**Volume Security:**
- [ ] ConfigMaps and Secrets mounted as volumes use appropriate permissions
- [ ] Sensitive data uses `defaultMode: 0400` or `0600`
- [ ] EmptyDir volumes have size limits

### 9. Multi-Cloud Specific Validation

**AWS/EKS:**
- [ ] IAM roles for service accounts (IRSA) configured if needed
- [ ] EBS/EFS storage classes appropriate
- [ ] ALB ingress annotations correct
- [ ] Security group policies compatible
- [ ] Region-specific resource availability

**GCP/GKE:**
- [ ] Workload Identity configured if accessing GCP services
- [ ] Persistent disk storage classes (pd-ssd, pd-standard)
- [ ] GCE ingress annotations valid
- [ ] VPC-native cluster considerations
- [ ] Regional/zonal resource placement

**Azure/AKS:**
- [ ] Azure AD pod identity configured if needed
- [ ] Azure Disk/File storage classes
- [ ] Azure Load Balancer annotations
- [ ] Network policy provider (Calico/Azure)
- [ ] Managed identity configuration

### 10. Automated Validation Tools

**Recommended validation tools:**

**kube-score** - Kubernetes object analysis:
```bash
kube-score score <manifest.yaml>
```

**kubeval** - Kubernetes manifest validation:
```bash
kubeval <manifest.yaml>
```

**Polaris** - Best practices and security:
```bash
polaris audit --audit-path <manifest.yaml>
```

**Open Policy Agent (OPA)** - Policy enforcement:
```bash
conftest test <manifest.yaml>
```

**trivy** - Security vulnerability scanning:
```bash
trivy config <manifest.yaml>
```

## Validation Output Format

### Validation Report

Generate a comprehensive validation report:

**Manifest Summary:**
- File: `<manifest-file>`
- Resources: `<count> (<types>)`
- Environment: `<env>`
- Validated: `<timestamp>`

**Validation Results:**

**1. Syntax Validation:** [PASS/FAIL]
- API versions: Valid
- Resource kinds: Valid
- Required fields: Present
- Issues: `<list any issues>`

**2. Security Assessment:** [PASS/FAIL/WARNING]
- Security contexts: `<X/Y containers compliant>`
- Secret management: `<status>`
- Image security: `<status>`
- Network security: `<status>`
- Critical issues: `<list>`
- Warnings: `<list>`

**3. Resource Configuration:** [PASS/FAIL/WARNING]
- Resource requests/limits: `<X/Y containers defined>`
- QoS class: `<Guaranteed/Burstable/BestEffort>`
- Issues: `<list>`

**4. High Availability:** [PASS/FAIL/WARNING]
- Replica count: `<count>`
- PDB configured: `<yes/no>`
- Distribution strategy: `<type>`
- Recommendations: `<list>`

**5. Health Checks:** [PASS/FAIL/WARNING]
- Liveness probes: `<X/Y containers>`
- Readiness probes: `<X/Y containers>`
- Startup probes: `<X/Y containers>`
- Missing probes: `<list containers>`

**6. Labels and Metadata:** [PASS/FAIL/WARNING]
- Standard labels: `<status>`
- Selector consistency: `<status>`
- Issues: `<list>`

**7. Networking:** [PASS/FAIL/WARNING]
- Service configuration: `<status>`
- Ingress configuration: `<status>`
- Network policies: `<present/missing>`

**Security Score:** `<score>/100`

**Production Readiness:** [READY/NOT READY]

### Issues and Recommendations

**Critical Issues (Must Fix):**
1. `<issue>` - `<location>` - `<fix>`
2. ...

**Warnings (Should Fix):**
1. `<issue>` - `<location>` - `<recommendation>`
2. ...

**Best Practice Recommendations:**
1. `<recommendation>` - `<benefit>`
2. ...

### Remediation Steps

For each issue, provide:
- **Issue:** Clear description
- **Location:** File, resource, field path
- **Severity:** Critical/High/Medium/Low
- **Fix:** Exact YAML changes needed
- **Reference:** Link to documentation or standards

**Example:**
```yaml
# Issue: Missing security context
# Location: deployment.yaml > spec.template.spec.containers[0]
# Severity: Critical
# Fix: Add security context

securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true
```

## Best Practices

**Validation in CI/CD:**
- Integrate validation in CI pipelines
- Fail builds on critical issues
- Generate reports for review
- Track improvements over time

**Policy as Code:**
- Define organization-wide policies using OPA
- Enforce policies at admission time (OPA Gatekeeper)
- Version control policy definitions
- Test policies before enforcement

**Continuous Validation:**
- Scan running workloads regularly
- Monitor for configuration drift
- Alert on policy violations
- Automated remediation where possible

**Documentation:**
- Document organization-specific standards
- Maintain validation checklist
- Share validation reports with teams
- Create fix guides for common issues

**Environment-Specific Rules:**
- Stricter validation for production
- Different security requirements per environment
- Compliance-specific checks (PCI, HIPAA, etc.)
- Cloud-specific best practices
