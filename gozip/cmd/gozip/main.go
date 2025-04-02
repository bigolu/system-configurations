package main

import (
	"flag"
	"fmt"
	"io"
	"os"

	"github.com/sanderhahn/gozip"
)

func main() {
	executablePath, err := os.Executable()
	if err != nil {
		gozip.GozipPanic(err)
	}
	if gozip.HasBoundary(executablePath) {
		exitCode := gozip.SelfExtractAndRunNixEntrypoint()
		os.Exit(exitCode)
	}

	flagSet := flag.NewFlagSet("", flag.ContinueOnError)
	flagSet.SetOutput(io.Discard)
	var list, extract, create bool
	flagSet.BoolVar(&create, "create", false, "create zip (arguments: zipfile [files...])")
	flagSet.BoolVar(&list, "list", false, "list zip (arguments: zipfile)")
	flagSet.BoolVar(&extract, "extract", false, "extract zip (arguments: zipfile [destination]")
	err = flagSet.Parse(os.Args[1:])
	if err != nil {
		gozip.GozipPanic(err)
	}

	args := flagSet.Args()
	argc := len(args)
	if list && argc == 1 {
		path := args[0]
		list := gozip.UnzipList(path)
		for _, f := range list {
			fmt.Printf("%s\n", f)
		}
	} else if extract && (argc == 1 || argc == 2) {
		path := args[0]
		dest := "."
		if argc == 2 {
			dest = args[1]
		}
		gozip.Unzip(path, dest)
	} else if create && argc > 1 {
		gozip.Zip(args[0], args[1:])
	}
}
