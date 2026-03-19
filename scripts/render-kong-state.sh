#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <template_dir> <env_file> <output_dir>"
  exit 1
fi

TEMPLATE_DIR="$1"
ENV_FILE="$2"
OUTPUT_DIR="$3"

test -d "$TEMPLATE_DIR" || { echo "Template directory not found: $TEMPLATE_DIR"; exit 1; }
test -f "$ENV_FILE" || { echo "Environment file not found: $ENV_FILE"; exit 1; }

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

required_vars=(
  CONTROL_PLANE_NAME
  ENV_TAG_LOWER
  INTERNAL_TLS_HOST
  PUBLIC_HOST_PRIMARY
  AML_REST_SERVICE_HOST
  BANCAWEB_SERVICE_HOST
  CLAIMHISTORY_STORM_SERVICE_HOST
  KYC_WSMANAGER_SERVICE_HOST
  GET_TOKEN_SERVICE_NAME
  GET_TOKEN_SERVICE_HOST
  ISSUER_URL
  REDIS_HOST
  REDIS_PASSWORD
  REDIS_PARTIAL_ID
  REDIS_PARTIAL_NAME
  REDIS_PARTIAL_TYPE
  REDIS_PARTIAL_HOST
  REDIS_PARTIAL_PASSWORD
  REDIS_PARTIAL_SENTINEL_MASTER
  REDIS_PARTIAL_SENTINEL_NODES
  REDIS_PARTIAL_SENTINEL_PASSWORD
  REDIS_PARTIAL_SENTINEL_ROLE
  REDIS_PARTIAL_SENTINEL_USERNAME
  REDIS_CACHE_PARTIAL_ID
  REDIS_CACHE_PARTIAL_NAME
  REDIS_CACHE_HOST
  REDIS_CACHE_PASSWORD
  REDIS_CACHE_SENTINEL_MASTER
  REDIS_CACHE_SENTINEL_NODES
  REDIS_CACHE_SENTINEL_PASSWORD
  REDIS_CACHE_SENTINEL_ROLE
  REDIS_CACHE_SENTINEL_USERNAME
  VAULT_CONFIG_STORE_ID
  STANDARD_AMLA_API_USER_CUSTOM_ID
  STANDARD_BANCA_PORTAL_USER_CUSTOM_ID
  STANDARD_CLAIM_HISTORY_USER_CUSTOM_ID
)

for var_name in "${required_vars[@]}"; do
  test -n "${!var_name:-}" || { echo "Missing required variable in $ENV_FILE: $var_name"; exit 1; }
done

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
cp -R "$TEMPLATE_DIR"/. "$OUTPUT_DIR"/

if [ "${ENV_TAG_LOWER}" = "prod" ]; then
  rm -f "$OUTPUT_DIR/partials/001-redis-partial-name.yaml"
  mv "$OUTPUT_DIR/partials/003-redis-partial-name-prod.yaml" "$OUTPUT_DIR/partials/001-redis-partial-name.yaml"
  rm -f "$OUTPUT_DIR/consumers/001-standard-amla-api-user.yaml"
  mv "$OUTPUT_DIR/consumers/001-standard-amla-api-user-prod.yaml" "$OUTPUT_DIR/consumers/001-standard-amla-api-user.yaml"
  rm -f "$OUTPUT_DIR/consumers/002-standard-banca-portal-user.yaml"
  mv "$OUTPUT_DIR/consumers/002-standard-banca-portal-user-prod.yaml" "$OUTPUT_DIR/consumers/002-standard-banca-portal-user.yaml"
  rm -f "$OUTPUT_DIR/consumers/003-standard-claim-history-user.yaml"
  mv "$OUTPUT_DIR/consumers/003-standard-claim-history-user-prod.yaml" "$OUTPUT_DIR/consumers/003-standard-claim-history-user.yaml"
else
  rm -f "$OUTPUT_DIR/partials/003-redis-partial-name-prod.yaml"
  rm -f "$OUTPUT_DIR/consumers/001-standard-amla-api-user-prod.yaml"
  rm -f "$OUTPUT_DIR/consumers/002-standard-banca-portal-user-prod.yaml"
  rm -f "$OUTPUT_DIR/consumers/003-standard-claim-history-user-prod.yaml"
