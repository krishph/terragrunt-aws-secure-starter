# Zero-Credential AWS Deployments with Terraform, Terragrunt & GitHub Actions

Deploy a serverless URL shortener on AWS using Terraform modules, Terragrunt multi-environment configs, and a GitHub Actions pipeline that authenticates via OIDC — no static AWS credentials stored anywhere.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      AWS Account                        │
│                                                         │
│   POST /shorten        GET /{code}                      │
│        │                    │                           │
│        ▼                    ▼                           │
│  ┌─────────────────────────────────┐                   │
│  │         API Gateway (REST)      │                   │
│  └──────────────┬──────────────────┘                   │
│                 │                                       │
│                 ▼                                       │
│  ┌──────────────────────────────┐                      │
│  │      Lambda (Python 3.12)    │                      │
│  │   - creates short codes      │                      │
│  │   - resolves & redirects     │                      │
│  └──────────┬───────────────────┘                      │
│             │   reads/writes                            │
│             ▼                                           │
│  ┌─────────────────┐   ┌──────────────────────────┐   │
│  │    S3 Bucket    │   │          VPC              │   │
│  │  (URL store)    │   │  private + public subnets │   │
│  └─────────────────┘   └──────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## Repository Structure

```
├── bootstrap/                        # Run ONCE locally to set up AWS prerequisites
│   ├── main.tf                       # GitHub OIDC provider, IAM role, S3 state bucket, DynamoDB lock
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars              # Pre-filled — update account-specific values before running
│
├── terraform/modules/                # Reusable Terraform modules
│   ├── vpc/                          # VPC, public/private subnets, IGW, NAT GW, Lambda SG
│   ├── s3/                           # App S3 bucket (versioned, encrypted, private)
│   ├── lambda/                       # Lambda function, IAM role, CloudWatch log group
│   └── apigw/                        # API Gateway REST API wired to Lambda
│
├── terragrunt/                       # Terragrunt wrappers (DRY environment configs)
│   ├── terragrunt.hcl                # Root: remote state (S3 + DynamoDB) + provider generation
│   ├── account.hcl                   # ⚠️  Update with your AWS account ID and region
│   └── environments/
│       ├── dev/  (vpc → s3 → lambda → apigw)
│       └── prod/ (same, separate CIDRs + longer log retention)
│
├── lambda/
│   └── index.py                      # URL shortener handler (POST /shorten, GET /{code})
│
└── .github/workflows/
    ├── plan.yml                      # Manual: security scan + plan + cost estimate (environment dropdown)
    ├── apply.yml                     # Manual: deploy to selected environment (environment dropdown)
    ├── destroy.yml                   # Manual only — requires typing DESTROY to confirm
    └── drift-detection.yml           # Manual: plan against live infra, opens GitHub issue if drift found
```

## Prerequisites

### Local machine

