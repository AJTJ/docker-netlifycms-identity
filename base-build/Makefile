IMAGENAME ?= gasbuddy/netlify-gotrue-git-gateway
IMAGETAG ?= base-build

.PHONY: all build clean publish

all: build

build:
	docker build --no-cache --pull -t $(IMAGENAME):$(IMAGETAG) .

clean:
	docker images | awk -F' ' '{if ($$1=="$(IMAGENAME)" && $$2=="$(IMAGETAG)") print $$3}' | xargs docker rmi

publish:
	docker push $(IMAGENAME):$(IMAGETAG)
