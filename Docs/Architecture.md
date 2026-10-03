# Architecture

MVVM + Observation + actor services + protocol-oriented DI via `AppEnvironment`.

```
Views → ViewModels → Services (SPM) → macOS APIs
```

Future modules (widgets, shredder, clipboard, etc.) should land as new SPM packages behind protocols in LumaCore.
