### Restart scenarios
* vrouter agent
* kubelet
* kubemanager restart
  * Create pod with some User
  * Restart kubemanager
  * Earlier one should be intact
  * Deleting new Pod
  * Creating new pod
* config_api restart
* keystone-auth-pod restart (Main)
  * Create user
  * Restart
  * After restart 
  * Add new user
* docker restart on Compute and Master

### Key components
* Keystone-auth-pod restart
* User and User privileges

### Policy
* Trailing , shouldn't be there

### Tests done
* Restart scenarios with Project in Default domain and Admin domain
* Policy change with Project in Default domain
* With different domain
* With Namespace
* With different user

### Tests to be done

### Tests not working
* version 2 policy
* version 2 in combination with version 1
  * Even version 1 policies don't work

https://stackoverflow.com/questions/28557626/how-to-update-yaml-file-using-python

I don't know whether all variations are covered, but here is the Status update
### Status update
I have done Tests around the following:
* admin role
* non admin role
* default domain
* admin domain
* user domain
* admin project
* non admin project
* default namespace
* other namespace
* all resources
* specific resources
* get, list, create, and delete Verbs
* Restart scenarios 
  * vrouter agent
  * kubelet
  * kubemanager restart
  * config_api restart
  * keystone-auth restart
  * docker restart on Compute and Master

### Problems faced
* You must be logged in to the server (Unauthorized)
  * After docker restart, getting the above Error
  * Workaround: Delete 10.64.0.0/12 route
* Working with version 1 policy, but not working with version 2 policy
  * But whatever can be done in version 2 can be implemented in version 1
  * The only difference is version 2 has short and concise syntax

Note: All of the tests were done manually. Need to automate it in the future