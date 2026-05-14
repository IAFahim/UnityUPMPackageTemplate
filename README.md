# __DISPLAY__

> __DESCRIPTION__

**Build outside Unity. Ship as Unity package.**

```bash
dotnet test -c Release
git push
```

## Installation

Add to your Unity project's `Packages/manifest.json`:

```json
{
  "dependencies": {
    "__PACKAGE__": "https://github.com/__AUTHOR__/__PACKAGE__.git"
  }
}
```

Or Unity Editor → Package Manager → Add package from git URL.

## Requirements

- .NET 8 SDK (for development)
- Unity 2022.3+ (for runtime)

## Development

```bash
dotnet restore
dotnet test -c Release
```

Source lives in `__PACKAGE__.Runtime/`. Tests in `__PACKAGE__.Tests/`.

## License

MIT © __AUTHOR__
