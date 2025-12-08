# K8S MONITORING thru ARGOCD

### Prometheus official repo add

```bash
argocd repo add https://prometheus-community.github.io/helm-charts \
  --type helm \
  --name prometheus-community

```
> [!NOTE]
> Prometheus <br>
> Alertmanager <br>
> kube-state-metrics <br>
> node-exporter <br>

### Grafana official repo add

```bash
argocd repo add https://grafana.github.io/helm-charts \
  --type helm \
  --name grafana

```
```bash
argocd repo list
```

### Prometheus — prometheus.yaml

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: prometheus
  namespace: argocd
spec:
  project: default

  source:
    repoURL: https://prometheus-community.github.io/helm-charts
    chart: prometheus
    targetRevision: '*'   # allways last rev.

    helm:
      values: |
        server:
          service:
            type: NodePort
          persistentVolume:
            enabled: false  # To avoid hanging of the pod at unbound immediate PersistentVolumeClaims
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi

        alertmanager:
          enabled: true
          service:
            type: NodePort
          resources:
            requests:  # without limiting Alertmanager and Pushgateway can eat up all the resource, start OOMKill and overload all the cluster. 
              cpu: 50m
              memory: 128Mi
            limits:
              cpu: 200m
              memory: 256Mi

        pushgateway:
          enabled: true
          service:
            type: NodePort
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 100m
              memory: 128Mi

  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true

```

> [!NOTE]
> Service: NodePort <br>
> namespace: monitoring <br>
> _Namespace created by ArgoCD_ <br>


### Grafana — grafana.yaml 

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: grafana
  namespace: argocd
spec:
  project: default

  source:
    repoURL: https://grafana.github.io/helm-charts
    chart: grafana
    targetRevision: '*'

    helm:
      values: |
        adminUser: admin
        adminPassword: admin

        service:
          type: NodePort

        persistence:
          enabled: false

        datasources:
          datasources.yaml:
            apiVersion: 1
            datasources:
              - name: Prometheus
                type: prometheus
                url: http://prometheus-server.monitoring.svc.cluster.local
                access: proxy
                isDefault: true
        sidecar:
          dashboards:
            enabled: true
            label: grafana_dashboard



  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: k8s-cluster-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  k8s-cluster.json: |
    {
      "annotations": { "list": [] },
      "editable": true,
      "panels": [],
      "title": "Kubernetes Cluster",
      "schemaVersion": 16,
      "version": 1
    }
```
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: node-exporter-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  node-exporter.json: |
    {
      "annotations": { "list": [] },
      "editable": true,
      "panels": [],
      "title": "Node Exporter",
      "schemaVersion": 16,
      "version": 1
    }
```
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: docker-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  docker.json: |
    {
      "annotations": { "list": [] },
      "editable": true,
      "panels": [],
      "title": "Docker",
      "schemaVersion": 16,
      "version": 1
    }
```


> [!NOTE]
> Service: NodePort <br>
> namespace: monitoring <br>
> _Namespace created by ArgoCD_ <br>
> Using config map for dashboards, fill them with json content of the proper dashboards

or else you can download/save dashboard json as a file (eg. k8s-cluster.json) and:

```bash
kubectl -n monitoring create configmap k8s-cluster-dashboard  --from-file=k8s-cluster.json  --label=grafana_dashboard= 1
```
or else you can add them manually using ID - the best and shortest option

### Applying

```bash
kubectl apply -f prometheus.yaml
kubectl apply -f grafana.yaml

```
### ArgoCD CLI cmd vs. prometheus.yaml

```bash
argocd app create prometheus \
  --project default \
  --repo https://prometheus-community.github.io/helm-charts \
  --helm-chart prometheus \
  --revision "*" \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace monitoring \
  --sync-policy automated \
  --self-heal \
  --auto-prune \
  --sync-option CreateNamespace=true \
  \
  --helm-set server.service.type=NodePort \
  --helm-set server.persistentVolume.enabled=false \
  --helm-set server.resources.requests.cpu=100m \
  --helm-set server.resources.requests.memory=256Mi \
  --helm-set server.resources.limits.cpu=500m \
  --helm-set server.resources.limits.memory=512Mi \
  \
  --helm-set alertmanager.enabled=true \
  --helm-set alertmanager.service.type=NodePort \
  --helm-set alertmanager.resources.requests.cpu=50m \
  --helm-set alertmanager.resources.requests.memory=128Mi \
  --helm-set alertmanager.resources.limits.cpu=200m \
  --helm-set alertmanager.resources.limits.memory=256Mi \
  \
  --helm-set pushgateway.enabled=true \
  --helm-set pushgateway.service.type=NodePort \
  --helm-set pushgateway.resources.requests.cpu=50m \
  --helm-set pushgateway.resources.requests.memory=64Mi \
  --helm-set pushgateway.resources.limits.cpu=100m \
  --helm-set pushgateway.resources.limits.memory=128Mi

```
```bash
argocd app sync prometheus

```

### ArgoCD CLI cmd vs. grafana.yaml

```bash
argocd app create grafana \
  --project default \
  --repo https://grafana.github.io/helm-charts \
  --helm-chart grafana \
  --revision "*" \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace monitoring \
  --sync-policy automated \
  --self-heal \
  --auto-prune \
  --sync-option CreateNamespace=true \
  --helm-set adminUser=admin \
  --helm-set adminPassword=admin \
  --helm-set service.type=NodePort \
  --helm-set persistence.enabled=false \
  --helm-set datasources.datasources\\.yaml.apiVersion=1 \
  --helm-set datasources.datasources\\.yaml.datasources[0].name=Prometheus \
  --helm-set datasources.datasources\\.yaml.datasources[0].type=prometheus \
  --helm-set datasources.datasources\\.yaml.datasources[0].url=http://prometheus-server.monitoring.svc.cluster.local \
  --helm-set datasources.datasources\\.yaml.datasources[0].access=proxy \
  --helm-set datasources.datasources\\.yaml.datasources[0].isDefault=true

```
```bash
argocd app sync grafana
argocd app get grafana

```

### NodePort show

```bash
kubectl get svc -n monitoring
```

### Grafana Login info

```pgsql
login: admin
password: admin
```

## TOP grafana dashboards

| Type               | ID        |
| ------------------ | --------- |
| Kubernetes Cluster | **6417**  |
| Node Exporter      | **1860**  |
| Docker             | **193**   |
| Linux server       | **11074** |

```pgsql
'+' → Import → enter ID → Load → Prometheus → Import

```

> [!IMPORTANT]
> For web access use _../open_ports.sh_ script




