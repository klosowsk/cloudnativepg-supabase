{{/*
Expand the name of the chart.
*/}}
{{- define "supabase-ha.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "supabase-ha.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "supabase-ha.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "supabase-ha.labels" -}}
helm.sh/chart: {{ include "supabase-ha.chart" . }}
{{ include "supabase-ha.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "supabase-ha.selectorLabels" -}}
app.kubernetes.io/name: {{ include "supabase-ha.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Auto-discover PostgreSQL secret name for a given user
Format: {username}.{cluster-name}.credentials.postgresql.acid.zalan.do
*/}}
{{- define "supabase-ha.postgresSecretName" -}}
{{- $user := .user -}}
{{- $clusterName := .clusterName -}}
{{- $userWithHyphens := replace "_" "-" $user -}}
{{- printf "%s.%s.credentials.postgresql.acid.zalan.do" $userWithHyphens $clusterName }}
{{- end }}

{{/*
Get database secret reference for a service
If dbSecretRef is explicitly set, use it. Otherwise auto-discover based on user.
*/}}
{{- define "supabase-ha.dbSecretRef" -}}
{{- $service := .service -}}
{{- $dbSecretRef := .dbSecretRef -}}
{{- $user := .user -}}
{{- $clusterName := .Values.global.clusterName -}}
{{- if $dbSecretRef }}
{{- $dbSecretRef }}
{{- else if and .Values.postgresql.enabled .Values.global.autoDiscoverSecrets }}
{{- include "supabase-ha.postgresSecretName" (dict "user" $user "clusterName" $clusterName) }}
{{- else }}
{{- required (printf "dbSecretRef is required for %s when not using auto-discovery" $service) $dbSecretRef }}
{{- end }}
{{- end }}

{{/*
Get PostgreSQL host
*/}}
{{- define "supabase-ha.postgresHost" -}}
{{- if .Values.postgresql.enabled }}
{{- printf "%s-rw.%s.svc.cluster.local" .Values.global.clusterName .Release.Namespace }}
{{- else }}
{{- required "postgresql.externalHost is required when postgresql.enabled=false" .Values.postgresql.externalHost }}
{{- end }}
{{- end }}

{{/*
Get PostgreSQL port
*/}}
{{- define "supabase-ha.postgresPort" -}}
{{- if .Values.postgresql.enabled }}
5432
{{- else }}
{{- .Values.postgresql.externalPort | default 5432 }}
{{- end }}
{{- end }}

{{/*
Get PostgreSQL pooler host (if using connection pooler)
*/}}
{{- define "supabase-ha.postgresPoolerHost" -}}
{{- if and .Values.postgresql.enabled .Values.postgresql.connectionPooler.enabled }}
{{- printf "%s-pooler.%s.svc.cluster.local" .Values.global.clusterName .Release.Namespace }}
{{- else }}
{{- include "supabase-ha.postgresHost" . }}
{{- end }}
{{- end }}

{{/*
Get PostgreSQL DB fullname (service hostname without namespace/cluster suffix)
This is the short service name used by services in the same namespace
*/}}
{{- define "supabase-ha.db.fullname" -}}
{{- if .Values.postgresql.enabled }}
{{- .Values.global.clusterName }}
{{- else }}
{{- required "postgresql.externalHost is required when postgresql.enabled=false" .Values.postgresql.externalHost }}
{{- end }}
{{- end }}

{{/*
JWT secret reference
*/}}
{{- define "supabase-ha.jwtSecretRef" -}}
{{- if .Values.secret.jwt.secretRef }}
{{- .Values.secret.jwt.secretRef }}
{{- else }}
{{- include "supabase-ha.fullname" . }}-jwt
{{- end }}
{{- end }}

{{/*
Dashboard secret reference
*/}}
{{- define "supabase-ha.dashboardSecretRef" -}}
{{- if .Values.secret.dashboard.secretRef }}
{{- .Values.secret.dashboard.secretRef }}
{{- else }}
{{- include "supabase-ha.fullname" . }}-dashboard
{{- end }}
{{- end }}

{{/*
Analytics secret reference
*/}}
{{- define "supabase-ha.analyticsSecretRef" -}}
{{- if .Values.secret.analytics.secretRef }}
{{- .Values.secret.analytics.secretRef }}
{{- else }}
{{- include "supabase-ha.fullname" . }}-analytics
{{- end }}
{{- end }}

{{/*
SMTP secret reference
*/}}
{{- define "supabase-ha.smtpSecretRef" -}}
{{- if .Values.secret.smtp.secretRef }}
{{- .Values.secret.smtp.secretRef }}
{{- else }}
{{- include "supabase-ha.fullname" . }}-smtp
{{- end }}
{{- end }}

{{/*
S3 secret reference
*/}}
{{- define "supabase-ha.secret.s3" -}}
{{- if .Values.secret.s3.secretRef }}
{{- .Values.secret.s3.secretRef }}
{{- else }}
{{- include "supabase-ha.fullname" . }}-s3
{{- end }}
{{- end }}

{{/*
Check if S3 secret is configured and valid
Returns "true" if S3 credentials are provided, "false" otherwise
*/}}
{{- define "supabase-ha.secret.s3.isValid" -}}
{{- if or .Values.secret.s3.secretRef (and .Values.secret.s3.keyId .Values.secret.s3.accessKey) -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{/*
Service account name
*/}}
{{- define "supabase-ha.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "supabase-ha.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Vector service account name
*/}}
{{- define "supabase-ha.vector.serviceAccountName" -}}
{{- if .Values.vector.serviceAccount.create }}
{{- default (printf "%s-vector" (include "supabase-ha.fullname" .)) .Values.vector.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.vector.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Vector name
*/}}
{{- define "supabase-ha.vector.name" -}}
{{- printf "%s-vector" (include "supabase-ha.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Vector fullname
*/}}
{{- define "supabase-ha.vector.fullname" -}}
{{- printf "%s-vector" (include "supabase-ha.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Vector selector labels
*/}}
{{- define "supabase-ha.vector.selectorLabels" -}}
app.kubernetes.io/name: {{ include "supabase-ha.name" . }}-vector
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Vector labels
*/}}
{{- define "supabase-ha.vector.labels" -}}
helm.sh/chart: {{ include "supabase-ha.chart" . }}
{{ include "supabase-ha.vector.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: vector
{{- end }}

{{/*
Kong name
*/}}
{{- define "supabase-ha.kong.name" -}}
{{- printf "%s-kong" (include "supabase-ha.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Kong fullname
*/}}
{{- define "supabase-ha.kong.fullname" -}}
{{- printf "%s-kong" (include "supabase-ha.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Analytics name
*/}}
{{- define "supabase-ha.analytics.name" -}}
{{- printf "%s-analytics" (include "supabase-ha.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Analytics fullname
*/}}
{{- define "supabase-ha.analytics.fullname" -}}
{{- printf "%s-analytics" (include "supabase-ha.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Auth name
*/}}
{{- define "supabase-ha.auth.name" -}}
{{- printf "%s-auth" (include "supabase-ha.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Auth fullname
*/}}
{{- define "supabase-ha.auth.fullname" -}}
{{- printf "%s-auth" (include "supabase-ha.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Functions name
*/}}
{{- define "supabase-ha.functions.name" -}}
{{- printf "%s-functions" (include "supabase-ha.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Functions fullname
*/}}
{{- define "supabase-ha.functions.fullname" -}}
{{- printf "%s-functions" (include "supabase-ha.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Imgproxy name
*/}}
{{- define "supabase-ha.imgproxy.name" -}}
{{- printf "%s-imgproxy" (include "supabase-ha.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Imgproxy fullname
*/}}
{{- define "supabase-ha.imgproxy.fullname" -}}
{{- printf "%s-imgproxy" (include "supabase-ha.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Meta name
*/}}
{{- define "supabase-ha.meta.name" -}}
{{- printf "%s-meta" (include "supabase-ha.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Meta fullname
*/}}
{{- define "supabase-ha.meta.fullname" -}}
{{- printf "%s-meta" (include "supabase-ha.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Realtime name
*/}}
{{- define "supabase-ha.realtime.name" -}}
{{- printf "%s-realtime" (include "supabase-ha.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Realtime fullname
*/}}
{{- define "supabase-ha.realtime.fullname" -}}
{{- printf "%s-realtime" (include "supabase-ha.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Rest name
*/}}
{{- define "supabase-ha.rest.name" -}}
{{- printf "%s-rest" (include "supabase-ha.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Rest fullname
*/}}
{{- define "supabase-ha.rest.fullname" -}}
{{- printf "%s-rest" (include "supabase-ha.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Storage name
*/}}
{{- define "supabase-ha.storage.name" -}}
{{- printf "%s-storage" (include "supabase-ha.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Storage fullname
*/}}
{{- define "supabase-ha.storage.fullname" -}}
{{- printf "%s-storage" (include "supabase-ha.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Studio name
*/}}
{{- define "supabase-ha.studio.name" -}}
{{- printf "%s-studio" (include "supabase-ha.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Studio fullname
*/}}
{{- define "supabase-ha.studio.fullname" -}}
{{- printf "%s-studio" (include "supabase-ha.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Supavisor name
*/}}
{{- define "supabase-ha.supavisor.name" -}}
{{- printf "%s-supavisor" (include "supabase-ha.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Supavisor fullname
*/}}
{{- define "supabase-ha.supavisor.fullname" -}}
{{- printf "%s-supavisor" (include "supabase-ha.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
DB name (PostgreSQL cluster name)
*/}}
{{- define "supabase-ha.db.name" -}}
{{- .Values.global.clusterName -}}
{{- end }}

{{/*
Analytics secret name
*/}}
{{- define "supabase-ha.secret.analytics" -}}
{{- include "supabase-ha.analyticsSecretRef" . -}}
{{- end }}

{{/*
JWT secret name
*/}}
{{- define "supabase-ha.secret.jwt" -}}
{{- include "supabase-ha.jwtSecretRef" . -}}
{{- end }}

{{/*
Dashboard secret name
*/}}
{{- define "supabase-ha.secret.dashboard" -}}
{{- include "supabase-ha.dashboardSecretRef" . -}}
{{- end }}

{{/*
SMTP secret name
*/}}
{{- define "supabase-ha.secret.smtp" -}}
{{- include "supabase-ha.smtpSecretRef" . -}}
{{- end }}

{{/*
MinIO name
*/}}
{{- define "supabase-ha.minio.name" -}}
{{- printf "%s-minio" (include "supabase-ha.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
MinIO fullname
*/}}
{{- define "supabase-ha.minio.fullname" -}}
{{- printf "%s-minio" (include "supabase-ha.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Service-specific serviceAccount names
*/}}
{{- define "supabase-ha.studio.serviceAccountName" -}}
{{- if .Values.studio.serviceAccount.create }}
{{- default (printf "%s-studio" (include "supabase-ha.fullname" .)) .Values.studio.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.studio.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "supabase-ha.auth.serviceAccountName" -}}
{{- if .Values.auth.serviceAccount.create }}
{{- default (printf "%s-auth" (include "supabase-ha.fullname" .)) .Values.auth.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.auth.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "supabase-ha.rest.serviceAccountName" -}}
{{- if .Values.rest.serviceAccount.create }}
{{- default (printf "%s-rest" (include "supabase-ha.fullname" .)) .Values.rest.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.rest.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "supabase-ha.realtime.serviceAccountName" -}}
{{- if .Values.realtime.serviceAccount.create }}
{{- default (printf "%s-realtime" (include "supabase-ha.fullname" .)) .Values.realtime.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.realtime.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "supabase-ha.meta.serviceAccountName" -}}
{{- if .Values.meta.serviceAccount.create }}
{{- default (printf "%s-meta" (include "supabase-ha.fullname" .)) .Values.meta.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.meta.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "supabase-ha.storage.serviceAccountName" -}}
{{- if .Values.storage.serviceAccount.create }}
{{- default (printf "%s-storage" (include "supabase-ha.fullname" .)) .Values.storage.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.storage.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "supabase-ha.imgproxy.serviceAccountName" -}}
{{- if .Values.imgproxy.serviceAccount.create }}
{{- default (printf "%s-imgproxy" (include "supabase-ha.fullname" .)) .Values.imgproxy.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.imgproxy.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "supabase-ha.kong.serviceAccountName" -}}
{{- if .Values.kong.serviceAccount.create }}
{{- default (printf "%s-kong" (include "supabase-ha.fullname" .)) .Values.kong.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.kong.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "supabase-ha.analytics.serviceAccountName" -}}
{{- if .Values.analytics.serviceAccount.create }}
{{- default (printf "%s-analytics" (include "supabase-ha.fullname" .)) .Values.analytics.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.analytics.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "supabase-ha.functions.serviceAccountName" -}}
{{- if .Values.functions.serviceAccount.create }}
{{- default (printf "%s-functions" (include "supabase-ha.fullname" .)) .Values.functions.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.functions.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "supabase-ha.minio.serviceAccountName" -}}
{{- if .Values.minio.serviceAccount.create }}
{{- default (printf "%s-minio" (include "supabase-ha.fullname" .)) .Values.minio.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.minio.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "supabase-ha.supavisor.serviceAccountName" -}}
{{- if .Values.supavisor.serviceAccount.create }}
{{- default (printf "%s-supavisor" (include "supabase-ha.fullname" .)) .Values.supavisor.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.supavisor.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Supavisor component name
*/}}
{{- define "supabase.supavisor.name" -}}
{{- printf "%s-supavisor" (include "supabase.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Supavisor fullname
*/}}
{{- define "supabase.supavisor.fullname" -}}
{{- printf "%s-supavisor" (include "supabase.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Supavisor selector labels
*/}}
{{- define "supabase.supavisor.selectorLabels" -}}
{{ include "supabase.selectorLabels" . }}
app.kubernetes.io/component: supavisor
{{- end -}}

{{/*
Supavisor service account name
*/}}
{{- define "supabase.supavisor.serviceAccountName" -}}
{{- if .Values.supavisor.serviceAccount.create -}}
    {{ default (include "supabase.supavisor.fullname" .) .Values.supavisor.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.supavisor.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Service-specific selector labels and labels
*/}}
{{- define "supabase-ha.studio.selectorLabels" -}}
app.kubernetes.io/name: {{ include "supabase-ha.name" . }}-studio
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "supabase-ha.studio.labels" -}}
helm.sh/chart: {{ include "supabase-ha.chart" . }}
{{ include "supabase-ha.studio.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: studio
{{- end }}

{{- define "supabase-ha.auth.selectorLabels" -}}
app.kubernetes.io/name: {{ include "supabase-ha.name" . }}-auth
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "supabase-ha.auth.labels" -}}
helm.sh/chart: {{ include "supabase-ha.chart" . }}
{{ include "supabase-ha.auth.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: auth
{{- end }}

{{- define "supabase-ha.rest.selectorLabels" -}}
app.kubernetes.io/name: {{ include "supabase-ha.name" . }}-rest
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "supabase-ha.rest.labels" -}}
helm.sh/chart: {{ include "supabase-ha.chart" . }}
{{ include "supabase-ha.rest.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: rest
{{- end }}

{{- define "supabase-ha.realtime.selectorLabels" -}}
app.kubernetes.io/name: {{ include "supabase-ha.name" . }}-realtime
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "supabase-ha.realtime.labels" -}}
helm.sh/chart: {{ include "supabase-ha.chart" . }}
{{ include "supabase-ha.realtime.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: realtime
{{- end }}

{{- define "supabase-ha.meta.selectorLabels" -}}
app.kubernetes.io/name: {{ include "supabase-ha.name" . }}-meta
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "supabase-ha.meta.labels" -}}
helm.sh/chart: {{ include "supabase-ha.chart" . }}
{{ include "supabase-ha.meta.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: meta
{{- end }}

{{- define "supabase-ha.storage.selectorLabels" -}}
app.kubernetes.io/name: {{ include "supabase-ha.name" . }}-storage
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "supabase-ha.storage.labels" -}}
helm.sh/chart: {{ include "supabase-ha.chart" . }}
{{ include "supabase-ha.storage.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: storage
{{- end }}

{{- define "supabase-ha.imgproxy.selectorLabels" -}}
app.kubernetes.io/name: {{ include "supabase-ha.name" . }}-imgproxy
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "supabase-ha.imgproxy.labels" -}}
helm.sh/chart: {{ include "supabase-ha.chart" . }}
{{ include "supabase-ha.imgproxy.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: imgproxy
{{- end }}

{{- define "supabase-ha.kong.selectorLabels" -}}
app.kubernetes.io/name: {{ include "supabase-ha.name" . }}-kong
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "supabase-ha.kong.labels" -}}
helm.sh/chart: {{ include "supabase-ha.chart" . }}
{{ include "supabase-ha.kong.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: kong
{{- end }}

{{- define "supabase-ha.analytics.selectorLabels" -}}
app.kubernetes.io/name: {{ include "supabase-ha.name" . }}-analytics
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "supabase-ha.analytics.labels" -}}
helm.sh/chart: {{ include "supabase-ha.chart" . }}
{{ include "supabase-ha.analytics.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: analytics
{{- end }}

{{- define "supabase-ha.functions.selectorLabels" -}}
app.kubernetes.io/name: {{ include "supabase-ha.name" . }}-functions
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "supabase-ha.functions.labels" -}}
helm.sh/chart: {{ include "supabase-ha.chart" . }}
{{ include "supabase-ha.functions.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: functions
{{- end }}

{{- define "supabase-ha.minio.selectorLabels" -}}
app.kubernetes.io/name: {{ include "supabase-ha.name" . }}-minio
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "supabase-ha.minio.labels" -}}
helm.sh/chart: {{ include "supabase-ha.chart" . }}
{{ include "supabase-ha.minio.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: minio
{{- end }}

{{- define "supabase-ha.supavisor.selectorLabels" -}}
app.kubernetes.io/name: {{ include "supabase-ha.name" . }}-supavisor
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "supabase-ha.supavisor.labels" -}}
helm.sh/chart: {{ include "supabase-ha.chart" . }}
{{ include "supabase-ha.supavisor.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: supavisor
{{- end }}
