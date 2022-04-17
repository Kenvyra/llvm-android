FROM registry.fedoraproject.org/fedora-minimal:35

RUN microdnf install -y \
    binutils \
    curl \
    gcc \
    g++ \
    git-core \
    hostname \
    jq \
    patch \
    perl \
    python3 \
    rsync \
    tar \
    xz \
    bison \
    ncurses-compat-libs \
    ccache \
    patchutils \
    automake \
    autoconf \
    flex \
    gdb \
    glibc-devel \
    libtool \
    pkgconf \
    pkgconf-m4 \
    pkgconf-pkg-config \
    strace \
    bzip2 \
    make \
    openssl \
    openssl-devel \
    procps-ng \
    openssh-clients \
    freetype \
    freetype-devel \
    ninja-build \ # TODO: Below this may be optional
    glibc-devel \
    glibc-devel.i686

RUN curl http://commondatastorage.googleapis.com/git-repo-downloads/repo > /usr/bin/repo && chmod +x /usr/bin/repo

WORKDIR /build
COPY . .

CMD [ "bash", "build.sh" ]
