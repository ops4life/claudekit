---
description: Multi-cloud cost analysis and optimization recommendations for infrastructure
---

# Cloud Cost Analysis and Optimization Command

You are helping analyze infrastructure costs and provide optimization recommendations across AWS, GCP, and Azure.

## Requirements

**User must provide:**
- Cloud provider(s) (AWS, GCP, Azure, or multi-cloud)
- Terraform configurations or cloud resources to analyze
- Target cost reduction goal (optional, e.g., 20%)
- Budget constraints

**Prerequisites:**
- Access to cloud billing/cost explorer
- Terraform state or resource inventory
- Historical cost data (if available)

## Cost Analysis Workflow

### 1. Resource Inventory and Current Costs

**A. Extract Resources from Terraform:**

```bash
# List all resources
terraform state list

# Get resource details
terraform state show <resource>

# Export state for analysis
terraform show -json > infrastructure.json
```

**B. Gather Current Cost Data:**

**AWS Cost Explorer:**
```bash
# Get cost and usage for current month
aws ce get-cost-and-usage \
  --time-period Start=$(date -d "1 month ago" +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE

# Get cost by tags
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-02-01 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=TAG,Key=Environment
```

**GCP Billing:**
```bash
# Export billing data
bq query --use_legacy_sql=false '
  SELECT
    service.description,
    SUM(cost) as total_cost
  FROM `<project>.billing_export.gcp_billing_export_v1_*`
  WHERE _TABLE_SUFFIX BETWEEN "20240101" AND "20240131"
  GROUP BY service.description
  ORDER BY total_cost DESC
'
```

**Azure Cost Management:**
```bash
# Get cost by resource group
az consumption usage list \
  --start-date 2024-01-01 \
  --end-date 2024-01-31 \
  --output table

# Get cost by service
az consumption usage list \
  --start-date 2024-01-01 \
  --end-date 2024-01-31 \
  --query "[].{Service:meterCategory, Cost:pretaxCost}" \
  --output table
```

### 2. Cost Breakdown by Category

**Analyze costs across categories:**

**A. Compute Costs:**

**AWS EC2/EKS:**
- EC2 instance costs by family/type
- EBS volume costs (type, size, IOPS)
- EKS control plane and node costs
- Data transfer costs
- Reserved Instance vs On-Demand utilization

**GCP Compute Engine/GKE:**
- VM instance costs by machine type
- Persistent disk costs (SSD vs Standard)
- GKE cluster and node costs
- Network egress costs
- Committed Use Discount utilization

**Azure VMs/AKS:**
- VM costs by size/series
- Managed disk costs (Premium vs Standard)
- AKS cluster costs
- Bandwidth costs
- Reserved VM Instance utilization

**B. Database Costs:**

**AWS RDS:**
- Instance costs (on-demand vs reserved)
- Storage costs (provisioned, IOPS, backups)
- Multi-AZ costs
- Read replica costs

**GCP Cloud SQL:**
- Instance costs by tier
- Storage and backup costs
- High availability costs
- Replication costs

**Azure SQL Database:**
- DTU/vCore costs
- Storage costs
- Geo-replication costs
- Backup storage

**C. Storage Costs:**

**AWS S3:**
- Storage costs by class (Standard, IA, Glacier)
- Request costs (PUT, GET, etc.)
- Data transfer costs
- Versioning/lifecycle costs

**GCP Cloud Storage:**
- Storage by class (Standard, Nearline, Coldline, Archive)
- Operation costs
- Network egress
- Retrieval costs

**Azure Blob Storage:**
- Storage by tier (Hot, Cool, Archive)
- Transaction costs
- Data transfer
- Snapshot costs

**D. Networking Costs:**

- Load balancers (ALB, NLB, Cloud LB, App Gateway)
- NAT gateways
- VPN connections
- Inter-region data transfer
- Internet egress
- VPC peering/private links

**E. Managed Services:**

- Lambda/Cloud Functions/Azure Functions
- API Gateway
- CloudFront/Cloud CDN/Azure CDN
- Route53/Cloud DNS/Azure DNS
- CloudWatch/Stackdriver/Azure Monitor

### 3. Cost Optimization Opportunities

**A. Compute Optimization:**

**1. Right-Sizing Recommendations:**

**Analyze resource utilization:**
```bash
# AWS - Get CloudWatch metrics for EC2
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=<instance-id> \
  --start-time <start> \
  --end-time <end> \
  --period 3600 \
  --statistics Average

# Get underutilized instances
aws compute-optimizer get-ec2-instance-recommendations
```

