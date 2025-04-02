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
	"unicode"

	"github.com/deepakjois/gousbdrivedetector"
	"github.com/klauspost/compress/zstd"
	"github.com/schollz/progressbar/v3"
	"golang.org/x/sync/errgroup"
	"golang.org/x/sync/semaphore"
	"golang.org/x/term"
)

// With this, I can distinguish my panics from other ones.
type GozipError struct{ error }

func GozipPanic(err error) {
	panic(GozipError{err})
}

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

func NextStep(count int, name string, options ...progressbar.Option) *progressbar.ProgressBar {
	EndProgress()
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
		log.Fatal("writing string:", err)
	}

	if f, ok := w.(*os.File); ok {
		// ignore any errors in Sync(), as stdout can't be synced on
		// some operating systems like Debian 9 (Stretch)
		f.Sync() //nolint:errcheck
	}
}
func ClearProgressBar() {
	width, _, err := term.GetSize(2)
	if err != nil {
		log.Fatal("getting terminal width:", err)
	}
	str := fmt.Sprintf("\r%s\r", strings.Repeat(" ", width))
	writeString(writer, str)
}

func EndProgress() {
	if currentBar != nil {
		// So the spinner stops. We have to do this before calling clear or else the
		// spinner will just render the bar again.
		err := currentBar.Finish()
		if err != nil {
			log.Fatal("finish progress bar:", err)
		}

		err = currentBar.Clear()
		if err != nil {
			log.Fatal("cleat progress bar:", err)
		}
		ClearProgressBar()
		currentBar = nil
	}
}

func IsSymlink(path string) bool {
	fileInfo, err := os.Lstat(path)
	if err != nil {
		return false, err
	}
	return fileInfo.Mode()&os.ModeSymlink == os.ModeSymlink, nil
}

func Zip(destinationPath string, filesToZip []string) {
	destinationFile, err := os.OpenFile(destinationPath, os.O_RDWR|os.O_CREATE|os.O_APPEND, 0644)
	if err != nil {
		return err
	}

	defer func() {
		err = errors.Join(err, destinationFile.Close())
	}()

	// To make a self extracting archive, the `destinationPath` can be the
	// executable that does the extraction.  For this reason, we set the
	// `startoffset` to `io.SeekEnd`. This way we append the contents of
	// the archive after the executable. Check the README for an example of
	// making a self-extracting archive.
	_, err = destinationFile.Seek(0, io.SeekEnd)
	if err != nil {
		return err
	}
	_, err = destinationFile.Write(boundary)
	if err != nil {
		log.Fatal("writing boundary to output file:", err)
	}

	zWrt, err := zstd.NewWriter(destinationFile, zstd.WithEncoderLevel(zstd.SpeedBestCompression))
	if err != nil {
		return err
	}
	defer func() {
		err = errors.Join(err, zWrt.Close())
	}()
	tarWrt := tar.NewWriter(zWrt)
	defer func() {
		err = errors.Join(err, tarWrt.Close())
	}()

	cd := "."
	for _, file := range filesToZip {
		rootDir := os.DirFS(cd)
		file = filepath.Clean(file)

		// If the input file is a symlink, don't dereference it.
		isSymlink, err := IsSymlink(file)
		if err != nil {
			return err
		}
		if isSymlink {
			var hdr tar.Header
			hdr.Name = file

			hdr.Typeflag = tar.TypeSymlink
			target, err := filepath.EvalSymlinks((filepath.Join(cd, file)))
			if err != nil {
				return err
			}
			hdr.Linkname = target

			err = tarWrt.WriteHeader(&hdr)
			if err != nil {
				return err
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
				log.Fatalf("unsupported file type: %s", path)
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
			return err
		}
	}

	// Return err in case a `defer`ed function sets it
	return err
}

func createFile(path string) *os.File {
	dir := filepath.Dir(path)
	err := os.MkdirAll(dir, 0755)
	if err != nil {
		return nil, err
	}
	f, err := os.Create(path)
	if err != nil {
		return nil, err
	}
	return f, nil
}

func cleanupDir(dir string) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return err
	}
	for _, entry := range entries {
		err := os.RemoveAll(filepath.Join(dir, entry.Name()))
		if err != nil {
			return err
		}
	}
	return nil
}

func cleanupAndDie(dir string, v ...any) {
	err := cleanupDir(dir)
	if err != nil {
		log.Fatal(append([]any{"got error:", err, "while cleaning up after:"}, v...))
	}
	log.Fatal(v...)
}

func GetBoundaryOffset(fileName string) int {
	fileBytes, err := os.ReadFile(fileName)
	if err != nil {
		log.Fatal("reading file:", err)
	}

	return bytes.Index(fileBytes, boundary)
}

