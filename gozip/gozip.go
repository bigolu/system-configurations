package gozip

import (
	"archive/tar"
	"bytes"
	"context"
	"crypto/sha256"
	"crypto/sha512"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"log"
	"math/rand"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"

	"github.com/klauspost/compress/zstd"
	"github.com/schollz/progressbar/v3"
	"golang.org/x/sync/errgroup"
	"golang.org/x/sync/semaphore"
	"golang.org/x/term"
)

var currentBar *progressbar.ProgressBar = nil

var writer = func() io.Writer {
	if term.IsTerminal(int(os.Stderr.Fd())) && len(os.Getenv("NIX_ROOTLESS_BUNDLER_QUIET")) == 0 {
		return os.Stderr
	}

	return io.Discard
}()

// since both the rewrite and extract steps need the total file count I'll store
// it here so I don't have to get it twice
var archiveCount int = 0

var boundary = func() []byte {
	hash := sha512.Sum512([]byte("boundary"))
	return hash[:]
}()

func nextStep(count int, name string, options ...progressbar.Option) *progressbar.ProgressBar {
	endProgress()
	description := fmt.Sprintf("[cyan]%s[reset]...", name)
	defaultOptions := []progressbar.Option{
		progressbar.OptionEnableColorCodes(true),
		progressbar.OptionSetWidth(20),
		progressbar.OptionSetRenderBlankState(true),
		progressbar.OptionSetWriter(writer),
		progressbar.OptionSetDescription(description),
		// the progress bar was flickering a lot when this wasn't set:
		// https://github.com/schollz/progressbar/issues/87
		progressbar.OptionUseANSICodes(true),
		// Since the ANSI way of clearing the line isn't working, if
		// the progress bar gets larger and then smaller, the larger
		// part won't get cleared. This can happen when predicting time
		// remaining since the estimate can get smaller so I'm disabling
		// this.
		progressbar.OptionSetPredictTime(false),
	}
	currentBar = progressbar.NewOptions(count, append(defaultOptions, options...)...)

	return currentBar
}

// For my progress bars I set the option 'UseANSICodes' so it doesn't flicker,
// but the ANSI way of clearing the line doesn't seem to be working so below is
// the code used to clear the line if 'UseANSICodes' isn't enabled:
// https://github.com/schollz/progressbar/blob/304f5f42a0a10315cae471d8530e13b6c1bdc4fe/progressbar.go#L1007
func writeString(w io.Writer, str string) {
	if _, err := io.WriteString(w, str); err != nil {
		panic(err)
	}

	if f, ok := w.(*os.File); ok {
		// ignore any errors in Sync(), as stdout can't be synced on
		// some operating systems like Debian 9 (Stretch)
		f.Sync() //nolint:errcheck
	}
}
func clearProgressBar() {
	width, _, err := term.GetSize(2)
	if err != nil {
		panic(err)
	}
	str := fmt.Sprintf("\r%s\r", strings.Repeat(" ", width))
	writeString(writer, str)
}

func endProgress() {
	if currentBar != nil {
		// So the spinner stops. We have to do this before calling clear or else the
		// spinner will just render the bar again.
		err := currentBar.Finish()
		if err != nil {
			panic(err)
		}

		err = currentBar.Clear()
		if err != nil {
			panic(err)
		}
		clearProgressBar()
		currentBar = nil
	}
}

func isSymlink(path string) bool {
	fileInfo, err := os.Lstat(path)
	if err != nil {
		panic(err)
	}
	return fileInfo.Mode()&os.ModeSymlink == os.ModeSymlink
}