**Identify:**
- Instances with <20% CPU utilization consistently
- Over-provisioned memory
- Underutilized disk IOPS
- Opportunities to downsize instance types

**Savings estimate:**
- Current: `t3.xlarge` (4 vCPU, 16GB RAM) @ $0.166/hr = $121/month
- Recommended: `t3.large` (2 vCPU, 8GB RAM) @ $0.083/hr = $61/month
- **Savings: $60/month (50%)**

**2. Reserved Instances / Committed Use Discounts:**

**AWS Reserved Instances:**
- 1-year partial upfront: ~30% discount
- 1-year all upfront: ~40% discount
- 3-year all upfront: ~60% discount

**GCP Committed Use Discounts:**
- 1-year commitment: ~25% discount
- 3-year commitment: ~50% discount

**Azure Reserved VM Instances:**
- 1-year: ~40% discount
- 3-year: ~60% discount

**Recommendation format:**
```
Resource: EC2 instance i-xxx (t3.large)
Current: On-Demand @ $0.083/hr = $61/month
Recommended: 1-year Partial Upfront RI
Savings: $18/month (30%)
Upfront cost: $220
Break-even: ~12 months
```

**3. Spot/Preemptible Instances:**

**Use cases:**
- Batch processing jobs
- CI/CD workers
- Data processing pipelines
- Development/test environments
- Stateless workloads

**Savings: 60-90% vs On-Demand**

**Example:**
- Current: On-Demand `c5.2xlarge` @ $0.34/hr = $248/month
- With Spot: ~$0.10/hr = $73/month
- **Savings: $175/month (70%)**

**4. Auto-Scaling and Scheduling:**

**Shut down non-production during off-hours:**
- Dev/test environments: Run 9am-6pm weekdays only
- Current: 24/7 = 730 hours/month
- Optimized: 45 hours/week = ~180 hours/month
- **Savings: 75% cost reduction**

**B. Storage Optimization:**

**1. Storage Tiering:**

**S3/GCS/Blob Storage lifecycle policies:**

```hcl
# Example: AWS S3 lifecycle policy
resource "aws_s3_bucket_lifecycle_configuration" "optimize" {
  bucket = aws_s3_bucket.data.id

  rule {
    id     = "optimize-storage"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"  # Infrequent Access
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = 730  # Delete after 2 years
    }
  }
}
```

**Savings example:**
- 1TB in S3 Standard: $23/month
- 1TB in S3 Infrequent Access: $12.50/month
- 1TB in Glacier: $4/month
- **Savings: $19/month per TB (83%)**

**2. Remove Unused Volumes and Snapshots:**

```bash
# AWS - Find unattached EBS volumes
aws ec2 describe-volumes \
  --filters Name=status,Values=available \
  --query 'Volumes[*].[VolumeId,Size,VolumeType]' \
  --output table

# Find old snapshots
aws ec2 describe-snapshots \
  --owner-ids self \
  --query 'Snapshots[?StartTime<=`2023-01-01`]' \
  --output table
```

**3. Compression and Deduplication:**

- Enable compression for backups
- Use deduplication for redundant data
- Optimize image sizes (containers, AMIs)

**C. Database Optimization:**

**1. Right-Size Database Instances:**

- Monitor CPU, memory, IOPS utilization
- Consider serverless options (Aurora Serverless, Azure SQL Serverless)
- Use read replicas only when needed

**2. Reserved Database Instances:**

- Similar discounts to compute RIs
- 1-year: 30-40% savings
- 3-year: 50-65% savings

**3. Storage Optimization:**

- Use appropriate storage type (SSD vs HDD)
- Reduce unnecessary IOPS provisioning
- Implement backup retention policies
- Consider lower RPO/RTO for non-critical DBs

**D. Network Cost Optimization:**

**1. Reduce Data Transfer:**

**Cross-region transfer:**
- Keep services in same region where possible
- Use CloudFront/CDN for content delivery
- Implement caching aggressively

**Internet egress:**
- AWS: $0.09/GB (first 10TB)
- GCP: $0.12/GB
- Azure: $0.087/GB

**Optimization:**
- Use CDN for static content
- Compress data before transfer
- Use Direct Connect/Cloud Interconnect for high volume

**2. Load Balancer Optimization:**

**AWS ALB pricing:**
- $0.0225/hour + $0.008/LCU-hour
- Consider consolidating ALBs (multi-target groups)

**3. NAT Gateway Costs:**

**AWS NAT Gateway:**
- $0.045/hour = $33/month
- $0.045/GB processed
- Consider NAT instances for high-volume (potential 50% savings)

