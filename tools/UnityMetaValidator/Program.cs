// Validate .meta files outside Unity — check GUIDs, orphans, duplicates
// Usage: dotnet run --project tools/UnityMetaValidator -- [--path ./Runtime]
namespace UnityMetaValidator;

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;

public static class Program
{
    public static int Main(string[] args)
    {
        var root = args.SkipWhile(a => a != "--path").Skip(1).FirstOrDefault() ?? ".";
        root = Path.GetFullPath(root);

        if (!Directory.Exists(root))
        {
            Console.Error.WriteLine($"Path not found: {root}");
            return 1;
        }

        var pass = 0;
        var fail = 0;

        // Find all .meta files
        var metas = Directory.GetFiles(root, "*.meta", SearchOption.AllDirectories)
            .Where(m => !m.Contains("/bin/") && !m.Contains("/obj/") && !m.Contains("/.git/"))
            .ToList();

        Console.WriteLine($"Checking {metas.Count} .meta files in {root}");
        Console.WriteLine();

        // Check 1: Orphan .meta files
        foreach (var meta in metas)
        {
            var asset = meta[..^5]; // strip .meta
            if (!File.Exists(asset) && !Directory.Exists(asset))
            {
                Console.WriteLine($"  ✗ Orphan .meta: {Path.GetRelativePath(root, meta)}");
                fail++;
            }
            else
            {
                pass++;
            }
        }

        // Check 2: Missing .meta for common asset types
        var extensions = new HashSet<string> { ".cs", ".asmdef", ".unity", ".prefab", ".asset", ".mat", ".uxml", ".uss" };
        foreach (var ext in extensions)
        {
            foreach (var asset in Directory.GetFiles(root, $"*{ext}", SearchOption.AllDirectories)
                .Where(a => !a.Contains("/bin/") && !a.Contains("/obj/") && !a.Contains("/.git/")))
            {
                if (!File.Exists(asset + ".meta"))
                {
                    Console.WriteLine($"  ✗ Missing .meta: {Path.GetRelativePath(root, asset)}");
                    fail++;
                }
            }
        }

        // Check 3: Duplicate GUIDs
        var guidRegex = new Regex(@"guid:\s*([0-9a-f]{32})", RegexOptions.Compiled);
        var guidMap = new Dictionary<string, List<string>>();

        foreach (var meta in metas)
        {
            var content = File.ReadAllText(meta);
            var match = guidRegex.Match(content);
            if (match.Success)
            {
                var guid = match.Groups[1].Value;
                if (!guidMap.TryGetValue(guid, out var list))
                {
                    list = new List<string>();
                    guidMap[guid] = list;
                }
                list.Add(Path.GetRelativePath(root, meta));
            }
        }

        foreach (var (guid, files) in guidMap)
        {
            if (files.Count > 1)
            {
                Console.WriteLine($"  ✗ Duplicate GUID {guid}:");
                foreach (var f in files)
                    Console.WriteLine($"    {f}");
                fail++;
            }
        }

        // Check 4: Non-lowercase GUIDs
        foreach (var meta in metas)
        {
            var content = File.ReadAllText(meta);
            var match = guidRegex.Match(content);
            if (match.Success)
            {
                var guid = match.Groups[1].Value;
                if (guid != guid.ToLowerInvariant())
                {
                    Console.WriteLine($"  ✗ Uppercase GUID in {Path.GetRelativePath(root, meta)}: {guid}");
                    fail++;
                }
            }
        }

        Console.WriteLine();
        if (fail == 0)
            Console.WriteLine($"  ✓ All {pass} .meta files valid");
        else
            Console.WriteLine($"  ✗ {fail} issues found ({pass} ok)");

        return fail > 0 ? 1 : 0;
    }
}
