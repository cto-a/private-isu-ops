FROM golang:1.20

RUN mkdir -p /opt/go
COPY . /opt/go
WORKDIR /opt/go
RUN go build -o bin/benchmarker

ENTRYPOINT ["/opt/go/run.sh", "./bin/benchmarker", "-u", "./userdata"]
