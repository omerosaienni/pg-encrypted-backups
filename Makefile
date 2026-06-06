.PHONY: build build-gcs \
        run run-db run-restore \
        stop stop-db stop-restore \
        exec-db exec-restore psql-db psql-restore \
        demo demo-gcs \
        delete clean destroy \
        terraform-apply terraform-destroy

# --- Build ---

# Build the image (local-only path, no GCS).
build:
	@echo "Building image..."
	@./scripts/build.sh

# Build for the GCS path: provision the bucket + service account, then build.
build-gcs: terraform-apply build

# --- Run ---

run-db: stop-db
	@echo "Running Source Database..."
	@./scripts/run-database.sh postgres-db

run-restore: stop-restore
	@echo "Running Restore Database..."
	@./scripts/run-restore.sh postgres-restore-db

run: run-db run-restore

# --- Shell / SQL access ---

exec-db:
	@echo "Executing Source Database..."
	@./scripts/exec.sh postgres-db

exec-restore:
	@echo "Executing Restore Database..."
	@./scripts/exec.sh postgres-restore-db

psql-db:
	@docker exec -it postgres-db psql -U myuser -d myuserdb

psql-restore:
	@docker exec -it postgres-restore-db psql -U myuser -d myuserdb

# --- Demo ---

# Walk the migration story (backup -> migrate -> encrypted backup -> inspect in
# the viewer -> roll the live source back to either stanza) on the local repo.
# Starts from a clean state so the migration always runs from scratch.
demo: clean run
	@./scripts/demo.sh local

# Same story on the GCS repo (needs the image built with build-gcs). TARGET makes
# run-*.sh mount the Terraform-generated docker/config/gcp/ config.
demo-gcs: export TARGET = gcp
demo-gcs: clean run
	@./scripts/demo.sh gcp

# --- Stop ---

stop-db:
	@echo "Stopping Source Database..."
	@./scripts/stop.sh postgres-db

stop-restore:
	@echo "Stopping Restore Database..."
	@./scripts/stop.sh postgres-restore-db

stop: stop-db stop-restore

# --- Cleanup ---

# Stop the containers and delete the image.
delete: stop
	@echo "Deleting image..."
	@./scripts/delete.sh

# Stop the containers and remove the named volumes (fast reset).
clean: stop
	@echo "Cleaning data..."
	@./scripts/clean.sh

# Full teardown: clean + delete image + destroy GCS infra.
destroy: clean delete terraform-destroy

# --- Infrastructure (GCS path only) ---

terraform-apply:
	@echo "Applying Terraform (creating bucket and service account)..."
	@cd ./terraform && terraform init
	@cd ./terraform && terraform apply --auto-approve

# Only destroy if state exists. Terraform removes the generated GCS config and
# key itself; the rm is a backstop so a half-finished destroy leaves nothing
# pointing at a deleted bucket.
terraform-destroy:
	@if [ -f ./terraform/terraform.tfstate ]; then \
		echo "Destroying Terraform (removing bucket and service account)..."; \
		cd ./terraform && terraform init && terraform destroy --auto-approve; \
	else \
		echo "No Terraform state - nothing to destroy."; \
	fi
	@rm -rf ./docker/config/gcp ./secrets/service-account-key.json
