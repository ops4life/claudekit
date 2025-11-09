---
description: Guided Kubernetes deployment workflow with validation and safety checks
---

# Kubernetes Deployment Command

You are helping deploy an application to a Kubernetes cluster. Follow this systematic workflow to ensure a safe, validated deployment.

## Requirements

**User must provide:**
- Application name and namespace
- Deployment manifests (YAML files) or Helm chart
- Target environment (dev/staging/production)
- Container image tag/version

**Prerequisites to verify:**
- kubectl installed and configured
- Valid kubeconfig context
- Appropriate RBAC permissions
- Container registry access

## Deployment Workflow

### 1. Pre-Deployment Validation

**Context Verification:**
- Verify current kubectl context: `kubectl config current-context`
- Confirm cluster connectivity: `kubectl cluster-info`
- Check namespace exists or create it: `kubectl get namespace <namespace>` or `kubectl create namespace <namespace>`
- Verify service account and RBAC permissions

**Image Validation:**
- Confirm container image exists in registry
- Verify image tag matches expected version
- Check image pull secrets if using private registry
- Recommend using specific tags, not `latest`

**Resource Validation:**
- Parse and validate YAML manifests for syntax errors
- Check resource quotas and limits are defined
- Verify security contexts (runAsNonRoot, readOnlyRootFilesystem)
- Ensure liveness and readiness probes are configured
- Validate resource requests/limits (CPU, memory)

**Security Checks:**
- Scan for hardcoded secrets (warn if found)
- Verify use of ConfigMaps/Secrets for configuration
- Check for privileged containers (flag as security risk)
- Validate network policies if applicable
- Ensure appropriate pod security standards

### 2. Deployment Strategy

**Determine deployment method:**
- **kubectl apply:** Direct manifest application
- **Helm:** Chart-based deployment with values
- **Kustomize:** Overlay-based configuration
- **ArgoCD/Flux:** GitOps deployment (if applicable)

**For production environments:**
- Recommend blue/green or canary deployment
- Suggest using progressive delivery tools (Flagger, Argo Rollouts)
- Plan rollback strategy before deploying

### 3. Execute Deployment

**Create deployment plan:**
```bash
# 1. Dry run to validate
kubectl apply -f <manifest> --dry-run=client -o yaml

# 2. Server-side dry run
kubectl apply -f <manifest> --dry-run=server

# 3. Apply with record for rollback capability
kubectl apply -f <manifest> --record

# 4. For Helm
helm upgrade --install <release> <chart> -n <namespace> --values values.yaml
```

**Monitor deployment progress:**
- Watch rollout status: `kubectl rollout status deployment/<name> -n <namespace>`
- Check pod creation: `kubectl get pods -n <namespace> -l app=<label> -w`
- View events: `kubectl get events -n <namespace> --sort-by='.lastTimestamp'`

### 4. Post-Deployment Validation

**Health Checks:**
- Verify all pods are running: `kubectl get pods -n <namespace>`
- Check pod logs for errors: `kubectl logs -n <namespace> <pod-name>`
- Test readiness probes are passing
- Verify service endpoints: `kubectl get endpoints -n <namespace>`

**Service Validation:**
- Test service connectivity: `kubectl port-forward` or internal curl
- Verify ingress/load balancer configuration
- Check DNS resolution for services
- Test external access if applicable

**Resource Verification:**
- Check actual resource usage: `kubectl top pods -n <namespace>`
- Compare against requests/limits
- Verify HPA configuration if autoscaling

**Multi-Cloud Specific:**
- **AWS/EKS:** Verify ALB/NLB provisioning, check IAM roles for service accounts (IRSA)
- **GCP/GKE:** Verify workload identity bindings, check GCE load balancers
- **Azure/AKS:** Verify Azure AD pod identity, check Azure load balancer

### 5. Rollback Plan

