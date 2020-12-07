# Testing isolated namespaces in k8s, that is integrated with openstack 

The goal of this test is to demonstrate that PODs created in isolated k8s namespaces that are associated with openstack projects can communicate to each other and at the same time can't communicate to PODs in other namespaces. To demonstrate this we will create a domain in openstack, that corresponds to default-domain in Contrail and where kube-manager will create projects. Currently creating projects in other domains then default-domain is not working due to a bug in kube-manager: https://contrail-jws.atlassian.net/browse/CEM-18271. We will create isolated namespaces in k8s and corresponding projects in keystone. We will create users in keystone that are assigned Member roles in their projects. We will create RBAC rules for the projects in Contrail that will allow users with Member role to access network in their projects. We will create a policy for k8s-keystone-auth, that will allow users keystone users access to only their namespaces. Then we will create deployments in each namespace on behalf of the user that is supposed to be authorized to work with it and demonstrate that communication between pods in different namespaces is not possible, while it is still possible within the same namespace.

## Preparation steps

To associate an openstack domain to default-domain of Contrail, we need to create a domain in openstack and then manipulate keystone database to make UUIDs of both domains match:

```
openstack domain create k8s
...
ubuntu@juju-jumphost:~$ openstack domain list
+----------------------------------+----------------+---------+--------------------+
| ID                               | Name           | Enabled | Description        |
+----------------------------------+----------------+---------+--------------------+
| 164baf9be7db4431abe9aff37e5e9207 | k8s            | True    |                    | << here ID is already matching the ID of default-domain in Contrail. It was replaced in mysql keystone database, table projects
| 39423424db0d4702a83c94aeefeae2ff | service_domain | True    | Created by Juju    |
| d0db685db68a4f4ab2da062315779df9 | admin_domain   | True    | Created by Juju    |
| default                          | Default        | True    | The default domain |
+----------------------------------+----------------+---------+--------------------+

ubuntu@juju-jumphost:~$ curl -H "X-Auth-Token: gAAAAABfQ67N_59bLkc7cowFayGriZK7_xtN0e3OLI9G6Y7E18SIHlCbCOkfCGAxWI1bf4hDwJa2XuSBKjfu_-NG2Luevvs8GLgft3SiikH_gMVeah8rG6vdP8o_mNOOWg1V_GRIqb4kMbTa3uIJ1FYTXPu_eC-YPAYQjBTkw8Raml_j__JQJ5E"  http://192.168.2.134:8082/domains | jq '.domains | .[] | select(.fq_name==["default-domain"]) | .href'
"http://192.168.2.134:8082/domain/164baf9b-e7db-4431-abe9-aff37e5e9207"

```

Creating isolated namespaces - it will only create namespaces and corresponding contrail projects, that are prepended with cluster name:

```
cat << EOF | k create -f -
---
kind: Namespace
apiVersion: v1
metadata:
  name: project1
  annotations:
    'opencontrail.org/isolation' : 'true'
  labels:
    name: project1
EOF

cat << EOF | k create -f -
---
kind: Namespace
apiVersion: v1
metadata:
  name: project2
  annotations:
    'opencontrail.org/isolation' : 'true'
  labels:
    name: project2
EOF
```

Contrail projects that were created as a result
```
  {
    "href": "http://192.168.2.134:8082/project/85e415dc-9024-4d3c-b3e3-1cd6ae23cc24",
    "fq_name": [
      "default-domain",
      "k8s-project1"
    ],
    "uuid": "85e415dc-9024-4d3c-b3e3-1cd6ae23cc24"
  },
  {
    "href": "http://192.168.2.134:8082/project/3a516080-2894-48ab-8a80-c1d3f0508306",
    "fq_name": [
      "default-domain",
      "k8s-project2"
    ],
    "uuid": "3a516080-2894-48ab-8a80-c1d3f0508306"
  }
```

Keystone still does not know about them. We need to create corresponding projects in keystone in that new domain.

```
openstack  project create --domain k8s k8s-project1
openstack  project create --domain k8s k8s-project2
```

