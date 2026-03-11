# Kong Internal OnPrem Shared State

This folder is the shared base state for `OnPrem`.

It is rendered at pipeline runtime using:

- `kong/env/dev-onprem.env`
- `kong/env/uat-onprem.env`
- `kong/env/preprod-onprem.env`
- `kong/env/prod-onprem.env`
- `kong/env/dr-onprem.env`

Do not put environment-specific literals directly in this folder. Use template tokens and env files instead.
