### Requirements for Test Automation

* **Openstack** domains, projects, roles, users **Creation**
* Add policy in **Policy.yaml**
* Creation and Source of **stackrc**
* **Apply policy** to keystone-policy via juju config
* **Watch** for changes to get applied in **k8s-auth-policy configmap**
* Test the required operation mentioned in Policy.yaml

### Example case 1
* Create policy for a project to just **get, list** all resources
* Tests around:
  * Get and list of all resources with no Error message
  * Failure of create and delete operations

### Policy.yaml
* Required field is data->policies
  * List of dictionaries
* Keys of dictionary
  * resource: Dict
    * verbs
    * resources
    * version
    * namespace
  * match: List
    * List of dictionaries with *type* and *values* keys
