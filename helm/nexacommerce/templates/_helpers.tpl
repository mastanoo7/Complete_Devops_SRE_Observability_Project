{{/*
  NexaCommerce Helm Chart — Service & HPA Templates
*/}}

{{- define "nexacommerce.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ .name }}
  namespace: {{ .Release.Namespace }}
  labels:
    app: {{ .name }}
    release: {{ .Release.Name }}
spec:
  type: ClusterIP
  selector:
    app: {{ .name }}
  ports:
    - name: http
      port: 80
      targetPort: {{ .service.port | default 8080 }}
    - name: metrics
      port: 9090
      targetPort: 9090
{{- end }}

{{- define "nexacommerce.hpa" -}}
{{- if .service.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ .name }}
  namespace: {{ .Release.Namespace }}
  labels:
    app: {{ .name }}
    release: {{ .Release.Name }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ .name }}
  minReplicas: {{ .service.autoscaling.minReplicas | default 3 }}
  maxReplicas: {{ .service.autoscaling.maxReplicas | default 10 }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .service.autoscaling.targetCPUUtilizationPercentage | default 70 }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
        - type: Pods
          value: 2
          periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Pods
          value: 1
          periodSeconds: 120
{{- end }}
{{- end }}

{{- define "nexacommerce.pdb" -}}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ .name }}-pdb
  namespace: {{ .Release.Namespace }}
  labels:
    app: {{ .name }}
    release: {{ .Release.Name }}
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: {{ .name }}
{{- end }}

{{- define "nexacommerce.serviceaccount" -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ .name }}
  namespace: {{ .Release.Namespace }}
  labels:
    app: {{ .name }}
    release: {{ .Release.Name }}
  {{- if .service.irsaRoleArn }}
  annotations:
    eks.amazonaws.com/role-arn: {{ .service.irsaRoleArn }}
  {{- end }}
{{- end }}

{{- define "nexacommerce.servicemonitor" -}}
{{- if .Values.serviceMonitor.enabled }}
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ .name }}
  namespace: {{ .Values.serviceMonitor.namespace | default "monitoring" }}
  labels:
    app: {{ .name }}
    release: {{ .Release.Name }}
spec:
  selector:
    matchLabels:
      app: {{ .name }}
  namespaceSelector:
    matchNames:
      - {{ .Release.Namespace }}
  endpoints:
    - port: metrics
      interval: {{ .Values.serviceMonitor.interval | default "30s" }}
      scrapeTimeout: {{ .Values.serviceMonitor.scrapeTimeout | default "10s" }}
      path: /metrics
{{- end }}
{{- end }}
