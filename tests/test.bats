#!/usr/bin/env bats

# Bats is a testing framework for Bash
# Documentation https://bats-core.readthedocs.io/en/stable/
# Bats libraries documentation https://github.com/ztombol/bats-docs

# For local tests, install bats-core, bats-assert, bats-file, bats-support
# And run this in the add-on root directory:
#   bats ./tests/test.bats
# To exclude release tests:
#   bats ./tests/test.bats --filter-tags '!release'
# For debugging:
#   bats ./tests/test.bats --show-output-of-passing-tests --verbose-run --print-output-on-failure

setup() {
  set -eu -o pipefail

  export GITHUB_REPO=penyaskito/ddev-authentik

  TEST_BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
  export BATS_LIB_PATH="${BATS_LIB_PATH}:${TEST_BREW_PREFIX}/lib:/usr/lib/bats"
  bats_load_library bats-assert
  bats_load_library bats-file
  bats_load_library bats-support

  export DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." >/dev/null 2>&1 && pwd)"
  export PROJNAME="test-$(basename "${GITHUB_REPO}")"
  mkdir -p "${HOME}/tmp"
  export TESTDIR="$(mktemp -d "${HOME}/tmp/${PROJNAME}.XXXXXX")"
  export DDEV_NONINTERACTIVE=true
  export DDEV_NO_INSTRUMENTATION=true
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1 || true
  cd "${TESTDIR}"
  run ddev config --project-name="${PROJNAME}" --project-tld=ddev.site
  assert_success
  run ddev start -y
  assert_success
}

# Wait for an HTTP endpoint to return a success status, so the checks below
# don't race Authentik's startup. Authentik runs migrations on boot, which on a
# cold database takes a while.
#
# Deliberately accepts any 2xx rather than one exact code: the health views
# return 204 in 2024.x and 200 in 2026.x, while an unready instance returns 503
# in both. That 2xx-vs-5xx split is the distinction worth asserting on.
wait_for_http() {
  local url="$1" attempts="${2:-60}" i status
  for ((i = 1; i <= attempts; i++)); do
    status="$(ddev exec "curl -s -o /dev/null -w '%{http_code}' ${url}" 2>/dev/null | tr -d '\r')"
    case "${status}" in
      2*) return 0 ;;
    esac
    sleep 5
  done
  echo "# timed out waiting for ${url} (last status: ${status:-none})" >&3
  return 1
}

# Same, but from the host through the DDEV router. Kept separate because the
# router needs its own grace period: once Authentik is healthy in-network,
# Traefik still has to pick up the backend, and it answers 502 until it does.
wait_for_router() {
  local url="$1" attempts="${2:-60}" i status
  for ((i = 1; i <= attempts; i++)); do
    status="$(curl -s -o /dev/null -w '%{http_code}' "${url}" 2>/dev/null || true)"
    case "${status}" in
      2*) return 0 ;;
    esac
    sleep 5
  done
  echo "# timed out waiting for ${url} via the router (last status: ${status:-none})" >&3
  return 1
}

health_checks() {
  # Liveness: the server process is up and serving.
  run wait_for_http "authentik:9000/-/health/live/"
  assert_success

  # Readiness: Authentik can reach PostgreSQL. This is the check that actually
  # catches a broken database or a migration that failed on boot -- the server
  # answers /-/health/live/ long before it is usable, and returns 503 here
  # until it is.
  run wait_for_http "authentik:9000/-/health/ready/"
  assert_success

  # The worker is a separate container that runs migrations and background
  # tasks, and it can die without the server noticing.
  run docker inspect --format '{{.State.Running}}' "ddev-${PROJNAME}-authentik-worker"
  assert_success
  assert_output "true"

  # End-to-end through the DDEV router, which is how a developer actually
  # reaches Authentik. This exercises HTTPS_EXPOSE, which the in-network
  # checks above bypass entirely.
  run wait_for_router "https://${PROJNAME}.ddev.site:9443/-/health/live/"
  assert_success

  # An anonymous request to the root is redirected into the default
  # authentication flow, which shows the default blueprints were applied.
  run curl -s -o /dev/null -w '%{redirect_url}' "https://${PROJNAME}.ddev.site:9443/"
  assert_success
  assert_output --partial "/flows/-/default/authentication/"
}

teardown() {
  set -eu -o pipefail
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1
  # Persist TESTDIR if running inside GitHub Actions. Useful for uploading test result artifacts
  # See example at https://github.com/ddev/github-action-add-on-test#preserving-artifacts
  if [ -n "${GITHUB_ENV:-}" ]; then
    [ -e "${GITHUB_ENV:-}" ] && echo "TESTDIR=${HOME}/tmp/${PROJNAME}" >> "${GITHUB_ENV}"
  else
    [ "${TESTDIR}" != "" ] && rm -rf "${TESTDIR}"
  fi
}

@test "install from directory" {
  set -eu -o pipefail
  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success
  health_checks
}

@test "install with configured image tags" {
  set -eu -o pipefail

  # Deliberately not the shipped defaults, and both real, pullable tags: this
  # test boots the stack on them. The Authentik one is the last release of the
  # minor before the default, which is the realistic thing a user pins.
  local alt_authentik_tag="2026.5.7"
  local alt_postgres_tag="15-alpine"

  echo "# ddev add-on get ${DIR} with authentik=${alt_authentik_tag} postgres=${alt_postgres_tag}" >&3
  run ddev add-on get "${DIR}"
  assert_success

  run ddev dotenv set .ddev/.env.authentik \
    --authentik-tag="${alt_authentik_tag}" \
    --authentik-postgres-tag="${alt_postgres_tag}"
  assert_success

  run ddev restart -y
  assert_success

  # Assert against the running containers rather than the rendered compose
  # config: this catches both an override that never reaches a service -- a
  # mistyped variable, or a .env.authentik DDEV doesn't load, either of which
  # silently leaves the default in place -- and one that reaches the compose
  # file but not the container.
  #
  # The server and the worker are checked separately because an override that
  # reaches only one of them leaves two Authentik versions sharing a single
  # database, and the failure should name which one drifted.
  run docker inspect --format '{{.Config.Image}}' "ddev-${PROJNAME}-authentik"
  assert_success
  assert_output "ghcr.io/goauthentik/server:${alt_authentik_tag}"

  run docker inspect --format '{{.Config.Image}}' "ddev-${PROJNAME}-authentik-worker"
  assert_success
  assert_output "ghcr.io/goauthentik/server:${alt_authentik_tag}"

  run docker inspect --format '{{.Config.Image}}' "ddev-${PROJNAME}-authentik-pgsql"
  assert_success
  assert_output "docker.io/library/postgres:${alt_postgres_tag}"

  # Pinning a tag is only useful if the stack actually comes up on it. The
  # readiness check in particular only passes once Authentik has connected to
  # the overridden PostgreSQL and run its migrations there.
  health_checks
}

# bats test_tags=release
@test "install from release" {
  set -eu -o pipefail
  echo "# ddev add-on get ${GITHUB_REPO} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${GITHUB_REPO}"
  assert_success
  run ddev restart -y
  assert_success
  health_checks
}
