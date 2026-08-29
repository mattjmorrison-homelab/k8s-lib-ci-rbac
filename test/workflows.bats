#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/.."
}

@test "check.yml no longer references actions-helm" {
  run bash -c "grep -c 'actions-helm' .github/workflows/check.yml"
  [ "$status" -ne 0 ]
}

@test "check.yml no longer has a dry-run key" {
  run bash -c "grep -c 'dry-run:' .github/workflows/check.yml"
  [ "$status" -ne 0 ]
}

@test "check.yml runs helm lint manifests" {
  run bash -c "grep -c 'run: helm lint manifests' .github/workflows/check.yml"
  [ "$status" -eq 0 ]
}

@test "check.yml still checks out the repo" {
  run bash -c "grep -c 'actions/checkout@' .github/workflows/check.yml"
  [ "$status" -eq 0 ]
}

@test "check.yml still triggers on pull_request" {
  run bash -c "grep -c 'pull_request:' .github/workflows/check.yml"
  [ "$status" -eq 0 ]
}

@test "publish.yml exists" {
  [ -f .github/workflows/publish.yml ]
}

@test "publish.yml triggers on push to main" {
  run bash -c "grep -c 'push:' .github/workflows/publish.yml"
  [ "$status" -eq 0 ]
  run bash -c "grep -A2 'branches:' .github/workflows/publish.yml | grep -qE '\[main\]|- *main[[:space:]]*\$'"
  [ "$status" -eq 0 ]
}

@test "publish.yml packages the chart with a version derived from the commit sha" {
  run bash -c "grep -c 'helm package manifests -d dist --version' .github/workflows/publish.yml"
  [ "$status" -eq 0 ]
  run bash -c "grep -c 'github.sha' .github/workflows/publish.yml"
  [ "$status" -eq 0 ]
}

@test "publish.yml pushes the chart to the OCI registry" {
  run bash -c "grep -c 'helm push' .github/workflows/publish.yml"
  [ "$status" -eq 0 ]
  run bash -c "grep -c 'oci://registry.morrisons.site/charts' .github/workflows/publish.yml"
  [ "$status" -eq 0 ]
}

@test "publish.yml authenticates to OpenBao via the in-cluster ServiceAccount JWT, not a GitHub secret" {
  run bash -c "grep -c '/var/run/secrets/kubernetes.io/serviceaccount/token' .github/workflows/publish.yml"
  [ "$status" -eq 0 ]
  run bash -c "grep -c 'secrets\.' .github/workflows/publish.yml"
  [ "$status" -ne 0 ]
}

@test "publish.yml fetches ZOT_CI_PASSWORD from the homelab/k8s-lib-ci-rbac OpenBao path" {
  run bash -c "grep -c 'homelab/k8s-lib-ci-rbac' .github/workflows/publish.yml"
  [ "$status" -eq 0 ]
  run bash -c "grep -c 'ZOT_CI_PASSWORD' .github/workflows/publish.yml"
  [ "$status" -eq 0 ]
}

@test "publish.yml logs into the registry with helm registry login" {
  run bash -c "grep -c 'helm registry login registry.morrisons.site' .github/workflows/publish.yml"
  [ "$status" -eq 0 ]
}