func Zip(destinationPath string, filesToZip []string) {
	destinationFile, err := os.OpenFile(destinationPath, os.O_RDWR|os.O_CREATE|os.O_APPEND, 0644)
	if err != nil {
		panic(err)
	}
	defer func() {
		errFromDefer := destinationFile.Close()
		if err != nil || errFromDefer != nil {
			panic(errors.Join(err, errFromDefer))
		}
	}()

	// To make a self extracting archive, the `destinationPath` can be the
	// executable that does the extraction. For this reason, we set the
	// `startoffset` to `io.SeekEnd`. This way we append the contents of
	// the archive after the executable. Check the README for an example of
	// making a self-extracting archive.
	_, err = destinationFile.Seek(0, io.SeekEnd)
	if err != nil {
		panic(err)
	}
	_, err = destinationFile.Write(boundary)
	if err != nil {
		panic(err)
	}

	zWrt, err := zstd.NewWriter(destinationFile, zstd.WithEncoderLevel(zstd.SpeedBestCompression))
	if err != nil {
		panic(err)
	}
	defer func() {
		errFromDefer := zWrt.Close()
		if err != nil || errFromDefer != nil {
			panic(errors.Join(err, errFromDefer))
		}
	}()
	tarWrt := tar.NewWriter(zWrt)
	defer func() {
		errFromDefer := tarWrt.Close()
		if err != nil || errFromDefer != nil {
			panic(errors.Join(err, errFromDefer))
		}
	}()

	cd := "."
	for _, file := range filesToZip {
		rootDir := os.DirFS(cd)
		file = filepath.Clean(file)

		// If the input file is a symlink, don't dereference it.
		isSymlink := isSymlink(file)
		if isSymlink {
			var hdr tar.Header
			hdr.Name = file

			hdr.Typeflag = tar.TypeSymlink
			target, err := filepath.EvalSymlinks((filepath.Join(cd, file)))
			if err != nil {
				panic(err)
			}
			hdr.Linkname = target

			err = tarWrt.WriteHeader(&hdr)
			if err != nil {
				panic(err)
			}

			continue
		}

		err = fs.WalkDir(rootDir, file, func(path string, d fs.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if path == "." {
				return nil
			}

			var hdr tar.Header
			hdr.Name = path

			info, err := d.Info()
			if err != nil {
				return err
			}
			mode := info.Mode()
			hdr.Mode = int64(mode)

			switch mode.Type() {
			case fs.ModeDir:
				hdr.Typeflag = tar.TypeDir
			case fs.ModeSymlink:
				hdr.Typeflag = tar.TypeSymlink
				target, err := os.Readlink(filepath.Join(cd, path))
				if err != nil {
					return err
				}
				hdr.Linkname = target
			case 0: // regular file
				hdr.Typeflag = tar.TypeReg
				hdr.Size = info.Size()
			default:
				panic(fmt.Errorf("unsupported file type: %s", path))
			}

			err = tarWrt.WriteHeader(&hdr)
			if err != nil {
				return err
			}

			if mode.Type() == 0 {
				wf, err := os.Open(filepath.Join(cd, path))
				if err != nil {
					return err
				}
				_, err = io.Copy(tarWrt, wf)
				if err != nil {
					return err
				}
				err = wf.Close()
				if err != nil {
					return err
				}
			}

			return nil
		})
		if err != nil {
			panic(err)
		}
	}
}

func createFile(path string) *os.File {
	dir := filepath.Dir(path)
	err := os.MkdirAll(dir, 0755)
	if err != nil {
		panic(err)
	}
	f, err := os.Create(path)
	if err != nil {
		panic(err)
	}

	return f
}

func cleanup(dir string) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		panic(err)
	}

	for _, entry := range entries {
		err := os.RemoveAll(filepath.Join(dir, entry.Name()))
		if err != nil {
			panic(err)
		}
	}
}

func getBoundaryOffset(fileName string) int {
	fileBytes, err := os.ReadFile(fileName)
	if err != nil {
		panic(err)
	}

	return bytes.Index(fileBytes, boundary)
}

func HasBoundary(fileName string) bool {
	boundaryOffset := getBoundaryOffset(fileName)

	if boundaryOffset == -1 {
		return false
	} else {
		return true
	}
}

func seekToTar(file os.File) os.File {
	boundaryOffset := getBoundaryOffset(file.Name())
	if boundaryOffset == -1 {
		panic(errors.New("no boundary"))
	}

	payloadOffset := boundaryOffset + len(boundary)

	_, err := file.Seek(int64(payloadOffset), io.SeekStart)
	if err != nil {
		panic(err)
	}

	return file
}

