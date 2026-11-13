#!/bin/sh
set -eu

KEYCLOAK_URL=http://authentication-identity-server:8080
REALM=realm_52300070

attempt=0
until curl -fsS http://authentication-identity-server:9000/health/ready >/dev/null; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 60 ]; then
    echo "Keycloak did not become ready in time" >&2
    exit 1
  fi
  sleep 2
done

token_response=$(curl -fsS -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'grant_type=password' \
  --data-urlencode "username=$KC_BOOTSTRAP_ADMIN_USERNAME" \
  --data-urlencode "password=$KC_BOOTSTRAP_ADMIN_PASSWORD" \
  --data-urlencode 'client_id=admin-cli')
admin_token=$(printf '%s' "$token_response" | jq -er '.access_token')

provision_user() {
  username=$1
  password=$2
  users=$(curl -fsS -G "$KEYCLOAK_URL/admin/realms/$REALM/users" \
    --data-urlencode "username=$username" \
    -H "Authorization: Bearer $admin_token")
  user_id=$(printf '%s' "$users" | jq -r '.[0].id // empty')

  if [ -z "$user_id" ]; then
    user_json=$(jq -n --arg username "$username" \
      '{username: $username, enabled: true, email: ($username + "@example.com"), emailVerified: true, firstName: "Sinh vien", lastName: $username, requiredActions: []}')
    curl -fsS -o /dev/null -X POST "$KEYCLOAK_URL/admin/realms/$REALM/users" \
      -H "Authorization: Bearer $admin_token" \
      -H 'Content-Type: application/json' \
      -d "$user_json"
    users=$(curl -fsS -G "$KEYCLOAK_URL/admin/realms/$REALM/users" \
      --data-urlencode "username=$username" \
      -H "Authorization: Bearer $admin_token")
    user_id=$(printf '%s' "$users" | jq -er '.[0].id')
  else
    user_json=$(printf '%s' "$users" | jq -c \
      '.[0] | .requiredActions=[] | .email=(.username + "@example.com") | .emailVerified=true | .firstName="Sinh vien" | .lastName=.username')
    curl -fsS -o /dev/null -X PUT "$KEYCLOAK_URL/admin/realms/$REALM/users/$user_id" \
      -H "Authorization: Bearer $admin_token" \
      -H 'Content-Type: application/json' \
      -d "$user_json"
  fi

  credential=$(jq -n --arg password "$password" \
    '{type: "password", value: $password, temporary: false}')
  curl -fsS -o /dev/null -X PUT \
    "$KEYCLOAK_URL/admin/realms/$REALM/users/$user_id/reset-password" \
    -H "Authorization: Bearer $admin_token" \
    -H 'Content-Type: application/json' \
    -d "$credential"
  echo "Provisioned Keycloak user $username"
}

provision_user sv01 "$SV01_PASSWORD"
provision_user sv02 "$SV02_PASSWORD"
