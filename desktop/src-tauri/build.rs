fn main() {
    // Embed Windows manifest for admin privileges
    #[cfg(target_os = "windows")]
    {
        let mut res = winresource::WindowsResource::new();
        // Embed manifest directly to ensure it's applied
        res.set_manifest(r#"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
  <assemblyIdentity
    version="1.0.0.0"
    processorArchitecture="*"
    name="com.ple7.vpn"
    type="win32"/>
  <description>PLE7 VPN Client</description>
  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v3">
    <security>
      <requestedPrivileges>
        <requestedExecutionLevel level="requireAdministrator" uiAccess="false"/>
      </requestedPrivileges>
    </security>
  </trustInfo>
</assembly>
"#);
        if let Err(e) = res.compile() {
            eprintln!("Failed to embed manifest: {}", e);
        }
    }

    tauri_build::build()
}
