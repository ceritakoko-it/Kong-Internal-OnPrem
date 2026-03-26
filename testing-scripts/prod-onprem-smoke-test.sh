#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_SECRET_FILE="${SCRIPT_DIR}/prod-onprem-secrets.local.sh"
export ONPREM_LOCAL_SECRET_FILE="${LOCAL_SECRET_FILE}"

if [ -f "${LOCAL_SECRET_FILE}" ]; then
  # shellcheck disable=SC1090
  source "${LOCAL_SECRET_FILE}"
fi

export PUBLIC_HOST_PRIMARY='kong-api.takaful-malaysia.com.my'
export AMLA_API_KEY='a3a4f228-7132-4e32-bd8b-13b2da223e6b'
export CLAIM_HISTORY_X_API_KEY='2a77d64b-fae2-41a9-ae5f-600a8ceb4537'
export AML_REST_SCAN_BODY='{"Client_Name":"TEST NAME","Client_DOB":"","Client_ID_Type":"NRIC","Client_ID_No":"XXXXXX-06-0332","Client_Gender":"","Client_Nationality":"","Source_System":"DTM","Transaction_Type":"NB","Department_Code":"FUCS","Transaction_Ref_No":"API test UAT","Transaction_Ref_No_2":"","Transaction_Date":"2026-02-02","Name01":"","Name02":"","Name03":"","Name04":"","Name05":"","Name06":"","Name07":"","Name08":"","Name09":"","Name10":"","Name11":"","Name12":"","Name13":"","Name14":"","Name15":""}'
export AML_REST_AB_SCAN_BODY='{"Client_Name":"TEST NAME","Client_DOB":"","Client_ID_Type":"NRIC","Client_ID_No":"XXXXXX-06-0332","Client_Gender":"","Client_Nationality":"","Source_System":"DTM","Transaction_Type":"NB","Department_Code":"FUCS","Transaction_Ref_No":"API test UAT","Transaction_Ref_No_2":"","Transaction_Date":"2026-02-02","Name01":"","Name02":"","Name03":"","Name04":"","Name05":"","Name06":"","Name07":"","Name08":"","Name09":"","Name10":"","Name11":"","Name12":"","Name13":"","Name14":"","Name15":""}'
export KYC_INPUT_ADD_BODY='{"messageId":"20251295511212testsq","partitionId":"0","message":"XML string payload"}'
export KYC_RISK_SCORE_QUERY='clientKey=XXXX01&zoneId=1'
export KYC_TOPIC_QUERY='topic=kyc.KycOutputAPI&clientId=ClientId1&groupId=groupId1&count=1'
export BANCA_LOGIN_BODY="${BANCA_LOGIN_BODY:-"{\"UserName\":\"smoke.test\",\"Password\":\"SmokeTest123!\"}"}"
export BANCA_AUTHENTICATE_BODY='<?xml version="1.0" encoding="UTF-8" standalone="yes"?><authentication><body><apiKey>bimbfos</apiKey><apiSecret>D03E9DAB-164A-47D9-9CC7-000008FD1FCB</apiSecret></body></authentication>'
export BANCA_LOGOUT_BODY='{"SessionID":"__BANCA_SESSION_ID__"}'
export BANCA_QUOTATION_BODY='<?xml version="1.0"?><equotation><body><pfeid>00003518</pfeid><name>KumarN</name><nationality>Malaysian</nationality><nationalityOthers/><mykad>8046038</mykad><otherid/><dob>19900113</dob><gender>Female</gender><paymentbasis>G</paymentbasis><plantype>MLTT</plantype><schemename>01</schemename><fr1>0</fr1><fr2>INCLUSIVE</fr2><fr3>20</fr3><amount>10000</amount><interim>0</interim><religion>Non Muslim</religion><race>Malay/Bumiputera</race><race_others/><email>naresh.vuyalla@takaful-malaysia.com.my</email><mobile>0122457745</mobile><address>KM 8, PENGKALAN JAJAR, KAMPUNG ALAI</address><city/><state>Melaka</state><postcode>75460</postcode><occupation>1120</occupation><occupation_others/><employer_name>INSIGHT ALLIANCE</employer_name><employer_address>10-2 MENARA LEXIS, JALAN RIA, 54200, KL</employer_address><employer_country>MY</employer_country><exactduties/><nature/><bankref>APP56289</bankref><typeofapplicant>Single Applicant</typeofapplicant><jointapplicants/><bankstaff_email>nanijasmine@gmail.com</bankstaff_email></body></equotation>'
export BANCA_CALCULATE_BODY='<?xml version="1.0" encoding="UTF-8" standalone="yes"?><calculate><body><nationality>Malaysian</nationality><dob>19730305</dob><gender>Male</gender><paymentbasis>N</paymentbasis><plantype>BLTT</plantype><schemename>01</schemename><fr1>0.00</fr1><fr2>INCLUSIVE</fr2><fr3>1</fr3><amount>1500000</amount><interim>0</interim></body></calculate>'
export CLAIM_STORM_ACCOUNT_BODY='{"userNric":"901010031111","userEmail":"user@example.com","userName":"m22","userMobile":"0111111","userDob":"03/04/2025","userNricType":"NEW"}'
export CLAIM_STORM_VELOGICA_BODY='{"nric":"971126107404","productCode":"MMD1"}'

bash "${SCRIPT_DIR}/run-onprem-smoke-test.sh" prod