We also need to create users, that will be members in those projects
```
openstack user create user1 --domain k8s --password c0ntrail123 --project k8s-project1
openstack user create user2 --domain k8s --password c0ntrail123 --project k8s-project2
openstack role add --project k8s-project1 --project-domain k8s --user user1 --user-domain k8s Member
openstack role add --project k8s-project2 --project-domain k8s --user user2 --user-domain k8s Member
```

We need to create RBAC rules in Contrail, that would allow user1 and user2 with roles Member to access networking objects in their projects. This is needed for both OpenStack and K8s, otherwise users with Member roles are completely blind of all Contrail controlled objects. Here are 2 RBAC rules that were added in project level RBAC:

```
+-------------------------------+-----------------+--------------+-------------------------------+
|Project                        | Object Property |      Role    |             Access            |
+-------------------------------+-----------------+--------------+-------------------------------+
|default-domain:k8s-project1    |      *.*        |     Member   | Create, Read, Update, Delete  |
|default-domain:k8s-project2    |      *.*        |     Member   | Create, Read, Update, Delete  |
+-------------------------------+-----------------+--------------+-------------------------------+
```

We need to create k8s-auth-policy, that will be used by keystone-auth service to authorize operations of users that are part of those projects:

```
cat << EOF > policy.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: k8s-auth-policy
  namespace: kube-system
  labels:
    k8s-app: k8s-keystone-auth
data:
  policies: |
    [
      {
       "resource": {
          "verbs": ["get", "list", "watch"],
          "resources": ["*"],
          "version": "*",
          "namespace": "*"
        },
        "match": [
          {
            "type": "role",
            "values": ["*"]
          },
          {
            "type": "project",
            "values": ["k8s"]
          }
        ]
      },
      {
       "resource": {
          "verbs": ["*"],
          "resources": ["*"],
          "version": "*",
          "namespace": "project1"
        },
        "match": [
          {
            "type": "role",
            "values": ["*"]
          },
          {
            "type": "project",
            "values": ["k8s-project1"]
          }
        ]
      },
      {
       "resource": {
          "verbs": ["*"],
          "resources": ["*"],
          "version": "*",
          "namespace": "project2"
        },
        "match": [
          {
            "type": "role",
            "values": ["*"]
          },
          {
            "type": "project",
            "values": ["k8s-project2"]
          }
        ]
      },
      {
       "resource": {
          "verbs": ["*"],
          "resources": ["*"],
          "version": "*",
          "namespace": "*"
        },
        "match": [
          {
            "type": "role",
            "values": ["*"]
          },
          {
            "type": "project",
            "values": ["admin"]
          }
        ]
      }
    ]
EOF
```

We need to pass this policy to juju, so that it creates a proper configmap and keystone-auth will consume it
```
juju config kubernetes-master keystone-policy="$(cat policy.yaml)"

ubuntu@juju-jumphost:~/k8s/keystone_auth$ k get configmap -n kube-system k8s-auth-policy
NAME              DATA   AGE
k8s-auth-policy   1      3d19h
```

We also need to instruct client to use k8s domain to authenticate with keystone. This is done by including --domain-name as command line argument into exec key of the user:

