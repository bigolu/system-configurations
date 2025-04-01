package main

import (
	"flag"
	"fmt"
	"io"
	"log"
	"os"

	"github.com/sanderhahn/gozip"
)

func main() {
	defer func() {
		err := recover()
		gozipErr, ok := err.(gozip.GozipError)
		if ok {
			log.Fatal(gozipErr)
		} else if err != nil {
			panic(err)
		}
	}()

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
		list, err := gozip.UnzipList(path)
		if err != nil {
			gozip.GozipPanic(err)
		}
		for _, f := range list {
			fmt.Printf("%s\n", f)
		}
	} else if extract && (argc == 1 || argc == 2) {
		path := args[0]
		dest := "."
		if argc == 2 {
			dest = args[1]
		}
		err := gozip.Unzip(path, dest)
		if err != nil {
			gozip.GozipPanic(err)
		}
	} else if create && argc > 1 {
		err := gozip.Zip(args[0], args[1:])
		if err != nil {
			gozip.GozipPanic(err)
		}
	}
}
