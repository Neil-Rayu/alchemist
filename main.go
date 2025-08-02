package main

// go run main.go
// ./myapp  <cmd> <pramas?>

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"syscall"
)

func main() {
	switch os.Args[1] {
	case "run":
		run()
	case "child":
		child()
	case "mkfs":
		mkfs()
	default:
		panic("Unrecognized CMD")
	}
}

func run() {
	fmt.Printf("OS: %s\n", runtime.GOOS)
	fmt.Printf("Arch: %s\n", runtime.GOARCH)
	fmt.Printf("Working directory: %s\n", os.Getenv("PWD"))

	fmt.Printf("bombadrio-uno %v as %d\n", os.Args[2:], os.Getpid())
	cmd := exec.Command("/proc/self/exe", append([]string{"child"}, os.Args[2:]...)...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if runtime.GOOS == "linux" {
		cmd.SysProcAttr = &syscall.SysProcAttr{
			Cloneflags:   syscall.CLONE_NEWUTS | syscall.CLONE_NEWPID | syscall.CLONE_NEWNS,
			Unshareflags: syscall.CLONE_NEWNS,
		}
	}
	cmd.Run()
}

func child() {
	fmt.Printf("bombadrio-dos %v as %d\n", os.Args[2:], os.Getpid())

	syscall.Sethostname([]byte("container"))

	cmd := exec.Command(os.Args[2], os.Args[3:]...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	cmd.Run()
}

func mkfs() {

}

func cg() {
	cgroups := "/sys/fs/cgroup/"
	pids := filepath.Join(cgroups, "pids")
	os.Mkdir(filepath.Join(pids, "alchemist"), 0755)
	os.WriteFile(filepath.Join(pids, "alchemist/pids.max"), []byte("20"), 0700)
	// Removes the new cgroup in place after the container exits
	os.WriteFile(filepath.Join(pids, "alchemist/notify_on_release"), []byte("1"), 0700)
	os.WriteFile(filepath.Join(pids, "alchemist/cgroup.procs"), []byte(strconv.Itoa(os.Getpid())), 0700)
}
