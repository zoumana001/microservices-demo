ENV_DIR := envs/prod
TF     := terraform -chdir=$(ENV_DIR)

.PHONY: bootstrap init plan apply destroy kubeconfig unlock

## Run once before anything else
bootstrap:
	@bash bootstrap.sh

## Initialise Terraform (downloads providers, connects S3 backend)
init:
	$(TF) init

## Preview changes without touching AWS
plan:
	$(TF) plan -out=$(ENV_DIR)/tfplan

## Apply the plan
apply:
	$(TF) apply $(ENV_DIR)/tfplan

## Destroy everything (careful!)
destroy:
	$(TF) destroy

## Configure kubectl after the cluster is up
kubeconfig:
	aws eks update-kubeconfig \
		--region us-east-1 \
		--name zoum_cluster

## Remove a stuck Terraform state lock
unlock:
	aws dynamodb delete-item \
		--table-name zoum-terraform-locks \
		--key '{"LockID":{"S":"zoum-cluster/prod/terraform.tfstate"}}'

## Show all outputs (cluster endpoint, bastion IP, nameservers, cert ARN)
outputs:
	$(TF) output