fi

find "$OUTPUT_DIR" -type f \( -name "*.yaml" -o -name "*.yml" -o -name "*.md" \) -print0 | while IFS= read -r -d '' file; do
  perl -0pe '
    my $secondary = $ENV{"PUBLIC_HOST_SECONDARY"} // "";
    s/^([ \t]*)-[ \t]*"?__OPTIONAL_PUBLIC_HOST_SECONDARY_TLS__"?[ \t]*\r?\n/
      $secondary ne "" ? $1 . "- \"" . $secondary . ":443\"\n" : ""/gme;
    s/^([ \t]*)-[ \t]*"?__OPTIONAL_PUBLIC_HOST_SECONDARY__"?[ \t]*\r?\n/
      $secondary ne "" ? $1 . "- \"" . $secondary . "\"\n" : ""/gme;

    my %repl = (
      "__CONTROL_PLANE_NAME__" => $ENV{"CONTROL_PLANE_NAME"},
      "__ENV_TAG_LOWER__" => $ENV{"ENV_TAG_LOWER"},
      "__INTERNAL_TLS_HOST__" => $ENV{"INTERNAL_TLS_HOST"},
      "__PUBLIC_HOST_PRIMARY__" => $ENV{"PUBLIC_HOST_PRIMARY"},
      "__PUBLIC_HOST_PRIMARY_TLS__" => $ENV{"PUBLIC_HOST_PRIMARY"} . ":443",
      "__AML_REST_SERVICE_HOST__" => $ENV{"AML_REST_SERVICE_HOST"},
      "__BANCAWEB_SERVICE_HOST__" => $ENV{"BANCAWEB_SERVICE_HOST"},
      "__CLAIMHISTORY_STORM_SERVICE_HOST__" => $ENV{"CLAIMHISTORY_STORM_SERVICE_HOST"},
      "__KYC_WSMANAGER_SERVICE_HOST__" => $ENV{"KYC_WSMANAGER_SERVICE_HOST"},
      "__GET_TOKEN_SERVICE_NAME__" => $ENV{"GET_TOKEN_SERVICE_NAME"},
      "__GET_TOKEN_SERVICE_HOST__" => $ENV{"GET_TOKEN_SERVICE_HOST"},
      "__ISSUER_URL__" => $ENV{"ISSUER_URL"},
      "__REDIS_HOST__" => $ENV{"REDIS_HOST"},
      "__REDIS_PASSWORD__" => $ENV{"REDIS_PASSWORD"},
      "__REDIS_PARTIAL_ID__" => $ENV{"REDIS_PARTIAL_ID"},
      "__REDIS_PARTIAL_NAME__" => $ENV{"REDIS_PARTIAL_NAME"},
      "__REDIS_PARTIAL_TYPE__" => $ENV{"REDIS_PARTIAL_TYPE"},
      "__REDIS_PARTIAL_HOST__" => $ENV{"REDIS_PARTIAL_HOST"},
      "__REDIS_PARTIAL_PASSWORD__" => $ENV{"REDIS_PARTIAL_PASSWORD"},
      "__REDIS_PARTIAL_SENTINEL_MASTER__" => $ENV{"REDIS_PARTIAL_SENTINEL_MASTER"},
      "__REDIS_PARTIAL_SENTINEL_NODES__" => $ENV{"REDIS_PARTIAL_SENTINEL_NODES"},
      "__REDIS_PARTIAL_SENTINEL_PASSWORD__" => $ENV{"REDIS_PARTIAL_SENTINEL_PASSWORD"},
      "__REDIS_PARTIAL_SENTINEL_ROLE__" => $ENV{"REDIS_PARTIAL_SENTINEL_ROLE"},
      "__REDIS_PARTIAL_SENTINEL_USERNAME__" => $ENV{"REDIS_PARTIAL_SENTINEL_USERNAME"},
      "__REDIS_CACHE_PARTIAL_ID__" => $ENV{"REDIS_CACHE_PARTIAL_ID"},
      "__REDIS_CACHE_PARTIAL_NAME__" => $ENV{"REDIS_CACHE_PARTIAL_NAME"},
      "__REDIS_CACHE_HOST__" => $ENV{"REDIS_CACHE_HOST"},
      "__REDIS_CACHE_PASSWORD__" => $ENV{"REDIS_CACHE_PASSWORD"},
      "__REDIS_CACHE_SENTINEL_MASTER__" => $ENV{"REDIS_CACHE_SENTINEL_MASTER"},
      "__REDIS_CACHE_SENTINEL_NODES__" => $ENV{"REDIS_CACHE_SENTINEL_NODES"},
      "__REDIS_CACHE_SENTINEL_PASSWORD__" => $ENV{"REDIS_CACHE_SENTINEL_PASSWORD"},
      "__REDIS_CACHE_SENTINEL_ROLE__" => $ENV{"REDIS_CACHE_SENTINEL_ROLE"},
      "__REDIS_CACHE_SENTINEL_USERNAME__" => $ENV{"REDIS_CACHE_SENTINEL_USERNAME"},
      "__VAULT_CONFIG_STORE_ID__" => $ENV{"VAULT_CONFIG_STORE_ID"},
      "__STANDARD_AMLA_API_USER_CUSTOM_ID__" => $ENV{"STANDARD_AMLA_API_USER_CUSTOM_ID"},
      "__STANDARD_BANCA_PORTAL_USER_CUSTOM_ID__" => $ENV{"STANDARD_BANCA_PORTAL_USER_CUSTOM_ID"},
      "__STANDARD_CLAIM_HISTORY_USER_CUSTOM_ID__" => $ENV{"STANDARD_CLAIM_HISTORY_USER_CUSTOM_ID"},
    );
    s/(__CONTROL_PLANE_NAME__|__ENV_TAG_LOWER__|__INTERNAL_TLS_HOST__|__PUBLIC_HOST_PRIMARY__|__PUBLIC_HOST_PRIMARY_TLS__|__AML_REST_SERVICE_HOST__|__BANCAWEB_SERVICE_HOST__|__CLAIMHISTORY_STORM_SERVICE_HOST__|__KYC_WSMANAGER_SERVICE_HOST__|__GET_TOKEN_SERVICE_NAME__|__GET_TOKEN_SERVICE_HOST__|__ISSUER_URL__|__REDIS_HOST__|__REDIS_PASSWORD__|__REDIS_PARTIAL_ID__|__REDIS_PARTIAL_NAME__|__REDIS_PARTIAL_TYPE__|__REDIS_PARTIAL_HOST__|__REDIS_PARTIAL_PASSWORD__|__REDIS_PARTIAL_SENTINEL_MASTER__|__REDIS_PARTIAL_SENTINEL_NODES__|__REDIS_PARTIAL_SENTINEL_PASSWORD__|__REDIS_PARTIAL_SENTINEL_ROLE__|__REDIS_PARTIAL_SENTINEL_USERNAME__|__REDIS_CACHE_PARTIAL_ID__|__REDIS_CACHE_PARTIAL_NAME__|__REDIS_CACHE_HOST__|__REDIS_CACHE_PASSWORD__|__REDIS_CACHE_SENTINEL_MASTER__|__REDIS_CACHE_SENTINEL_NODES__|__REDIS_CACHE_SENTINEL_PASSWORD__|__REDIS_CACHE_SENTINEL_ROLE__|__REDIS_CACHE_SENTINEL_USERNAME__|__VAULT_CONFIG_STORE_ID__|__STANDARD_AMLA_API_USER_CUSTOM_ID__|__STANDARD_BANCA_PORTAL_USER_CUSTOM_ID__|__STANDARD_CLAIM_HISTORY_USER_CUSTOM_ID__)/$repl{$1}/ge;
  ' "$file" > "${file}.tmp"
  mv "${file}.tmp" "$file"
done

if grep -R -n -E '__[A-Z0-9_]+__' "$OUTPUT_DIR" >/dev/null; then
  echo "Unresolved template tokens found in rendered output:"
  grep -R -n -E '__[A-Z0-9_]+__' "$OUTPUT_DIR"
  exit 1
fi

echo "Rendered Kong state to: $OUTPUT_DIR"
