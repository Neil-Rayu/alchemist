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
	"time"

	"github.com/alexflint/go-arg"
)

type args struct {
	Input   string   `arg:"positional,required" help:"input file, or mkfs"`
	MaxPids int      `arg:"-p, --maxpid" help:"Maximum number of PIDs allowed in the container"`
	Cmd     []string `arg:"positional,required" help:"Command to run inside container"`
}

func main() {
	var args args
	arg.MustParse(&args)
	switch args.Input {
	case "run":
		run(args.Cmd)
	case "child":
		child(args.Cmd, args.MaxPids)
	case "mkfs":
		mkfs()
	default:
		panic("Unrecognized CMD, use --help")
	}
}

func run(commandArgs []string) {
	fmt.Printf("OS: %s\n", runtime.GOOS)
	fmt.Printf("Arch: %s\n", runtime.GOARCH)
	fmt.Printf("Working directory: %s\n", os.Getenv("PWD"))

	fmt.Printf("bombadrio-uno %v as %d\n", commandArgs, os.Getpid())
	cmd := exec.Command("/proc/self/exe", append([]string{"child"}, commandArgs...)...)
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

func setupCgroups() {
	// Create directories
	os.MkdirAll("/sys/fs/cgroup", 0755)
	syscall.Mount("tmpfs", "/sys/fs/cgroup", "tmpfs", 0, "")

	os.MkdirAll("/sys/fs/cgroup/pids", 0755)
	os.MkdirAll("/sys/fs/cgroup/cpu", 0755)

	// Mount controllers directly (no tmpfs needed)
	err1 := syscall.Mount("cgroup", "/sys/fs/cgroup/pids", "cgroup", 0, "pids")
	err2 := syscall.Mount("cgroup", "/sys/fs/cgroup/cpu", "cgroup", 0, "cpu")

	if err1 != nil {
		fmt.Printf("Error mounting pids cgroup: %v\n", err1)
	}
	if err2 != nil {
		fmt.Printf("Error mounting cpu cgroup: %v\n", err2)
	}

	fmt.Println("Cgroups mounted successfully")
}

func child(commandArgs []string, maxPids int) {
	fmt.Printf("bombadrio-dos %v as %d\n", commandArgs[0], os.Getpid())

	setupCgroups()

	time.Sleep(100 * time.Microsecond)

	//Handle Max Pids default value should be 20.
	if maxPids != 0 {
		cg(maxPids)
	} else {
		cg(20)
	}

	cmd := exec.Command(commandArgs[0], commandArgs[1:]...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	syscall.Sethostname([]byte("container"))
	syscall.Chroot("/tmp/alpine-minifs")
	os.Chdir("/")
	syscall.Mount("proc", "proc", "proc", 0, "")

	cmd.Run()

	syscall.Unmount("proc", 0)

}

func mkfs() {
	panic("not implemented")
}

func cg(maxPids int) {
	cgroups := "/sys/fs/cgroup/"
	pids := filepath.Join(cgroups, "pids")
	os.Mkdir(filepath.Join(pids, "alchemist"), 0755)

	maxPidsStr := strconv.Itoa(maxPids)

	// Write the files
	os.WriteFile(filepath.Join(pids, "alchemist/pids.max"), []byte(maxPidsStr), 0700)
	os.WriteFile(filepath.Join(pids, "alchemist/notify_on_release"), []byte("1"), 0700)
	os.WriteFile(filepath.Join(pids, "alchemist/cgroup.procs"), []byte(strconv.Itoa(os.Getpid())), 0700)

	fmt.Printf("Created cgroup alchemist with max PIDs: %d\n", maxPids)
}