| Tool | Minimum version | Install |
|------|----------------|---------|
| Terraform | 1.7.0 | [terraform.io/downloads](https://www.terraform.io/downloads) |
| Terragrunt | 0.55.0 | [terragrunt.gruntwork.io](https://terragrunt.gruntwork.io/docs/getting-started/install/) |
| AWS CLI | 2.0 | [aws.amazon.com/cli](https://aws.amazon.com/cli/) |
| Python | 3.12 | [python.org](https://www.python.org/downloads/) |
| zip | any | pre-installed on macOS/Linux |

### AWS credentials (local — bootstrap only)

The bootstrap step runs once from your local machine and needs an IAM user or role with broad permissions (AdministratorAccess is simplest for the one-time setup). After bootstrap, GitHub Actions takes over using the OIDC role — your personal credentials are never used again.

```bash
aws configure
# AWS Access Key ID:     <your key>
# AWS Secret Access Key: <your secret>
# Default region:        us-east-1
# Default output format: json

# Verify it works
aws sts get-caller-identity
```

### GitHub Secrets (set these in your repo Settings → Secrets → Actions)

| Secret | Where to get it | When needed |
|--------|----------------|-------------|
| `AWS_ROLE_ARN` | Output of the bootstrap step | All pipelines |
| `INFRACOST_API_KEY` | Free at [infracost.io/docs/](https://www.infracost.io/docs/) — run `infracost auth login` | Plan pipeline cost estimate job |

---

## Step 1 — Bootstrap (run once, locally)

This creates the GitHub OIDC provider in AWS, the IAM role GitHub Actions will assume, the S3 bucket for Terraform remote state, and the DynamoDB table for state locking.

### 1a. Update values for your account

Open [bootstrap/terraform.tfvars](bootstrap/terraform.tfvars) and set:

```hcl
aws_region             = "us-east-1"          # change if needed
github_org             = "krishph"            # your GitHub username or org
github_repo            = "terragrunt-aws-secure-starter"
role_name              = "terragrunt-aws-secure-starter"
terraform_state_bucket = "terraform-state-bucket"  # must be globally unique
terraform_lock_table   = "terraform-state-lock"
```

Open [terragrunt/account.hcl](terragrunt/account.hcl) and set your real AWS account ID:

```hcl
locals {
  aws_region = "us-east-1"
  account_id = "<AWS-ACCOUNT#>"   # ⚠️  replace with your 12-digit AWS account ID
}
```

### 1b. Run bootstrap

```bash
cd bootstrap
terraform init
terraform apply
```

The output will print the IAM role ARN:

```
Outputs:
github_actions_role_arn = "arn:aws:iam::123456789012:role/github-actions-deploy-role"
```

### 1c. Add the role ARN to GitHub Secrets

Go to your repo → **Settings → Secrets and variables → Actions → New repository secret**:

- Name: `AWS_ROLE_ARN`
- Value: the ARN from the output above

---

## Step 2 — Add Infracost API key (optional but recommended)

```bash
# Install infracost CLI
brew install infracost        # macOS
# or: https://www.infracost.io/docs/

infracost auth login          # opens browser, creates free account, prints your API key
```

Add to GitHub Secrets:
- Name: `INFRACOST_API_KEY`
- Value: the key printed by `infracost auth login`

---

## Step 3 — Push and let the pipelines run

```bash
git add .
git commit -m "initial infrastructure setup"
git push origin main
```

### Plan (plan.yml)

Go to **Actions → Plan → Run workflow**, choose `dev` or `prod` from the dropdown. Three jobs run:

1. **Security scan** — Checkov scans `terraform/modules/` for misconfigurations and blocks the run if any fail.
2. **Plan** — `terragrunt run-all plan` runs against the selected environment. Output is written to the workflow job summary.
3. **Cost estimate** — Infracost posts a monthly cost breakdown to the job summary (and as a PR comment when triggered from a pull request).

### Apply (apply.yml)

Go to **Actions → Apply → Run workflow**, choose `dev` or `prod`.

`terragrunt run-all apply` runs in dependency order: VPC → S3 → Lambda → API Gateway.

### Drift detection (drift-detection.yml)

Go to **Actions → Drift Detection → Run workflow** to run on demand against both `dev` and `prod` in parallel.

- Compares live AWS resources against the Terraform state file
- If anything has been changed outside Terraform (console, CLI, another tool), a GitHub issue is opened with the full plan diff
- If an issue is already open, a comment is added instead of creating a duplicate

**To enable scheduled drift detection**, uncomment the `schedule` block in [.github/workflows/drift-detection.yml](.github/workflows/drift-detection.yml):

```yaml
schedule:
  - cron: "0 6 * * *"   # daily at 06:00 UTC
```

> **Note:** When using a schedule, `AWS_ROLE_ARN` must be set as a **repository-level secret** (not environment-scoped). Scheduled workflows in GitHub Actions do not have access to environment secrets.

### Destroy (destroy.yml)

Manual only. Go to **Actions → Destroy → Run workflow**, choose the environment, and type `DESTROY` to confirm.

---

## Testing the deployed URL shortener

Once deployed, grab the API Gateway invoke URL from the Terragrunt output:

```bash
cd terragrunt/environments/dev/apigw
terragrunt output invoke_url
```

```bash
# Shorten a URL
curl -X POST https://<invoke-url>/dev/shorten \
  -H "Content-Type: application/json" \
  -d '{"url": "https://devto.com/articles/terraform-terragrunt"}'

# Response
{"code": "aB3xYz", "short_url": "https://<invoke-url>/dev/aB3xYz"}

# Resolve it (follow the redirect)
curl -L https://<invoke-url>/dev/aB3xYz
```

---

## Troubleshooting

**`Error: acquiring the state lock`** — another run is holding the lock, or a previous run crashed. Force-unlock it:
```bash
cd terragrunt/environments/dev/vpc
terraform force-unlock <LOCK_ID>
```

**`Access Denied` on plan/apply** — verify the OIDC role ARN in the secret matches exactly what bootstrap created:
```bash
aws sts get-caller-identity   # run locally with your credentials
```

**Infracost job skipped** — the `INFRACOST_API_KEY` secret is missing. The plan and security scan jobs still run; only the cost estimate is skipped.

**Checkov false positive** — add the check ID to [.checkov.yaml](.checkov.yaml) under `skip-check` with a comment explaining why.

---

## Resources

- [Terraform docs](https://www.terraform.io/docs)
- [Terragrunt docs](https://terragrunt.gruntwork.io/docs)
- [GitHub OIDC with AWS](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [Infracost docs](https://www.infracost.io/docs/)
- [Checkov docs](https://www.checkov.io/1.Welcome/What%20is%20Checkov.html)
