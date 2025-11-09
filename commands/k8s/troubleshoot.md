---
description: Systematic Kubernetes pod and service debugging workflow
---

# Kubernetes Troubleshooting Command

You are helping debug issues in a Kubernetes cluster. Follow this systematic diagnostic workflow to identify and resolve problems.

## Requirements

**User must provide:**
- Resource type (Pod, Deployment, Service, etc.)
- Resource name and namespace
- Observed symptoms/behavior

**Prerequisites:**
- kubectl installed and configured
- Valid kubeconfig with appropriate permissions
- Access to cluster logs and metrics

## Diagnostic Workflow

### 1. Initial Assessment

**Gather basic information:**
```bash
# Get resource status
kubectl get <resource-type> <name> -n <namespace> -o wide

# Get detailed description
kubectl describe <resource-type> <name> -n <namespace>

# Check recent events
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | tail -20
```

**Identify problem category:**
- **Pod Issues:** CrashLoopBackOff, ImagePullBackOff, Pending, OOMKilled
- **Service Issues:** Connection failures, DNS resolution, endpoint problems
- **Performance:** High latency, resource exhaustion, throttling
- **Configuration:** Missing ConfigMaps/Secrets, RBAC issues
- **Network:** Connectivity problems, policy violations, ingress issues

### 2. Pod-Specific Troubleshooting

**For Pod Issues:**

**A. Check Pod Status and Conditions:**
```bash
# Get pod status
kubectl get pod <pod-name> -n <namespace> -o yaml

# Check pod conditions
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.status.conditions[*]}'

# View pod events
kubectl describe pod <pod-name> -n <namespace>
```

**B. Analyze Container Status:**
```bash
# Check container states
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.status.containerStatuses[*]}'

# View container logs (current)
kubectl logs <pod-name> -n <namespace>

# View previous container logs (if crashed)
kubectl logs <pod-name> -n <namespace> --previous

# Follow logs in real-time
kubectl logs <pod-name> -n <namespace> -f

# For multi-container pods
kubectl logs <pod-name> -n <namespace> -c <container-name>
```

**C. Resource Usage Analysis:**
```bash
# Check current resource usage
kubectl top pod <pod-name> -n <namespace>

# View resource requests/limits
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[*].resources}'

# Check node resources
kubectl top nodes
kubectl describe node <node-name>
```

**D. Execute Commands in Pod (if running):**
```bash
# Interactive shell
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh

# Run diagnostic commands
kubectl exec <pod-name> -n <namespace> -- ps aux
kubectl exec <pod-name> -n <namespace> -- df -h
kubectl exec <pod-name> -n <namespace> -- netstat -tlnp
kubectl exec <pod-name> -n <namespace> -- env
```

**Common Pod Issues and Diagnostics:**

**1. CrashLoopBackOff:**
- Check logs for application errors: `kubectl logs <pod> --previous`
- Verify environment variables and secrets
- Check resource limits (OOMKilled indicator)
- Review liveness probe configuration
- Validate dependencies (databases, services)

**2. ImagePullBackOff:**
- Verify image name and tag: `kubectl get pod <pod> -o jsonpath='{.spec.containers[*].image}'`
- Check image pull secrets: `kubectl get pod <pod> -o jsonpath='{.spec.imagePullSecrets}'`
- Test registry access from node
- Verify service account permissions

**3. Pending:**
- Check node resources: `kubectl top nodes`
- View scheduling events: `kubectl describe pod <pod>`
- Check for taints: `kubectl describe node <node>`
- Verify PVC status: `kubectl get pvc -n <namespace>`
- Review affinity/anti-affinity rules

**4. OOMKilled:**
- Review memory limits: `kubectl get pod <pod> -o jsonpath='{.spec.containers[*].resources.limits.memory}'`
- Check actual usage: `kubectl top pod <pod>`
- Analyze application memory leaks
- Consider increasing limits or optimizing application

**5. Error/Completed:**
- Check exit code: `kubectl get pod <pod> -o jsonpath='{.status.containerStatuses[*].state.terminated.exitCode}'`
- Review logs for errors
- Verify job/cronjob configuration if applicable

### 3. Service-Specific Troubleshooting

**For Service Issues:**

**A. Verify Service Configuration:**
```bash
# Get service details
kubectl get svc <service-name> -n <namespace> -o wide

# Check service endpoints
kubectl get endpoints <service-name> -n <namespace>

# Describe service
kubectl describe svc <service-name> -n <namespace>
```

**B. Validate Selector and Labels:**
```bash
# Check service selector
kubectl get svc <service-name> -n <namespace> -o jsonpath='{.spec.selector}'

# List pods matching selector
kubectl get pods -n <namespace> -l <selector-labels>

# Verify pod labels
kubectl get pod <pod-name> -n <namespace> --show-labels
```

**C. Test Service Connectivity:**
```bash
# Port forward to test service
kubectl port-forward svc/<service-name> -n <namespace> <local-port>:<service-port>

# Create debug pod for network testing
kubectl run debug-pod --rm -i --tty --image=nicolaka/netshoot -n <namespace> -- /bin/bash

# From debug pod, test service
curl http://<service-name>.<namespace>.svc.cluster.local:<port>
nslookup <service-name>.<namespace>.svc.cluster.local
```

**D. DNS Troubleshooting:**
```bash
# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup <service-name>.<namespace>

# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns
```

**Common Service Issues:**

**1. No Endpoints:**
- Verify pod selector matches pod labels
- Check if pods are ready (readiness probes)
- Ensure pods are in same namespace
- Verify network policies allow traffic

**2. Connection Refused:**
- Verify service port matches container port
- Check target port configuration
- Test pod directly: `kubectl exec <pod> -- curl localhost:<port>`
- Review application listening address (0.0.0.0 vs 127.0.0.1)

