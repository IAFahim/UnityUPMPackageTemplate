// Unity Editor script: export package as .unitypackage
// Run via Unity batch mode:
//   Unity -batchmode -nographics -quit -projectPath <tmp> \
//     -executeMethod UnityPackageExporter.Export \
//     -logFile artifacts/unity-export.log
//
// This file is copied into a temp Unity project's Assets/Editor/ folder
// during the release workflow. It is NOT part of the shipped package.

using System;
using System.IO;
using UnityEditor;
using UnityEngine;

public static class UnityPackageExporter
{
    public static void Export()
    {
        var packageName = Environment.GetEnvironmentVariable("PACKAGE_DISPLAY_NAME") ?? "Package";
        var outputDir = Environment.GetEnvironmentVariable("RELEASE_OUT") ?? "artifacts/release";
        var packageId = Environment.GetEnvironmentVariable("PACKAGE_ID") ?? "com.unknown.package";

        Directory.CreateDirectory(outputDir);

        var assetRoot = $"Assets/{packageName}";

        if (!Directory.Exists(assetRoot))
        {
            Debug.LogError($"Asset root not found: {assetRoot}");
            EditorApplication.Exit(1);
            return;
        }

        AssetDatabase.Refresh(ImportAssetOptions.ForceUpdate);

        // Export .unitypackage
        var unityPackagePath = Path.GetFullPath(Path.Combine(outputDir, $"{packageId}.unitypackage"));
        AssetDatabase.ExportPackage(
            new[] { assetRoot },
            unityPackagePath,
            ExportPackageOptions.Recurse | ExportPackageOptions.IncludeDependencies
        );

        if (!File.Exists(unityPackagePath))
        {
            Debug.LogError($"Export failed: {unityPackagePath} not created");
            EditorApplication.Exit(1);
            return;
        }

        Debug.Log($"Exported .unitypackage: {unityPackagePath}");

        // Also validate all .meta files
        var metaFiles = Directory.GetFiles(assetRoot, "*.meta", SearchOption.AllDirectories);
        var assetFiles = Directory.GetFiles(assetRoot, "*.*", SearchOption.AllDirectories)
            .Where(f => !f.EndsWith(".meta"))
            .ToList();

        Debug.Log($"Assets: {assetFiles.Count}, Metas: {metaFiles.Length}");

        EditorApplication.Exit(0);
    }
}