**Prepare rollback procedure:**
```bash
# View rollout history
kubectl rollout history deployment/<name> -n <namespace>

# Rollback to previous version
kubectl rollout undo deployment/<name> -n <namespace>

# Rollback to specific revision
kubectl rollout undo deployment/<name> -n <namespace> --to-revision=<N>

# For Helm
helm rollback <release> <revision> -n <namespace>
```

**Document rollback triggers:**
- Pod crash loops (CrashLoopBackOff)
- Failed health checks
- Increased error rates
- Performance degradation
- Security incidents

## Output Format

### Deployment Checklist
Provide a structured checklist:

**Pre-Deployment:**
- [ ] kubectl context verified
- [ ] Namespace exists
- [ ] Image exists and tagged correctly
- [ ] Manifests validated (syntax, security)
- [ ] Resource quotas checked
- [ ] RBAC permissions confirmed

**Deployment:**
- [ ] Dry run completed successfully
- [ ] Deployment applied
- [ ] Rollout status monitoring active
- [ ] No error events detected

**Post-Deployment:**
- [ ] All pods running and healthy
- [ ] Health checks passing
- [ ] Service endpoints accessible
- [ ] Resource usage within limits
- [ ] Cloud-specific resources provisioned (LB, IAM, etc.)

**Rollback Plan:**
- [ ] Previous revision documented
- [ ] Rollback command prepared
- [ ] Rollback triggers defined

### Deployment Summary
Generate summary including:
- Application: `<name>`
- Namespace: `<namespace>`
- Environment: `<env>`
- Image: `<registry>/<image>:<tag>`
- Replicas: `<count>`
- Strategy: `<RollingUpdate|Recreate|Blue-Green|Canary>`
- Status: `<Success|Failed|In Progress>`
- Cloud Provider: `<AWS|GCP|Azure|On-Prem>`

### Commands Reference
Provide quick reference of commands used during deployment for documentation.

## Best Practices

**Configuration Management:**
- Use ConfigMaps for non-sensitive configuration
- Use Secrets for sensitive data (with encryption at rest)
- Never hardcode credentials in manifests
- Use external secret management (AWS Secrets Manager, GCP Secret Manager, Azure Key Vault, Vault)

**Resource Management:**
- Always define resource requests and limits
- Set appropriate CPU/memory based on profiling
- Use Vertical Pod Autoscaler (VPA) for recommendations
- Configure Horizontal Pod Autoscaler (HPA) for scaling

**High Availability:**
- Deploy multiple replicas (minimum 2 for HA)
- Use pod anti-affinity for replica distribution
- Configure pod disruption budgets (PDB)
- Use topology spread constraints

**Security:**
- Run containers as non-root user
- Use read-only root filesystem where possible
- Enable security contexts and pod security admission
- Scan images for vulnerabilities
- Implement network policies for micro-segmentation

**Observability:**
- Configure structured logging (JSON)
- Export metrics in Prometheus format
- Implement distributed tracing (OpenTelemetry)
- Set up alerts for deployment failures

**Multi-Cloud Considerations:**
- Use cloud-agnostic ingress controllers when possible (nginx, Traefik)
- Abstract cloud-specific features using operators/CRDs
- Document cloud-specific dependencies (IAM roles, load balancers)
- Test deployments in cloud-specific staging environments

## Error Handling

**Common Issues and Solutions:**

1. **ImagePullBackOff:**
   - Verify image name and tag
   - Check image pull secrets
   - Confirm registry authentication

2. **CrashLoopBackOff:**
   - Check application logs
   - Verify environment variables
   - Review resource limits (OOMKilled)
   - Validate health check configurations

3. **Pending Pods:**
   - Check node resources (CPU/memory)
   - Verify persistent volume claims
   - Review pod affinity/anti-affinity rules
   - Check for taints/tolerations issues

4. **Service Unavailable:**
   - Verify selector labels match pods
   - Check service port configuration
   - Review network policies
   - Test DNS resolution

**For each error:**
- Provide diagnostic commands
- Explain root cause
- Suggest remediation steps
- Include rollback option if unrecoverable
