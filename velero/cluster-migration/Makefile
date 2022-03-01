## YOU MUST CUSTOMIZE THESE
##
SRC_KUBECONFIG = /home/jmiller/Downloads/k8s-calico.yaml
SRC_KUBE_CONTEXT = default
DEST_KUBECONFIG = /home/jmiller/Downloads/single-master.yaml
DEST_KUBE_CONTEXT = default
##
## OPTIONALLY CUSTOMIZE THE FOLLOWING
##
IGNORE_NAMESPACES=kube-node-lease \
	kube-public \
	kube-system \
	kubernetes-dashboard \
	luigi-system \
	metallb-system \
	pf9-addons \
	pf9-monitoring \
	pf9-olm \
	pf9-operators \
	platform9-system
APP_LABELS=one \
	   two \
	   three
SRC_CLUSTER_NAME = source-cluster
DEST_CLUSTER_NAME = dest-cluster
VELERO_NAMESPACE = velero
MINIO_NAMESPACE = minio
VELERO_CLIENT_VERSION = v1.8.0
VELERO_CLIENT_ARCH = linux-amd64
VELERO_AWS_PLUGIN_VERSION = v1.4.0
VELERO_CSI_PLUGIN_VERSION = v0.2.0
MINIO_VERSION_TAG = latest
MINIO_ACCESS_KEY = minioadmin
MINIO_SECRET_KEY = minio30673
BUCKET_NAME = velero
INTERNAL_MINIO_HOST = minio.$(MINIO_NAMESPACE).svc.cluster.local
INTERNAL_MINIO_PORT = 9000
MINIO_NODEPORT = 30673
##
## DO NOT CHANGE THE FOLLOWING
##
CREDENTIALS_FILE_PATH = ./credentials
VELERO_CLIENT = velero
MINIO = minio_is_installed
TARGET ?= undef
KUBE_CONTEXT = undef
KUBECONFIG = undef
MINIO_HOST = undef
BACKUP_NAME ?= undef
##

export VELERO_NAMESPACE MINIO_NAMESPACE MINIO_ACCESS_KEY MINIO_SECRET_KEY BUCKET_NAME \
	INTERNAL_MINIO_PORT MINIO_NODEPORT MINIO_VERSION_TAG

check:
	which kubectl
	which make
	which tar
	which curl
	which git
	which envsubst
	@echo "All pre-requisites available!"

$(VELERO_CLIENT):
	@echo "========================================"
	@echo "Downloading velero client $(VELERO_CLIENT_VERSION) for $(VELERO_CLIENT_ARCH)"
	curl -L \
 	  https://github.com/vmware-tanzu/velero/releases/download/$(VELERO_CLIENT_VERSION)/velero-$(VELERO_CLIENT_VERSION)-$(VELERO_CLIENT_ARCH).tar.gz \
	  -o velero.tar.gz
	tar xvf velero.tar.gz --strip-components 1 \
		velero-$(VELERO_CLIENT_VERSION)-$(VELERO_CLIENT_ARCH)/velero
	chmod a+x velero
	@echo "========================================"

$(MINIO):
	@echo "========================================"
	@echo "Installing minio into namespace $(MINIO_NAMESPACE)"
	@echo "using the $(SRC_KUBE_CONTEXT) kube context from $(SRC_KUBECONFIG)"
	envsubst < ./minio-velero-nodeport.yaml | kubectl \
		--context ${SRC_KUBE_CONTEXT} \
		--kubeconfig ${SRC_KUBECONFIG} \
		apply -f -
	touch minio_is_installed
	@echo "========================================"

minio: $(MINIO)

uninstall_minio:
	@echo "========================================"
	@echo "Uinstalling minio from namespace $(MINIO_NAMESPACE)"
	@echo "using the $(SRC_KUBE_CONTEXT) kube context from $(SRC_KUBECONFIG)"
	envsubst < ./minio-velero-nodeport.yaml | kubectl \
		--context ${SRC_KUBE_CONTEXT} \
		--kubeconfig ${SRC_KUBECONFIG} \
		delete -f - || true
	rm -f minio_is_installed
	@echo "========================================"