// Unzip unzips the file zippath and puts it in destination
func Unzip(zippath string, destination string) {
	nextStep(
		-1,
		"Calculating archive size",
		progressbar.OptionSpinnerType(14),
	)
	files := UnzipList(zippath)
	archiveCount = len(files)

	progressBar := nextStep(
		archiveCount,
		"Extracting archive",
		progressbar.OptionShowCount(),
	)

	zipFile, err := os.Open(zippath)
	if err != nil {
		panic(err)
	}
	defer func() {
		errFromDefer := zipFile.Close()
		if err != nil || errFromDefer != nil {
			panic(errors.Join(err, errFromDefer))
		}
	}()
	seekToTar(*zipFile)

	zRdr, err := zstd.NewReader(zipFile)
	if err != nil {
		panic(err)
	}
	defer zRdr.Close()
	tarRdr := tar.NewReader(zRdr)

	err = os.RemoveAll(destination)
	if err != nil {
		panic(err)
	}
	err = os.Mkdir(destination, 0755)
	if err != nil {
		panic(err)
	}

	defer func() {
		recoverErr := recover()
		if recoverErr != nil {
			cleanup(destination)
			panic(recoverErr)
		}
	}()

	for {
		hdr, err := tarRdr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			panic(err)
		}

		name := filepath.Clean(hdr.Name)
		if name == "." {
			continue
		}
		pathName := filepath.Join(destination, name)
		switch hdr.Typeflag {
		case tar.TypeReg:
			f := createFile(pathName)

			_, err = io.Copy(f, tarRdr)
			if err != nil {
				panic(err)
			}

			err = f.Chmod(os.FileMode(hdr.Mode))
			if err != nil {
				panic(err)
			}

			err = f.Close()
			if err != nil {
				panic(err)
			}
		case tar.TypeDir:
			// We choose to disregard directory permissions and use a default
			// instead. Custom permissions (e.g. read-only directories) are
			// complex to handle, both when extracting and also when cleaning
			// up the directory.
			err := os.Mkdir(pathName, 0755)
			if err != nil {
				panic(err)
			}
		case tar.TypeSymlink:
			err := os.Symlink(hdr.Linkname, pathName)
			if err != nil {
				panic(err)
			}
		default:
			panic(errors.New("unsupported file type"))
		}

		err = progressBar.Add(1)
		if err != nil {
			panic(err)
		}
	}
}

// UnzipList Lists all the files in zip file
func UnzipList(path string) (list []string) {
	zipFile, err := os.Open(path)
	if err != nil {
		panic(err)
	}
	defer func() {
		errFromDefer := zipFile.Close()
		if err != nil || errFromDefer != nil {
			panic(errors.Join(err, errFromDefer))
		}
	}()
	seekToTar(*zipFile)

	zRdr, err := zstd.NewReader(zipFile)
	if err != nil {
		panic(err)
	}
	defer zRdr.Close()
	tarRdr := tar.NewReader(zRdr)

	for {
		hdr, err := tarRdr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			panic(err)
		}

		name := filepath.Clean(hdr.Name)
		if name == "." {
			continue
		}
		list = append(list, name)
	}

	return list
}

func createDirectoryIfNotExtant(path string) {
	err := os.MkdirAll(path, 0755)
	if err != nil {
		panic(err)
	}
}

func isFileExtant(path string) bool {
	_, err := os.Stat(path)
	if err == nil {
		return true
	} else if errors.Is(err, fs.ErrNotExist) {
		return false
	} else {
		return false
	}
}

func isSymlinkExtant(path string) bool {
	_, err := os.Lstat(path)
	if err == nil {
		return true
	} else if errors.Is(err, fs.ErrNotExist) {
		return false
	} else {
		return false
	}
}

func getFileCount(path string) int {
	count := 0

	err := filepath.Walk(path, filepath.WalkFunc(func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			return nil
		}

		count = count + 1

		return nil
	}))

	if err != nil {
		panic(fmt.Errorf("getting file count: %s", err))
	}

	return count
}

