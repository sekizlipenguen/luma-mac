# API Matrix

| Feature | API | Notes |
|---------|-----|-------|
| CPU | `host_processor_info` | Tick deltas |
| Memory | `host_statistics64` / `HOST_VM_INFO64` | Active, wired, compressed, etc. |
| Memory pressure | `DispatchSource.makeMemoryPressureSource` | Falls back to labeled VM estimate |
| Swap | `sysctl vm.swapusage` | |
| Volumes | `FileManager.mountedVolumeURLs` + `statfs` | |
| Battery | `IOPSCopyPowerSourcesInfo` | Desktops: not present |
| Process energy | `proc_pid_rusage` / `ri_energy_nj` | Rate via sample deltas (mW); not Activity Monitor Energy Impact |
| Network | `getifaddrs` + `NWPathMonitor` + `SCDynamicStore` + `proc_pidfdinfo` | Rates, IPs, DNS, live sockets (app ↔ remote). No invented per-app byte rates; no cloud public-IP |
| Processes | `proc_listpids` / `proc_pidinfo` | Resident size |
| Temperature | — | Explicitly unavailable (no public SMC) |
| Disk health | `/usr/sbin/diskutil info` | SMART only if reported |
| SHA-256 | CryptoKit | Streaming |
| Trash | `FileManager.trashItem` | Undo via Finder Trash |
| Docker | `docker` CLI | Disabled if missing |
| Schedule | User `LaunchAgent` plist | Opens app; no silent delete |

App Sandbox is **off**. Hardened Runtime recommended for notarized builds.