```
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURVVENDQWptZ0F3SUJBZ0lVRmVXeW1aUFBwdE13WU9SSnRpMzk0V3FVY3Brd0RRWUpLb1pJaHZjTkFRRUwKQlFBd0dERVdNQlFHQTFVRUF3d05NVGt5TGpFMk9DNHlMakV3TVRBZUZ3MHlNREE0TWpBeE5qRTNNRGRhRncwegpNREE0TVRneE5qRTNNRGRhTUJneEZqQVVCZ05WQkFNTURURTVNaTR4TmpndU1pNHhNREV3Z2dFaU1BMEdDU3FHClNJYjNEUUVCQVFVQUE0SUJEd0F3Z2dFS0FvSUJBUURWMjkzOXpiZUpuRUlMV3FqTklUUUwrMlhMUmVKakhQdHYKSVdrS0V1OHQzQ1c4M2QrdVdCWk9sejZyOWNsZVFmQlFkUVRKeTFFK2xiQmxRK094RWJRa0dzUFY5Z2dFM3RYUApHSmtwQ0FLcngxYWpnbWs4elpndnM1d0VlVHlRKytzbCt6TGxQV3Z1VXFmYlZQVDUvazRUU1p3R0VFUGZsblRZCnczTkp3aGdXK3VZS1o3QThxdHlUQkVIWjhsT1VRMU1XMHd6NnlId0JwcE1MVE94MnJWbTB6VXJHOVFyVlNQN0IKczJacmdnLzRDcGd1SWt2TWRDZldZT25GZHZsMmQ0N0IwZUd1UUdHQlROQUtqY0UrYWlmZTBEeTlPVENMOFI5NQpacGd0TGdEOEFNQWZDWXptWHhycWlrWlNkKytnWEF3Si9rUGF0ZC9rRnltZlk1amVHNTMvQWdNQkFBR2pnWkl3CmdZOHdIUVlEVlIwT0JCWUVGQWVVYktxL2FhSVRSVnVoRFpEdCs1Wnc4d2tNTUZNR0ExVWRJd1JNTUVxQUZBZVUKYktxL2FhSVRSVnVoRFpEdCs1Wnc4d2tNb1J5a0dqQVlNUll3RkFZRFZRUUREQTB4T1RJdU1UWTRMakl1TVRBeApnaFFWNWJLWms4K20wekJnNUVtMkxmM2hhcFJ5bVRBTUJnTlZIUk1FQlRBREFRSC9NQXNHQTFVZER3UUVBd0lCCkJqQU5CZ2txaGtpRzl3MEJBUXNGQUFPQ0FRRUFFV3ZNcWpXcm5hSGVONi9nOFl1VUJwZjdvQzJyMUE5b2RCUHgKaGJlZHFoNVUrSDFCKzY4WmFvSlFRQXpSSnUremVRTFZKeC9VV1F5UExGN2hHUFJiT0VVK2I3TEl3ZklJMlQrYQpEckhFSWY4RGhlY1NmTStENnlTeFc3VHp3YmRiL2dIeTFqY1hibXQwazY1YmYxemdtMVJyaXBCd3o2dUQweGxTCmE3RWJWbXdVVzgrcUFMb3NlVUU5a3NUeTRXTGJrZGFPQytEblRRRWlHOENmVFdjQ1lXdEpYc2RoU3RTajFmajYKTkpMVW51UGNERE82VStqOXQwSjFZbjRoMDFuVmF5eTZTY1hxRGxTbm5tZDMrUmlFL0FLOGJOSGp4QzUzRVArSQpOdWpHbkY2eHVkbkNnT2FYbk85TUFDempvb2VKOWJlSXBzc0dxYW5ONm91U1ZyeVBXUT09Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K
    server: https://192.168.2.85:443
  name: juju-cluster
contexts:
- context:
    cluster: juju-cluster
    user: keystone-user-k8s
  name: keystone-k8s
- name: keystone-user-k8s
kind: Config
users:
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      args:
      - --domain-name=k8s
      command: /snap/bin/client-keystone-auth
      env: null
```

We need to save openstackrc files to be able to use our new projects and users:

