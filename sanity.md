### Process of running Sanity in Juju based setup

```sh
git clone https://github.com/tungstenfabric/tf-dev-test

# Export the below(Did it in controller(n20))
export ORCHESTRATOR=all
export CONTROLLER_NODES="192.168.7.20, 192.168.30.29, 192.168.30.34"
export AGENT_NODES="192.168.7.9,192.168.30.19"
export SSH_USER=root
# export CONTAINER_REGISTRY="bng-artifactory.juniper.net/contrail-nightly"
export TF_TEST_IMAGE="bng-artifactory.juniper.net/contrail-nightly/contrail-test-test:2008.46"
export CONTRAIL_CONTAINER_TAG=2008.46
# export SSL_ENABLE=True
export SSL_ENABLE=false
export DEPLOYER=juju
export OPENSTACK_VERSION=queens
export AUTH_PASSWORD=password
export AUTH_DOMAIN=admin_domain
export AUTH_REGION=RegionOne
export AUTH_URL="http://192.168.7.187:35357/v3"
export AUTH_PORT=35357

# Allow RootLogin in all of the nodes
sudo su
passwd root
# In /etc/ssh/sshd_config, PermitRootLogin yes and PasswordAuthentication yes
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo systemctl restart sshd

./tf-dev-test/contrail-sanity/run.sh
```

### Note

- Andrey told that tf-dev-test doesn’t have support of deployments where components of control plane are separated to different nodes

### Manual sanity

```sh
# change the keystone ip in the contrail_test_input and enable ssl or disable it if deployment is not done without it
# If ssl is enabled, need to mount volume
docker run --name nuthan_test --entrypoint /bin/bash --network=host -v /etc/contrail:/etc/contrail -it bng-artifactory.juniper.net/contrail-nightly/contrail-test-test:2011.61

export PYTHONPATH=./scripts:./fixtures TEST_CONFIG_FILE=contrail_test_input.yaml
export MX_GW_TEST=0
export PYTHON3=1
export EMAIL_SUBJECT="o7k-juju-ci-sanity"
export EMAIL_SUBJECT="k8s-juju-ci-sanity"
bash -x run_tests.sh -m -U -T ci_sanity -t
bash -x run_tests.sh -m -U -T ci_k8s_sanity -t

```
