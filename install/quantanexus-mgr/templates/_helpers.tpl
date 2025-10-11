{{/*
Expand the name of the chart.
*/}}
{{- define "quantanexus.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS1123 standard).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "quantanexus.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "quantanexus.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "quantanexus.labels" -}}
helm.sh/chart: {{ include "quantanexus.chart" . }}
{{ include "quantanexus.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "quantanexus.selectorLabels" -}}
app.kubernetes.io/name: {{ include "quantanexus.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "quantanexus.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "quantanexus.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end -}}

{{- define "quantanexus.domainName" -}}
{{- .Values.global.domainName | default "example.com" -}}
{{- end -}}


{{/*
获取 Redis Secret 名称
*/}}
{{- define "redis.secretName" -}}
{{- if .Values.redis.auth.existingSecret }}
    {{- .Values.redis.auth.existingSecret }}
{{- else }}
    {{- printf "%s-redis" (include "quantanexus.fullname" .) }}
{{- end }}
{{- end }}

{{/*
获取 Redis 密码（单例模式，确保一致性）
*/}}
{{- define "redis.password" -}}
{{- if .Values.redis.auth._password -}}
{{- .Values.redis.auth._password -}}
{{- else -}}
{{- $password := "" -}}
{{- if .Values.redis.auth.password -}}
{{- $password = .Values.redis.auth.password -}}
{{- else if .Values.redis.auth.existingSecret -}}
{{- $secret := (lookup "v1" "Secret" .Release.Namespace .Values.redis.auth.existingSecret) -}}
{{- if $secret -}}
{{- $password = (index $secret.data .Values.redis.auth.secretKeys.passwordKey | b64dec) -}}
{{- else -}}
{{- $password = (randAlphaNum 16) -}}
{{- end -}}
{{- else -}}
{{- $password = (randAlphaNum 16) -}}
{{- end -}}
{{- $_ := set .Values.redis.auth "_password" $password -}}
{{- $password -}}
{{- end -}}
{{- end -}}

{{/*
获取 Redis 密码（base64 编码）
*/}}
{{- define "redis.password.b64" -}}
{{- include "redis.password" . | b64enc | quote -}}
{{- end -}}