func rewritePaths(archiveContentsPath string, oldStorePath string, newStorePath string) {
	if archiveCount == 0 {
		nextStep(
			-1,
			"Calculating archive size",
			progressbar.OptionSpinnerType(14),
		)
		archiveCount = getFileCount(archiveContentsPath)
	}

	progressBar := nextStep(
		archiveCount,
		"Rewriting store paths",
		progressbar.OptionShowCount(),
	)
	archiveContents, err := os.Open(archiveContentsPath)
	if err != nil {
		panic(err)
	}
	defer func() {
		errFromDefer := archiveContents.Close()
		if err != nil || errFromDefer != nil {
			panic(errors.Join(err, errFromDefer))
		}
	}()

	// The top level files in the archive are the directories of the Nix
	// packages so we can use those directory names to get a list of all the
	// package paths that need to be rewritten in the binaries.
	//
	// The 0 means return all files in the directory, as opposed to setting
	// a max.
	topLevelFilesInArchive, err := archiveContents.Readdir(0)
	if err != nil {
		panic(err)
	}
	var oldAndNewPackagePaths []string
	extraSlashesCount := len(oldStorePath) - len(newStorePath)
	// The new store path must be the same length as the old one or it
	// messes up the binary.
	newStorePathWithPadding := strings.Replace(newStorePath, "/", strings.Repeat("/", extraSlashesCount+1), 1)
	for _, file := range topLevelFilesInArchive {
		name := file.Name()
		oldPackagePath := filepath.Join(oldStorePath, name)
		// I'm intentionally not using `filepath.Join` here since it
		// normalizes the path which would remove the padding.
		newPackagePath := newStorePathWithPadding + "/" + name
		oldAndNewPackagePaths = append(oldAndNewPackagePaths, oldPackagePath, newPackagePath)
	}
	replacer := strings.NewReplacer(oldAndNewPackagePaths...)

	ctx := context.TODO()
	g, ctx := errgroup.WithContext(ctx)
	var (
		maxWorkers = runtime.GOMAXPROCS(0)
		sem        = semaphore.NewWeighted(int64(maxWorkers))
	)
	err = filepath.Walk(archiveContentsPath, filepath.WalkFunc(func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			return nil
		}

		if err := sem.Acquire(ctx, 1); err != nil {
			return err
		}
		g.Go(func() error {
			defer sem.Release(1)
			err = progressBar.Add(1)
			if err != nil {
				return err
			}
			if info.Mode()&os.ModeSymlink != 0 {
				str, err := os.Readlink(path)
				if err != nil {
					log.Println(err)
					return err
				}
				if strings.HasPrefix(str, oldStorePath) {
					newTarget := strings.Replace(str, oldStorePath, newStorePath, 1)
					err = os.Remove(path)
					if err != nil {
						log.Println(err)
						return err
					}
					err = os.Symlink(newTarget, path)
					if err != nil {
						log.Println(err)
						return err
					}
				}
				return nil
			}

			fileContents, err := os.ReadFile(path)
			if err != nil {
				log.Println(err)
				return err
			}
			newFileContents := replacer.Replace(string(fileContents))
			err = os.WriteFile(path, []byte(newFileContents), 0)
			if err != nil {
				log.Println(err)
				return err
			}
			return nil
		})

		return nil
	}))
	if err != nil {
		panic(err)
	}

	err = g.Wait()
	if err != nil {
		panic(err)
	}
}

func getNewStorePath() (prefix string) {
	random := rand.New(rand.NewSource(time.Now().UnixNano()))
	charset := "abcdefghijklmnopqrstuvwxyz"
	var candidatePrefix string
	for i := 1; i <= 1000; i++ {
		candidatePrefix = "/tmp/"

		// needs to be <= 5 since it will be appended to '/tmp/' and
		// needs to be <= '/nix/store'
		stringLength := 5
		for i := 1; i <= stringLength; i++ {
			candidatePrefix = candidatePrefix + string(charset[random.Intn(len(charset))])
		}

		if !isFileExtant(candidatePrefix) {
			return candidatePrefix
		}
	}

	panic(errors.New("unable to find a new store prefix"))
}

