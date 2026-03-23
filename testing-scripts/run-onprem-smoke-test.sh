#!/usr/bin/env bash
set -euo pipefail

ENV_NAME="${1:-}"
TIMEOUT_SECONDS=60
CONNECT_TIMEOUT_SECONDS=10

test -n "${ENV_NAME}" || { echo "Usage: $0 <dev|uat|prod>"; exit 1; }

: "${PUBLIC_HOST_PRIMARY:?Set PUBLIC_HOST_PRIMARY in the env-specific smoke test script}"
: "${AMLA_API_KEY:?Set AMLA_API_KEY in the env-specific smoke test script}"
: "${CLAIM_HISTORY_X_API_KEY:?Set CLAIM_HISTORY_X_API_KEY in the env-specific smoke test script}"

if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN="python"
else
  echo "python3 or python is required"
  exit 1
fi

BASE_URL="${TEST_BASE_URL:-https://${PUBLIC_HOST_PRIMARY}}"
TOKEN_GRANT_TYPE="${TOKEN_GRANT_TYPE:-client_credentials}"

: "${AML_REST_SCAN_BODY:?Set AML_REST_SCAN_BODY in the env-specific smoke test script}"
: "${AML_REST_AB_SCAN_BODY:?Set AML_REST_AB_SCAN_BODY in the env-specific smoke test script}"
: "${KYC_INPUT_ADD_BODY:?Set KYC_INPUT_ADD_BODY in the env-specific smoke test script}"
: "${KYC_RISK_SCORE_QUERY:?Set KYC_RISK_SCORE_QUERY in the env-specific smoke test script}"
: "${KYC_TOPIC_QUERY:?Set KYC_TOPIC_QUERY in the env-specific smoke test script}"
: "${BANCA_LOGIN_BODY:?Set BANCA_LOGIN_BODY in the env-specific smoke test script}"
: "${BANCA_AUTHENTICATE_BODY:?Set BANCA_AUTHENTICATE_BODY in the env-specific smoke test script}"
: "${BANCA_CALCULATE_BODY:?Set BANCA_CALCULATE_BODY in the env-specific smoke test script}"
: "${BANCA_QUOTATION_BODY:?Set BANCA_QUOTATION_BODY in the env-specific smoke test script}"
: "${CLAIM_STORM_ACCOUNT_BODY:?Set CLAIM_STORM_ACCOUNT_BODY in the env-specific smoke test script}"
: "${CLAIM_STORM_VELOGICA_BODY:?Set CLAIM_STORM_VELOGICA_BODY in the env-specific smoke test script}"

case "${ENV_NAME}" in
  uat)
    AMLA_CLIENT_ID="${TOKEN_AMLA_CLIENT_ID_UAT_ONPREM:-}"
    AMLA_CLIENT_SECRET="${TOKEN_AMLA_CLIENT_SECRET_UAT_ONPREM:-}"
    BANCA_CLIENT_ID="${TOKEN_BANCA_CLIENT_ID_UAT_ONPREM:-}"
    BANCA_CLIENT_SECRET="${TOKEN_BANCA_CLIENT_SECRET_UAT_ONPREM:-}"
    CLAIM_HISTORY_CLIENT_ID="${TOKEN_CLAIM_HISTORY_CLIENT_ID_UAT_ONPREM:-}"
    CLAIM_HISTORY_CLIENT_SECRET="${TOKEN_CLAIM_HISTORY_CLIENT_SECRET_UAT_ONPREM:-}"
    ;;
  prod)
    AMLA_CLIENT_ID="${TOKEN_AMLA_CLIENT_ID_PROD_ONPREM:-}"
    AMLA_CLIENT_SECRET="${TOKEN_AMLA_CLIENT_SECRET_PROD_ONPREM:-}"
    BANCA_CLIENT_ID="${TOKEN_BANCA_CLIENT_ID_PROD_ONPREM:-}"
    BANCA_CLIENT_SECRET="${TOKEN_BANCA_CLIENT_SECRET_PROD_ONPREM:-}"
    CLAIM_HISTORY_CLIENT_ID="${TOKEN_CLAIM_HISTORY_CLIENT_ID_PROD_ONPREM:-}"
    CLAIM_HISTORY_CLIENT_SECRET="${TOKEN_CLAIM_HISTORY_CLIENT_SECRET_PROD_ONPREM:-}"
    ;;
  *)
    AMLA_CLIENT_ID="${TOKEN_AMLA_CLIENT_ID_DEV_ONPREM:-}"
    AMLA_CLIENT_SECRET="${TOKEN_AMLA_CLIENT_SECRET_DEV_ONPREM:-}"
    BANCA_CLIENT_ID="${TOKEN_BANCA_CLIENT_ID_DEV_ONPREM:-}"
    BANCA_CLIENT_SECRET="${TOKEN_BANCA_CLIENT_SECRET_DEV_ONPREM:-}"
    CLAIM_HISTORY_CLIENT_ID="${TOKEN_CLAIM_HISTORY_CLIENT_ID_DEV_ONPREM:-}"
    CLAIM_HISTORY_CLIENT_SECRET="${TOKEN_CLAIM_HISTORY_CLIENT_SECRET_DEV_ONPREM:-}"
    ;;
