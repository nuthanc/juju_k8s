
### Working policy process
* Deploy with vhost-gateway commented
* Refer to CEM/13066/my-k8s-os-mi.yaml of this commit
* In master add /etc/hosts to /etc/cloud/templates/hosts.debian.tmpl
```sh
contrail-status
kubectl get pods -A
ip r add 10.32.0.0/12 via 192.168.27.1 dev vhost0
kubectl run cirros --image=cirros
kubectl edit ns default
# Copy config to .kube/config of noden18
# Add cluster in context of keystone in .kube/config
cat .kube/config
```
```sh
# In noden18
kubectl config use-context keystone
source stackrc.sh
k get pods
```
* Virtual routers in webui: nodec9.maas, noden29.maas, noden19.maas
```sh
# Traceroute from k8s-auth-pod to keystone
root@noden29:~ kubectl exec -it k8s-keystone-auth-674b895f4c-7242f -n kube-system sh
kubectl exec [POD] [COMMAND] is DEPRECATED and will be removed in a future version. Use kubectl kubectl exec [POD] -- [COMMAND] instead.
/ # ping 192.168.7.5
PING 192.168.7.5 (192.168.7.5): 56 data bytes
64 bytes from 192.168.7.5: seq=0 ttl=61 time=1.339 ms
64 bytes from 192.168.7.5: seq=1 ttl=61 time=1.734 ms
64 bytes from 192.168.7.5: seq=2 ttl=61 time=1.803 ms
64 bytes from 192.168.7.5: seq=3 ttl=61 time=1.773 ms
^C
--- 192.168.7.5 ping statistics ---
4 packets transmitted, 4 packets received, 0% packet loss
round-trip min/avg/max = 1.339/1.662/1.803 ms
/ # ip r
default via 10.47.255.254 dev eth0
10.32.0.0/12 dev eth0 scope link  src 10.47.255.250
/ # traceroute 192.168.7.5
# 192.168.7.5 is keystone ip
traceroute to 192.168.7.5 (192.168.7.5), 30 hops max, 46 byte packets
 1  *  *  *
 2  192.168.27.9 (192.168.27.9)  1.392 ms  1.036 ms  4.955 ms
 3  192.168.27.9 (192.168.27.9)  0.663 ms  0.953 ms  4.757 ms
 4  192.168.7.5 (192.168.7.5)  0.964 ms  1.250 ms  1.027 ms
 ```

 ```sh
 # ip route in keystone-auth pod
ip r
default via 10.47.255.254 dev eth0
10.32.0.0/12 dev eth0 scope link  src 10.47.255.250
```

### n19 history and route
```sh
ip r
contrail-status
ip r add 10.32.0.0/12 via 192.168.27.1 dev vhost0
exit
ip r
history
```

```txt
default via 192.168.7.18 dev eno1 proto static
10.32.0.0/12 via 192.168.27.1 dev vhost0
169.254.0.3 dev vhost0 proto 109 scope link
169.254.0.4 dev vhost0 proto 109 scope link
169.254.0.6 dev vhost0 proto 109 scope link
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1 linkdown
192.168.7.0/24 dev eno1 proto kernel scope link src 192.168.7.19
192.168.27.0/24 dev vhost0 proto kernel scope link src 192.168.27.19
```

### n20 history and route
```sh
cat /etc/hosts
vi /etc/hosts
vi /etc/cloud/templates/hosts.debian.tmpl
ip r
contrail-status
kubectl get pods -A
ip r add 10.32.0.0/12 via 192.168.27.1 dev vhost0
ip r
kubectl get pods -A
kubectl get pods
kubectl run cirros --image=cirros
kubectl get pods
kubectl get pods -w
kubectl get pods -A
kubectl get config-map
kubectl get config-map -n kube-system
kubectl get configmap -n kube-system
kubectl descibe configmap k8s-auth-policy -n kube-system
kubectl describe configmap k8s-auth-policy -n kube-system
kubectl edit ns default
vi .kube/config
cat  .kube/config
history
kubectl get pods -A -o wide
kubectl exec -it k8s-keystone-auth-674b895f4c-7242f -n kube-system sh
history
ip r
history
```

```txt
default via 192.168.7.18 dev eno1 proto static
10.32.0.0/12 via 192.168.27.1 dev vhost0
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1 linkdown
192.168.7.0/24 dev eno1 proto kernel scope link src 192.168.7.29
192.168.27.0/24 dev vhost0 proto kernel scope link src 192.168.27.29
```

 ### Andrey's response to above issue
 ```txt
 it’s all up to vrouter team
looks like now vrouter sends all traffic into 192.168.7.* network and thus keystone-auth pod can reach keystone
but you have to add routes manually
```