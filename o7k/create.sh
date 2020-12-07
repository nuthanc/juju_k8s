set -x
openstack domain list | grep ${DOMAIN_NAME}
status=$?
if [[ $status -ne 0 ]]
then
  openstack domain create ${DOMAIN_NAME}
fi

openstack project list | grep ${PROJECT_NAME}
status=$?
if [[ $status -ne 0 ]]
then
  openstack project create --domain ${DOMAIN_NAME} ${PROJECT_NAME}
fi

openstack user list --domain ${DOMAIN_NAME} --project ${PROJECT_NAME}| grep ${USERNAME}
status=$?
if [[ $status -ne 0 ]]
then
  openstack user create ${USERNAME} --domain ${DOMAIN_NAME} --password ${PASSWORD} --project ${PROJECT_NAME}
fi

openstack role add --project ${PROJECT_NAME} --project-domain ${DOMAIN_NAME} --user ${USERNAME} --user-domain ${DOMAIN_NAME} ${ROLE}
echo ' '
openstack role assignment list --names | grep ${USERNAME}
openstack user list --domain ${DOMAIN_NAME} --project ${PROJECT_NAME}