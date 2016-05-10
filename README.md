# ZipArchive.swift

[![Build Status](https://travis-ci.org/yaslab/ZipArchive.swift.svg?branch=master)](https://travis-ci.org/yaslab/ZipArchive.swift)

Zip archiving library written in Swift.

This library inspired by System.IO.Compression namespace of the .NET Framework.

Contains the [Minizip](http://www.winimage.com/zLibDll/minizip.html) in this library.

## Usage

### Unzip

```swift
import ZipArchive

let sourceFile = "/path/to/archive.zip"
let destinationDirectory = "/path/to/directory"
try! ZipFile.extractToDirectory(sourceFile, destinationDirectoryName: destinationDirectory)
```

### Zip

```swift
import ZipArchive

let sourceDirectory = "/path/to/directory"
let destinationFile = "/path/to/archive.zip"
try! ZipFile.createFromDirectory(sourceDirectory, destinationArchiveFileName: destinationFile)
```

### Enumerate files in zip file

```swift
import ZipArchive

let archiveFile = "/path/to/archive.zip"
let archive = ZipArchive(path: archiveFile, mode: .Read)!
defer { archive.dispose() }

for entry in archive.entries {
    print("\(entry.fullName)")
}
```

## Installation

### CocoaPods

TBD

### Carthage

Cartfile

```
github "yaslab/ZipArchive.swift" ~> 0.1
```

## License

ZipArchive.swift is licensed under the [MIT license](https://github.com/yaslab/ZipArchive.swift/blob/master/LICENSE).

[Minizip](http://www.winimage.com/zLibDll/minizip.html) is licensed under the [zlib license](http://www.zlib.net/zlib_license.html).
