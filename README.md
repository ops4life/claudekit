# claudekit - DevOps/SRE/Platform Engineering Toolkit for Claude Code

A comprehensive Claude Code plugin providing production-ready slash commands for DevOps, SRE, and Platform Engineering workflows across multi-cloud environments (AWS, GCP, Azure).

## Overview

**claudekit** enhances DevOps productivity by providing guided, interactive workflows for:

- **Kubernetes Operations** - Deploy, troubleshoot, and validate K8s resources
- **Infrastructure as Code** - Terraform plan analysis, safe apply workflows, and cost optimization
- **CI/CD Automation** - Create production pipelines and design deployment strategies
- **Observability** - Define SLOs, create monitoring alerts, and manage error budgets
- **Incident Response** - Structured postmortem creation with blameless culture

## Installation

### Prerequisites

- Claude Code 2.0.13 or higher
- Git (for local installation method)

### Quick Install (Recommended)

Install directly from GitHub in two commands:

1. **Add the marketplace:** `/plugin marketplace add ops4life/claudekit`
2. **Install the plugin:** `/plugin install claudekit`

### Install from Local Source

For development or customization purposes:

```bash
# Clone the repository
git clone https://github.com/ops4life/claudekit.git

# Navigate to the cloned directory
cd claudekit

# Add as local marketplace source
# Run this command in Claude Code:
# /plugin marketplace add /absolute/path/to/claudekit

# Install the plugin
# /plugin install claudekit
```

### Post-Installation

Once installed, all commands are immediately available. You can customize any command by editing files in:
- `.claude/commands/` - Modify command workflows and templates
- Restart Claude Code after making changes to command files

## Commands

All commands are invoked using the pattern: `/claudekit:<category>:<command>`

### Kubernetes Operations

#### `/claudekit:k8s:deploy`
**Guided Kubernetes deployment workflow with validation and safety checks**

Provides comprehensive deployment guidance including:
- Pre-deployment validation (context, image, resources)
- Security checks (pod security, secrets, network policies)
- Deployment execution with monitoring
- Post-deployment validation
- Rollback plan preparation
- Multi-cloud support (EKS, GKE, AKS)

**Example Usage:**
```
/claudekit:k8s:deploy

Application: my-web-app
Namespace: production
Image: myregistry.io/webapp:v2.1.0
Environment: production
```

#### `/claudekit:k8s:troubleshoot`
**Systematic Kubernetes pod and service debugging workflow**

Comprehensive troubleshooting for:
- Pod issues (CrashLoopBackOff, ImagePullBackOff, Pending, OOMKilled)
- Service connectivity and DNS resolution
- Network debugging and policy validation
- Resource saturation analysis
- Multi-cloud specific issues

**Example Usage:**
```
/claudekit:k8s:troubleshoot

Resource: Pod/my-app-5d7c8f9-abcd
Namespace: production
Symptom: CrashLoopBackOff
```

#### `/claudekit:k8s:manifest-validate`
**Validate Kubernetes YAML manifests for syntax, security, and best practices**

Validates:
- YAML syntax and Kubernetes API compatibility
- Security contexts and pod security standards
- Resource requests/limits configuration
- High availability settings (replicas, PDBs)
- Health check configuration
- Label and annotation standards

**Example Usage:**
```
/claudekit:k8s:manifest-validate

Manifest file: deployment.yaml
Environment: production
Compliance: PCI-DSS
```

### Infrastructure as Code (Terraform)

#### `/claudekit:terraform:plan-review`
**Analyze Terraform plan output for risks, security issues, and cost impact**

Comprehensive plan analysis:
- Risk assessment (replacements, deletions, high-risk changes)
- Security analysis (public exposure, encryption, IAM)
- Cost impact estimation
- Resource change categorization
- Dependency mapping
- Pre-apply checklist

**Example Usage:**
```
/claudekit:terraform:plan-review

Plan file: tfplan
Environment: production
Cloud: AWS
```

#### `/claudekit:terraform:apply`
**Guided Terraform apply workflow with safety checks and rollback procedures**

Safe apply execution:
- Pre-apply validation and backups
- State backup procedures
- Database snapshot creation
- Controlled apply with monitoring
- Post-apply verification
- Rollback procedures

**Example Usage:**
```
/claudekit:terraform:apply

Plan file: tfplan
Environment: production
Approval: Confirmed
```

#### `/claudekit:terraform:cloud-cost`
**Multi-cloud cost analysis and optimization recommendations**

Cost optimization across:
- Compute (EC2, GCE, VMs)
- Database (RDS, Cloud SQL, Azure SQL)
- Storage (S3, GCS, Blob Storage)
- Networking (Load Balancers, NAT Gateways)
- Right-sizing and reserved instances
- Multi-cloud cost comparison

**Example Usage:**
```
/claudekit:terraform:cloud-cost

Cloud providers: AWS, GCP
Target reduction: 20%
Budget: $10,000/month
```

### CI/CD Automation

#### `/claudekit:cicd:pipeline-new`
**Create production-ready CI/CD pipeline with best practices**

Pipeline creation for:
- GitHub Actions, GitLab CI, Jenkins, CircleCI
- Multi-stage pipelines (build, test, security, deploy)
- Security scanning integration
- Container image building
- Multi-environment deployment
- Notification and monitoring

