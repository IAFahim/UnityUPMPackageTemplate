using BenchmarkDotNet.Attributes;

// This file exists so `dotnet run -c Release` on benchmarks works out of the box.
// Replace it with your own benchmarks.
namespace __NAMESPACE__.Benchmarks
{
    [MemoryDiagnoser]
    public class PlaceholderBenchmarks
    {
        [Benchmark]
        public int Template_works() => 42;
    }
}
