// ═══════════════════════════════════════════════════════════════════════════════
// Demo: Unity.Mathematics integration
// ═══════════════════════════════════════════════════════════════════════════════
// This shows the full pipeline:
// 1. dotnet build → compiles Runtime/**/*.cs using UnityMathematics NuGet
// 2. Unity → imports package.json, resolves com.unity.mathematics, compiles via asmdef
// ═══════════════════════════════════════════════════════════════════════════════

namespace __NAMESPACE__
{
    /// <summary>
    /// Sample demonstrating math types work in both dotnet and Unity contexts.
    /// Run: dotnet build Dev~/src/__PACKAGE__/__PACKAGE__.csproj -c Release
    /// </summary>
    public struct MathDemo
    {
        public Unity.Mathematics.float3 Position;
        public Unity.Mathematics.quaternion Rotation;
        public Unity.Mathematics.float4 Color;

        public Unity.Mathematics.float3 Forward
            => Unity.Mathematics.math.forward();

        public float Magnitude
            => Unity.Mathematics.math.length(Position);

        public Unity.Mathematics.float3 Normalized
            => Unity.Mathematics.math.normalize(Position);
    }
}