**E. Serverless and Managed Services:**

**When to use serverless:**
- Infrequent/sporadic workloads
- Event-driven architectures
- Automatic scaling needs

**Cost comparison example:**

**EC2 (t3.small running 24/7):**
- Instance: $15/month
- Storage: $10/month
- Total: $25/month

**Lambda (equivalent workload):**
- 10M requests/month @ $0.20/1M = $2
- Compute: 1GB-sec, 100ms avg = $0.167
- Total: $2.17/month
- **Savings: $22.83/month (91%)**

### 4. Multi-Cloud Cost Comparison

**Equivalent resource pricing:**

**Compute (2 vCPU, 8GB RAM):**
- AWS t3.large: $0.083/hr = $61/month
- GCP n1-standard-2: $0.095/hr = $69/month
- Azure D2s v3: $0.096/hr = $70/month

**Storage (1TB SSD):**
- AWS gp3: $80/month
- GCP pd-ssd: $170/month
- Azure Premium SSD: $135/month

**Load Balancer:**
- AWS ALB: ~$20/month base
- GCP HTTP(S) LB: ~$18/month base
- Azure App Gateway: ~$142/month

**Database (2 vCPU, 8GB):**
- AWS RDS MySQL: ~$120/month
- GCP Cloud SQL MySQL: ~$135/month
- Azure SQL Database: ~$240/month (4 vCore)

### 5. Cost Allocation and Tagging

**Implement cost allocation tags:**

**Required tags:**
```hcl
# Example tagging strategy
tags = {
  Environment  = "production"
  Team         = "platform"
  CostCenter   = "engineering"
  Owner        = "ops4life"
  Application  = "web-app"
  ManagedBy    = "terraform"
}
```

**Cost allocation benefits:**
- Track costs by team/project
- Identify cost anomalies
- Chargeback to business units
- Budget enforcement

### 6. Continuous Cost Monitoring

**Set up alerts:**

**AWS Budgets:**
```bash
aws budgets create-budget \
  --account-id <account> \
  --budget file://budget.json \
  --notifications-with-subscribers file://notifications.json
```

**GCP Budget Alerts:**
```bash
gcloud billing budgets create \
  --billing-account=<account> \
  --display-name="Monthly Budget" \
  --budget-amount=5000
```

**Azure Cost Alerts:**
```bash
az consumption budget create \
  --budget-name monthly-budget \
  --amount 5000 \
  --time-grain Monthly
```

## Cost Analysis Output Format

### Executive Summary

**Current Monthly Cost:** `$X,XXX`

**Optimization Potential:** `$X,XXX/month` (X%)

**Quick Wins:** `$XXX/month` (implementable within 1 week)

**Total Annual Savings Potential:** `$XX,XXX`

### Detailed Cost Breakdown

**Current Costs by Category:**

| Category | Monthly Cost | % of Total | Trend |
|----------|--------------|------------|-------|
| Compute | $2,500 | 45% | ↑ 10% |
| Database | $1,200 | 22% | → Stable |
| Storage | $800 | 15% | ↓ 5% |
| Network | $600 | 11% | ↑ 15% |
| Other | $400 | 7% | → Stable |
| **Total** | **$5,500** | **100%** | **↑ 8%** |

**Top 10 Cost Drivers:**

1. RDS production database (db.r5.2xlarge): $520/month
2. EC2 application servers (10x t3.large): $610/month
3. ALB for web tier: $180/month
4. NAT Gateways (3 AZs): $150/month
5. S3 storage (5TB): $115/month
...

### Optimization Recommendations

**Priority 1: High Impact, Low Effort (Quick Wins)**

**1. Purchase Reserved Instances for stable workloads**
- **Resources:** 10x t3.large EC2 instances
- **Current cost:** $610/month (On-Demand)
- **Optimized cost:** $427/month (1-year Partial Upfront RI)
- **Savings:** $183/month ($2,196/year)
- **Effort:** Low (1-2 hours)
- **Implementation:** Purchase RIs through AWS console

**2. Delete unused EBS volumes**
- **Resources:** 15 unattached volumes (total 2TB)
- **Current cost:** $200/month
- **Savings:** $200/month ($2,400/year)
- **Effort:** Low (30 minutes)
- **Risk:** None (verified unused)

**3. Implement S3 lifecycle policies**
- **Resources:** 3TB of S3 data older than 90 days
- **Current cost:** $69/month (Standard storage)
- **Optimized cost:** $12/month (Glacier)
- **Savings:** $57/month ($684/year)
- **Effort:** Low (1 hour)

