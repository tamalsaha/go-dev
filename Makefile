SHELL=/bin/bash -o pipefail

REGISTRY   ?= appscode
BIN        ?= golang-dev
IMAGE      := $(REGISTRY)/$(BIN)
VERSION    ?= 1.22.7
SRC_REG    ?=

DOCKER_PLATFORMS := linux/amd64 linux/arm64
PLATFORM         ?= $(firstword $(DOCKER_PLATFORMS))
TAG              = $(VERSION)_$(subst /,_,$(PLATFORM))

container-%:
	@$(MAKE) container \
	    --no-print-directory \
	    PLATFORM=$(subst _,/,$*)

push-%:
	@$(MAKE) push \
	    --no-print-directory \
	    PLATFORM=$(subst _,/,$*)

all-container: $(addprefix container-, $(subst /,_,$(DOCKER_PLATFORMS)))

all-push: $(addprefix push-, $(subst /,_,$(DOCKER_PLATFORMS)))

.PHONY: container
ifeq (,$(SRC_REG))
container:
	@echo "container: $(IMAGE):$(TAG)"
	@docker buildx build --platform $(PLATFORM) --load --pull -t $(IMAGE):$(TAG) -f Dockerfile .
	@echo
else
container:
	@echo "container: $(IMAGE):$(TAG)"
	@docker tag $(SRC_REG)/$(BIN):$(TAG) $(IMAGE):$(TAG)
	@echo
endif

push: container
	@docker push $(IMAGE):$(TAG)
	@echo "pushed: $(IMAGE):$(TAG)"
	@echo

# https://stackoverflow.com/a/3732456
VER_MAJOR := $(shell echo $(VERSION) | cut -f1 -d.)
VER_MINOR := $(shell echo $(VERSION) | cut -f2 -d.)
Mm        := $(VER_MAJOR).$(VER_MINOR)

.PHONY: docker-manifest
docker-manifest:
	docker manifest create -a $(IMAGE):$(VERSION) $(foreach PLATFORM,$(DOCKER_PLATFORMS),$(IMAGE):$(VERSION)_$(subst /,_,$(PLATFORM)))
	docker manifest push $(IMAGE):$(VERSION)
	docker manifest create -a $(IMAGE):$(Mm) $(foreach PLATFORM,$(DOCKER_PLATFORMS),$(IMAGE):$(VERSION)_$(subst /,_,$(PLATFORM)))
	docker manifest push $(IMAGE):$(Mm)

.PHONY: release
release:
	@$(MAKE) all-push docker-manifest --no-print-directory

.PHONY: fmt
fmt:
	@find . -path ./vendor -prune -o -name '*.sh' -exec shfmt -l -w -ci -i 4 {} \;

.PHONY: verify
verify: fmt
	@if !(git diff --exit-code HEAD); then \
		echo "files are out of date, run make fmt"; exit 1; \
	fi

.PHONY: ci
ci: verify

# make and load docker image to kind cluster
.PHONY: push-to-kind
push-to-kind: container
	@echo "Loading docker image into kind cluster...."
	@kind load docker-image $(IMAGE):$(TAG)
	@echo "Image has been pushed successfully into kind cluster."