esac

test -n "${AMLA_CLIENT_ID}" || { echo "Set TOKEN_AMLA_CLIENT_ID_*_ONPREM for ${ENV_NAME}"; exit 1; }
test -n "${AMLA_CLIENT_SECRET}" || { echo "Set TOKEN_AMLA_CLIENT_SECRET_*_ONPREM for ${ENV_NAME}"; exit 1; }
test -n "${BANCA_CLIENT_ID}" || { echo "Set TOKEN_BANCA_CLIENT_ID_*_ONPREM for ${ENV_NAME}"; exit 1; }
test -n "${BANCA_CLIENT_SECRET}" || { echo "Set TOKEN_BANCA_CLIENT_SECRET_*_ONPREM for ${ENV_NAME}"; exit 1; }
test -n "${CLAIM_HISTORY_CLIENT_ID}" || { echo "Set TOKEN_CLAIM_HISTORY_CLIENT_ID_*_ONPREM for ${ENV_NAME}"; exit 1; }
test -n "${CLAIM_HISTORY_CLIENT_SECRET}" || { echo "Set TOKEN_CLAIM_HISTORY_CLIENT_SECRET_*_ONPREM for ${ENV_NAME}"; exit 1; }

token_response_file="$(mktemp)"
api_response_file="$(mktemp)"
FAILURES=0
FAILED_TESTS=()

print_result() {
  local status="$1"
  local category="$2"
  local method="$3"
  local test_name="$4"
  local http_code="$5"
  local time_total="$6"

  printf '[%s] [%s] %s %s | HTTP %s | %ss\n' \
    "${status}" "${category}" "${method}" "${test_name}" "${http_code}" "${time_total}"
}

print_failure_detail() {
  local response_body

  if [ -s "${api_response_file}" ]; then
    response_body="$(tr '\r\n' ' ' < "${api_response_file}" | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')"
    if [ -n "${response_body}" ]; then
      printf '  detail: %s\n' "${response_body}"
    fi
  fi
}

cleanup() {
  rm -f "${token_response_file}" "${api_response_file}"
}
trap cleanup EXIT

fetch_access_token() {
  local client_id="$1"
  local client_secret="$2"
  local category="$3"
  local token_http_code
  local time_total
  local access_token

  read -r token_http_code time_total <<< "$(
    curl -sS \
      --connect-timeout "${CONNECT_TIMEOUT_SECONDS}" \
      --max-time "${TIMEOUT_SECONDS}" \
      -o "${token_response_file}" \
      -w "%{http_code} %{time_total}" \
      -X POST "${BASE_URL}/api/token" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      --data-urlencode "grant_type=${TOKEN_GRANT_TYPE}" \
      --data-urlencode "client_id=${client_id}" \
      --data-urlencode "client_secret=${client_secret}"
  )"

  if [ "${token_http_code}" != "200" ]; then
    print_result "FAIL" "${category}" "POST" "Get Access Token" "${token_http_code}" "${time_total}"
    if [ -s "${token_response_file}" ]; then
      printf '  detail: %s\n' "$(tr '\r\n' ' ' < "${token_response_file}" | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')"
    fi
    exit 1
  fi

  print_result "PASS" "${category}" "POST" "Get Access Token" "${token_http_code}" "${time_total}" >&2

  access_token="$(
    "${PYTHON_BIN}" -c 'import json, sys; data = json.load(sys.stdin); print(data.get("access_token", ""))' \
      < "${token_response_file}"
  )"
  test -n "${access_token}" || { echo "${category} token response did not contain access_token"; cat "${token_response_file}"; exit 1; }
  printf '%s' "${access_token}"
}

