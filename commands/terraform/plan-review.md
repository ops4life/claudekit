---
description: Analyze Terraform plan output for risks, security issues, and cost impact
---

# Terraform Plan Review Command

You are helping review a Terraform plan to identify risks, security issues, cost implications, and ensure safe infrastructure changes.

## Requirements

**User must provide:**
- Terraform plan output (text or JSON format)
- Target environment (dev/staging/production)
- Cloud provider (AWS/GCP/Azure)

**Prerequisites:**
- Terraform plan has been generated
- Access to plan output or plan file

## Plan Analysis Workflow

### 1. Parse Plan Output

**Extract key information:**

```bash
# Generate human-readable plan
terraform plan -out=tfplan

# View plan
terraform show tfplan

# Generate JSON format for detailed analysis
terraform show -json tfplan > plan.json
```

**Identify change categories:**
- **Create:** New resources being added
- **Update:** Existing resources being modified
- **Replace:** Resources being destroyed and recreated
- **Delete:** Resources being removed

### 2. Risk Assessment

**High-Risk Changes (Require careful review):**

**A. Resource Replacement/Destruction:**
- Identify resources marked for replacement (destroy + create)
- **Critical:** Databases, storage, load balancers, DNS records
- **Impact:** Potential data loss, service downtime, DNS propagation delays

**Check for:**
- [ ] Database instances being replaced (RDS, Cloud SQL, Cosmos DB)
- [ ] Storage buckets/containers being destroyed (S3, GCS, Blob Storage)
- [ ] Persistent volumes being replaced
- [ ] Load balancers being recreated (potential IP/DNS changes)
- [ ] NAT gateways/routers (network disruption)
- [ ] VPCs/VNets (widespread impact)

**B. Force Replacement Triggers:**

Identify what's causing replacement:
- Immutable attribute changes (instance type, subnet, encryption settings)
- Resource name changes (forces recreation)
- Provider version upgrades
- State drift requiring replacement

**C. Deletion Risk:**
- Resources being deleted without recreation
- Orphaned resources (check dependencies)
- Impact on other resources or applications

### 3. Security Analysis

**A. Exposed Resources:**

Check for resources becoming publicly accessible:

**AWS:**
- [ ] S3 buckets with public access
- [ ] Security groups allowing 0.0.0.0/0 on sensitive ports
- [ ] RDS instances with public accessibility
- [ ] IAM policies with overly permissive actions
- [ ] KMS keys with broad access

**GCP:**
- [ ] GCS buckets with public access
- [ ] Firewall rules allowing 0.0.0.0/0
- [ ] Cloud SQL instances with public IP
- [ ] IAM bindings with overly broad roles
- [ ] Compute instances with external IPs unnecessarily

**Azure:**
- [ ] Storage accounts with public blob access
- [ ] Network security groups allowing 0.0.0.0/0
- [ ] SQL databases with public endpoints
- [ ] RBAC assignments with excessive permissions
- [ ] Key vault access policies too permissive

**B. Encryption and Compliance:**

- [ ] Encryption at rest enabled for databases
- [ ] Encryption at rest enabled for storage
- [ ] Encryption in transit (TLS/SSL) configured
- [ ] KMS/Key Vault keys properly configured
- [ ] Compliance tags present (PCI, HIPAA, SOC2)

**C. Secret Management:**

- [ ] No hardcoded credentials in configurations
- [ ] Secrets using secure parameter stores
- [ ] Database passwords properly managed
- [ ] API keys stored in secret management services

**D. Network Security:**

- [ ] Security groups/firewall rules follow least privilege
- [ ] Private subnets for sensitive resources
- [ ] Network ACLs configured appropriately
- [ ] VPN/Private connectivity for databases
- [ ] No unnecessary public endpoints

### 4. Cost Impact Analysis

**Estimate cost changes:**

**A. Compute Resources:**

**AWS:**
- EC2 instances: Instance type, family, pricing model
- EKS: Node groups, Fargate usage
- Lambda: Memory, execution time, invocations
- RDS: Instance class, storage type, Multi-AZ

**GCP:**
- Compute Engine: Machine type, preemptible vs standard
- GKE: Node pool configuration
- Cloud Functions: Memory, invocations
- Cloud SQL: Tier, storage, HA configuration

**Azure:**
- Virtual Machines: Size, series
- AKS: Node pools, VM sizes
- Functions: Consumption vs Premium
- SQL Database: Service tier, DTUs/vCores

**B. Storage and Data Transfer:**
- Storage type (SSD vs HDD, Premium vs Standard)
- Storage size increases
- Data transfer costs (egress, cross-region)
- Backup storage and retention

