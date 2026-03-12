# OnPrem Air Flight Template

This folder is a sample onboarding template for adding a new `OnPrem` API.

It is intentionally outside `kong/` so the pipeline does not validate, render, diff, or sync it.

Use this template by copying the relevant files into `kong/internal/onprem/` and then replacing the placeholders with real values.

Template filenames use a generic placeholder pattern:

- `<number-sequence>-service-name.yaml`
- `<number-sequence>-route-name.yaml`
- `<number-sequence>-plugin-name.yaml`
- `<number-sequence>-consumer-name.yaml`

Rename them to the real file names when onboarding the actual API.

Included samples:

- `services/001-service-name.yaml`
- `routes/001-route-name.yaml`
- `plugins/001-plugin-name.yaml`
- `plugins/002-plugin-name.yaml`
- `consumers/001-consumer-name.yaml`

## Recommended onboarding order

1. Create the `service` under `kong/internal/onprem/services/`.
2. Add the route inside that service file if it is service-specific.
3. Add service-level or route-level plugins inside the service file when they belong only to that API.
4. Add standalone files under `kong/internal/onprem/plugins/` only for truly global plugins.
5. Add the `consumer` or `consumer-group` if the API is accessed by a known internal client.
6. Add or update `kong/env/*-onprem.env` if the new config needs environment-specific values.
7. Validate the copied files with `deck file validate`.

## Service onboarding

Source template:

- `services/001-service-name.yaml`

Target location:

- `kong/internal/onprem/services/<number-sequence>-<service-name>.yaml`

Update these fields:

- file name to the next available sequence and the real service name
- `services[].name`
- `services[].host`
- `services[].port`
- `services[].protocol`
- timeout or retry values if the upstream requires different settings
- `services[].plugins[]` for service-level concerns such as `file-log` or `openid-connect`
- `services[].routes[]` for routes that belong only to this service

OnPrem checks:

- keep service-specific routes nested inside the service file, following the current `kong/internal/onprem/services/` pattern
- keep service-specific plugins nested on the service or route instead of creating separate plugin files
- use `__...__` placeholder tokens for environment-specific values
- avoid hardcoding environment-specific hosts, URLs, or secrets in shared config
- if the API needs consumer-specific IDs that change by environment, parameterize `custom_id` through `kong/env/*-onprem.env`

Example outcome:

- `kong/internal/onprem/services/006-air-flight-api.yaml`

## Route onboarding

Source template:

- `routes/001-route-name.yaml`

Target location:

- usually embedded under `services[].routes[]` in `kong/internal/onprem/services/<number-sequence>-<service-name>.yaml`

Use this route template as a snippet reference, not as the final file layout.

Update these fields:

- `routes[].name`
- `routes[].hosts`
- `routes[].paths`
- `routes[].methods` when needed
- route-level `plugins[]`
- `strip_path`, `preserve_host`, and protocol settings if required by the API

Route checks:

- make sure the route stays under the correct service
- use the same public host placeholder style already used by on-prem services
- keep the route name descriptive, for example `air-flight-search-route`

## Plugin onboarding

Source templates:

- `plugins/001-plugin-name.yaml`
- `plugins/002-plugin-name.yaml`

Target location:

- service-specific plugin:
  `kong/internal/onprem/services/<number-sequence>-<service-name>.yaml`
- global plugin:
  `kong/internal/onprem/plugins/<number-sequence>-<plugin-name>.yaml`

Update these fields:

- `plugins[].name`
- `plugins[].config`
- attach plugins in the right place:
  service-level under `services[].plugins[]`
  route-level under `services[].routes[].plugins[]`
  global plugins in their own file under `kong/internal/onprem/plugins/`

Plugin checks:

- `file-log` is now part of the common on-prem service pattern
- use one global-plugin file per plugin for clarity
- if the plugin contains environment-specific values, add them to `kong/env/*-onprem.env` and reference them through placeholders

## Consumer onboarding

Source template:

- `consumers/001-consumer-name.yaml`

Target location:

- `kong/internal/onprem/consumers/<number-sequence>-<consumer-name>.yaml`

Update these fields:

- file name to the next available sequence and the real consumer name
- `consumers[].username`
- `consumers[].custom_id`
- `consumers[].tags`

Consumer checks:

- use a stable username that reflects the calling application or internal client
- parameterize `custom_id` when it differs by environment
- if authentication credentials are needed, create the related credential object in the appropriate Kong config after the consumer is defined

## Environment variable onboarding

Add new variables to:

- `kong/env/dev-onprem.env`
- `kong/env/uat-onprem.env`
- `kong/env/preprod-onprem.env`
- `kong/env/prod-onprem.env`
- `kong/env/dr-onprem.env`

Use env variables for values such as:

- upstream host names
- public host names
- issuer URLs
- vault or partial references
- consumer custom IDs

If you add a new placeholder token to the shared `kong/internal/onprem` files, also update:

- the render logic used by your deployment pipeline

## Validation checklist

Before creating a PR or running deployment:

1. Confirm all copied files are under `kong/internal/onprem/`, not under `templates/`.
2. Confirm numbering does not collide with existing files.
3. Confirm all `__PLACEHOLDER__` values have been replaced in live config.
4. Confirm any new env variables exist in every required `kong/env/*-onprem.env` file.
5. Run `deck file validate kong/internal/onprem`.
