FROM registry.fedoraproject.org/fedora-minimal:37

RUN microdnf install -y \
    autoconf \
    automake \
    bc \
    binutils \
    binutils-devel \
    bison \
    bzip2 \
    curl \
    diffutils \
    elfutils-libelf-devel \
    file \
    findutils \
    flex \
    freetype \
    freetype-devel \
    g++ \
    gcc \
    gdb \
    git-core \
    glibc-devel \
    glibc-devel.i686 \
    hdf5-devel \
    hostname \
    jq \
    libtool \
    make \
    musl-libc \
    ncurses-compat-libs \
    openssh-clients \
    openssl \
    openssl-devel \
    patch \
    patchelf \
    patchutils \
    perf \
    perl \
    pkgconf \
    pkgconf-m4 \
    pkgconf-pkg-config \
    procps-ng \
    python3 \
    python3-pip \
    python3-devel \
    rsync \
    ninja-build \
    strace \
    tar \
    texinfo \
    uboot-tools \
    xz \
    zlib-devel

RUN curl http://commondatastorage.googleapis.com/git-repo-downloads/repo > /usr/bin/repo && chmod +x /usr/bin/repo

RUN pip install tf-nightly-cpu

ENV TENSORFLOW_INSTALL=/usr/local/lib64/python3.11/site-packages/tensorflow

WORKDIR /build
COPY . .

CMD [ "bash" ]
