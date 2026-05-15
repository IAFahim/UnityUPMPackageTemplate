# Source Generator

Drop `.cs` source generator files here. Build outputs go to `__PACKAGE__/SourceGenerators/`.

```bash
dotnet build SourceGenerator~/__PACKAGE__.SourceGenerator.csproj -c Release
```

Unity auto-imports `.dll` files from `SourceGenerators/` inside the package root.
