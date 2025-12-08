kubectl run -n default -it --rm dns-test --image=busybox --restart=Never -- nslookup github.com

# if so result, chech the following and fix if needed:
# kubectl -n kube-system edit configmap coredns
# Forward sect should be like this - forward . 8.8.8.8 8.8.4.4
# After fixing, run:
# kubectl -n kube-system rollout restart deployment coredns

