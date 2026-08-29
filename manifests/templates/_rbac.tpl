{{/*
Renders per-namespace CI RBAC: a ServiceAccount, a writer Role/RoleBinding for
it, and a token-issuer Role/RoleBinding scoped to the shared
github-runner-workload identity.

Params (dict):
  namespace          - (required) namespace to create the ServiceAccount and Roles in
  apiGroups          - (required) list of apiGroups the writer Role is granted on
  serviceAccountName - (optional) defaults to "<namespace>-ci"
*/}}
{{- define "k8s-ci-rbac.rbac" -}}
{{- $namespace := .namespace -}}
{{- $apiGroups := .apiGroups -}}
{{- $serviceAccountName := .serviceAccountName | default (printf "%s-ci" $namespace) -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ $serviceAccountName }}
  namespace: {{ $namespace }}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{ $serviceAccountName }}-writer
  namespace: {{ $namespace }}
rules:
  - apiGroups: {{ $apiGroups | toYaml | nindent 6 }}
    resources: ["*"]
    verbs: ["get", "list", "create", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ $serviceAccountName }}-writer
  namespace: {{ $namespace }}
subjects:
  - kind: ServiceAccount
    name: {{ $serviceAccountName }}
    namespace: {{ $namespace }}
roleRef:
  kind: Role
  name: {{ $serviceAccountName }}-writer
  apiGroup: rbac.authorization.k8s.io
---
# Narrow, separate from the writer Role above: only lets the *shared*
# runner identity (github-runner-workload, used by every repo's CI) mint
# a short-lived token for this one namespace's CI ServiceAccount --
# nothing else. The runner identity itself never gains direct write
# access; only the per-namespace {{ $serviceAccountName }} identity does, and
# only for as long as a freshly minted token lasts.
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{ $serviceAccountName }}-token-issuer
  namespace: {{ $namespace }}
rules:
  - apiGroups: [""]
    resources: ["serviceaccounts/token"]
    verbs: ["create"]
    resourceNames: ["{{ $serviceAccountName }}"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ $serviceAccountName }}-token-issuer
  namespace: {{ $namespace }}
subjects:
  - kind: ServiceAccount
    name: github-runner-workload
    namespace: github-runner
roleRef:
  kind: Role
  name: {{ $serviceAccountName }}-token-issuer
  apiGroup: rbac.authorization.k8s.io
{{- end -}}
