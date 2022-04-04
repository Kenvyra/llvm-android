FROM registry.fedoraproject.org/fedora-minimal:35

RUN microdnf install -y git-core python3 hostname curl jq rsync patch

RUN curl http://commondatastorage.googleapis.com/git-repo-downloads/repo > /usr/bin/repo && chmod +x /usr/bin/repo

WORKDIR /build
COPY . .

CMD [ "bash", "build.sh" ]
