namespace __NAMESPACE__
{
    public struct Template
    {
        public Unity.Mathematics.float3 Position;
        public Unity.Mathematics.quaternion Rotation;
        public Unity.Mathematics.float4 Color;

        public float Magnitude
            => Unity.Mathematics.math.length(Position);

        public Unity.Mathematics.float3 Normalized
            => Unity.Mathematics.math.normalize(Position);
    }
}