func HasBoundary(fileName string) bool {
	boundaryOffset := GetBoundaryOffset(fileName)

	if boundaryOffset == -1 {
		return false
	} else {
		return true
	}
}

func SeekToTar(file os.File) os.File {
	boundaryOffset := GetBoundaryOffset(file.Name())
	if boundaryOffset == -1 {
		log.Fatal("no boundary")
	}

	payloadOffset := boundaryOffset + len(boundary)

	_, err := file.Seek(int64(payloadOffset), io.SeekStart)
	if err != nil {
		log.Fatal("seeking to start of payload:", err)
	}

	return file
}

// Unzip unzips the file zippath and puts it in destination
func Unzip(zippath string, destination string) {
	NextStep(
		-1,
		"Calculating archive size",
		progressbar.OptionSpinnerType(14),
	)
	files, err := UnzipList(zippath)
	if err != nil {
		return err
	}
	archiveCount = len(files)

	progressBar := NextStep(
		archiveCount,
		"Extracting archive",
		progressbar.OptionShowCount(),
	)

	zipFile, err := os.Open(zippath)
	if err != nil {
		return err
	}
	defer func() {
		err = errors.Join(err, zipFile.Close())
	}()
	SeekToTar(*zipFile)

	zRdr, err := zstd.NewReader(zipFile)
	if err != nil {
		return err
	}
	defer zRdr.Close()
	tarRdr := tar.NewReader(zRdr)

	err = os.RemoveAll(destination)
	if err != nil {
		return err
	}
	err = os.Mkdir(destination, 0755)
	if err != nil {
		return err
	}

	for {
		hdr, err := tarRdr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}

		name := filepath.Clean(hdr.Name)
		if name == "." {
			continue
		}
		pathName := filepath.Join(destination, name)
		switch hdr.Typeflag {
		case tar.TypeReg:
			f, err := createFile(pathName)
			if err != nil {
				cleanupAndDie(destination, "creating file:", err)
			}

			_, err = io.Copy(f, tarRdr)
			if err != nil {
				cleanupAndDie(destination, "writing file:", err)
			}

			err = f.Chmod(os.FileMode(hdr.Mode))
			if err != nil {
				cleanupAndDie(destination, "setting mode of file:", err)
			}

			err = f.Close()
			if err != nil {
				cleanupAndDie(destination, "closing file:", err)
			}
		case tar.TypeDir:
			// We choose to disregard directory permissions and use a default
			// instead. Custom permissions (e.g. read-only directories) are
			// complex to handle, both when extracting and also when cleaning
			// up the directory.
			err := os.Mkdir(pathName, 0755)
			if err != nil {
				cleanupAndDie(destination, "creating directory", err)
			}
		case tar.TypeSymlink:
			err := os.Symlink(hdr.Linkname, pathName)
			if err != nil {
				cleanupAndDie(destination, "creating symlink", err)
			}
		default:
			cleanupAndDie(destination, "unsupported file type in tar", hdr.Typeflag)
		}

		err = progressBar.Add(1)
		if err != nil {
			cleanupAndDie(destination, "adding to progress bar", err)
		}
	}

	return
}

// UnzipList Lists all the files in zip file
func UnzipList(path string) (list []string) {
	zipFile, err := os.Open(path)
	if err != nil {
		GozipPanic(err)
	}
	defer func() {
		err = errors.Join(err, zipFile.Close())
	}()
	SeekToTar(*zipFile)

	zRdr, err := zstd.NewReader(zipFile)
	if err != nil {
		GozipPanic(err)
	}
	defer zRdr.Close()
	tarRdr := tar.NewReader(zRdr)

	for {
		hdr, err := tarRdr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			GozipPanic(err)
		}

		name := filepath.Clean(hdr.Name)
		if name == "." {
			continue
		}
		list = append(list, name)
	}

	return list
}

func CreateDirectoryIfNotExists(path string) {
	return os.MkdirAll(path, 0755)
}

func IsFileExists(path string) bool {
	_, err := os.Stat(path)
	if err == nil {
		return true, nil
	} else if errors.Is(err, fs.ErrNotExist) {
		return false, nil
	} else {
		return false, err
	}
}

func IsSymlinkExists(path string) bool {
	_, err := os.Lstat(path)
	if err == nil {
		return true, nil
	} else if errors.Is(err, fs.ErrNotExist) {
		return false, nil
	} else {
		return false, err
	}
}

func GetFileCount(path string) int {
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
		log.Fatal("getting file count:", err)
	}

	return count
}

