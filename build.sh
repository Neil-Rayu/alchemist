#!/bin/bash

echo "Building Go binary for Linux..."
GOOS=linux GOARCH=amd64 go build -o myapp main.go

# Copy to shared folder
mkdir -p shared
cp myapp shared/

echo "Binary ready in shared folder!"
echo "In Alpine: /shared/myapp"