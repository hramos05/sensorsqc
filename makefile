SHELL := /bin/bash

.PHONY: all

# Static Variables
GIT_REPO=https://github.com/hramos05/sensorsqc.git
FLUX_POLL=5s

# From Zero to Hero!
# Fluxctl is not installed on Azure Shell, so we'll download and register it
# Other tools will need to be manually installed for now
# TODO: Add all required tools so we can use this outside of Azure Shell
all: infra-deploy docker-buildpush arc-deploy check-app

# Azure infrastructure management using Terraform v0.14.3
infra-deploy: tf_init tf_apply
infra-destroy: tf_destroy

# Azure Arc/Flux management
arc-deploy: arc-prereq arc-connectaks arc-config-ingress arc-config-sensorsqc

# Arc Configs
arc-clean-up: arc-delete-sensorsqc arc-delete-ingress

# Terraform
tf_init:
	@cd ./infra && \
		terraform init
tf_plan: tf_init
	@cd ./infra && \
		terraform plan
tf_apply: tf_init
	@cd ./infra && \
		terraform apply
tf_destroy: tf_init
	@cd ./infra && \
		terraform destroy

# Get TF Outputs
tf_set_vars:
RESOURCEGROUP_NAME ?= $(shell terraform output -state=./infra/terraform.tfstate resourcegroup_name)
ACR_LOGIN_SERVER ?= $(shell terraform output -state=./infra/terraform.tfstate acr_login_server)
AKS_SERVER_NAME ?= $(shell terraform output -state=./infra/terraform.tfstate aks_server_name)

# Docker build/push using Dockerfile and Az cli
docker-buildpush: tf_set_vars
	@echo Build docker image and upload to $(ACR_LOGIN_SERVER)
	@cd ./app && \
	az acr build --image sensorsqc:latest \
  		--registry $(ACR_LOGIN_SERVER) \
  		--file Dockerfile .

# Azure ARC - it's like a managed Flux (and more)
# Unfortunately, I didn't see a Terraform module for this as of now. We'll use azure cli for now
arc-prereq:
	@echo Install Azure ARC and K8s extensions. This may takes a few mins!
	@az extension add --name connectedk8s
	@az extension add --name k8sconfiguration

arc-connectaks: tf_set_vars
	@echo Connecting to AKS and registering to Azure Arc. This may take 5-10mins!
	@az aks get-credentials -n $(AKS_SERVER_NAME) -g $(RESOURCEGROUP_NAME) --overwrite-existing
	@az connectedk8s connect --name $(AKS_SERVER_NAME) --resource-group $(RESOURCEGROUP_NAME)

arc-config-ingress: tf_set_vars
	@echo Create Flux GitOps Config ingress
	@az k8sconfiguration create --cluster-name $(AKS_SERVER_NAME) \
		--cluster-type connectedClusters \
		--name ingress \
		--operator-namespace ingress \
		--resource-group $(RESOURCEGROUP_NAME) \
		--repository-url $(GIT_REPO) \
		--enable-helm-operator \
		--helm-operator-params '--set helm.versions=v3' \
		--operator-params '--git-poll-interval $(FLUX_POLL) --git-readonly --git-path=flux/releases/nginx' \
		--scope cluster

arc-delete-ingress: tf_set_vars
	@echo Delete Flux GitOps Config ingress
	@az k8sconfiguration delete --cluster-name $(AKS_SERVER_NAME) \
		--cluster-type connectedClusters \
		--name ingress \
		--resource-group $(RESOURCEGROUP_NAME)

arc-config-sensorsqc: tf_set_vars
	@echo Create Flux GitOps Config sensorsqc
	@az k8sconfiguration create --cluster-name $(AKS_SERVER_NAME) \
		--cluster-type connectedClusters \
		--name sensorsqc \
		--operator-namespace sensorsqc \
		--resource-group $(RESOURCEGROUP_NAME) \
		--repository-url $(GIT_REPO) \
		--enable-helm-operator \
		--helm-operator-params '--set helm.versions=v3' \
		--operator-params '--git-poll-interval $(FLUX_POLL) --git-readonly --git-path=flux/releases/sensorsqc' \
		--scope namespace

arc-delete-sensorsqc: tf_set_vars
	@echo Delete Flux GitOps Config sensorsqc
	@az k8sconfiguration delete --cluster-name $(AKS_SERVER_NAME) \
		--cluster-type connectedClusters \
		--name sensorsqc \
		--resource-group $(RESOURCEGROUP_NAME)

# Check the app, and display URL
check-app:
	@source $(shell pwd)/toolkit/check-sensorsqc.sh
