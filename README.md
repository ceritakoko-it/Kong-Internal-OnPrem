# Kong Konnect CI/CD Governance

This repository is the source of truth for Kong decK configuration and promotion flow across environments.

For `OnPrem`, the current mechanism is:

- shared base state lives in `kong/internal/onprem/`
- environment values live in `kong/env/system/*.env` and `kong/env/user/*-onprem.env`
- the pipeline renders the shared base with the selected env file at runtime
- the rendered output is what `deck file validate`, `deck gateway diff`, and `deck gateway sync` operate on

## OnPrem Source Of Truth

The `OnPrem` control plane is no longer maintained as separate environment folders.

Use:

- shared config: `kong/internal/onprem/`
- system env files:
  - `kong/env/system/dev-system.env`
  - `kong/env/system/uat-system.env`
  - `kong/env/system/prod-system.env`
  - `kong/env/system/dr-system.env`
- user env files:
  - `kong/env/user/dev-onprem.env`
  - `kong/env/user/uat-onprem.env`
  - `kong/env/user/prod-onprem.env`

Do not create or maintain `kong/<env>/onprem` state folders for active `OnPrem` work.

## Repository Layout

Important `OnPrem` paths:

- `kong/internal/onprem/00-meta.yaml`
- `kong/internal/onprem/certificates/`
- `kong/internal/onprem/consumer-groups/`
- `kong/internal/onprem/consumers/`
- `kong/internal/onprem/partials/`
- `kong/internal/onprem/plugins/`
- `kong/internal/onprem/routes/`
- `kong/internal/onprem/services/`
- `kong/internal/onprem/vaults/`
- `kong/env/system/`
- `kong/env/user/`

Current object ownership:

- `services/`:
  primary place for service definitions
- `routes/`:
  contains route definitions attached to services through `service.name`
- `services/`:
  contains service-level plugins only
- `plugins/`:
  only for truly global plugins
- `consumers/`:
  consumer definitions, with `custom_id` parameterized through system env files
- `partials/`:
  shared redis and cache partials referenced by plugins

## Current OnPrem Authoring Pattern

Follow these rules when making changes:

1. Put service-specific changes in the matching file under `kong/internal/onprem/services/`.
2. Keep service definitions in `kong/internal/onprem/services/` and route definitions in `kong/internal/onprem/routes/`.
3. Keep service-specific plugins nested inside the owning service or route object.
4. Use standalone files under `kong/internal/onprem/plugins/` only for global plugins.
5. Do not hardcode environment-specific values in `kong/internal/onprem/`.
6. Use `__PLACEHOLDER__` tokens and define the real values in the matching `kong/env/system/*.env` or `kong/env/user/*-onprem.env` files.

Examples of parameterized values already in use:

- public host names
- upstream host names
- issuer URLs
- redis hosts and partial names
- vault config store IDs
- consumer `custom_id` values

Examples of shared values that stay in shared config:

- service and route names
- route paths
- common plugin structures
- shared `file-log` path `/usr/local/kong/logs/transaction.log`

## Current Service Pattern

The usual `OnPrem` service file now contains:

- one `services[]` entry
- service-level plugins such as `file-log`, `openid-connect`, or other API-specific plugins

The usual `OnPrem` route file now contains:

- one or more `routes[]` entries
- the owning `service.name` reference for each route
- route-level plugins such as `request-transformer`, `proxy-cache-advanced`, `pre-function`, or `post-function`

That means adding or changing an API usually requires touching the matching service file and route file, not embedding routes inside the service object.

## Current Consumer Pattern

Consumers live under `kong/internal/onprem/consumers/`.

Current rules:

- `username` stays in shared config
- `custom_id` must be parameterized if it differs by environment
- the matching env variable must exist in every required `kong/env/system/*.env` or `kong/env/user/*-onprem.env` file

Current parameter names include:

- `STANDARD_AMLA_API_USER_CUSTOM_ID`
- `STANDARD_BANCA_PORTAL_USER_CUSTOM_ID`
- `STANDARD_CLAIM_HISTORY_USER_CUSTOM_ID`

If a value is not yet known for an environment, use a clear `CHANGE_ME_...` placeholder until the real value is available.

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
- `controlPlane`: `OnPremise`
- `rollbackBuildId`: required when `mode=rollback`
- `rollbackBackupFile`: required when `mode=rollback`

If `Commit` is filled, the pipeline explicitly pins checkout to `Build.SourceVersion` and fails if the checked-out commit does not match.

## Azure DevOps Prerequisites

Create these variables in Azure DevOps:

- `KONG_TOKEN`
  secret used by decK
- `KONG_ADDR`
  Konnect API base URL

Without these values, deployment, promotion, and rollback will fail.

## Environment Files

Each rendered environment is composed from:

- `kong/env/system/<env>-system.env`
- `kong/env/user/<env>-onprem.env`

Values currently parameterized include:

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
- `STANDARD_AMLA_API_RATE_LIMIT`
- `STANDARD_BANCA_PORTAL_RATE_LIMIT`
- `STANDARD_CLAIM_HISTORY_RATE_LIMIT`
- `STANDARD_AMLA_API_USER_CUSTOM_ID`
- `STANDARD_BANCA_PORTAL_USER_CUSTOM_ID`
- `STANDARD_CLAIM_HISTORY_USER_CUSTOM_ID`

Notes:

- `PUBLIC_HOST_PRIMARY` is required
- `PUBLIC_HOST_SECONDARY` is optional
- user-editable values such as hosts and standard rate limits belong in `kong/env/user/`
- internal values such as consumer custom IDs and Redis partial IDs belong in `kong/env/system/`

## Deployment And Promotion Flow

Shared high-level behavior:

1. Checkout repository and pin to the selected commit ID.
2. Install decK.
3. Validate required secrets.
4. Resolve control plane and env file.
5. Render `kong/internal/onprem` with the selected `kong/env/user/*-onprem.env`, which is merged with the matching `kong/env/system/*-system.env`.
6. Run `deck gateway ping`, `deck file validate`, and `diff` on the rendered output.
7. If changes exist, back up current state.
8. Publish the backup artifact.
9. Run `deck gateway sync`.

Promotion behavior:

- promotion does not copy repo folders for `OnPrem`
- it renders the same shared base using the target environment file
- then it deploys that rendered target state to the selected target control plane
- `DR` promotion does not use `kong/env/user/dr-onprem.env`
- `DR` promotion renders from `kong/env/user/prod-onprem.env` and switches Redis-backed plugin references through an override

## Rollback Flow

Rollback re-applies backup dump state from a previous run artifact to the selected target control plane.

High-level flow:

1. Validate run rules and rollback parameters.
2. Download the requested backup artifact.
3. Resolve the selected backup YAML file.
4. Verify the rollback file matches the intended target control plane.
5. Run `deck gateway ping`, `deck file validate`, and `diff`.
6. If changes exist, run `deck gateway sync` using the rollback file.

## Validation Checklist

Before creating a PR or deployment run:

1. Confirm changes were made under `kong/internal/onprem/`, `kong/env/system/`, or `kong/env/user/`.
2. Confirm no environment-specific literals were added to shared state.
3. Confirm every new `__PLACEHOLDER__` has values in all required env files.
4. Confirm service-specific routes are stored under `kong/internal/onprem/routes/` and point to the correct `service.name`.
5. Confirm any new consumer `custom_id` placeholder exists in all env files.
6. Run `deck file validate` against the rendered or target state used by the pipeline.
