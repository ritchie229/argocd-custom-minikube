
# ARGO CD

## Project structure
```bash
argocd-custom-minikube/
├── another_ns.yaml
├── argo_login.sh
├── close_custom.sh
├── close_ports.sh
├── dns_check.sh
├── install_bak.yaml
├── install.yaml
├── list_rules.sh
├── open_ports.sh
├── README.md
└── Taskfile.yaml

```
## Install Minikube

### Minikube prep

```bash
docker pull quay.io/coreos/flannel:v0.22.0

minikube start --nodes=3 --driver=docker \
--cpus=2 --memory=4096 --force \
--cni=flannel --preload \
--dns-domain=cluster.local \
--embed-certs --kubernetes-version=1.27.0

kubectl get pods -n kube-system

kubectl run -it --rm busybox --image=busybox --restart=Never -- sh
#inside the pod run:
ping 10.244.1.2  
nslookup kubernetes.default

```
### Core DNS reconfig for direct resolve thru extenal DNS
```bash
kubectl -n kube-system edit configmap coredns
```
```yaml
data:
  Corefile: |
    .:53 {
        forward . 8.8.8.8 8.8.4.4
}
```
```bash
kubectl -n kube-system rollout restart deployment coredns
```
Test DNS
```bash
kubectl run -n default -it --rm dns-test --image=busybox --restart=Never -- nslookup github.com
```

### Minikube Clean up
```bash
minikube delete --all --purge
```
:warning: docker ps -aq | xargs docker rm -f **DONT DO THIS**
:warning: docker network prune -f **DONT DO THIS**


## ArgoCD thru kubectl

### Install
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f install.yaml

```
### Change service type for argocd-service to get web access and run Open... script

```bash
kubectl -n argocd edit service/argocd-server
>> type: NodePort
```
### Run the Port Opener script
```bash
./open_port.sh
```

### Argo CD web interface log in info

Username: admin
Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d


### DNS Check
```bash
kubectl run dns-check -n argocd \
  --image=busybox \
  --restart=Never \
  --rm -it \
  -- nslookup github.com
```
or
```bash
./dns_check.sh
```

### Repo server logs
```bash
kubectl logs -n argocd deploy/argocd-repo-server
kubectl logs -n argocd deploy/argocd-repo-server | grep -i error

```
### Argo components internal links

```bash
# repo-server seeing controller or not
kubectl exec -n argocd -it deploy/argocd-repo-server -- \
  nc -zv argocd-application-controller 8082

# controller seeing repo-server or not
kubectl exec -n argocd -it deploy/argocd-application-controller -- \
  nc -zv argocd-repo-server 8081

```

## USEFUL SCRIPS

### For Remote Repo Access from othe NameSpaces
```bash
kubectl apply -f another_ns.yam
```
### To Open External access to ClusterIP:NodePort thru manually specified external port
```bash
./open_ports.sh
```
### To close External access to ClusterIP:NodePort thru manually specified external port
```bash
./close_ports.sh
```
### To list IP Tables NAT Rules
```bash
./list_rules.sh
```
### Use this to remove rules manually entering Ext_Port, ClusterIP and NodePort, ie. cleanup garbage
```bash
./close_custom.sh
```


## ARGO CD CLI

### Install
```bash
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/
argocd version

```

### Argo CLI login

#### Argo CLI login looks like this:
```bash
argocd login <CLUSTER_IP:PORT> --username admin --password <PWD> --insecure
```
#### ArgoCD URL
```bash
minikube service argocd-server -n argocd --url
```
#### Admin PWD
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```
#### The scrip below will log you in automatically at one run
```bash
./argo_login.sh
```
### Repo adding

#### Public repo
```bash
argocd repo add https://github.com/USER/REPO.git
```
#### Private repo (https+token)
```bash
argocd repo add https://github.com/USER/REPO.git \
  --username USER --password <PERSONAL_ACCESS_TOKEN>
```
#### Private repo (ssh)
```bash
argocd repo add git@github.com:USER/REPO.git --ssh-private-key-path ~/.ssh/id_rsa
```
#### checking repo list added
```bash
argocd repo list
```

### Repo structure (GitOps eg.)

```bash
repo-root/
├─ apps/
│  ├─ myapp/
│  │  ├─ base/           # kustomize base or raw manifests
│  │  │  └─ deployment.yaml
│  │  └─ overlays/
│  │     └─ dev/         # overlay for dev (kustomize) or helm values.yaml
├─ charts/               # optionally: helm charts
└─ argocd/               # optionally: ArgoCD Application manifests (declarative)
   └─ myapp-application.yaml
```
#### myapp-application.yaml example

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'https://github.com/USER/REPO.git'   # or git@github.com:USER/REPO.git
    targetRevision: HEAD
    path: apps/myapp/base
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: myapp-namespace
  syncPolicy:
    automated:
      prune: true      # removing non-existing resources from Git
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```
#### Applying myapp-application.yaml 
```bash
kubectl apply -f argocd/myapp-application.yaml
```

#### or thru CLI:
```bash
argocd app create myapp \
  --repo https://github.com/USER/REPO.git \
  --path apps/myapp/base \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace myapp-namespace \
  --sync-policy automated --auto-prune --self-heal
```
#### Testing
```bash
argocd app get myapp
argocd app list
```

### Best Practices

> [!TIP]
> spec.syncPolicy.automated + prune: true + selfHeal: true — make ArgoCD automatic, all changes in git repo will be applyed, removed resources will be removed completely, deviations will be corrected.
> syncOptions: 
>   CreateNamespace=true - argocd creates requested namespace itself.
>   ApplyOutOfSyncOnly=true — applyes only the changes, economic.