**C. Managed Services:**
- Load balancers (ALB/NLB, Cloud Load Balancer, App Gateway)
- NAT gateways (hourly + data processing)
- Managed databases
- Monitoring and logging services

**D. Cost Optimization Opportunities:**
- Reserved instances/committed use discounts available
- Right-sizing recommendations
- Unused resources being created
- More cost-effective alternatives

### 5. Change Impact Analysis

**Dependency Mapping:**

Identify downstream impacts:
- Resources dependent on changing resources
- Applications affected by infrastructure changes
- Potential cascade effects
- Order of operations for safe execution

**Downtime Risk:**
- Changes requiring service interruption
- Resources with active connections
- Blue/green or rolling update opportunities
- Maintenance window requirements

**Rollback Complexity:**
- Reversibility of changes
- State backup requirements
- Data migration reversibility
- Time to rollback if issues occur

### 6. Best Practices Validation

**Terraform Standards:**

- [ ] Resources properly tagged/labeled
- [ ] Naming conventions followed
- [ ] Modules used for reusability
- [ ] Remote state configured securely
- [ ] State locking enabled
- [ ] Workspaces used appropriately

**Resource Configuration:**

- [ ] Variables used instead of hardcoded values
- [ ] Outputs defined for important values
- [ ] Data sources used for existing resources
- [ ] Lifecycle rules configured where needed
- [ ] Timeouts set for long-running operations

**Multi-Cloud Best Practices:**

**AWS:**
- [ ] Tags include: Name, Environment, Owner, CostCenter
- [ ] Default tags at provider level
- [ ] AWS-managed policies preferred over custom

**GCP:**
- [ ] Labels include: environment, team, cost-center
- [ ] Organization policies enforced
- [ ] Service accounts follow least privilege

**Azure:**
- [ ] Tags include: environment, owner, cost-center
- [ ] Resource naming follows conventions
- [ ] Management groups and policies applied

### 7. Specific Resource Checks

**Databases:**
- Backup retention configured
- Multi-AZ/HA enabled for production
- Parameter groups reviewed
- Maintenance windows set appropriately
- Deletion protection enabled

**Networking:**
- CIDR blocks don't overlap
- Subnet sizing appropriate
- Route tables correctly configured
- Peering/VPN connections validated

**IAM/Security:**
- Principle of least privilege
- No overly permissive wildcard permissions
- Service accounts with minimal permissions
- Role assumptions properly scoped

**Compute:**
- Instance sizes appropriate for workload
- Auto-scaling configured
- Health checks defined
- Monitoring and alerting enabled

## Plan Review Output Format

### Executive Summary

**Plan Overview:**
- Total Changes: `<count>`
- Creates: `<count>`
- Updates: `<count>`
- Replaces: `<count>`
- Deletes: `<count>`
- Environment: `<env>`
- Cloud Provider: `<AWS|GCP|Azure>`

**Risk Level:** `<LOW|MEDIUM|HIGH|CRITICAL>`

**Approval Recommendation:** `<APPROVE|REVIEW REQUIRED|REJECT>`

### Detailed Analysis

#### 1. High-Risk Changes

**Critical Resources Affected:**

| Resource Type | Name | Action | Risk Level | Reason |
|--------------|------|--------|------------|---------|
| aws_db_instance | prod-db | Replace | CRITICAL | Data loss risk, downtime |
| aws_lb | api-lb | Replace | HIGH | IP change, DNS update needed |

**Mitigation Steps:**
1. Backup database before apply
2. Update DNS with lower TTL in advance
3. Plan maintenance window
4. Prepare rollback plan

#### 2. Security Assessment

**Security Score:** `<score>/100`

**Critical Issues:**
- [ ] Issue 1: `<description>` - Location: `<resource>`
- [ ] Issue 2: `<description>` - Location: `<resource>`

**Warnings:**
- Issue 1: `<description>` - Location: `<resource>`

**Recommendations:**
- Recommendation 1: `<action>`
- Recommendation 2: `<action>`

#### 3. Cost Impact

**Estimated Monthly Cost Change:** `$X,XXX` (±X%)

**Cost Breakdown:**
| Category | Current | New | Change | Impact |
|----------|---------|-----|--------|---------|
| Compute | $1,000 | $1,500 | +$500 | +50% |
| Storage | $200 | $250 | +$50 | +25% |
| Network | $100 | $100 | $0 | 0% |
| **Total** | **$1,300** | **$1,850** | **+$550** | **+42%** |

