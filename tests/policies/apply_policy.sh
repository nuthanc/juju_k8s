set -x
juju config kubernetes-master keystone-policy="$(cat policy.yaml)"