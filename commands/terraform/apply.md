---
description: Guided Terraform apply workflow with safety checks and rollback procedures
---

# Terraform Apply Command

You are helping safely execute a Terraform apply operation with proper validation, safety checks, and rollback procedures.

## Requirements

**User must provide:**
- Terraform plan file or confirmation to generate new plan
- Target environment (dev/staging/production)
- Approval confirmation for changes

**Prerequisites:**
- Terraform initialized (`terraform init`)
- Valid credentials for cloud provider
- Terraform plan reviewed and approved
- Backup strategy in place

## Apply Workflow

### 1. Pre-Apply Validation

**A. Verify Terraform Environment:**

```bash
# Check Terraform version
terraform version

# Verify workspace (if using workspaces)
terraform workspace show

# Check backend configuration
terraform init -backend-config=<config>

# Verify state is accessible
terraform state list
```

**B. Validate Plan:**

```bash
# Generate fresh plan if not already done
terraform plan -out=tfplan

# Review plan output
terraform show tfplan

# Check for no unexpected changes
# Ensure plan matches what was reviewed
```

**C. Environment-Specific Checks:**

**For Production:**
- [ ] Plan has been peer-reviewed
- [ ] Security team approval obtained (if required)
- [ ] Change ticket created and approved
- [ ] Maintenance window scheduled (if downtime expected)
- [ ] Stakeholders notified
- [ ] Rollback plan documented

**For Staging/Dev:**
- [ ] Plan reviewed by engineer
- [ ] No production data at risk
- [ ] Testing plan ready

### 2. Pre-Apply Backups

**Critical Resources to Backup:**

**A. Terraform State:**

```bash
# Backup current state
terraform state pull > state-backup-$(date +%Y%m%d-%H%M%S).json

# For S3 backend (AWS)
aws s3 cp s3://<bucket>/<key>/terraform.tfstate \
  ./state-backup-$(date +%Y%m%d-%H%M%S).tfstate

# For GCS backend (GCP)
gsutil cp gs://<bucket>/<path>/terraform.tfstate \
  ./state-backup-$(date +%Y%m%d-%H%M%S).tfstate

# For Azure Blob backend
az storage blob download \
  --account-name <account> \
  --container-name <container> \
  --name terraform.tfstate \
  --file state-backup-$(date +%Y%m%d-%H%M%S).tfstate
```

**B. Database Snapshots (if databases being modified):**

**AWS RDS:**
```bash
aws rds create-db-snapshot \
  --db-instance-identifier <db-instance> \
  --db-snapshot-identifier pre-terraform-apply-$(date +%Y%m%d-%H%M%S)
```

**GCP Cloud SQL:**
```bash
gcloud sql backups create \
  --instance=<instance-name> \
  --description="Pre-terraform-apply-$(date +%Y%m%d-%H%M%S)"
```

**Azure SQL:**
```bash
az sql db export \
  --resource-group <rg> \
  --server <server> \
  --name <db> \
  --storage-key <key> \
  --storage-key-type StorageAccessKey \
  --storage-uri https://<account>.blob.core.windows.net/<container>/backup-$(date +%Y%m%d-%H%M%S).bacpac
```

**C. Critical Data Backups:**
- Storage buckets (S3, GCS, Blob Storage)
- Persistent volumes
- Configuration data
- DNS records (if changing)

### 3. Execute Apply with Safety Measures

**A. Controlled Apply Execution:**

**Standard Apply:**
```bash
# Apply with saved plan (recommended)
terraform apply tfplan

# Or apply with approval prompt
terraform apply

# For non-interactive (use with caution)
terraform apply -auto-approve
```

**B. Apply with Parallelism Control:**

```bash
# Limit parallel operations (safer for critical infrastructure)
terraform apply -parallelism=1 tfplan

# Default is 10, reduce for sensitive changes
terraform apply -parallelism=5 tfplan
```

**C. Target Specific Resources (if needed):**

```bash
# Apply changes to specific resources only
terraform apply -target=<resource-type>.<resource-name>

# Multiple targets
terraform apply \
  -target=aws_instance.web \
  -target=aws_security_group.web_sg

# Use targeting cautiously - can cause dependency issues
```

**D. Apply with Logging:**

```bash
# Enable detailed logging
TF_LOG=DEBUG terraform apply tfplan 2>&1 | tee apply-$(date +%Y%m%d-%H%M%S).log

# Or specific log levels
TF_LOG=TRACE terraform apply tfplan 2>&1 | tee apply.log
```

### 4. Monitor Apply Progress

**During Apply:**

**A. Watch for Errors:**
- Resource creation failures
- Timeout errors
- Permission/authentication issues
- Dependency conflicts
- API rate limiting

