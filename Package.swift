import PackageDescription

let package = Package(
    name: "ZipArchive",
    targets: [
        Target(name: "ZipArchive", dependencies: ["CMinizip"]),
        Target(name: "CMinizip", dependencies: [])
    ],
    dependencies: [
//        .Package(url: "../CZlib", majorVersion: 1)
    ]
)