func RewritePaths(archiveContentsPath string, oldStorePath string, newStorePath string) {
	if archiveCount == 0 {
		NextStep(
			-1,
			"Calculating archive size",
			progressbar.OptionSpinnerType(14),
		)
		archiveCount = GetFileCount(archiveContentsPath)
	}

	progressBar := NextStep(
		archiveCount,
		"Rewriting store paths",
		progressbar.OptionShowCount(),
	)
	archiveContents, err := os.Open(archiveContentsPath)
	if err != nil {
		return err
	}
	defer func() {
		err = errors.Join(err, archiveContents.Close())
	}()

	// The top level files in the archive are the directories of the Nix
	// packages so we can use those directory names to get a list of all the
	// package paths that need to be rewritten in the binaries.
	//
	// The 0 means return all files in the directory, as opposed to setting
	// a max.
	topLevelFilesInArchive, err := archiveContents.Readdir(0)
	if err != nil {
		return err
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
		return err
	}

	return g.Wait()
}

func GetNewStorePath() (prefix string) {
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

		isFileExists, err := IsFileExists(candidatePrefix)
		if err != nil {
			return "", err
		}
		if !isFileExists {
			return candidatePrefix, nil
		}
	}

	return "", errors.New("unable to find a new store prefix")
}

func GetTempDir() (tempDir string) {
	return os.TempDir()
}

func IsDir(name string) bool {
	// TODO: lstat?
	fi, err := os.Stat(name)
	if os.IsNotExist(err) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	if !fi.IsDir() {
		return false, nil
	}
	return true, nil
}

func genTestFilename(str string) string {
	flip := true
	return strings.Map(func(r rune) rune {
		if flip {
			if unicode.IsLower(r) {
				u := unicode.ToUpper(r)
				if unicode.ToLower(u) == r {
					r = u
					flip = false
				}
			} else if unicode.IsUpper(r) {
				l := unicode.ToLower(r)
				if unicode.ToUpper(l) == r {
					r = l
					flip = false
				}
			}
		}
		return r
	}, str)
}

func isCaseSensitiveFilesystem(dir string) bool {
	alt := filepath.Join(filepath.Dir(dir),
		genTestFilename(filepath.Base(dir)))

	dInfo, err := os.Stat(dir)
	if err != nil {
		return true
	}

	aInfo, err := os.Stat(alt)
	if err != nil {
		return true
	}

	return !os.SameFile(dInfo, aInfo)
}

// The logic for this function, and all the functions it calls, was copied from
// here: https://github.com/golang/dep/pull/395/files
func HasFilepathPrefix(path, prefix string) bool {
	if filepath.VolumeName(path) != filepath.VolumeName(prefix) {
		return false
	}

	var dn string

	if isDir, err := IsDir(path); err != nil {
		return false
	} else if isDir {
		dn = path
	} else {
		dn = filepath.Dir(path)
	}

	dn = strings.TrimSuffix(dn, string(os.PathSeparator))
	prefix = strings.TrimSuffix(prefix, string(os.PathSeparator))

	dirs := strings.Split(dn, string(os.PathSeparator))[1:]
	prefixes := strings.Split(prefix, string(os.PathSeparator))[1:]

	if len(prefixes) > len(dirs) {
		return false
	}

	var d, p string

	for i := range prefixes {
		// need to test each component of the path for
		// case-sensitiveness because on Unix we could have
		// something like ext4 filesystem mounted on FAT
		// mountpoint, mounted on ext4 filesystem, i.e. the
		// problematic filesystem is not the last one.
		if isCaseSensitiveFilesystem(filepath.Join(d, dirs[i])) {
			d = filepath.Join(d, dirs[i])
			p = filepath.Join(p, prefixes[i])
		} else {
			d = filepath.Join(d, strings.ToLower(dirs[i]))
			p = filepath.Join(p, strings.ToLower(prefixes[i]))
		}

		if p != d {
			return false
		}
	}

	return true
}

func IsRunningOnUsb() bool {
	if runtime.GOOS == "linux" {
		// On Linux, the go module 'gousbdrivedetector' needs the
		// `udevadm` CLI and it may not be there so we'll check first.
		path, err := exec.LookPath("udevadm")
		if err != nil || path == "" {
			return false
		}
	}

	usbDevicePaths, err := usbdrivedetector.Detect()
	if err != nil {
		return false
	}

	executablePath, err := os.Executable()
	if err != nil {
		return false
	}
	for _, usbPath := range usbDevicePaths {
		if HasFilepathPrefix(executablePath, usbPath) {
			return true
		}
	}

	return false
}

// If we are running on a usb device, store the cache there, for stronger
// isolation. Otherwise use a temporary directory.
func GetCacheDirectory() (cacheDirectory string) {
	if IsRunningOnUsb() {
		executablePath, err := os.Executable()
		if err != nil {
			return GetTempDir()
		}
		return filepath.Dir(executablePath)
	} else {
		return GetTempDir()
	}
}