**B. Monitor Cloud Console:**
- AWS Console: Watch CloudFormation events, resource creation
- GCP Console: Monitor deployment manager, resource creation
- Azure Portal: Watch deployment progress, resource groups

**C. Track Progress:**
- Note which resources completed successfully
- Identify any failed resources
- Monitor for unexpected behavior
- Watch for cascading failures

**D. Be Prepared to Interrupt:**

```bash
# If critical issue detected, stop apply
Ctrl+C (interrupt)

# Note: Interrupting can leave state inconsistent
# Resources may be partially created
```

### 5. Post-Apply Verification

**A. Verify Apply Completion:**

```bash
# Check apply exit code
echo $?
# 0 = success, non-zero = errors

# Review apply output for errors
# All resources should show "created" or "updated" or "destroyed"
```

**B. Validate Infrastructure State:**

```bash
# Check no drift immediately after apply
terraform plan -detailed-exitcode
# Exit code 0 = no changes needed (success)
# Exit code 1 = error
# Exit code 2 = changes detected (investigate)

# List all resources
terraform state list

# Show outputs
terraform output
```

**C. Verify Resource Health:**

**AWS:**
```bash
# Check EC2 instances
aws ec2 describe-instances --filters "Name=tag:ManagedBy,Values=Terraform"

# Check RDS status
aws rds describe-db-instances --db-instance-identifier <name>

# Verify load balancer
aws elbv2 describe-load-balancers --names <lb-name>
```

**GCP:**
```bash
# Check compute instances
gcloud compute instances list --filter="labels.managed-by=terraform"

# Check Cloud SQL
gcloud sql instances describe <instance>

# Verify load balancer
gcloud compute forwarding-rules list
```

**Azure:**
```bash
# Check VMs
az vm list --resource-group <rg> --output table

# Check SQL databases
az sql db show --resource-group <rg> --server <server> --name <db>

# Verify load balancer
az network lb show --resource-group <rg> --name <lb>
```

**D. Application-Level Validation:**

- [ ] Applications can connect to infrastructure
- [ ] Services are responding to health checks
- [ ] Load balancers routing traffic correctly
- [ ] Databases accessible from application tier
- [ ] DNS resolving correctly (if changed)
- [ ] SSL/TLS certificates valid
- [ ] Monitoring and alerting functional

**E. Security Validation:**

```bash
# Verify security groups/firewall rules applied correctly
# AWS
aws ec2 describe-security-groups --group-ids <sg-id>

# GCP
gcloud compute firewall-rules list

# Azure
az network nsg show --resource-group <rg> --name <nsg>

# Check IAM roles/permissions
# AWS
aws iam get-role --role-name <role>

# GCP
gcloud iam roles describe <role>

# Azure
az role assignment list --assignee <principal>
```

**F. Cost Verification:**

- Check cloud billing dashboard for unexpected charges
- Verify resource counts match expectations
- Confirm no unintended resource creation
- Review cost tags applied correctly

### 6. Handle Apply Failures

**If Apply Fails:**

**A. Diagnose the Failure:**

```bash
# Review error messages carefully
# Check apply log for detailed errors

# Inspect state for partially created resources
terraform state list

# Show specific resource state
terraform state show <resource>
```

**B. Common Failure Scenarios:**

**1. Resource Already Exists:**
- Import existing resource: `terraform import <resource> <id>`
- Or remove from plan and re-apply

**2. Permission Denied:**
- Verify credentials are valid
- Check IAM/RBAC permissions
- Ensure service principals have necessary access

**3. Timeout:**
- Increase timeout in resource configuration
- Check cloud provider status page
- Retry apply with specific target

**4. Dependency Issues:**
- Review dependency chain
- May need to apply resources in specific order
- Use explicit `depends_on` if needed

**5. API Rate Limiting:**
- Reduce parallelism: `-parallelism=1`
- Wait and retry
- Check provider throttling settings

**C. Partial Apply Recovery:**

```bash
# Refresh state to match reality
terraform refresh

# Generate new plan to see remaining changes
terraform plan

# Apply remaining changes
terraform apply
```

### 7. Rollback Procedures

**When to Rollback:**
- Critical functionality broken
- Security vulnerability introduced
- Data loss detected
- Performance severely degraded
- Unrecoverable errors

**A. Rollback Methods:**

**Method 1: Terraform Rollback (Preferred):**

```bash
# 1. Restore state backup if state corrupted
terraform state push state-backup-<timestamp>.json

# 2. Checkout previous Terraform code version
git checkout <previous-commit>

# 3. Generate plan to revert
terraform plan -out=rollback-plan

# 4. Review rollback plan carefully
terraform show rollback-plan

# 5. Apply rollback
terraform apply rollback-plan
```