```
cat << EOF > openstackrc/kubernetes-user1.sh
#!/usr/bin/env bash
# To use an OpenStack cloud you need to authenticate against the Identity
# service named keystone, which returns a **Token** and **Service Catalog**.
# The catalog contains the endpoints for all services the user/tenant has
# access to - such as Compute, Image Service, Identity, Object Storage, Block
# Storage, and Networking (code-named nova, glance, keystone, swift,
# cinder, and neutron).
#
# *NOTE*: Using the 3 *Identity API* does not necessarily mean any other
# OpenStack API is version 3. For example, your cloud provider may implement
# Image API v1.1, Block Storage API v2, and Compute API v2.0. OS_AUTH_URL is
# only for the Identity API served through keystone.
export OS_AUTH_URL=http://192.168.2.146:5000/v3
# With the addition of Keystone we have standardized on the term **project**
# as the entity that owns the resources.
export OS_PROJECT_ID=85e415dc90244d3cb3e31cd6ae23cc24
export OS_PROJECT_NAME="k8s-project1"
export OS_USER_DOMAIN_NAME="k8s"
if [ -z "$OS_USER_DOMAIN_NAME" ]; then unset OS_USER_DOMAIN_NAME; fi
export OS_PROJECT_DOMAIN_ID="164baf9be7db4431abe9aff37e5e9207"
if [ -z "$OS_PROJECT_DOMAIN_ID" ]; then unset OS_PROJECT_DOMAIN_ID; fi
# unset v2.0 items in case set
unset OS_TENANT_ID
unset OS_TENANT_NAME
# In addition to the owning entity (tenant), OpenStack stores the entity
# performing the action as the **user**.
export OS_USERNAME="user1"
# With Keystone you pass the keystone password.
export OS_PASSWORD="c0ntrail123"
# If your configuration has multiple regions, we set that information here.
# OS_REGION_NAME is optional and only valid in certain environments.
export OS_REGION_NAME="RegionOne"
# Don't leave a blank variable, unset it if it was empty
if [ -z "$OS_REGION_NAME" ]; then unset OS_REGION_NAME; fi
export OS_INTERFACE=public
export OS_IDENTITY_API_VERSION=3
EOF


cat << EOF > openstackrc/kubernetes-user2.sh
#!/usr/bin/env bash
# To use an OpenStack cloud you need to authenticate against the Identity
# service named keystone, which returns a **Token** and **Service Catalog**.
# The catalog contains the endpoints for all services the user/tenant has
# access to - such as Compute, Image Service, Identity, Object Storage, Block
# Storage, and Networking (code-named nova, glance, keystone, swift,
# cinder, and neutron).
#
# *NOTE*: Using the 3 *Identity API* does not necessarily mean any other
# OpenStack API is version 3. For example, your cloud provider may implement
# Image API v1.1, Block Storage API v2, and Compute API v2.0. OS_AUTH_URL is
# only for the Identity API served through keystone.
export OS_AUTH_URL=http://192.168.2.146:5000/v3
# With the addition of Keystone we have standardized on the term **project**
# as the entity that owns the resources.
export OS_PROJECT_ID=3a516080289448ab8a80c1d3f0508306
export OS_PROJECT_NAME="k8s-project2"
export OS_USER_DOMAIN_NAME="k8s"
if [ -z "$OS_USER_DOMAIN_NAME" ]; then unset OS_USER_DOMAIN_NAME; fi
export OS_PROJECT_DOMAIN_ID="164baf9be7db4431abe9aff37e5e9207"
if [ -z "$OS_PROJECT_DOMAIN_ID" ]; then unset OS_PROJECT_DOMAIN_ID; fi
# unset v2.0 items in case set
unset OS_TENANT_ID
unset OS_TENANT_NAME
# In addition to the owning entity (tenant), OpenStack stores the entity
# performing the action as the **user**.
export OS_USERNAME="user2"
# With Keystone you pass the keystone password.
export OS_PASSWORD="c0ntrail123"
# If your configuration has multiple regions, we set that information here.
# OS_REGION_NAME is optional and only valid in certain environments.
export OS_REGION_NAME="RegionOne"
# Don't leave a blank variable, unset it if it was empty
if [ -z "$OS_REGION_NAME" ]; then unset OS_REGION_NAME; fi
export OS_INTERFACE=public
export OS_IDENTITY_API_VERSION=3
```

Now we can source the appropriate openstack rc file and while using the correct context we can create deployment:

