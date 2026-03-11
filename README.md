# Kong Konnect CI/CD Governance

This repository is the source of truth for Kong decK configuration and promotion flow across environments.

For `OnPrem`, the source of truth is:

- shared base: `kong/internal/onprem`
- environment values: `kong/env/*.env`

## Naming Conventions

| Component | Naming Convention | Sample |
| --- | --- | --- |
| Azure Repos Repository | `<environment>-kong` | `dev-kong.conf` |
| Azure DevOps Pipeline | `<external/internal>-api-<deployment/promotion>-pipeline` | `internal-api-deployment-pipeline` |
| Kong Control Plane | `<environment>-<data-center>` | `development-azure` |
| Kong Gateway Service | `<application-name>-<env>` | `saldo-dev` |
| Kong API Route | `<application-name>-<env>-route` | `saldo-dev-route` |

## Branching Strategy

- `development` is used for deployment to Dev.
- `master` is used for deployment to Uat, promotions to PreProd/Prod/DR, and rollback to Uat/Prod.
- Feature work is done in feature branches and merged via PR.
- Hotfix work can branch from `master` and merge back to `master`.

## Pipeline Model

The pipeline is manual-only:

- `trigger: none`
- `pr: none`

Run via Azure DevOps `Run pipeline` with parameters:

- `mode`: `deployment` or `promotion` or `rollback`
- `environment`: `Dev`, `Uat`, `PreProd`, `Prod`, `DR`
- `controlPlane`: `OnCloud` or `OnPremise`
- `rollbackBuildId`: required when `mode=rollback`, points to the source pipeline `BuildId` that published backup artifact
- `rollbackBackupFile`: required when `mode=rollback`, exact backup YAML filename inside the published artifact

Azure DevOps also exposes:

- `Branch/tag`
- `Commit`

If `Commit` is filled, the pipeline explicitly pins checkout to `Build.SourceVersion` and fails if the checked-out commit does not match.

## Azure DevOps Prerequisites

Before running any pipeline, create these variables in Azure DevOps:

- `KONG_TOKEN`
  - secret
  - Konnect access token used by decK
- `KONG_ADDR`
  - plain text
  - Konnect API base URL
  - masked example: `https://<region>.api.konghq.com`

Recommended:

- store them in a variable group
- link that variable group to this pipeline

Without these values, deployment, promotion, and rollback will fail in the `Validate required variables` step.

## Shared OnPrem Layout

Shared `OnPrem` state now lives in:

- `kong/internal/onprem`

Environment files live in:

- `kong/env/dev-onprem.env`
- `kong/env/uat-onprem.env`
- `kong/env/preprod-onprem.env`
- `kong/env/prod-onprem.env`
- `kong/env/dr-onprem.env`

Legacy per-environment source folders such as `kong/dev/onprem` are no longer the source of truth.

## Environment Setup

Each environment must have a matching env file under `kong/env/`.

The env files currently parameterize:

- `CONTROL_PLANE_NAME`
- `ENV_TAG_LOWER`
- `INTERNAL_TLS_HOST`
- `PUBLIC_HOST_PRIMARY`
- `PUBLIC_HOST_SECONDARY`
- `AML_REST_SERVICE_HOST`
- `BANCAWEB_SERVICE_HOST`
- `CLAIMHISTORY_STORM_SERVICE_HOST`
- `KYC_WSMANAGER_SERVICE_HOST`
- `GET_TOKEN_SERVICE_NAME`
- `GET_TOKEN_SERVICE_HOST`
- `ISSUER_URL`
- `REDIS_HOST`
- `REDIS_PASSWORD`
- `REDIS_PARTIAL_NAME`
- `REDIS_CACHE_PARTIAL_NAME`
- `VAULT_CONFIG_STORE_ID`

Values that must be reviewed per environment before first deployment:

- control plane name and casing
- all public and internal hostnames
- all upstream service hosts
- issuer URL and get-token host/name
- redis host and password
- redis partial names if they differ by environment
- vault `config_store_id`

## First-Time Environment Setup

Before first deployment to a new environment, make sure these dependencies already exist in Konnect for that target control plane:

1. Identity issuer / identity domain
- update both:
  - `ISSUER_URL`
  - `GET_TOKEN_SERVICE_HOST`
- masked example:
  - `https://<env-identity-domain>.sg.identity.konghq.com/auth`

2. Vault `konnect` with prefix `identity`
- create the vault in the target control plane if it does not exist yet
- after creating it, get the JSON and copy:
  - `config.config_store_id`
- put that value into:
  - `VAULT_CONFIG_STORE_ID`

Important:

- do not use the top-level vault `id`
- use only `config.config_store_id`

3. Route and certificate hostnames
- set:
  - `INTERNAL_TLS_HOST`
  - `PUBLIC_HOST_PRIMARY`
  - `PUBLIC_HOST_SECONDARY`
- `PUBLIC_HOST_SECONDARY` may be left blank

