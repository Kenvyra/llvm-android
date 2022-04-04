FROM registry.fedoraproject.org/fedora-minimal:35

RUN microdnf install -y \
    binutils \
    curl \
    gcc \
    g++ \
    git-core \
    hostname \
    patch \
    perl \
    python3 \
    rsync

RUN curl http://commondatastorage.googleapis.com/git-repo-downloads/repo > /usr/bin/repo && chmod +x /usr/bin/repo

WORKDIR /build
COPY . .

CMD [ "bash", "build.sh" ]
