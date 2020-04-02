#
# Targets for building of Kiali from source.
#

## clean: Clean ${GOPATH}/bin/kiali, ${GOPATH}/pkg/*, ${OUTDIR}/docker and the kiali binary
clean:
	@echo Cleaning...
	@rm -f kiali
	@rm -rf ${GOPATH}/bin/kiali
	@[ -d ${GOPATH}/pkg/* ] && chmod -R +rw ${GOPATH}/pkg/* || true
	@rm -rf ${GOPATH}/pkg/*
	@rm -rf ${OUTDIR}/docker

## clean-all: Runs `make clean` internally and remove the _output dir
clean-all: clean
	@rm -rf ${OUTDIR}

## go-check: Check if the go version installed is supported by Kiali
go-check:
	@GO=${GO} hack/check_go_version.sh "${GO_VERSION_KIALI}"

## build: Runs `make go-check` internally and build Kiali binary
build: go-check
	@echo Building...
	${GO_BUILD_ENVVARS} ${GO} build \
		-o ${GOPATH}/bin/kiali -ldflags "-X main.version=${VERSION} -X main.commitHash=${COMMIT_HASH}"

## build-in-docker
build-in-docker:
	@echo Building in docker...
	docker run --rm -i -e GOPATH=/usr/src/myapp -v "${GOPATH}":/usr/src/myapp -w /usr/src/myapp/src/github.com/kiali/kiali/ golang:${GO_VERSION_KIALI} make build

## install: Install missing dependencies. Runs `go install` internally
install:
	@echo Installing...
	${GO_BUILD_ENVVARS} ${GO} install \
		-ldflags "-X main.version=${VERSION} -X main.commitHash=${COMMIT_HASH}"

## format: Format all the files excluding vendor. Runs `gofmt` internally
format:
	@# Exclude more paths find . \( -path './vendor' -o -path <new_path_to_exclude> \) -prune -o -type f -iname '*.go' -print
	@for gofile in $$(find . -path './vendor' -prune -o -type f -iname '*.go' -print); do \
			${GOFMT} -w $$gofile; \
	done

## build-system-test: Building executable for system tests with code coverage enabled
build-system-test:
	@echo Building executable for system tests with code coverage enabled
	${GO} test -c -covermode=count -coverpkg $(shell ${GO} list ./... | grep -v test |  awk -vORS=, "{ print $$1 }" | sed "s/,$$//") \
	  -o ${GOPATH}/bin/kiali -ldflags "-X main.version=${VERSION} -X main.commitHash=${COMMIT_HASH}"

## build-test: Run tests and install test deps, excluding third party tests under vendor. Runs `go test -i`
build-test:
	@echo Building and installing test dependencies to help speed up test runs.
	${GO} test -i $(shell ${GO} list ./... | grep -v -e /vendor/)

## test: Run tests, excluding third party tests under vendor. Runs `go test` internally
test:
	@echo Running tests, excluding third party tests under vendor
	${GO} test $(shell ${GO} list ./... | grep -v -e /vendor/)

## test-debug: Run tests in debug mode, excluding third party tests under vendor. Runs `go test -v`
test-debug:
	@echo Running tests in debug mode, excluding third party tests under vendor
	${GO} test -v $(shell ${GO} list ./... | grep -v -e /vendor/)

## test-race: Run tests with race detection, excluding third party tests under vendor. Runs `go test -race`
test-race:
	@echo Running tests with race detection, excluding third party tests under vendor
	${GO} test -race $(shell ${GO} list ./... | grep -v -e /vendor/)

## test-e2e-setup: Setup Python environment for running test suite
test-e2e-setup:
	@echo Setting up E2E tests
	cd tests/e2e && ./setup.sh

## test-e2e: Run E2E test suite
test-e2e:
	@echo Running E2E tests
	cd tests/e2e && source .kiali-e2e/bin/activate && pytest -s tests/

## run: Run kiali binary
run:
	@echo Running...
	@${GOPATH}/bin/kiali -v 4 -config config.yaml

#
# Dependency management targets
#

## dep-install: Install Glide.
dep-install:
	@echo Installing Glide itself
	@mkdir -p ${GOPATH}/bin
	# We want to pin on a specific version
	# @curl https://glide.sh/get | sh
	@curl https://glide.sh/get | awk '{gsub("get TAG https://glide.sh/version", "TAG=v0.13.1", $$0); print}' | sh

## dep-update: Updating dependencies and storing in vendor directory. Runs `glide update` internally
dep-update:
	@echo Updating dependencies and storing in vendor directory
	@glide update --strip-vendor

#
# Swagger Documentation
#

## swagger-install: Install swagger from github
swagger-install:
	@echo "Installing swagger binary to ${GOPATH}/bin..."
	@curl https://github.com/go-swagger/go-swagger/releases/download/v0.22.0/swagger_linux_amd64 -Lo ${GOPATH}/bin/swagger && chmod +x ${GOPATH}/bin/swagger

## swagger-validate: Validate that swagger.json is correctly. Runs `swagger validate` internally
swagger-validate:
	@swagger validate ./swagger.json

## swagger-gen: Generate that swagger.json from Code. Runs `swagger generate` internally
swagger-gen:
	@swagger generate spec -o ./swagger.json

## swagger-serve: Serve the swagger.json in a website in local. Runs `swagger serve` internally
swagger-serve: swagger-validate
	@swagger serve ./swagger.json

## swagger-travis: Check that swagger.json is the correct one
swagger-travis: swagger-validate
	@swagger generate spec -o ./swagger_copy.json
	@cmp -s swagger.json swagger_copy.json; \
	RETVAL=$$?; \
	if [ $$RETVAL -ne 0 ]; then \
	  echo "SWAGGER FILE IS NOT CORRECT"; exit 1; \
	fi

#
# Lint targets
#

## lint-install: Installs golangci-lint
lint-install:
	curl -sfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $$(${GO} env GOPATH)/bin v1.23.8

## lint: Runs golangci-lint
# doc.go is ommited for linting, because it generates lots of warnings.
lint:
	golangci-lint run --skip-files "doc\.go" --tests --timeout 5m
