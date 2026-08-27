# Adapted from frappe_docker images/layered/Containerfile.
# Changes: pinned to version-15, apps.json COPYed in (Coolify builds
# don't support build secrets), entrypoint scripts vendored in ./resources.
ARG FRAPPE_BRANCH=version-15
ARG FRAPPE_IMAGE_PREFIX=frappe

FROM ${FRAPPE_IMAGE_PREFIX}/build:${FRAPPE_BRANCH} AS builder

ARG FRAPPE_BRANCH=version-15
ARG FRAPPE_PATH=https://github.com/frappe/frappe

USER frappe

COPY --chown=frappe:frappe apps.json /opt/frappe/apps.json

RUN bench init --apps_path=/opt/frappe/apps.json \
    --frappe-branch=${FRAPPE_BRANCH} \
    --frappe-path=${FRAPPE_PATH} \
    --no-procfile \
    --no-backups \
    --skip-redis-config-generation \
    --verbose \
    /home/frappe/frappe-bench && \
  cd /home/frappe/frappe-bench && \
  echo "{}" > sites/common_site_config.json && \
  find apps -mindepth 1 -path "*/.git" | xargs rm -fr

# whitelabel installed separately: its version-15 pyproject wrongly pins
# frappe/pypika/gunicorn (bench manages those), which breaks uv resolution.
# Strip the deps, then install from the patched local copy.
# The patch must be COMMITTED: bench get-app git-clones the local repo,
# which drops uncommitted changes.
RUN git clone --depth 1 -b version-15 https://github.com/bhavesh95863/whitelabel /tmp/whitelabel && \
  sed -i '/^dependencies = \[/,/^\]/c\dependencies = []' /tmp/whitelabel/pyproject.toml && \
  grep -q 'dependencies = \[\]' /tmp/whitelabel/pyproject.toml && \
  git -C /tmp/whitelabel -c user.email=build@growwwtech.com -c user.name=build \
    commit -am "build: strip bench-managed deps from pyproject" && \
  cd /home/frappe/frappe-bench && \
  bench get-app /tmp/whitelabel && \
  rm -rf /tmp/whitelabel apps/whitelabel/.git

FROM ${FRAPPE_IMAGE_PREFIX}/base:${FRAPPE_BRANCH} AS backend

USER frappe

COPY --from=builder --chown=frappe:frappe /home/frappe/frappe-bench /home/frappe/frappe-bench

WORKDIR /home/frappe/frappe-bench

# Move assets to image-layer storage
RUN cp -r /home/frappe/frappe-bench/sites/assets /home/frappe/frappe-bench/assets && \
  rm -rf /home/frappe/frappe-bench/sites/assets

VOLUME [ \
  "/home/frappe/frappe-bench/sites", \
  "/home/frappe/frappe-bench/logs" \
]

USER root
COPY resources/main-entrypoint.sh /usr/local/bin/entrypoint.sh
COPY resources/start.sh /usr/local/bin/start.sh
COPY scripts/create-sites.sh /usr/local/bin/create-sites.sh
COPY scripts/reset-demos.sh /usr/local/bin/reset-demos.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh /usr/local/bin/start.sh \
  /usr/local/bin/create-sites.sh /usr/local/bin/reset-demos.sh

USER frappe
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["start.sh"]
