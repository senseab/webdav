FROM golang:1.21 as build

ENV CGO_ENABLED=0
COPY ./ /webdav
RUN cd /webdav && go build -tags netgo -trimpath -ldflags "-w -s" -o webdav

FROM scratch

CMD [ "-c", "/config/config.yaml" ]
ENTRYPOINT [ "/webdav" ]

COPY --from=build /webdav/webdav /webdav

WORKDIR /files
