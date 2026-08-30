# k8s-ci-rbac

A shared Helm **library chart** providing per-namespace CI RBAC
(ServiceAccount + Role/RoleBinding) for server-side dry-run checks in
CI. Included as a dependency by consumer charts; generates RBAC once per
included chart, scoped to that chart's own namespace.

## Why this exists

`kubectl apply --dry-run=server` (used by
[`actions-helm`](https://github.com/mattjmorrison-homelab/actions-helm)'s
shared check, called from every `k8s-` repo's own CI) still goes through
full RBAC authorization — only the final write to etcd is skipped. So
the identity running that check needs real create/patch permissions, not
just read access. Rather than have every `k8s-` repo carry its own copy
of that RBAC (a ServiceAccount + Role/RoleBinding + a second Role
letting the shared CI runner mint tokens for it — roughly 40-50 lines,
duplicated per repo), this library chart lets each repo include a named
template that generates all of it from a simple dict. Each consumer
renders its own copy of the RBAC as part of its own single-namespace
Application, avoiding the cross-namespace resource sync issues that
plagued the old shared-Application model.

## How to consume it

### 1. Add to your chart's dependencies

In your chart's `Chart.yaml`, add this library chart as a dependency:

```yaml
dependencies:
  - name: k8s-ci-rbac
    version: "1.0.0"
    repository: "oci://registry.morrisons.site/charts"
```

Then run `helm dependency update` to fetch it.

### 2. Call the template in your own chart

Add a file `templates/ci-rbac.yaml` to your chart that includes the
named template:

```yaml
{{ include "k8s-ci-rbac.rbac" (dict "namespace" .Release.Namespace "apiGroups" (list "" "apps" "batch") "serviceAccountName" "prometheus-ci") }}
```

### 3. Parameters

The `k8s-ci-rbac.rbac` template accepts a dict with three keys:

- **`namespace`** (required): The namespace where the CI identity will
  live. Almost always `.Release.Namespace` — use the same namespace your
  chart itself deploys to.
- **`apiGroups`** (required): A list of API groups the CI identity needs
  access to. Should cover every API group your chart's own manifests
  actually use (core `""`, `apps` for Deployments, `batch` for Jobs, plus
  whatever CRDs it depends on). Within each group, this grants `get`/`list`/`create`/`patch` on `resources: ["*"]`, so new kinds in an already-listed group don't need a further change.
- **`serviceAccountName`** (optional): The name of the ServiceAccount to
  create. Defaults to `<namespace>-ci`. Pass it explicitly only when you
  need a different name — e.g., when your namespace hosts multiple CI
  identities from different owning repos (e.g. `monitoring` namespace has
  both `prometheus-ci` from `k8s-prometheus` and `alertmanager-ci` from
  `k8s-alertmanager`).

## What it generates per include

For each call to the template:

- A **ServiceAccount** named `<serviceAccountName>` (or `<namespace>-ci`
  by default)
- A **Role** + **RoleBinding** (`<serviceAccountName>-writer`) granting
  that ServiceAccount `get`/`list`/`create`/`patch` on the listed
  `apiGroups`, scoped to just that one namespace
- A **Role** + **RoleBinding** (`<serviceAccountName>-token-issuer`)
  granting `github-runner-workload` (the shared identity every repo's CI
  runs as) permission to mint a short-lived token *for* `<serviceAccountName>`
  specifically — `resourceNames` restricted to that one ServiceAccount,
  nothing else. The runner's own identity never gains direct write
  access; only the per-namespace `-ci` identity does, and only for as
  long as a freshly minted token (10 minutes) lasts. The RoleBinding is
  labeled with `ci-namespace: <namespace>` for external identification.

No token or secret is ever stored anywhere — everything here is plain,
declarative Kubernetes RBAC.

## Known limitation: cluster-scoped resources aren't covered

A namespace-scoped `Role` can never grant access to a cluster-scoped
kind like `Namespace`, regardless of how it's bound. Rather than add any
cluster-scoped RBAC grant here, `actions-helm`'s check script filters
the cluster-scoped `Namespace` object out of the dry-run entirely if a
chart renders one — that one object just isn't dry-run-validated. See
`actions-helm`'s `check.sh` for the exact mechanism.

## This repo's CI

- `check.yml` runs `helm lint` on the library chart itself, verifying
  syntax and validity.
- `publish.yml` runs on every push to `main`: packages the chart with a
  version derived from the commit SHA (e.g., `1.0.0-a1b2c3d`), logs into
  the OCI registry, and pushes the package to
  `registry.morrisons.site/charts`. Consumers pin an exact version in
  their dependency declaration, so each push is uniquely addressable.
