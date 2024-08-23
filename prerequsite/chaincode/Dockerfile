FROM golang:1.17-alpine AS build

WORKDIR /go/src/github.com/chaincode

# Copy go mod and sum files
COPY go.mod go.sum ./

# Download all dependencies
RUN go mod download

# Copy the source from the current directory to the working Directory inside the container
COPY . .

# Build the Go app
RUN go build -o chaincode .

# Start a new stage from scratch
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy the Pre-built binary file from the previous stage
COPY --from=build /go/src/github.com/chaincode/chaincode .

# Expose port 9999
EXPOSE 9999

# Command to run the executable
CMD ["./chaincode"]
