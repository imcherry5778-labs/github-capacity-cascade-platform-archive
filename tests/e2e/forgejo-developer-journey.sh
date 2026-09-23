#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

# shellcheck disable=SC1091
source "$repo_root/versions.env"

runtime_dir="$repo_root/.tmp/local"
kubeconfig_path="$runtime_dir/kubeconfig"
local_port="${LOCAL_FORGEJO_PORT:-3000}"

for command_name in kubectl curl python3 git openssl base64; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $command_name" >&2
    exit 1
  fi
done

if [[ ! -s "$kubeconfig_path" ]]; then
  echo "ERROR: local kubeconfig not found. Run 'make local-up' first." >&2
  exit 1
fi

export KUBECONFIG="$kubeconfig_path"

json_get() {
  local key="$1"
  python3 -c 'import json,sys; print(json.load(sys.stdin)[sys.argv[1]])' "$key"
}

port_forward_log="$runtime_dir/e2e-port-forward.log"
kubectl -n platform port-forward service/forgejo-http "$local_port:3000" >"$port_forward_log" 2>&1 &
port_forward_pid=$!

cleanup_port_forward() {
  kill "$port_forward_pid" >/dev/null 2>&1 || true
  wait "$port_forward_pid" >/dev/null 2>&1 || true
}
trap cleanup_port_forward EXIT

base_url="http://127.0.0.1:$local_port"
healthy=false
for _ in $(seq 1 30); do
  if curl -fsS "$base_url/api/healthz" >/dev/null; then
    healthy=true
    break
  fi
  sleep 1
done

if [[ "$healthy" != "true" ]]; then
  echo "ERROR: Forgejo did not become reachable for E2E" >&2
  cat "$port_forward_log" >&2 || true
  exit 1
fi

admin_username="$(kubectl -n platform get secret forgejo-admin -o jsonpath='{.data.username}' | base64 --decode)"
admin_password="$(kubectl -n platform get secret forgejo-admin -o jsonpath='{.data.password}' | base64 --decode)"

admin_token_name="e2e-admin-$(date -u +%H%M%S)-$$"
admin_token_response="$(curl --fail-with-body --silent --show-error \
  --user "$admin_username:$admin_password" \
  --header "Content-Type: application/json" \
  --request POST \
  --data "{\"name\":\"$admin_token_name\",\"scopes\":[\"all\"]}" \
  "$base_url/api/v1/users/$admin_username/tokens")"
admin_token="$(printf '%s' "$admin_token_response" | json_get sha1)"

developer_suffix="$(date -u +%H%M%S)-$$"
developer_username="e2e-developer-$developer_suffix"
developer_password="E2e-$(openssl rand -hex 16)-Aa1!"
developer_email="$developer_username@example.com"

developer_payload="$(printf '{"username":"%s","email":"%s","password":"%s","must_change_password":false}' \
  "$developer_username" "$developer_email" "$developer_password")"

curl --fail-with-body --silent --show-error \
  --header "Authorization: token $admin_token" \
  --header "Content-Type: application/json" \
  --request POST \
  --data "$developer_payload" \
  "$base_url/api/v1/admin/users" \
  >/dev/null

developer_token_name="developer-journey-$developer_suffix"
developer_token_response="$(curl --fail-with-body --silent --show-error \
  --user "$developer_username:$developer_password" \
  --header "Content-Type: application/json" \
  --request POST \
  --data "{\"name\":\"$developer_token_name\",\"scopes\":[\"all\"]}" \
  "$base_url/api/v1/users/$developer_username/tokens")"
developer_token="$(printf '%s' "$developer_token_response" | json_get sha1)"

repo_name="journey-$developer_suffix"
repo_response="$(curl --fail-with-body --silent --show-error \
  --header "Authorization: token $developer_token" \
  --header "Content-Type: application/json" \
  --request POST \
  --data "{\"name\":\"$repo_name\",\"private\":true,\"auto_init\":false,\"default_branch\":\"main\",\"description\":\"Developer journey E2E fixture\"}" \
  "$base_url/api/v1/user/repos")"
created_repo_name="$(printf '%s' "$repo_response" | json_get name)"
[[ "$created_repo_name" == "$repo_name" ]]

askpass_path="$runtime_dir/git-askpass.sh"
cat >"$askpass_path" <<'EOF'
#!/usr/bin/env sh
case "$1" in
  *Username*) printf '%s\n' "$FORGEJO_GIT_USERNAME" ;;
  *Password*) printf '%s\n' "$FORGEJO_GIT_TOKEN" ;;
  *) exit 1 ;;
esac
EOF
chmod 700 "$askpass_path"

export GIT_ASKPASS="$askpass_path"
export GIT_TERMINAL_PROMPT=0
export FORGEJO_GIT_USERNAME="$developer_username"
export FORGEJO_GIT_TOKEN="$developer_token"