run_get_test() {
  local category="$1"
  local test_name="$2"
  local path="$3"
  local query_string="$4"
  local bearer_token="$5"
  local extra_header_name="${6:-}"
  local extra_header_value="${7:-}"
  local url="${BASE_URL}${path}"
  local http_code
  local time_total
  local curl_rc=0

  if [ -n "${query_string}" ]; then
    url="${url}?${query_string}"
  fi

  if [ -n "${extra_header_name}" ]; then
    set +e
    read -r http_code time_total <<< "$(
      curl -sS \
        --connect-timeout "${CONNECT_TIMEOUT_SECONDS}" \
        --max-time "${TIMEOUT_SECONDS}" \
        -o "${api_response_file}" \
        -w "%{http_code} %{time_total}" \
        -X GET "${url}" \
        -H "Authorization: Bearer ${bearer_token}" \
        -H "${extra_header_name}: ${extra_header_value}"
    )"
    curl_rc=$?
    set -e
  else
    set +e
    read -r http_code time_total <<< "$(
      curl -sS \
        --connect-timeout "${CONNECT_TIMEOUT_SECONDS}" \
        --max-time "${TIMEOUT_SECONDS}" \
        -o "${api_response_file}" \
        -w "%{http_code} %{time_total}" \
        -X GET "${url}" \
        -H "Authorization: Bearer ${bearer_token}"
    )"
    curl_rc=$?
    set -e
  fi

  if [ "${curl_rc}" -ne 0 ] || [ "${http_code}" != "200" ]; then
    if [ "${http_code}" = "000" ]; then
      http_code="CURL-${curl_rc}"
    fi
    print_result "FAIL" "${category}" "GET" "${test_name}" "${http_code}" "${time_total}"
    print_failure_detail
    FAILURES=$((FAILURES + 1))
    FAILED_TESTS+=("[${category}] ${test_name}")
    return 0
  fi
  print_result "PASS" "${category}" "GET" "${test_name}" "${http_code}" "${time_total}"
}

run_post_test() {
  local category="$1"
  local test_name="$2"
  local path="$3"
  local content_type="$4"
  local body="$5"
  local bearer_token="$6"
  local extra_header_name="${7:-}"
  local extra_header_value="${8:-}"
  local http_code
  local time_total
  local curl_rc=0

  if [ -n "${extra_header_name}" ]; then
    set +e
    read -r http_code time_total <<< "$(
      curl -sS \
        --connect-timeout "${CONNECT_TIMEOUT_SECONDS}" \
        --max-time "${TIMEOUT_SECONDS}" \
        -o "${api_response_file}" \
        -w "%{http_code} %{time_total}" \
        -X POST "${BASE_URL}${path}" \
        -H "Authorization: Bearer ${bearer_token}" \
        -H "Content-Type: ${content_type}" \
        -H "${extra_header_name}: ${extra_header_value}" \
        --data "${body}"
    )"
    curl_rc=$?
    set -e
  else
    set +e
    read -r http_code time_total <<< "$(
      curl -sS \
        --connect-timeout "${CONNECT_TIMEOUT_SECONDS}" \
        --max-time "${TIMEOUT_SECONDS}" \
        -o "${api_response_file}" \
        -w "%{http_code} %{time_total}" \
        -X POST "${BASE_URL}${path}" \
        -H "Authorization: Bearer ${bearer_token}" \
        -H "Content-Type: ${content_type}" \
        --data "${body}"
    )"
    curl_rc=$?
    set -e
  fi

  if [ "${curl_rc}" -ne 0 ] || [ "${http_code}" != "200" ]; then
    if [ "${http_code}" = "000" ]; then
      http_code="CURL-${curl_rc}"
    fi
    print_result "FAIL" "${category}" "POST" "${test_name}" "${http_code}" "${time_total}"
    print_failure_detail
    FAILURES=$((FAILURES + 1))
    FAILED_TESTS+=("[${category}] ${test_name}")
    return 0
  fi
  print_result "PASS" "${category}" "POST" "${test_name}" "${http_code}" "${time_total}"
}