4. Upstream and cache dependencies
- set the real values for:
  - `AML_REST_SERVICE_HOST`
  - `BANCAWEB_SERVICE_HOST`
  - `CLAIMHISTORY_STORM_SERVICE_HOST`
  - `KYC_WSMANAGER_SERVICE_HOST`
  - `REDIS_HOST`
  - `REDIS_PASSWORD`
  - `REDIS_PARTIAL_NAME`
  - `REDIS_CACHE_PARTIAL_NAME`

## Parameter Checklist By Environment

`Dev-OnPremise`
- `CONTROL_PLANE_NAME=Dev-OnPremise`
- fill all host values with the real Dev endpoints
- `VAULT_CONFIG_STORE_ID` must match the Dev config store

`Uat-OnPremise`
- `CONTROL_PLANE_NAME=Uat-OnPremise`
- replace the placeholder hosts in `kong/env/uat-onprem.env`
- replace the placeholder redis password and config store ID before first run

`PreProd-OnPremise`
- `CONTROL_PLANE_NAME=PreProd-OnPremise`
- replace the placeholder hosts in `kong/env/preprod-onprem.env`
- replace the placeholder redis password and config store ID before first run

`Prod-OnPremise`
- `CONTROL_PLANE_NAME=Prod-OnPremise`
- replace the placeholder hosts in `kong/env/prod-onprem.env`
- replace the placeholder redis password and config store ID before first run

`DR-OnPremise`
- `CONTROL_PLANE_NAME=DR-OnPremise`
- replace the placeholder hosts in `kong/env/dr-onprem.env`
- replace the placeholder redis password and config store ID before first run

## Governance Rules (Enforced)

The stage `Validate_Run_Rules` blocks invalid combinations and fails the run.

Allowed combinations:

1. Deployment to Dev
- `mode=deployment`
- `environment=Dev`
- branch `refs/heads/development`

2. Deployment to Uat
- `mode=deployment`
- `environment=Uat`
- branch `refs/heads/master`

3. Promotion Uat -> PreProd
- `mode=promotion`
- `environment=PreProd`
- branch `refs/heads/master`

4. Promotion PreProd -> Prod
- `mode=promotion`
- `environment=Prod`
- branch `refs/heads/master`

5. Promotion Prod -> DR
- `mode=promotion`
- `environment=DR`
- branch `refs/heads/master`

6. Rollback to Dev
- `mode=rollback`
- `environment=Dev`
- branch `refs/heads/development`

7. Rollback to Uat
- `mode=rollback`
- `environment=Uat`
- branch `refs/heads/master`

8. Rollback to Prod
- `mode=rollback`
- `environment=Prod`
- branch `refs/heads/master`

Any other combination fails in the guard stage.

## Deployment and Promotion Flow

Shared high-level behavior:

1. Checkout repository and pin to the selected commit ID.
2. Install decK.
3. Validate required secrets (`KONG_TOKEN`, `KONG_ADDR`).
4. Resolve control plane and desired state path.
5. Render shared `OnPrem` state when applicable.
6. Ping gateway, validate config locally, run diff.
7. If any diff summary count is non-zero (`Created`, `Updated`, `Deleted`), treat as changes.
8. Backup current state.
9. Publish backup as pipeline artifact.
10. Run `deck gateway sync`.

OnPrem repository behavior:

1. `kong/internal/onprem` is the shared base template.
2. The selected target environment loads the matching env file from `kong/env/`.
3. The pipeline renders the shared base into a temporary folder and deploys that rendered output.
4. Promotion for shared `OnPrem` no longer copies repo folders. It renders `kong/internal/onprem` using the target environment file and deploys directly to the target control plane.
5. Legacy folder-copy promotion remains only as fallback for control planes without a shared base template.

Rendering notes:

- `PUBLIC_HOST_PRIMARY` is required.
- `PUBLIC_HOST_SECONDARY` is optional.
- if `PUBLIC_HOST_SECONDARY` is blank, the renderer removes the second `hosts` item so the output YAML stays valid.

## Backup Mechanism

Backups are created only when changes are detected.

Backup location on agent:

- `$(Build.ArtifactStagingDirectory)/kong-backup`

Backup file:

1. Current state dump:
- `<control-plane>-current-before-sync-<timestamp>.yaml`

Published artifact name:

- `kong-backup-<environment>-<controlPlane>-<BuildId>`

Note: backup files are not committed to this repo; they are available in Azure DevOps run artifacts.

## Rollback Flow

Rollback re-applies backup dump state from a previous run artifact to the selected target control plane.

1. Validate run rules and ensure `rollbackBuildId` and `rollbackBackupFile` are provided.
2. Download artifact named `kong-backup-<environment>-<controlPlane>-<rollbackBuildId>`.
3. Resolve rollback source file using the exact `rollbackBackupFile` parameter value.
4. Validate rollback alignment:
- artifact directory must match the selected `environment`, `controlPlane`, and `rollbackBuildId`
- rollback YAML `control_plane_name` must exactly match the selected target control plane
5. Run `deck gateway ping`, `deck file validate`, and `diff`.
6. If diff shows changes, execute `deck gateway sync` using the resolved rollback dump file.

## Validation

CI validates the rendered output with `deck file validate` by rendering each committed `kong/env/*-onprem.env` file against `kong/internal/onprem`.