**Cost Optimization Opportunities:**
1. Consider reserved instances for `<resources>` - Save ~$XXX/month
2. Right-size `<resource>` from X to Y - Save ~$XXX/month
3. Use spot/preemptible instances for `<workload>` - Save ~$XXX/month

#### 4. Resource Changes by Category

**Creates (X resources):**
- `aws_instance.web-server` - t3.medium web server
- `aws_security_group.web-sg` - Security group for web tier
- `aws_ebs_volume.data` - 100GB gp3 volume

**Updates (X resources):**
- `aws_autoscaling_group.app` - Changing desired capacity: 2 → 4
- `aws_security_group.db` - Adding ingress rule for new CIDR

**Replaces (X resources):**
- `aws_db_instance.main` - ⚠️ Instance class change: db.t3.small → db.t3.medium
  - **Risk:** Downtime during replacement
  - **Data:** Snapshot taken automatically
  - **Mitigation:** Schedule during maintenance window

**Deletes (X resources):**
- `aws_instance.old-server` - Decommissioned server
- `aws_security_group.unused` - Cleanup of unused SG

#### 5. Dependencies and Order

**Execution Order Considerations:**
1. Create new security groups before instances
2. Update load balancer listeners after target groups
3. Replace database requires application downtime
4. Delete old resources after verification

**Dependency Graph:**
```
VPC
 ├── Subnets
 │    ├── Security Groups
 │    │    └── Instances
 │    └── Load Balancer
 └── Route Tables
```

#### 6. Compliance and Governance

**Tag Coverage:** `<X>%` of resources properly tagged

**Missing Tags:**
- Resource: `<name>` - Missing: Environment, Owner

**Compliance Checks:**
- [ ] All production databases encrypted
- [ ] All S3 buckets have versioning
- [ ] All resources tagged per policy
- [ ] No public access to sensitive data

### Pre-Apply Checklist

**Before running `terraform apply`:**

**Backups:**
- [ ] Database snapshots taken
- [ ] Critical data backed up
- [ ] Terraform state backed up

**Notifications:**
- [ ] Stakeholders notified of maintenance
- [ ] Change ticket created/updated
- [ ] Team members aware of changes

**Validation:**
- [ ] Plan reviewed by senior engineer
- [ ] Security team approval (if required)
- [ ] Cost within budget approval
- [ ] Compliance requirements met

**Preparation:**
- [ ] Maintenance window scheduled
- [ ] Rollback plan documented
- [ ] Monitoring alerts configured
- [ ] Runbook prepared for issues

**Verification:**
- [ ] Post-apply verification steps defined
- [ ] Health checks identified
- [ ] Testing plan ready
- [ ] Documentation updated

### Rollback Plan

**If apply fails or issues occur:**

```bash
# 1. Rollback terraform changes
terraform apply -auto-approve -lock=true <previous-plan>

# 2. Restore from backups if needed
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier <name> \
  --db-snapshot-identifier <snapshot>

# 3. Verify rollback success
terraform plan  # Should show no changes

# 4. Restore traffic/services
# <specific steps based on changes>
```

**Recovery Time Objective (RTO):** `<time>`

**Recovery Point Objective (RPO):** `<time>`

### Post-Apply Verification

**Validation Steps:**
1. Run `terraform plan` to verify no unexpected drift
2. Check resource health in cloud console
3. Verify application connectivity
4. Review monitoring dashboards
5. Check cost explorer for unexpected charges
6. Validate security configurations

**Commands:**
```bash
# Verify no drift
terraform plan -detailed-exitcode

# Check outputs
terraform output

# Validate specific resources
terraform state show <resource>
```

## Best Practices

**Plan Generation:**
- Always save plan to file: `terraform plan -out=tfplan`
- Generate JSON for automated analysis: `terraform show -json tfplan`
- Use `-detailed-exitcode` for CI/CD pipelines
- Review plan before every apply (never auto-approve in production)

**Peer Review:**
- Require plan review for production changes
- Use version control for all Terraform code
- Document rationale for major changes
- Share plan output with relevant teams

**Risk Mitigation:**
- Test changes in lower environments first
- Use workspaces or separate state for environments
- Enable deletion protection on critical resources
- Implement state locking to prevent concurrent modifications

**Cost Management:**
- Review cost impact before approval
- Set up cost alerts and budgets
- Use tagging for cost allocation
- Regular reviews to identify waste

**Security:**
- Never commit sensitive data to version control
- Use encrypted remote state
- Implement least privilege for Terraform execution
- Scan plans for security issues (checkov, tfsec, terrascan)

**Automation:**
- Integrate plan review in CI/CD pipelines
- Automated security and compliance scanning
- Cost estimation automation (Infracost)
- Plan archival for audit trails