work_dir="$runtime_dir/developer-journey"
seed_dir="$work_dir/seed"
clone_dir="$work_dir/clone"
rm -rf "$work_dir"
mkdir -p "$work_dir"

git init -b main "$seed_dir" >/dev/null
git -C "$seed_dir" config user.name "E2E Developer"
git -C "$seed_dir" config user.email "$developer_email"
printf '# Developer Journey\n' >"$seed_dir/README.md"
git -C "$seed_dir" add README.md
git -C "$seed_dir" commit -m "initial developer journey commit" >/dev/null

repo_url="$base_url/$developer_username/$repo_name.git"
git -C "$seed_dir" remote add origin "$repo_url"
git -C "$seed_dir" push -u origin main >/dev/null
echo "developer operation: git push main PASS"

curl --fail-with-body --silent --show-error \
  --header "Authorization: token $developer_token" \
  --header "Content-Type: application/json" \
  --request PATCH \
  --data '{"default_branch":"main","has_pull_requests":true,"has_issues":true}' \
  "$base_url/api/v1/repos/$developer_username/$repo_name" \
  >/dev/null

repo_state_response="$(curl --fail-with-body --silent --show-error \
  --header "Authorization: token $developer_token" \
  "$base_url/api/v1/repos/$developer_username/$repo_name")"
[[ "$(printf '%s' "$repo_state_response" | json_get default_branch)" == "main" ]]
[[ "$(printf '%s' "$repo_state_response" | json_get has_pull_requests)" == "True" ]]
[[ "$(printf '%s' "$repo_state_response" | json_get has_issues)" == "True" ]]

git clone "$repo_url" "$clone_dir" >/dev/null 2>&1
git -C "$clone_dir" fetch origin main >/dev/null 2>&1
echo "developer operation: git clone/fetch PASS"

git -C "$clone_dir" config user.name "E2E Developer"
git -C "$clone_dir" config user.email "$developer_email"
git -C "$clone_dir" checkout -b feature/e2e >/dev/null
printf 'feature change\n' >"$clone_dir/feature.txt"
git -C "$clone_dir" add feature.txt
git -C "$clone_dir" commit -m "add E2E feature" >/dev/null
git -C "$clone_dir" push -u origin feature/e2e >/dev/null
echo "developer operation: git push feature PASS"

git ls-remote --heads "$repo_url" main feature/e2e >"$runtime_dir/git-refs.txt"
grep -Fq "refs/heads/main" "$runtime_dir/git-refs.txt"
grep -Fq "refs/heads/feature/e2e" "$runtime_dir/git-refs.txt"

curl --fail-with-body --silent --show-error \
  --header "Authorization: token $developer_token" \
  "$base_url/api/v1/repos/$developer_username/$repo_name/pulls" \
  >"$runtime_dir/pulls-before.json"

pr_body_file="$runtime_dir/pr-create-response.json"
pr_status="$(curl --silent --show-error \
  --output "$pr_body_file" \
  --write-out '%{http_code}' \
  --header "Authorization: token $developer_token" \
  --header "Content-Type: application/json" \
  --request POST \
  --data "{\"title\":\"E2E pull request\",\"head\":\"$developer_username:feature/e2e\",\"base\":\"main\",\"body\":\"Developer journey pull request\"}" \
  "$base_url/api/v1/repos/$developer_username/$repo_name/pulls")"

if [[ "$pr_status" != "201" ]]; then
  echo "ERROR: PR create returned HTTP $pr_status" >&2
  cat "$pr_body_file" >&2 || true
  exit 1
fi

pr_response="$(cat "$pr_body_file")"
pr_number="$(printf '%s' "$pr_response" | json_get number)"

pr_read_response="$(curl --fail-with-body --silent --show-error \
  --header "Authorization: token $developer_token" \
  "$base_url/api/v1/repos/$developer_username/$repo_name/pulls/$pr_number")"
[[ "$(printf '%s' "$pr_read_response" | json_get title)" == "E2E pull request" ]]
echo "developer operation: PR create/read PASS"

issue_response="$(curl --fail-with-body --silent --show-error \
  --header "Authorization: token $developer_token" \
  --header "Content-Type: application/json" \
  --request POST \
  --data '{"title":"E2E issue","body":"Developer journey issue"}' \
  "$base_url/api/v1/repos/$developer_username/$repo_name/issues")"
issue_number="$(printf '%s' "$issue_response" | json_get number)"

issue_read_response="$(curl --fail-with-body --silent --show-error \
  --header "Authorization: token $developer_token" \
  "$base_url/api/v1/repos/$developer_username/$repo_name/issues/$issue_number")"
[[ "$(printf '%s' "$issue_read_response" | json_get title)" == "E2E issue" ]]
echo "developer operation: Issue create/read PASS"

echo "Forgejo developer journey E2E: PASS"