func ExtractArchiveAndRewritePaths() (extractedArchivePath string, executableCachePath string) {
	NextStep(
		-1,
		"Checking cache",
		progressbar.OptionSpinnerType(14),
	)

	cachePath := filepath.Join(GetCacheDirectory(), "nix-rootless-bundler")
	CreateDirectoryIfNotExists(cachePath)

	executablePath, err := os.Executable()
	if err != nil {
		GozipPanic(err)
	}

	executableName := filepath.Base(executablePath)
	executableCachePath = filepath.Join(cachePath, executableName)
	CreateDirectoryIfNotExists(executableCachePath)

	executable, err := os.Open(executablePath)
	if err != nil {
		GozipPanic(err)
	}
	defer func() {
		errFromDefer := executable.Close()
		if err != nil || errFromDefer != nil {
			GozipPanic(errors.Join(err, errFromDefer))
		}
	}()
	hash := sha256.New()
	_, err = io.Copy(hash, executable)
	if err != nil {
		GozipPanic(err)
	}
	expectedExecutableChecksum := []byte(hex.EncodeToString(hash.Sum(nil)))
	archiveContentsPath := filepath.Join(executableCachePath, "archive-contents")

	isNewExtraction := false
	executableChecksumFile := filepath.Join(executableCachePath, "checksum.txt")
	executableChecksumFileExists := IsFileExists(executableChecksumFile)
	if executableChecksumFileExists {
		checksum, err := os.ReadFile(executableChecksumFile)
		if err != nil {
			GozipPanic(err)
		}
		if !bytes.Equal(checksum, expectedExecutableChecksum) {
			Unzip(executablePath, archiveContentsPath)
			err = os.WriteFile(executableChecksumFile, expectedExecutableChecksum, 0755)
			if err != nil {
				GozipPanic(err)
			}
			isNewExtraction = true
		}
	} else {
		Unzip(executablePath, archiveContentsPath)
		err = os.WriteFile(executableChecksumFile, expectedExecutableChecksum, 0755)
		if err != nil {
			GozipPanic(err)
		}
		isNewExtraction = true
	}

	var currentStorePath string
	var newStorePath string
	isNewStorePath := false
	linkToCurrentStorePath := filepath.Join(executableCachePath, "link-to-store")
	doesLinkToCurrentStorePathExist := IsSymlinkExists(linkToCurrentStorePath)
	if doesLinkToCurrentStorePathExist {
		currentStorePath, err = os.Readlink(linkToCurrentStorePath)
		if err != nil {
			GozipPanic(err)
		}
		// TODO: Should I worry about other programs making a file with
		// the same name?
		doesCurrentStorePathExist := IsSymlinkExists(currentStorePath)
		if doesCurrentStorePathExist {
			currentStorePathTarget, _ := os.Readlink(currentStorePath)
			if currentStorePathTarget != archiveContentsPath {
				err = os.Remove(linkToCurrentStorePath)
				if err != nil {
					GozipPanic(err)
				}
				// recreate it
				err = os.Symlink(archiveContentsPath, currentStorePath)
				if err != nil {
					GozipPanic(err)
				}
			}
		} else { // recreate it
			err = os.Symlink(archiveContentsPath, currentStorePath)
			if err != nil {
				GozipPanic(err)
			}
		}

		if isNewExtraction {
			newStorePath = currentStorePath
			currentStorePath = "/nix/store"
		}
	} else { // if there's no link-to-store we must not have ever made a new store path so assume it's the original store path
		currentStorePath = "/nix/store"
		newStorePath = GetNewStorePath()
		err = os.Symlink(archiveContentsPath, newStorePath)
		if err != nil {
			GozipPanic(err)
		}
		err = os.Symlink(newStorePath, linkToCurrentStorePath)
		if err != nil {
			GozipPanic(err)
		}
		isNewStorePath = true
	}

	if isNewExtraction || isNewStorePath {
		RewritePaths(archiveContentsPath, currentStorePath, newStorePath)
	}

	return archiveContentsPath, executableCachePath
}

func SelfExtractAndRunNixEntrypoint() (exitCode int) {
	var err error

	extractedArchivePath, cachePath := ExtractArchiveAndRewritePaths()
	defer func() {
		deleteCacheEnvVariable := os.Getenv("NIX_ROOTLESS_BUNDLER_DELETE_CACHE")
		if len(deleteCacheEnvVariable) > 0 {
			errFromDefer := os.RemoveAll(cachePath)
			if err != nil || errFromDefer != nil {
				GozipPanic(errors.Join(err, errFromDefer))
			}
		}
	}()

	EndProgress()
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
			GozipPanic(err)
		}
	}

	return cmd.ProcessState.ExitCode()
}