func extractArchiveAndRewritePaths() (extractedArchivePath string, executableCachePath string) {
	nextStep(
		-1,
		"Checking cache",
		progressbar.OptionSpinnerType(14),
	)

	cachePath := filepath.Join(os.TempDir(), "nix-rootless-bundler")
	createDirectoryIfNotExtant(cachePath)

	executablePath, err := os.Executable()
	if err != nil {
		panic(err)
	}

	executableName := filepath.Base(executablePath)
	executableCachePath = filepath.Join(cachePath, executableName)
	createDirectoryIfNotExtant(executableCachePath)

	executable, err := os.Open(executablePath)
	if err != nil {
		panic(err)
	}
	defer func() {
		errFromDefer := executable.Close()
		if err != nil || errFromDefer != nil {
			panic(errors.Join(err, errFromDefer))
		}
	}()
	hash := sha256.New()
	_, err = io.Copy(hash, executable)
	if err != nil {
		panic(err)
	}
	expectedExecutableChecksum := []byte(hex.EncodeToString(hash.Sum(nil)))
	archiveContentsPath := filepath.Join(executableCachePath, "archive-contents")

	isNewExtraction := false
	executableChecksumFile := filepath.Join(executableCachePath, "checksum.txt")
	executableChecksumFileExists := isFileExtant(executableChecksumFile)
	if executableChecksumFileExists {
		checksum, err := os.ReadFile(executableChecksumFile)
		if err != nil {
			panic(err)
		}
		if !bytes.Equal(checksum, expectedExecutableChecksum) {
			Unzip(executablePath, archiveContentsPath)
			err = os.WriteFile(executableChecksumFile, expectedExecutableChecksum, 0755)
			if err != nil {
				panic(err)
			}
			isNewExtraction = true
		}
	} else {
		Unzip(executablePath, archiveContentsPath)
		err = os.WriteFile(executableChecksumFile, expectedExecutableChecksum, 0755)
		if err != nil {
			panic(err)
		}
		isNewExtraction = true
	}

	var currentStorePath string
	var newStorePath string
	isNewStorePath := false
	linkToCurrentStorePath := filepath.Join(executableCachePath, "link-to-store")
	doesLinkToCurrentStorePathExist := isSymlinkExtant(linkToCurrentStorePath)
	if doesLinkToCurrentStorePathExist {
		currentStorePath, err = os.Readlink(linkToCurrentStorePath)
		if err != nil {
			panic(err)
		}
		// TODO: Should I worry about other programs making a file with
		// the same name?
		doesCurrentStorePathExist := isSymlinkExtant(currentStorePath)
		if doesCurrentStorePathExist {
			currentStorePathTarget, _ := os.Readlink(currentStorePath)
			if currentStorePathTarget != archiveContentsPath {
				err = os.Remove(linkToCurrentStorePath)
				if err != nil {
					panic(err)
				}
				// recreate it
				err = os.Symlink(archiveContentsPath, currentStorePath)
				if err != nil {
					panic(err)
				}
			}
		} else { // recreate it
			err = os.Symlink(archiveContentsPath, currentStorePath)
			if err != nil {
				panic(err)
			}
		}

		if isNewExtraction {
			newStorePath = currentStorePath
			currentStorePath = "/nix/store"
		}
	} else { // if there's no link-to-store we must not have ever made a new store path so assume it's the original store path
		currentStorePath = "/nix/store"
		newStorePath = getNewStorePath()
		err = os.Symlink(archiveContentsPath, newStorePath)
		if err != nil {
			panic(err)
		}
		err = os.Symlink(newStorePath, linkToCurrentStorePath)
		if err != nil {
			panic(err)
		}
		isNewStorePath = true
	}

	if isNewExtraction || isNewStorePath {
		rewritePaths(archiveContentsPath, currentStorePath, newStorePath)
	}

	return archiveContentsPath, executableCachePath
}

func SelfExtractAndRunNixEntrypoint() (exitCode int) {
	var err error

	extractedArchivePath, cachePath := extractArchiveAndRewritePaths()
	defer func() {
		deleteCacheEnvVariable := os.Getenv("NIX_ROOTLESS_BUNDLER_DELETE_CACHE")
		if len(deleteCacheEnvVariable) > 0 {
			errFromDefer := os.RemoveAll(cachePath)
			if err != nil || errFromDefer != nil {
				panic(errors.Join(err, errFromDefer))
			}
		}
	}()

	endProgress()
	entrypointPath := filepath.Join(extractedArchivePath, "entrypoint")
	// First argument is the program name so we omit that.
	args := os.Args[1:]
	cmd := exec.Command(entrypointPath, args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	err = cmd.Run()
	if err != nil {
		// I don't want to report an error if the command exited with a
		// non-zero exit code. Instead I'll exit this process with that
		// same exit code.
		_, isExitError := err.(*exec.ExitError)
		if !isExitError {
			panic(err)
		}
	}

	return cmd.ProcessState.ExitCode()
}