**3. DNS Resolution Failure:**
- Check CoreDNS health
- Verify DNS policy in pod spec
- Test with FQDN: `<service>.<namespace>.svc.cluster.local`
- Check for network policies blocking DNS (port 53)

### 4. Network Troubleshooting

**Network Diagnostics:**

**A. Test Pod-to-Pod Communication:**
```bash
# Deploy network debug pod
kubectl run netshoot --rm -i --tty --image=nicolaka/netshoot -n <namespace>

# Test connectivity to another pod
ping <pod-ip>
curl http://<pod-ip>:<port>
telnet <pod-ip> <port>
traceroute <pod-ip>
```

**B. Check Network Policies:**
```bash
# List network policies
kubectl get networkpolicies -n <namespace>

# Describe policy
kubectl describe networkpolicy <policy-name> -n <namespace>

# Verify policy selectors match pods
kubectl get pods -n <namespace> --show-labels
```

**C. Ingress/Load Balancer Issues:**
```bash
# Check ingress status
kubectl get ingress -n <namespace>
kubectl describe ingress <ingress-name> -n <namespace>

# View ingress controller logs
kubectl logs -n <ingress-namespace> -l app=<ingress-controller>

# For cloud load balancers
kubectl get svc <service-name> -n <namespace> -o jsonpath='{.status.loadBalancer}'
```

**Multi-Cloud Network Troubleshooting:**

**AWS/EKS:**
- Check security groups on nodes and load balancers
- Verify VPC CNI plugin health: `kubectl get pods -n kube-system -l k8s-app=aws-node`
- Review NACLs and route tables
- Check ALB/NLB target group health

**GCP/GKE:**
- Verify VPC firewall rules
- Check GKE network mode (VPC-native vs routes-based)
- Review load balancer health checks
- Validate workload identity configuration

**Azure/AKS:**
- Check Network Security Groups (NSGs)
- Verify Azure CNI or kubenet configuration
- Review Azure Load Balancer rules
- Check pod-to-pod communication with network policies

### 5. Node and Cluster Health

**Node Diagnostics:**
```bash
# Check node status
kubectl get nodes -o wide

# Describe node for conditions
kubectl describe node <node-name>

# Check node resource pressure
kubectl top nodes

# View node events
kubectl get events --field-selector involvedObject.kind=Node
```

**Cluster Component Health:**
```bash
# Check control plane components
kubectl get componentstatuses

# Check system pods
kubectl get pods -n kube-system

# Review critical system components
kubectl get pods -n kube-system -o wide | grep -E 'kube-proxy|kube-dns|coredns|calico|flannel|weave'
```

### 6. Configuration and RBAC Issues

**ConfigMap/Secret Troubleshooting:**
```bash
# Verify ConfigMap exists
kubectl get configmap <name> -n <namespace>

# Check Secret exists
kubectl get secret <name> -n <namespace>

# Verify volume mounts in pod
kubectl get pod <pod> -n <namespace> -o jsonpath='{.spec.volumes}'
kubectl exec <pod> -n <namespace> -- ls -la <mount-path>
```

**RBAC Debugging:**
```bash
# Check service account
kubectl get serviceaccount <sa-name> -n <namespace>

# Check if service account can perform action
kubectl auth can-i <verb> <resource> --as=system:serviceaccount:<namespace>:<sa-name>

# View role bindings
kubectl get rolebindings,clusterrolebindings -n <namespace>
```

## Diagnostic Output Format

### Issue Report
Generate a structured diagnostic report:

**Problem Summary:**
- Resource: `<type>/<name>`
- Namespace: `<namespace>`
- Status: `<current-state>`
- Symptom: `<observed-behavior>`

**Diagnostic Findings:**
1. **Status Check:** [PASS/FAIL]
   - Details: ...

2. **Event Analysis:** [PASS/FAIL]
   - Recent events: ...
   - Error messages: ...

3. **Log Analysis:** [PASS/FAIL]
   - Key errors: ...
   - Patterns identified: ...

4. **Resource Analysis:** [PASS/FAIL]
   - CPU usage: X% (limit: Y%)
   - Memory usage: X MB (limit: Y MB)
   - Node resources: ...

5. **Network Connectivity:** [PASS/FAIL]
   - Service endpoints: ...
   - DNS resolution: ...
   - Network policies: ...

6. **Configuration:** [PASS/FAIL]
   - ConfigMaps: ...
   - Secrets: ...
   - RBAC: ...

**Root Cause Analysis:**
- Primary cause: ...
- Contributing factors: ...

**Recommended Actions:**
1. Immediate fix: ...
2. Commands to run: ...
3. Configuration changes: ...
4. Prevention measures: ...

**Verification Steps:**
- [ ] Apply fix
- [ ] Verify resource status
- [ ] Check logs for errors
- [ ] Test functionality
- [ ] Monitor for recurrence

## Best Practices

**Logging:**
- Use structured logging (JSON format)
- Include correlation IDs for distributed tracing
- Set appropriate log levels
- Avoid logging sensitive data
- Use log aggregation (ELK, Loki, CloudWatch, Stackdriver)

**Monitoring:**
- Monitor pod restarts and OOMKills
- Track resource usage trends
- Set up alerts for anomalies
- Use distributed tracing (Jaeger, Zipkin, X-Ray)
- Implement health check endpoints

**Debugging Tools:**
- Keep debug images ready (nicolaka/netshoot, busybox)
- Use ephemeral debug containers (kubectl debug)
- Enable verbose logging when needed
- Use port-forwarding for local testing
- Leverage cloud-native debugging tools

**Documentation:**
- Document common issues and solutions
- Create runbooks for frequent problems
- Maintain troubleshooting checklists
- Track incident patterns
- Share knowledge across team
