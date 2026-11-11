# CI IAM setup

The workflow in `.github/workflows/terraform.yml` authenticates to AWS with GitHub OIDC and one IAM role per environment. This page shows the AWS-side setup it expects. Nothing here has been applied for you: replace every placeholder (`<ACCOUNT_ID>`, `<ROLE_NAME>`) with your own values.

| Environment | Repository variable | Runs on |
|---|---|---|
| dev | `AWS_ROLE_ARN_DEV` | pull request, or manual run |
| stag | `AWS_ROLE_ARN_STAG` | pull request, or manual run |
| prod | `AWS_ROLE_ARN_PROD` | push to `main`, or manual run from `main` |

The role ARN has the form `arn:aws:iam::<ACCOUNT_ID>:role/<ROLE_NAME>`. Store it as a repository **variable** (not a secret).

## 1. OIDC provider

Create once per AWS account:

- Provider URL: `https://token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`

## 2. Trust policies

One role per environment. Each trust policy pins the audience and the subject claim of the workflow run.

### dev

Trusts pull requests from this repository and the `main` branch (a manual run started from `main` presents the `main` subject).

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": [
            "repo:riyan-ahmed/terraform-aws-multi-environment:pull_request",
            "repo:riyan-ahmed/terraform-aws-multi-environment:ref:refs/heads/main"
          ]
        }
      }
    }
  ]
}
```

**Note:** the workflow runs dev on `pull_request` and on a manual run with `environment=dev`; it does not run dev on a push to `main`. A manual run from any branch other than `main` is not blocked by the workflow but is rejected by this trust policy. The `main` subject has not been tested against AWS.

### stag

Trusts pull requests from this repository and the `main` branch (a manual run started from `main` presents the `main` subject), the same as dev.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": [
            "repo:riyan-ahmed/terraform-aws-multi-environment:pull_request",
            "repo:riyan-ahmed/terraform-aws-multi-environment:ref:refs/heads/main"
          ]
        }
      }
    }
  ]
}
```

The `main` subject lets a manual run of stag from `main` assume this role. It has not been tested against AWS.

### prod

Prod must never be assumable from a pull request. Trust only the `main` branch:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:riyan-ahmed/terraform-aws-multi-environment:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

A push to `main` and a `workflow_dispatch` run started from `main` both present this same subject (`...:ref:refs/heads/main`), so one entry covers both. A manual run started from any other branch presents `...:ref:refs/heads/<branch>`, is rejected by this policy, and is also skipped by the workflow's own `if` condition. If you later add a GitHub Environment to the prod job, the subject becomes `...:environment:<name>` and this policy must change.

## 3. State access policy (one per role, own key only)

Attach each policy to its own role only. Each one is limited to that environment's state key.

Terraform's S3 backend with `use_lockfile = true` writes a lock object named `<key>.tflock` next to the state and deletes it when it releases the lock, so each role needs `s3:DeleteObject` on that one object.

### dev

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListOwnStatePrefix",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::riyan-terraform-state-2026",
      "Condition": {
        "StringLike": {
          "s3:prefix": [
            "dev",
            "dev/*"
          ]
        }
      }
    },
    {
      "Sid": "ReadWriteOwnStateAndLock",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::riyan-terraform-state-2026/dev/terraform.tfstate*"
    },
    {
      "Sid": "DeleteOwnLockOnly",
      "Effect": "Allow",
      "Action": "s3:DeleteObject",
      "Resource": "arn:aws:s3:::riyan-terraform-state-2026/dev/terraform.tfstate.tflock"
    }
  ]
}
```

### stag

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListOwnStatePrefix",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::riyan-terraform-state-2026",
      "Condition": {
        "StringLike": {
          "s3:prefix": [
            "stag",
            "stag/*"
          ]
        }
      }
    },
    {
      "Sid": "ReadWriteOwnStateAndLock",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::riyan-terraform-state-2026/stag/terraform.tfstate*"
    },
    {
      "Sid": "DeleteOwnLockOnly",
      "Effect": "Allow",
      "Action": "s3:DeleteObject",
      "Resource": "arn:aws:s3:::riyan-terraform-state-2026/stag/terraform.tfstate.tflock"
    }
  ]
}
```

### prod

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListOwnStatePrefix",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::riyan-terraform-state-2026",
      "Condition": {
        "StringLike": {
          "s3:prefix": [
            "prod",
            "prod/*"
          ]
        }
      }
    },
    {
      "Sid": "ReadWriteOwnStateAndLock",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::riyan-terraform-state-2026/prod/terraform.tfstate*"
    },
    {
      "Sid": "DeleteOwnLockOnly",
      "Effect": "Allow",
      "Action": "s3:DeleteObject",
      "Resource": "arn:aws:s3:::riyan-terraform-state-2026/prod/terraform.tfstate.tflock"
    }
  ]
}
```

Notes:

- `terraform plan` does not change the state, but it does create and delete the lock object, which is why `PutObject` and `DeleteObject` are needed. `GetObject`/`PutObject` on `<env>/terraform.tfstate*` also cover the lock object and the state file itself.
- `s3:DeleteObject` is granted on the lock object only, not on the state file.
- `s3:ListBucket` is limited to the environment's own prefix (`<env>` and `<env>/*`) with an `s3:prefix` condition. **This condition is untested.** It has not been checked against a real `terraform init`/`plan` with this backend. If init fails with `AccessDenied` on `ListObjectsV2`, the backend is listing a prefix outside these two values; widen the condition or remove it.
- The bootstrap bucket uses default S3 encryption. If you switch it to a customer-managed KMS key, each role also needs `kms:Decrypt` and `kms:GenerateDataKey` on that key.

## 4. Read-only EC2 and VPC policy (all roles)

`plan` refreshes existing resources and looks up the Ubuntu AMI with `data.aws_ami`. Both need read access only:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadEc2AndVpcForPlan",
      "Effect": "Allow",
      "Action": "ec2:Describe*",
      "Resource": "*"
    }
  ]
}
```

These roles can plan but not create anything. Applying changes is outside this workflow and would need a separate, broader role.

## 5. Moving prod to its own account

Prod currently shares a state bucket and, presumably, an account with dev and stag. Putting prod in a separate AWS account is recommended. When that happens, these policies change:

- Create the OIDC provider and the prod role in the prod account; the `<ACCOUNT_ID>` in the trust policy and in `AWS_ROLE_ARN_PROD` becomes the prod account.
- Prefer a state bucket in the prod account. If the bucket stays where it is, add a bucket policy that allows the prod role (cross-account) and keep the identity policy above.
- Update the backend `bucket` in `environments/prod/backend.tf` and the bucket ARNs in the prod state-access policy accordingly.
- The `ec2:Describe*` policy is unchanged, but must be attached in the new account.
