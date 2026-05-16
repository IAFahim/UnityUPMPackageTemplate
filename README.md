# Unity UPM Package Template

> **Build outside Unity. Ship as a Unity package. No DLLs. No Unity project needed.**

A minimal template that scaffolds a Unity UPM package you can develop and test entirely with `dotnet` — no Unity Editor required.

## Quick start

```bash
# One-liner
bash <(curl -sL https://raw.githubusercontent.com/IAFahim/UnityUPMPackageTemplate/main/install.sh) my-package

# Or clone and run
git clone https://github.com/IAFahim/UnityUPMPackageTemplate.git my-package
cd my-package && ./install.sh --yes
```

## The trick

```
Runtime/*.cs          ← your code (uses Unity.Mathematics types)
  │
  ├─ dotnet build     ← UnityMathematics.NoDeps NuGet
  │   dotnet test     ← same NuGet, no Unity needed
  │
  └─ Unity            ← com.unity.mathematics UPM via package.json
```

Write code once in `Runtime/`. Two consumers compile it:
- **dotnet CLI** via `Dev~/src/` (for fast local dev and CI)
- **Unity** via UPM git URL (for actual usage)

No DLLs. No adapters. Source is the package.

Three names, three places:

| Context | Package name | Source |
|---------|-------------|--------|
| C# code | `Unity.Mathematics` | `using Unity.Mathematics;` |
| dotnet csproj | `UnityMathematics.NoDeps` | NuGet (`PrivateAssets="All"`) |
| Unity UPM | `com.unity.mathematics` | `package.json` dependencies |

## Generated structure

```
my-package/
├── package.json                  ← UPM manifest (Unity reads this)
├── Runtime/                      ← your code
│   ├── Template.cs
│   └── com.owner.pkg.asmdef
├── Tests/                        ← your tests
│   ├── Template.Tests.cs
│   └── com.owner.pkg.Tests.asmdef
├── Editor/                       ← editor code (optional)
│   └── com.owner.pkg.Editor.asmdef
├── Dev~/
│   ├── src/                      ← dotnet csproj → compiles Runtime/**/*.cs
│   │   ├── Directory.Build.props
│   │   └── com.owner.pkg/com.owner.pkg.csproj
│   ├── tests/                    ← dotnet test csproj → compiles Tests/**/*.cs
│   │   ├── Directory.Build.props
│   │   └── com.owner.pkg.Tests/com.owner.pkg.Tests.csproj
│   └── infra/                    ← slnx (hidden from Unity)
│       └── com.owner.pkg.slnx
├── .gitignore
├── .gitattributes
├── LICENSE
└── README.md
```

## Dev loop

```bash
# Write code
vim Runtime/MyType.cs
vim Tests/MyType.Tests.cs

# Build and test (no Unity needed)
dotnet test -c Release

# Push to GitHub → Unity imports via git URL
git push
```

## Install in Unity

Add to `Packages/manifest.json`:

```json
"com.owner.pkg": "https://github.com/owner/com.owner.pkg.git"
```

Or Unity → Package Manager → Add from git URL.

## License

MIT