```
ubuntu@juju-jumphost:~$ k config use-context keystone-k8s
Switched to context "keystone-k8s".

source openstackrc/kubernetes-user1.sh
k create deployment --image=nginx -n project1 danil-project1 --replicas=2

ubuntu@juju-jumphost:~$ o network list
+--------------------------------------+------------------------------+---------+
| ID                                   | Name                         | Subnets |
+--------------------------------------+------------------------------+---------+
| 4fa3eb2d-cbc7-477a-beaf-1c4d89dc066a | k8s-project1-service-network |         |
| 6f10279c-752e-471a-aacb-391aa2e1345f | k8s-project1-pod-network     |         |
+--------------------------------------+------------------------------+---------+

k get po -n project1 -o wide
NAME                              READY   STATUS    RESTARTS   AGE   IP              NODE                  NOMINATED NODE   READINESS GATES
danil-project1-5b88575848-ns552   1/1     Running   0          98m   10.79.255.251   juju-cae5ad-0-kvm-6   <none>           <none>
danil-project1-5b88575848-stxz8   1/1     Running   0          72m   10.79.255.248   juju-cae5ad-0-kvm-6   <none>           <none>

source openstackrc/kubernetes-user2.sh
k create deployment --image=nginx -n project2 danil-project2

ubuntu@juju-jumphost:~$ o network list
+--------------------------------------+------------------------------+---------+
| ID                                   | Name                         | Subnets |
+--------------------------------------+------------------------------+---------+
| c3e93f25-57b6-46d2-8ec2-6a8ba3bc494e | k8s-project2-service-network |         |
| 81de7044-8915-44ed-b510-126d5657c75e | k8s-project2-pod-network     |         |
+--------------------------------------+------------------------------+---------+

ubuntu@juju-jumphost:~$ k get po -n project2 -o wide
NAME                              READY   STATUS    RESTARTS   AGE    IP              NODE                  NOMINATED NODE   READINESS GATES
danil-project2-7cd8c78999-l69zc   1/1     Running   0          73m    10.79.255.247   juju-cae5ad-0-kvm-6   <none>           <none>
danil-project2-7cd8c78999-mpsfb   1/1     Running   0          100m   10.79.255.249   juju-cae5ad-0-kvm-6   <none>           <none>
```

We make sure that we are allowed to do anything only in our own namespace:

```
source openstackrc/kubernetes-user2.sh
ubuntu@juju-jumphost:~$ k get po -n project1
Error from server (Forbidden): pods is forbidden: User "user2" cannot list resource "pods" in API group "" in the namespace "project1"
```

We can send traffic between the PODs of a namespace:

```
ubuntu@juju-jumphost:~$ k exec -n project2 -it danil-project2-7cd8c78999-l69zc -- bash
root@danil-project2-7cd8c78999-l69zc:/# curl 10.79.255.249
<!DOCTYPE html>
<html>
```

But not between PODs in different namespaces:

```
root@danil-project2-7cd8c78999-l69zc:/# curl 10.79.255.251
#no reply from server
```

If we inspect vrouter interfaces on the nodes, we will see that PODs from different namespaces are in different VRFs:

```
root@juju-cae5ad-0-kvm-6:/home/ubuntu# ./ist.py vr intf --max_width 300  | grep 10.79.255.251
| 11    | tapeth0-00605e | Active | 02:83:40:41:f6:e5 | 10.79.255.251 | 169.254.0.11  | n/a     | default-domain:k8s-project1:k8s-project1-pod-network |

# it's in VRF 4
root@juju-cae5ad-0-kvm-6:/home/ubuntu# vif --get 11  | grep Vrf
            Vrf:0 Mcast Vrf:4 Flags:PL3DProxyEr QOS:-1 Ref:6

root@juju-cae5ad-0-kvm-6:/home/ubuntu# ./ist.py vr intf --max_width 300  | grep 10.79.255.247
| 14    | tapeth0-9838b8 | Active | 02:77:d2:be:26:e5 | 10.79.255.247 | 169.254.0.14  | n/a     | default-domain:k8s-project2:k8s-project2-pod-network |

# and this one is in VRF 5
root@juju-cae5ad-0-kvm-6:/home/ubuntu# vif --get 14  | grep Vrf
            Vrf:0 Mcast Vrf:5 Flags:PL3DProxyEr QOS:-1 Ref:6
```

