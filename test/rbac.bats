#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/.."
}

@test "default serviceAccountName defaults to <namespace>-ci and renders writer + token-issuer RBAC" {
  run bash -c "helm dependency update test/harness && helm template test/harness"
  [ "$status" -eq 0 ]
  [[ "$output" == *"name: garage-ci"* ]]
  [[ "$output" == *"name: garage-ci-writer"* ]]
  [[ "$output" == *"name: garage-ci-token-issuer"* ]]
  [[ "$output" == *"name: github-runner-workload"* ]]
  [[ "$output" == *"namespace: github-runner"* ]]
}

@test "two owners with distinct serviceAccountName in the same namespace get separate, non-colliding RBAC" {
  run bash -c "helm dependency update test/harness && helm template test/harness"
  [ "$status" -eq 0 ]
  [[ "$output" == *"name: prometheus-ci"* ]]
  [[ "$output" == *"name: alertmanager-ci"* ]]
  [[ "$output" == *"name: prometheus-ci-writer"* ]]
  [[ "$output" == *"name: alertmanager-ci-writer"* ]]
  [[ "$output" == *"name: prometheus-ci-token-issuer"* ]]
  [[ "$output" == *"name: alertmanager-ci-token-issuer"* ]]
  # Split on helm's "---" document separator, keep only ServiceAccount
  # documents in the monitoring namespace, then count them.
  sa_count=$(echo "$output" | awk 'BEGIN{RS="---\n"} /kind: ServiceAccount/ && /namespace: monitoring/' | grep -c '^kind: ServiceAccount$')
  [ "$sa_count" -eq 2 ]
}
