# Use the official PostgreSQL image as the base image
FROM postgres:14.23

# Non-interactive apt for the build
ENV DEBIAN_FRONTEND=noninteractive

ENV POSTGRES_USER=postgres
# Default database for superuser psql calls that pass no -d (see demo.sh)
ENV PGDATABASE=postgres

# POSTGRES_PASSWORD is provided at run time (-e), not baked into the image

# Dependencies for adding the pgdg apt repo below
RUN apt-get update && \
    apt-get install -y lsb-release ca-certificates wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Add the PostgreSQL APT repository (signed-by keyring) and install pgBackRest.
# Pinned for reproducible builds; bump when pgdg prunes this version from the repo.
RUN wget --quiet -O /usr/share/keyrings/pgdg.asc https://www.postgresql.org/media/keys/ACCC4CF8.asc && \
    echo "deb [signed-by=/usr/share/keyrings/pgdg.asc] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    apt-get update && \
    apt-get install -y pgbackrest=2.58.0-1.pgdg13+1 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Note: pgBackRest talks to GCS natively (repo1-gcs-key); no gcloud CLI needed
# in the image. The host's gcloud is only used by scripts/clean.sh.

# pgBackRest config is NOT baked in - run-database.sh bind-mounts the per-target
# config dir (static local/, or Terraform-generated gcp/ with its bucket), so one
# image serves both modes and a new bucket needs no rebuild. Also create the
# postgres conf.d the archive_command drop-in is mounted into (include_dir in the
# sample).
RUN mkdir -p /etc/pgbackrest /etc/postgresql/conf.d

# Postgres config (applied to the data dir on first init). We ship no custom
# pg_hba.conf - the official image generates it. Network exposure is constrained
# by binding the mapped ports to loopback (see scripts/run-*.sh), not by pg_hba.
COPY config/postgresql.conf.sample /usr/share/postgresql/postgresql.conf.sample

# pgBackRest backup/restore scripts onto PATH
COPY ./scripts/pgbackrest /usr/local/bin

# Seed roles, database and sample data on first init
COPY scripts/init/init-user-db.sh /docker-entrypoint-initdb.d/

# Create the non-root user, make our scripts runnable, and give it ownership of
# the dirs it reads/writes (single layer to avoid duplicating trees on disk)
RUN useradd -u 1000 -g postgres -m myuser && \
    chmod +x /usr/local/bin/*.sh && \
    chown myuser:postgres /usr/local/bin/*.sh && \
    chown -R myuser:postgres \
        /etc/pgbackrest \
        /var/lib/postgresql \
        /var/run/postgresql \
        /var/lib/pgbackrest \
        /var/log/pgbackrest \
        /var/log/postgresql

# Run as non-root, uid pinned to 1000 (above) so host-written bind mounts like
# secrets/ are readable inside the container
USER myuser

# Put the postgres binaries and our scripts on the interactive PATH
RUN echo 'export PATH=$PATH:/usr/lib/postgresql/14/bin:/usr/local/bin' >> ~/.bashrc

# Expose the default PostgreSQL port
EXPOSE 5432

# Start the PostgreSQL service
CMD ["postgres"]