determine_velero_target:
ifeq ($(TARGET),dest)
	$(eval KUBE_CONTEXT=$(DEST_KUBE_CONTEXT))
	$(eval KUBECONFIG=$(DEST_KUBECONFIG))
else
	$(eval KUBE_CONTEXT=$(SRC_KUBE_CONTEXT))
	$(eval KUBECONFIG=$(SRC_KUBECONFIG))
endif

uninstall_velero: determine_velero_target
	@echo "========================================"
	@echo "Uninstalling velero $(VELERO_CLIENT_VERSION) and component versions:"
	@echo "AWS Plugin $(VELERO_AWS_PLUGIN_VERSION)"
	@echo "CSI Plugin $(VELERO_CSI_PLUGIN_VERSION)"
	@echo "from namespace $(VELERO_NAMESPACE), using the $(KUBE_CONTEXT) kube context from $(KUBECONFIG)"
	@echo "========================================"
	./velero uninstall \
		--kubecontext $(KUBE_CONTEXT) \
		--kubeconfig $(KUBECONFIG) \
		--force \
		--namespace $(VELERO_NAMESPACE)

get_node_ip:
	@echo "Determining Node IP for NodePort.."
	$(eval MINIO_HOST=$(shell kubectl --context $(SRC_KUBE_CONTEXT) \
		--kubeconfig $(SRC_KUBECONFIG) \
		get nodes -o \
		jsonpath='{ $$.items[0].status.addresses[?(@.type=="InternalIP")].address }'))

install:
	$(MAKE) minio
	$(MAKE) TARGET=source install_velero
	$(MAKE) TARGET=dest install_velero

install_velero: $(VELERO_CLIENT) determine_velero_target get_node_ip
	@echo "========================================"
	@echo "Installing velero $(VELERO_CLIENT_VERSION) and component versions:"
	@echo "AWS Plugin $(VELERO_AWS_PLUGIN_VERSION)"
	@echo "CSI Plugin $(VELERO_CSI_PLUGIN_VERSION)"
	@echo "into namespace $(VELERO_NAMESPACE), using the $(KUBE_CONTEXT) kube context from $(KUBECONFIG)"
	@echo "========================================"
	envsubst < credentials.tmpl > credentials
	@echo "Minio Host URL will be: http://$(MINIO_HOST):$(MINIO_NODEPORT)"
	./velero install \
		--provider aws \
		--plugins velero/velero-plugin-for-aws:$(VELERO_AWS_PLUGIN_VERSION),velero/velero-plugin-for-csi:$(VELERO_CSI_PLUGIN_VERSION) \
		--bucket $(BUCKET_NAME) \
		--secret-file ./credentials \
		--use-volume-snapshots=false \
		--default-volumes-to-restic \
		--backup-location-config region=minio,s3ForcePathStyle="true",s3Url=http://$(MINIO_HOST):$(MINIO_NODEPORT) \
		--use-restic \
		--kubecontext $(KUBE_CONTEXT) \
		--kubeconfig $(KUBECONFIG) \
		--image "velero/velero:$(VELERO_CLIENT_VERSION)" \
		--wait
	kubectl get deploy/velero \
		--context $(KUBE_CONTEXT) \
		--kubeconfig $(KUBECONFIG) \
		--namespace $(VELERO_NAMESPACE)

check_comms: get_node_ip
	kubectl run tmp-shell \
		--restart=Never --rm -i --tty \
		--image nicolaka/netshoot -n $(VELERO_NAMESPACE) \
		--context $(DEST_KUBE_CONTEXT) \
		--kubeconfig $(DEST_KUBECONFIG) \
		-- nc -z -v -w5 $(MINIO_HOST) $(MINIO_NODEPORT)

