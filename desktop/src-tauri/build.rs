fn main() {
    // Embed Windows manifest for admin privileges
    #[cfg(target_os = "windows")]
    {
        let mut res = winresource::WindowsResource::new();
        res.set_manifest_file("ple7.exe.manifest");
        if let Err(e) = res.compile() {
            eprintln!("Failed to embed manifest: {}", e);
        }
    }

    tauri_build::build()
}
