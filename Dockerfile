ARG package=arcaflow_plugin_minio
ARG minio_version=20230629051228.0.0

# build poetry
FROM quay.io/centos/centos:stream8 as poetry
ARG package
ARG minio_version
RUN dnf -y module install python39 && dnf -y install python39 python39-pip
RUN dnf -y install https://dl.min.io/server/minio/release/linux-amd64/archive/minio-${minio_version}.x86_64.rpm

WORKDIR /app

COPY poetry.lock /app/
COPY pyproject.toml /app/

RUN python3.9 -m pip install poetry \
# FIX per https://github.com/python-poetry/poetry/issues/5977
 && python3.9 -m poetry add certifi \
 && python3.9 -m poetry config virtualenvs.create false \
 && python3.9 -m poetry install --without dev --no-root\
 && python3.9 -m poetry export -f requirements.txt --output requirements.txt --without-hashes

# run tests
COPY ${package}/ /app/${package}
COPY tests /app/${package}/tests

ENV PYTHONPATH /app/${package}

WORKDIR /app/${package}

RUN mkdir /htmlcov
RUN python3.9 -m pip install coverage
# FIX for some reason, the test was reporting it could not find the yaml module
RUN python3.9 -m pip install -r /app/requirements.txt
RUN python3.9 -m coverage run tests/test_arcaflow_plugin_minio.py
RUN python3.9 -m coverage html -d /htmlcov --omit=/usr/local/*


# final image
FROM quay.io/centos/centos:stream8
ARG package
ARG minio_version
RUN dnf -y module install python39 && dnf -y install python39 python39-pip
RUN dnf -y install https://dl.min.io/server/minio/release/linux-amd64/minio-${minio_version}.x86_64.rpm

WORKDIR /app

COPY --from=poetry /app/requirements.txt /app/
COPY --from=poetry /htmlcov /htmlcov/
COPY LICENSE /app/
COPY README.md /app/
COPY ${package}/ /app/${package}

RUN python3.9 -m pip install -r requirements.txt

RUN mkdir /arca-bucket
RUN chmod 777 /arca-bucket

WORKDIR /app/${package}

ENTRYPOINT ["python3.9", "minio_plugin.py"]
CMD []

LABEL org.opencontainers.image.source="https://github.com/arcalot/arcaflow-plugin-minio"
LABEL org.opencontainers.image.licenses="Apache-2.0+GPL-2.0+AGPL-3.0-only"
LABEL org.opencontainers.image.vendor="Arcalot project"
LABEL org.opencontainers.image.authors="Arcalot contributors"
LABEL org.opencontainers.image.title="Arcaflow MinIO plugin"
LABEL io.github.arcalot.arcaflow.plugin.version="1"