AMLA_ACCESS_TOKEN="$(fetch_access_token "${AMLA_CLIENT_ID}" "${AMLA_CLIENT_SECRET}" "AMLA")"
run_post_test "AMLA" "Add KYC data" "/api/wsmanager/kycinput/add" "application/json" "${KYC_INPUT_ADD_BODY}" "${AMLA_ACCESS_TOKEN}" "apikey" "${AMLA_API_KEY}"
run_get_test "AMLA" "Get KYC Topic data" "/api/wsmanager/kycTopic/get" "${KYC_TOPIC_QUERY}" "${AMLA_ACCESS_TOKEN}" "apikey" "${AMLA_API_KEY}"
run_get_test "AMLA" "Get KYC Risk Score" "/api/wsmanager/kyc/riskscore/getLatest" "${KYC_RISK_SCORE_QUERY}" "${AMLA_ACCESS_TOKEN}" "apikey" "${AMLA_API_KEY}"
run_post_test "AMLA" "FILTERING AML Scan" "/aml/restsvc/scan" "application/json" "${AML_REST_SCAN_BODY}" "${AMLA_ACCESS_TOKEN}"
run_post_test "AMLA" "FILTERING Scan General Product" "/aml/restsvc-ab/scan" "application/json" "${AML_REST_AB_SCAN_BODY}" "${AMLA_ACCESS_TOKEN}"

BANCA_ACCESS_TOKEN="$(fetch_access_token "${BANCA_CLIENT_ID}" "${BANCA_CLIENT_SECRET}" "Banca")"
run_post_test "Banca Portal" "Banca Login" "/auth/banca/login" "application/json" "${BANCA_LOGIN_BODY}" "${BANCA_ACCESS_TOKEN}"
BANCA_LOGIN_TOKEN="$(
  "${PYTHON_BIN}" -c 'import json, sys; data = json.load(sys.stdin); print(data.get("token", ""))' \
    < "${api_response_file}"
)"
test -n "${BANCA_LOGIN_TOKEN}" || { echo "Banca login response did not contain token"; cat "${api_response_file}"; exit 1; }
BANCA_X_AUTH_TOKEN="Bearer ${BANCA_ACCESS_TOKEN}"
run_post_test "Banca Portal" "Banca Authentication" "/auth/banca/authenticate" "application/xml" "${BANCA_AUTHENTICATE_BODY}" "${BANCA_LOGIN_TOKEN}" "X-Auth-Token" "${BANCA_X_AUTH_TOKEN}"
run_post_test "Banca Portal" "Data Transfer eQuotation" "/api/banca/quotation" "application/xml" "${BANCA_QUOTATION_BODY}" "${BANCA_LOGIN_TOKEN}" "X-Auth-Token" "${BANCA_X_AUTH_TOKEN}"
run_post_test "Banca Portal" "Data Transfer Calculate" "/api/banca/calculate" "application/xml" "${BANCA_CALCULATE_BODY}" "${BANCA_LOGIN_TOKEN}" "X-Auth-Token" "${BANCA_X_AUTH_TOKEN}"

CLAIM_HISTORY_ACCESS_TOKEN="$(fetch_access_token "${CLAIM_HISTORY_CLIENT_ID}" "${CLAIM_HISTORY_CLIENT_SECRET}" "Claim History")"
run_post_test "Claim History" "Storm API Account" "/api/storm/account" "application/json" "${CLAIM_STORM_ACCOUNT_BODY}" "${CLAIM_HISTORY_ACCESS_TOKEN}" "X-API-KEY" "${CLAIM_HISTORY_X_API_KEY}"
run_post_test "Claim History" "Storm API Velogica" "/api/storm/velogica" "application/json" "${CLAIM_STORM_VELOGICA_BODY}" "${CLAIM_HISTORY_ACCESS_TOKEN}" "X-API-KEY" "${CLAIM_HISTORY_X_API_KEY}"

if [ "${FAILURES}" -gt 0 ]; then
  echo
  echo "${ENV_NAME} OnPrem smoke tests completed with ${FAILURES} failure(s):"
  for failed_test in "${FAILED_TESTS[@]}"; do
    echo "- ${failed_test}"
  done
  exit 1
fi

echo "All ${ENV_NAME} OnPrem smoke tests passed."
