import AppKit

if let flag = CommandLine.arguments.firstIndex(of: "--diagnose") {
    let next = flag + 1
    Diagnostics.run(writingTo: next < CommandLine.arguments.count ? CommandLine.arguments[next] : "/dev/stdout")
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
