package main

import (
	"fmt"
	"os"
	"runtime"
)

func main() {
	fmt.Printf("Hello from Go!\n")
	fmt.Printf("OS: %s\n", runtime.GOOS)
	fmt.Printf("Arch: %s\n", runtime.GOARCH)
	fmt.Printf("Working directory: %s\n", os.Getenv("PWD"))

	// Your container/runtime logic here
	fmt.Println("This is where your container runtime would go!")
}