**Example Usage:**
```
/claudekit:cicd:pipeline-new

Platform: GitHub Actions
Application: Node.js web app
Deployment: Kubernetes (EKS)
Environments: staging, production
```

#### `/claudekit:cicd:deploy-strategy`
**Design deployment strategies (blue/green, canary, rolling) with implementation**

Deployment strategy design:
- Rolling deployments
- Blue/Green deployments
- Canary deployments
- Recreate strategy
- Feature flags / Dark launches
- Platform-specific implementations

**Example Usage:**
```
/claudekit:cicd:deploy-strategy

Application: E-commerce checkout
Traffic: 10,000 req/min
Downtime tolerance: Zero
Platform: Kubernetes with Istio
```

### Observability & Monitoring

#### `/claudekit:observability:alert-new`
**Create monitoring alerts with SLO-based thresholds and best practices**

Alert creation for:
- Availability alerts (success rate)
- Latency alerts (P95, P99)
- Error rate alerts
- Resource saturation (CPU, memory, disk)
- Database alerts
- Application-specific alerts

**Example Usage:**
```
/claudekit:observability:alert-new

Service: checkout-api
Platform: Prometheus
Alert type: Availability
SLO: 99.9%
Notification: PagerDuty, Slack
```

#### `/claudekit:observability:slo-define`
**Calculate and define SLOs/SLIs with error budgets and monitoring**

SLO management:
- SLI selection (availability, latency, quality)
- SLO target setting
- Error budget calculation
- Multi-window burn-rate alerting
- SLO dashboarding
- Error budget policy

**Example Usage:**
```
/claudekit:observability:slo-define

Service: payment-processor
Type: User-facing API
Criticality: Critical
Target: 99.95% availability
```

### Incident Management

#### `/claudekit:incident:postmortem`
**Structured postmortem template with timeline, RCA, and action items**

Blameless postmortem creation:
- Incident summary and impact
- Detailed timeline
- Root cause analysis
- What went well / What went wrong
- Lessons learned
- Actionable follow-up items

**Example Usage:**
```
/claudekit:incident:postmortem

Incident: Checkout service outage
Date: 2025-01-15
Duration: 2 hours 34 minutes
Root cause: Database connection pool exhaustion
```

## Features

### Multi-Cloud Support

All infrastructure commands support AWS, GCP, and Azure with:
- Cloud-specific CLI commands and examples
- Provider-agnostic patterns where possible
- Platform-specific best practices
- Cost optimization per cloud provider

### Production-Ready Focus

Every command emphasizes:
- **Security-first**: RBAC, secrets management, least privilege
- **Comprehensive validation**: Pre-checks and post-checks
- **Rollback procedures**: Detailed recovery steps
- **Error handling**: Troubleshooting guidance
- **Monitoring integration**: Observability built-in

### SRE Best Practices

Commands incorporate Site Reliability Engineering principles:
- SLO-based alerting and error budget management
- Blameless postmortem templates
- Chaos engineering considerations
- Incident response frameworks
- Service reliability patterns

## Use Cases

### Deploying to Kubernetes
```
1. Validate manifests: /claudekit:k8s:manifest-validate
2. Deploy application: /claudekit:k8s:deploy
3. Troubleshoot if needed: /claudekit:k8s:troubleshoot
```

### Infrastructure Changes
```
1. Review plan: /claudekit:terraform:plan-review
2. Apply changes: /claudekit:terraform:apply
3. Optimize costs: /claudekit:terraform:cloud-cost
```

### Setting Up Monitoring
```
1. Define SLOs: /claudekit:observability:slo-define
2. Create alerts: /claudekit:observability:alert-new
```

### Incident Response
```
1. Respond to incident
2. Resolve and stabilize
3. Create postmortem: /claudekit:incident:postmortem
```

## Best Practices

### Before Using Commands

- Ensure you have appropriate cloud provider credentials configured
- Have kubectl/terraform/cloud CLIs installed and accessible
- Review command requirements section for prerequisites
- Test in non-production environments first

### Security Considerations

- Never hardcode secrets in configurations
- Use cloud provider secret management services
- Follow least privilege principles for IAM/RBAC
- Enable audit logging for all infrastructure changes

### Reliability Patterns

- Always have rollback procedures ready
- Test in staging before production
- Monitor during and after changes
- Implement gradual rollouts where possible

## Contributing

Contributions are welcome! To add new commands:

1. Fork the repository
2. Create a new command in the appropriate `commands/<category>/` directory
3. Follow the command structure pattern (see CLAUDE.md)
4. Test the command in Claude Code
5. Submit a pull request

See [CLAUDE.md](./CLAUDE.md) for detailed plugin architecture and development guidelines.

## License

MIT License - See [LICENSE](./LICENSE) file for details.

## Resources

- **Documentation**: [CLAUDE.md](./CLAUDE.md) - Plugin architecture guide
- **Reference**: [Edmund's Claude Code](https://github.com/edmund-io/edmunds-claude-code) - Inspiration and patterns
- **Claude Code Docs**: [https://code.claude.com/docs](https://code.claude.com/docs)

## Support

For issues, questions, or feature requests:
- Open an issue on GitHub
- Review existing commands for patterns and examples
- Consult CLAUDE.md for architecture details

---

**Built by ops4life for the DevOps/SRE/Platform Engineering community**