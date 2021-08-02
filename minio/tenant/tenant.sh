#!/bin/bash
function inputs ()
{
        echo "Tenant: ${tenant}"
        echo "Namesapce: ${namespace}"
}

function apply ()
{

for f in certs manifest
do
	ff=all_tenants/${tenant}-${f}.yaml
	echo ${ff}
	cp -pr ${f} ${ff}
	sed -i.bkup  "s/\${tenant}/${tenant}/g" ${ff} 
	sed -i.bkup  "s/\${namespace}/${namespace}/g" ${ff}
	# NOTE: replace with exact string ${tenant} sed -i.bu  "s/TENANt/\${tenant}/g"  ./tenant-certs-example.yaml
	# NOTE: replace with value of variable ${tenant} sed -i.bu  "s/TENANt/${tenant}/g"  ./tenant-certs-example.yaml
	#		kubectl apply -f ${ff} --dry-run=client
	kubectl apply -f ${ff} 
	#cat ${ff}
	rm ${ff}.bkup
done
}

if [ $1 == "--help" ]
then
	echo "Runs on macOS currently."
	echo "USAGE: ./tenant.sh TENANT_NAME  [NAMESPACE_NAME]"
	echo "NOTE: if NAMESPACE_NAME is not specified then it is set to TENANT_NAME"
	exit 1
fi
if [ -z $1 ]
then
	echo "Must enter name of tenant as first argument to the script. Second argument is namespace, if not defined then namesapce is set to the first argument"
	exit 1
fi
tenant=$1
if [ -z $2 ]
then
	namespace=${tenant}
	inputs
else
	namespace=$2 
	inputs
fi
if [ ! -d all_tenants ] 
then
	mkdir all_tenants
fi
apply
