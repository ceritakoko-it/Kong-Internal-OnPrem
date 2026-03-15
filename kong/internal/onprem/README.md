# Kong Internal OnPrem Shared State

This folder is the shared base state for `OnPrem`.

It is rendered at pipeline runtime using:

- `kong/env/dev-onprem.env`
- `kong/env/uat-onprem.env`
- `kong/env/preprod-onprem.env`
- `kong/env/prod-onprem.env`
- `kong/env/dr-onprem.env`

## Current Work Mechanism

This folder is the only shared source of truth for `OnPrem` configuration.

Current pattern:

- `services/` contains the service definition
- `routes/` contains service-specific `routes[]`
- `services/` contains service-level `plugins[]`
- `routes/` also contains route-level `plugins[]`
- `plugins/` is reserved for global plugins only
- `consumers/` contains shared consumer definitions
- consumer `custom_id` values are parameterized through env files when they differ by environment

## Authoring Rules

1. Do not put environment-specific literals directly in this folder.
2. Use named template tokens for environment-specific values.
3. Define the real values in every required `kong/env/*-onprem.env` file.
4. Keep service-specific routes in `routes/` and service-specific plugins on the owning service or route object.
5. Add global plugins under `plugins/` only when the plugin is not tied to one service.

## Common Parameterized Values

Examples already parameterized from env files:

- control plane name
- internal and public host names
- upstream service hosts
- issuer URL
- redis host and partial names
- vault config store ID
- consumer custom IDs

Examples of values that usually remain shared:

- service names
- route names
- route paths
- common plugin structures
- `file-log` path `/usr/local/kong/logs/transaction.log`
