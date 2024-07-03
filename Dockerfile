FROM golang:1.22.5

ARG TARGETOS
ARG TARGETARCH
ARG VERSION

LABEL org.opencontainers.image.source https://github.com/appscodelabs/golang-dev

RUN set -x \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
    apt-utils         \
    bash              \
    build-essential   \
    bzip2             \
    bzr               \
    ca-certificates   \
    curl              \
    git               \
    gnupg             \
    mercurial         \
    protobuf-compiler \
    socat             \
    wget              \
    xz-utils          \
    zip               \
  && rm -rf /var/lib/apt/lists/* /usr/share/doc /usr/share/man /tmp/*

# https://candid.technology/error-obtaining-vcs-status-exit-status-128/
# https://stackoverflow.com/a/73100228
RUN set -x \
  && git config --global --add safe.directory '*' \
  && cp /root/.gitconfig /.gitconfig

# install protobuf
RUN mkdir -p /go/src/github.com/golang \
  && cd /go/src/github.com/golang \
  && rm -rf protobuf \
  && git clone https://github.com/golang/protobuf.git \
  && cd protobuf \
  && git checkout v1.3.1 \
  && GO111MODULE=on go install ./... \
  && cd /go \
  && rm -rf /go/pkg /go/src

RUN set -x \
  && curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b /usr/local/bin v1.59.1

# https://github.com/golangci/golangci-lint/pull/2438#issuecomment-1069262198
# RUN set -x \
#   && export GOBIN=/usr/local/go/bin \
#   && mkdir -p /go/src/github.com/golangci \
#   && cd /go/src/github.com/golangci \
#   && git clone https://github.com/golangci/golangci-lint.git \
#   && cd golangci-lint \
#   && git fetch origin refs/pull/2438/merge:go1.18 \
#   && git checkout go1.18 \
#   && go install -v ./cmd/golangci-lint \
#   && export GOBIN=

RUN set -x \
  && export GOBIN=/usr/local/go/bin \
  && go install github.com/bwplotka/bingo@main \
  && bingo get -l github.com/bwplotka/bingo@main \
  && bingo get -l github.com/go-delve/delve/cmd/dlv@v1.22.1 \
  && bingo get -l golang.org/x/tools/cmd/goimports \
  # replace gofmt with https://github.com/mvdan/gofumpt
  && rm -rf /usr/local/go/bin/gofmt \
  && bingo get -l -n gofmt mvdan.cc/gofumpt@v0.4.0 \
  && bingo get -l github.com/onsi/ginkgo/v2/ginkgo@v2.1.4 \
  && bingo get -l github.com/appscodelabs/gh-tools@v0.2.13 \
  && bingo get -l github.com/appscodelabs/hugo-tools@v0.2.25 \
  && bingo get -l github.com/appscodelabs/ltag@v0.2.0 \
  && bingo get -l github.com/vbatts/git-validation@master \
  && bingo get -l mvdan.cc/sh/v3/cmd/shfmt@v3.4.3 \
  && bingo get -l kubepack.dev/chart-doc-gen@v0.4.7 \
  && bingo get -l github.com/go-bindata/go-bindata/go-bindata@latest \
  && go install golang.org/x/vuln/cmd/govulncheck@latest \
  && go install github.com/abice/go-enum@latest \
  && export GOBIN= \
  && cd /go \
  && rm -rf /go/pkg /go/src

COPY reimport.py /usr/local/bin/reimport.py
COPY reimport3.py /usr/local/bin/reimport3.py

RUN set -x                                        \
  && wget https://dl.k8s.io/$(curl -fsSL https://storage.googleapis.com/kubernetes-release/release/stable.txt)/kubernetes-client-linux-${TARGETARCH}.tar.gz \
  && tar -xzvf kubernetes-client-linux-${TARGETARCH}.tar.gz \
  && mv kubernetes/client/bin/kubectl /usr/bin/kubectl \
  && chmod +x /usr/bin/kubectl \
  && rm -rf kubernetes kubernetes-client-linux-${TARGETARCH}.tar.gz

RUN set -x \
  && cd /usr/local/bin \
  && curl -fsSL -o helm https://github.com/x-helm/helm/releases/download/ac-1.29.0/helm-$TARGETOS-$TARGETARCH \
  && chmod +x helm
