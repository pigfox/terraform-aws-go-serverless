# Two stages: build a static Go binary, then copy it into an empty image.
# The final image has no shell and no package manager, runs as a non-root
# user, and is a few megabytes, which keeps ECR storage and pull time small.
FROM --platform=$BUILDPLATFORM golang:1.26-alpine AS build
ARG TARGETOS=linux
ARG TARGETARCH=arm64
WORKDIR /src
COPY go.mod ./
COPY *.go ./
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath -ldflags='-s -w' -o /out/job .

FROM scratch
COPY --from=build /out/job /job
USER 65532:65532
ENTRYPOINT ["/job"]
