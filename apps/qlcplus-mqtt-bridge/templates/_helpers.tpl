{{- define "qlcplus-mqtt-bridge.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "qlcplus-mqtt-bridge.labels" -}}
{{ include "qlcplus-mqtt-bridge.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end }}