**Method 2: Manual Resource Restoration:**

```bash
# Restore database from snapshot (AWS)
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier <name> \
  --db-snapshot-identifier <snapshot-id>

# Restore storage from backup
# Depends on backup strategy

# Revert network changes manually if needed
```

**Method 3: Targeted Destroy and Recreate:**

```bash
# Destroy problematic resources
terraform destroy -target=<resource>

# Checkout previous code version
git checkout <previous-commit>

# Recreate with previous configuration
terraform apply -target=<resource>
```

**B. Post-Rollback Verification:**

- [ ] Services restored to previous state
- [ ] Applications functioning normally
- [ ] Data integrity verified
- [ ] Terraform state consistent
- [ ] No orphaned resources

### 8. Post-Apply Tasks

**A. Documentation:**

- [ ] Update infrastructure documentation
- [ ] Document changes made
- [ ] Record any issues encountered
- [ ] Update runbooks if needed
- [ ] Close change tickets

**B. Cleanup:**

```bash
# Remove plan files (may contain sensitive data)
rm -f tfplan *.tfplan

# Archive apply logs
mv apply-*.log logs/archive/

# Clean up backup files after verification period
# Keep state backups for audit/recovery
```

**C. Team Communication:**

- Notify stakeholders of completion
- Report any issues or deviations
- Share lessons learned
- Update team on infrastructure changes

**D. Monitoring:**

- Watch monitoring dashboards for anomalies
- Review logs for new errors
- Check performance metrics
- Monitor cost trends

## Apply Output Format

### Apply Summary

**Execution Details:**
- Started: `<timestamp>`
- Completed: `<timestamp>`
- Duration: `<minutes>`
- Environment: `<env>`
- Applied By: `<user>`
- Plan File: `<filename>`

**Changes Applied:**
- ✅ Created: `<count>` resources
- ✅ Updated: `<count>` resources
- ✅ Replaced: `<count>` resources
- ✅ Destroyed: `<count>` resources
- ❌ Failed: `<count>` resources

**Status:** `<SUCCESS|PARTIAL|FAILED>`

### Resource Changes

**Successfully Created:**
- `aws_instance.web-01` - t3.medium web server
- `aws_security_group.web-sg` - Web tier security group
- ...

**Successfully Updated:**
- `aws_autoscaling_group.app` - Increased capacity 2→4
- ...

**Successfully Replaced:**
- `aws_db_instance.main` - Upgraded from db.t3.small to db.t3.medium
- ...

**Failed (if any):**
- `aws_lb.api` - Error: Timeout waiting for creation
  - **Action Required:** Manual intervention needed
  - **Rollback:** Included in rollback plan

### Verification Checklist

**Infrastructure Validation:**
- [x] Terraform plan shows no drift
- [x] All resources in expected state
- [x] Outputs generated correctly
- [x] No orphaned resources

**Application Validation:**
- [x] Services responding to health checks
- [x] Applications can access resources
- [x] Load balancers routing correctly
- [x] DNS resolution working

**Security Validation:**
- [x] Security groups configured correctly
- [x] IAM roles applied properly
- [x] Encryption settings verified
- [x] No public exposure of sensitive resources

**Monitoring:**
- [x] Metrics flowing to monitoring system
- [x] Alerts configured and active
- [x] Logs being collected
- [x] No error alerts triggered

### Issues and Resolutions

**Issues Encountered:**
1. **Issue:** Timeout creating load balancer
   - **Resolution:** Increased timeout and retried successfully
   - **Duration:** 10 minutes

**Warnings:**
1. **Warning:** Resource near capacity limits
   - **Action:** Monitor usage, plan for scaling

### Next Steps

- [ ] Monitor infrastructure for 24 hours
- [ ] Review cost impact after 7 days
- [ ] Schedule cleanup of old backups
- [ ] Update documentation with new architecture
- [ ] Share apply summary with team

## Best Practices

**Safety:**
- Always use saved plan files (`-out=tfplan`)
- Never use `-auto-approve` in production without thorough testing
- Keep state backups before every apply
- Test in lower environments first
- Use state locking to prevent concurrent applies

**Reliability:**
- Use version pinning for providers and modules
- Implement retry logic for transient failures
- Monitor apply operations actively
- Document rollback procedures
- Keep audit trail of all applies

**Security:**
- Protect plan files (may contain sensitive data)
- Use encrypted remote state
- Limit who can run apply in production
- Review security implications of changes
- Scan for security issues before apply

**Operational Excellence:**
- Automate apply in CI/CD where appropriate
- Use workspaces or separate states per environment
- Tag all resources for tracking
- Implement change approval workflows
- Regular state cleanup and maintenance
