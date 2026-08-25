# k8s-ci-rbac

RBAC (Role-Based Access Control — Kubernetes' own permission system,
governing who/what can do which actions on which resources) for CI's
server-side dry-run checks, generated for every namespace listed in
`manifests/values.yaml`, shared by every `k8s-` repo rather than each
one carrying its own copy.

## Why this exists

`kubectl apply --dry-run=server` (used by
[`actions-helm`](https://github.com/mattjmorrison-homelab/actions-helm)'s
shared check, called from every `k8s-` repo's own CI) still goes through
full RBAC authorization — only the final write to etcd is skipped. So
the identity running that check needs real create/patch permissions, not
just read access. Rather than have every `k8s-` repo carry its own copy
of that RBAC (a ServiceAccount + Role/RoleBinding + a second Role
letting the shared CI runner mint tokens for it — roughly 40-50 lines,
duplicated per repo), this repo generates all of it from one list.
Adding CI to a new `k8s-` repo becomes a 2-line addition here, not a
copy-pasted RBAC block in that repo's own chart.

## What it generates, per entry in `ciTargets`

For each `{namespace, apiGroups}` entry in `manifests/values.yaml`:

- A **ServiceAccount** named `<namespace>-ci`
- A **Role** + **RoleBinding** (`<namespace>-ci-writer`) granting that
  ServiceAccount `get`/`list`/`create`/`patch` on the listed `apiGroups`,
  scoped to just that one namespace
- A **Role** + **RoleBinding** (`<namespace>-ci-token-issuer`) granting
  `github-runner-workload` (the shared identity every repo's CI runs
  as) permission to mint a short-lived token *for* `<namespace>-ci`
  specifically — `resourceNames` restricted to that one ServiceAccount,
  nothing else. The runner's own identity never gains direct write
  access; only the per-namespace `-ci` identity does, and only for as
  long as a freshly minted token (10 minutes) lasts.

No token or secret is ever stored anywhere — everything here is plain,
declarative Kubernetes RBAC, deployed by ArgoCD like every other `k8s-`
repo.

## Adding a new namespace

Add an entry to `manifests/values.yaml`:

```yaml
ciTargets:
  - namespace: garage
    apiGroups: ["", "apps", "batch", "external-secrets.io"]
  - namespace: hdmi-switch
    apiGroups: ["", "apps", "batch"]
```

`apiGroups` should cover every API group that repo's own chart actually
uses (core `""`, `apps` for Deployments, `batch` for Jobs, plus whatever
CRDs it depends on) — `resources: ["*"]` within those groups, so new
kinds within an already-listed group don't need a further change, but a
brand new API group does.

## Known limitation: cluster-scoped resources aren't covered

A namespace-scoped `Role` can never grant access to a cluster-scoped
kind like `Namespace`, regardless of how it's bound. Rather than add any
cluster-scoped RBAC grant here, `actions-helm`'s check script filters
the cluster-scoped `Namespace` object out of the dry-run entirely if a
chart renders one — that one object just isn't dry-run-validated. See
`actions-helm`'s `check.sh` for the exact mechanism.
