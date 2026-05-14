// Compact NUnit XML test results → failed-test summary
// Usage: dotnet run --project tools/TestResultsCompact -- --input TestResults.xml [--output compact.txt] [--stdout]
namespace TestResultsCompact;

using System;
using System.IO;
using System.Xml.Linq;

public static class Program
{
    public static int Main(string[] args)
    {
        string? input = null, output = null;
        bool stdout = false;

        for (int i = 0; i < args.Length; i++)
        {
            if (args[i] == "--input" && i + 1 < args.Length) input = args[++i];
            else if (args[i] == "--output" && i + 1 < args.Length) output = args[++i];
            else if (args[i] == "--stdout") stdout = true;
        }

        if (input == null)
        {
            Console.Error.WriteLine("Usage: TestResultsCompact --input <xml> [--output <file>] [--stdout]");
            return 1;
        }

        if (!File.Exists(input))
        {
            Console.Error.WriteLine($"File not found: {input}");
            return 1;
        }

        var doc = XDocument.Load(input);
        var testRun = doc.Root;

        var total = testRun?.Attribute("total")?.Value ?? "?";
        var passed = testRun?.Attribute("passed")?.Value ?? "?";
        var failed = testRun?.Attribute("failed")?.Value ?? "?";
        var skipped = testRun?.Attribute("skipped")?.Value ?? "?";
        var duration = testRun?.Attribute("duration")?.Value ?? "?";

        using var writer = output != null ? new StreamWriter(output) : new StreamWriter(Console.OpenStandardOutput());
        var w = writer;

        w.WriteLine("## Test Results Summary");
        w.WriteLine();
        w.WriteLine($"Total: {total}  Passed: {passed}  Failed: {failed}  Skipped: {skipped}  Duration: {duration}s");
        w.WriteLine();

        // Find failed tests
        var failures = testRun?.Descendants("test-case")
            .Where(tc => tc.Attribute("result")?.Value == "Failed")
            .ToList() ?? [];

        if (failures.Count > 0)
        {
            w.WriteLine("### Failed Tests");
            foreach (var tc in failures)
            {
                var name = tc.Attribute("fullname")?.Value ?? tc.Attribute("name")?.Value ?? "unknown";
                var message = tc.Descendants("message").FirstOrDefault()?.Value?.Trim() ?? "";
                var stack = tc.Descendants("stack-trace").FirstOrDefault()?.Value?.Trim() ?? "";

                w.WriteLine($"**{name}**");
                if (!string.IsNullOrEmpty(message))
                    w.WriteLine($"  Message: {message}");
                if (!string.IsNullOrEmpty(stack))
                    w.WriteLine($"  Stack: {stack.Split('\n').FirstOrDefault()}");
                w.WriteLine();
            }
        }
        else
        {
            w.WriteLine("✓ All tests passed.");
        }

        if (stdout && output != null)
            Console.WriteLine(File.ReadAllText(output));

        return failures.Count > 0 ? 1 : 0;
    }
}
