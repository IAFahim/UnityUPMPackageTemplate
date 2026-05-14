// Compact Unity Editor log → compile-error summary
// Usage: dotnet run --project tools/TestLogCompact -- --input Editor.log [--output compact.txt] [--stdout]
namespace TestLogCompact;

using System;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;

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
            Console.Error.WriteLine("Usage: TestLogCompact --input <log> [--output <file>] [--stdout]");
            return 1;
        }

        if (!File.Exists(input))
        {
            Console.Error.WriteLine($"File not found: {input}");
            return 1;
        }

        var lines = File.ReadAllLines(input);
        var errors = new List<string>();
        var warnings = new List<string>();
        bool inError = false, inWarning = false;
        string? currentBlock = null;

        foreach (var line in lines)
        {
            // Compile errors
            if (line.Contains("error CS") || line.Contains("CompilerOutput"))
            {
                inError = true;
                inWarning = false;
                currentBlock = line.Trim();
            }
            else if (line.Contains("warning CS"))
            {
                inWarning = true;
                inError = false;
                if (warnings.Count < 20)
                    warnings.Add(line.Trim());
            }
            else if (inError && !string.IsNullOrWhiteSpace(line))
            {
                currentBlock += "\n  " + line.Trim();
            }
            else if (inError && string.IsNullOrWhiteSpace(line))
            {
                if (currentBlock != null && errors.Count < 20)
                    errors.Add(currentBlock);
                inError = false;
                currentBlock = null;
            }
        }

        if (currentBlock != null && errors.Count < 20)
            errors.Add(currentBlock);

        using var writer = output != null ? new StreamWriter(output) : new StreamWriter(Console.OpenStandardOutput());
        var w = writer;

        w.WriteLine("## Unity Editor Log Summary");
        w.WriteLine();
        w.WriteLine($"Total lines: {lines.Length}");
        w.WriteLine($"Errors: {errors.Count}");
        w.WriteLine($"Warnings: {Math.Min(warnings.Count, 20)}");
        w.WriteLine();

        if (errors.Count > 0)
        {
            w.WriteLine("### Errors");
            foreach (var e in errors)
                w.WriteLine($"```\n{e}\n```");
            w.WriteLine();
        }

        if (warnings.Count > 0)
        {
            w.WriteLine("### Warnings (first 20)");
            foreach (var w2 in warnings)
                w.WriteLine($"- {w2}");
            w.WriteLine();
        }

        if (stdout && output != null)
            Console.WriteLine(File.ReadAllText(output));

        return errors.Count > 0 ? 1 : 0;
    }
}