**Priority 2: High Impact, Medium Effort**

**4. Right-size over-provisioned instances**
- **Resources:** 5x t3.2xlarge with <30% CPU utilization
- **Current cost:** $605/month
- **Optimized:** 5x t3.xlarge
- **Optimized cost:** $302/month
- **Savings:** $303/month ($3,636/year)
- **Effort:** Medium (testing required)
- **Risk:** Medium (validate performance)

**5. Migrate dev/test to Spot instances**
- **Resources:** Development environment (8 instances)
- **Current cost:** $480/month (On-Demand)
- **Optimized cost:** $145/month (Spot)
- **Savings:** $335/month ($4,020/year)
- **Effort:** Medium (modify ASG/launch templates)
- **Risk:** Low (dev environment)

**6. Schedule non-production shutdowns**
- **Resources:** Staging and dev environments
- **Current cost:** $890/month (24/7)
- **Optimized cost:** $223/month (9am-6pm weekdays)
- **Savings:** $667/month ($8,004/year)
- **Effort:** Medium (implement scheduling)
- **Risk:** Low (non-production)

**Priority 3: Medium Impact, Complexity**

**7. Migrate to Aurora Serverless for variable workload**
- **Resource:** RDS MySQL instance (db.t3.medium)
- **Current cost:** $120/month + storage
- **Optimized:** Aurora Serverless v2 (2-4 ACUs)
- **Estimated cost:** $60-80/month
- **Savings:** $40-60/month ($480-720/year)
- **Effort:** High (migration required)
- **Risk:** Medium (test thoroughly)

**8. Consolidate Application Load Balancers**
- **Resources:** 4 separate ALBs
- **Current cost:** $360/month
- **Optimized:** 2 ALBs with multiple target groups
- **Optimized cost:** $180/month
- **Savings:** $180/month ($2,160/year)
- **Effort:** High (infrastructure changes)
- **Risk:** Medium (routing complexity)

### Implementation Roadmap

**Month 1 - Quick Wins ($440/month savings):**
- Week 1: Purchase Reserved Instances
- Week 2: Delete unused volumes and snapshots
- Week 3: Implement S3 lifecycle policies
- Week 4: Monitor and validate

**Month 2 - Right-Sizing ($638/month additional):**
- Week 1: Analyze and test instance right-sizing
- Week 2: Implement Spot instances for dev/test
- Week 3: Deploy scheduling for non-production
- Week 4: Validate and monitor

**Month 3 - Advanced Optimizations ($220/month additional):**
- Week 1-2: Plan database migration
- Week 3: Consolidate load balancers
- Week 4: Test and validate

**Total Implementation:** `$1,298/month` ($15,576/year)

### Cost Governance Recommendations

**1. Tagging Strategy:**
- Enforce mandatory tags (Environment, Owner, CostCenter)
- Implement tag policies
- Regular tag compliance audits

**2. Budget Alerts:**
- Overall monthly budget: $6,000 (alert at 80%, 100%)
- Per-environment budgets
- Per-team cost allocations

**3. Regular Reviews:**
- Weekly: Cost anomaly detection
- Monthly: Cost optimization review
- Quarterly: Architecture cost review

**4. FinOps Practices:**
- Establish cost ownership by teams
- Implement showback/chargeback
- Create cost optimization culture
- Regular training on cost-aware architecture

### Monitoring and Tracking

**KPIs to Track:**
- Cost per customer/transaction
- Cost as % of revenue
- Month-over-month cost trend
- Waste percentage (unused resources)
- Reserved Instance utilization
- Savings realized vs potential

**Tools:**
- AWS Cost Explorer & Trusted Advisor
- GCP Cost Management & Recommender
- Azure Cost Management & Advisor
- Third-party: CloudHealth, Cloudability, Infracost

## Best Practices

**Proactive Cost Management:**
- Review costs weekly, not monthly
- Automate cost anomaly detection
- Implement cost-aware CI/CD (Infracost in pipelines)
- Right-size during initial deployment

**Architecture for Cost:**
- Use managed services appropriately
- Implement auto-scaling
- Design for horizontal scaling
- Choose appropriate storage tiers
- Optimize data transfer patterns

**Continuous Optimization:**
- Regular resource cleanup
- Review and renew reservations
- Keep up with new pricing options
- Benchmark against industry standards
- Iterate on cost optimization

**Cultural Practices:**
- Make cost visibility transparent
- Celebrate cost savings
- Include cost in design reviews
- Train engineers on cloud economics
- Incentivize cost-conscious decisions
