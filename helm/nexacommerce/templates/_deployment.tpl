{{/*
  NexaCommerce Helm Chart — Deployment Template
  Reusable deployment template for all microservices
*/}}

{{- define "nexacommerce.deployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .name }}
  namespace: {{ .Release.Namespace }}
  labels:
    app: {{ .name }}
    version: {{ .Values.global.imageTag | quote }}
    chart: {{ .Chart.Name }}-{{ .Chart.Version }}
    release: {{ .Release.Name }}
    managed-by: helm
spec:
  replicas: {{ .service.replicaCount | default 3 }}
  selector:
    matchLabels:
      app: {{ .name }}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: {{ .name }}
        version: {{ .Values.global.imageTag | quote }}
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
    spec:
      serviceAccountName: {{ .name }}
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
        seccompProfile:
          type: RuntimeDefault
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchExpressions:
                  - key: app
                    operator: In
                    values:
                      - {{ .name }}
              topologyKey: topology.kubernetes.io/zone
      containers:
        - name: {{ .name }}
          image: "{{ .Values.global.registry }}/nexacommerce/{{ .name }}:{{ .Values.global.imageTag }}"
          imagePullPolicy: {{ .Values.global.imagePullPolicy | default "Always" }}
          ports:
            - name: http
              containerPort: {{ .service.port | default 8080 }}
            - name: metrics
              containerPort: 9090
          resources:
            requests:
              cpu: {{ .service.resources.requests.cpu | default "250m" }}
              memory: {{ .service.resources.requests.memory | default "256Mi" }}
            limits:
              cpu: {{ .service.resources.limits.cpu | default "500m" }}
              memory: {{ .service.resources.limits.memory | default "512Mi" }}
          livenessProbe:
            httpGet:
              path: /health/live
              port: {{ .service.port | default 8080 }}
            initialDelaySeconds: 30
            periodSeconds: 10
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /health/ready
              port: {{ .service.port | default 8080 }}
            initialDelaySeconds: 10
            periodSeconds: 5
            failureThreshold: 3
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}
{{- end }}