backup:
	$(eval BACKUP_TIME = $(shell date +%F-%s))
	$(eval BACKUP_NAME = $(SRC_CLUSTER_NAME)-$(BACKUP_TIME))
	$(eval IGNORE = $(shell echo "$(IGNORE_NAMESPACES)" | sed -e 's/\s\+/,/g'))
	@echo "========================================"
	@echo "Backup Name: $(BACKUP_NAME)"
	./velero backup create $(BACKUP_NAME) \
		--exclude-namespaces=$(VELERO_NAMESPACE),$(MINIO_NAMESPACE),$(IGNORE) \
		--include-resources=* \
		--include-cluster-resources \
		--kubecontext $(SRC_KUBE_CONTEXT) \
		--kubeconfig $(SRC_KUBECONFIG)
	@echo "========================================"
	./velero backup describe $(BACKUP_NAME) \
		--details \
		--kubecontext $(SRC_KUBE_CONTEXT) \
		--kubeconfig $(SRC_KUBECONFIG)

restore_all:
ifeq ($(BACKUP_NAME),undef)
	@echo "Specify the backup name. ie. \`BACKUP_NAME=source-cluster-xxxx make restore\`"
	exit 1
endif
	$(eval IGNORE = $(shell echo "$(IGNORE_NAMESPACES)" | sed -e 's/\s\+/,/g'))
	$(eval RESTORE_TIME = $(shell date +%F-%s))
	$(eval RESTORE_NAME = $(DEST_CLUSTER_NAME)-$(RESTORE_TIME))
	@echo "========================================"
	@echo "Backup Name to Restore From: $(BACKUP_NAME)"
	./velero create restore $(RESTORE_NAME) \
		--from-backup $(BACKUP_NAME) \
		--include-resources=* \
		--include-cluster-resources \
		--exclude-namespaces=$(VELERO_NAMESPACE),$(MINIO_NAMESPACE),$(IGNORE) \
		--preserve-nodeports=true \
		--kubecontext $(DEST_KUBE_CONTEXT) \
		--kubeconfig $(DEST_KUBECONFIG)

restore_only_apps:
ifeq ($(BACKUP_NAME),undef)
	@echo "Specify the backup name. ie. \`BACKUP_NAME=source-cluster-xxxx make restore_only_apps\`"
	exit 1
endif
	$(eval IGNORE = $(shell echo "$(IGNORE_NAMESPACES)" | sed -e 's/\s\+/,/g'))
	$(eval RESTORE_TIME = $(shell date +%F-%s))
	$(eval RESTORE_NAME = $(DEST_CLUSTER_NAME)-$(RESTORE_TIME))
	@echo "========================================"
	@echo "Backup Name to Restore From: $(BACKUP_NAME)"
	for label in $(APP_LABELS); do \
		echo "Restoring app label=$$label" ; \
		./velero create restore "$(RESTORE_NAME)-$$label" \
			--from-backup $(BACKUP_NAME) \
			--selector "app.kubernetes.io/component=$$label" \
			--preserve-nodeports=true \
			--kubecontext $(DEST_KUBE_CONTEXT) \
			--kubeconfig $(DEST_KUBECONFIG) ; \
	done

get_backups:
	./velero get backups \
		--kubecontext $(SRC_KUBE_CONTEXT) \
		--kubeconfig $(SRC_KUBECONFIG)

get_backup:
ifeq ($(BACKUP_NAME),undef)
	@echo "Specify the backup name. ie. \`BACKUP_NAME=source-cluster-xxxx make get_backup\`"
	exit 1
endif
	./velero backup describe $(BACKUP_NAME) \
		--details \
		--kubecontext $(SRC_KUBE_CONTEXT) \
		--kubeconfig $(SRC_KUBECONFIG)

get_restores:
	./velero get restores \
		--kubecontext $(DEST_KUBE_CONTEXT) \
		--kubeconfig $(DEST_KUBECONFIG)

get_restore:
ifeq ($(RESTORE_NAME),undef)
	@echo "Specify the backup name. ie. \`RESTORE_NAME=dest-cluster-xxxx make get_restore\`"
	exit 1
endif
	./velero restore describe $(RESTORE_NAME) \
		--details \
		--kubecontext $(DEST_KUBE_CONTEXT) \
		--kubeconfig $(DEST_KUBECONFIG)

clean:
	$(MAKE) TARGET=dest uninstall_velero
	$(MAKE) TARGET=source uninstall_velero
	$(MAKE) uninstall_minio
	@echo "All clean now"
