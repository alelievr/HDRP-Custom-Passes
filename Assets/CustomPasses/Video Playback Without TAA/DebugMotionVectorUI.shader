Shader "Unlit/Test"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            // Debug Motion Vector from https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.high-definition/Runtime/Debug/DebugFullScreen.shader#L221

            // Motion vector debug utilities
            float DistanceToLine(float2 p, float2 p1, float2 p2)
            {
                float2 center = (p1 + p2) * 0.5;
                float len = length(p2 - p1);
                float2 dir = (p2 - p1) / len;
                float2 rel_p = p - center;
                return dot(rel_p, float2(dir.y, -dir.x));
            }

            float DistanceToSegment(float2 p, float2 p1, float2 p2)
            {
                float2 center = (p1 + p2) * 0.5;
                float len = length(p2 - p1);
                float2 dir = (p2 - p1) / len;
                float2 rel_p = p - center;
                float dist1 = abs(dot(rel_p, float2(dir.y, -dir.x)));
                float dist2 = abs(dot(rel_p, dir)) - 0.5 * len;
                return max(dist1, dist2);
            }

            float2 SampleMotionVectors(float2 coords)
            {
                float4 col = tex2D(_MainTex, coords);

                // In case material is set as no motion
                if (col.x > 1)
                    return 0;
                else
                    return col.xy;
            }

            float DrawArrow(float2 texcoord, float body, float head, float height, float linewidth, float antialias)
            {
                float w = linewidth / 2.0 + antialias;
                float2 start = -float2(body / 2.0, 0.0);
                float2 end = float2(body / 2.0, 0.0);

                // Head: 3 lines
                float d1 = DistanceToLine(texcoord, end, end - head * float2(1.0, -height));
                float d2 = DistanceToLine(texcoord, end - head * float2(1.0, height), end);
                float d3 = texcoord.x - end.x + head;

                // Body: 1 segment
                float d4 = DistanceToSegment(texcoord, start, end - float2(linewidth, 0.0));

                float d = min(max(max(d1, d2), -d3), d4);
                return d;
            }

            #define PI 3.14159265359
            float4 frag (v2f i) : SV_Target
            {
                float2 mv = SampleMotionVectors(i.uv);

                // Background color intensity - keep this low unless you want to make your eyes bleed
                const float kMinIntensity = 0.03f;
                const float kMaxIntensity = 0.50f;

                // Map motion vector direction to color wheel (hue between 0 and 360deg)
                float phi = atan2(mv.x, mv.y);
                float hue = (phi / PI + 1.0) * 0.5;
                float r = abs(hue * 6.0 - 3.0) - 1.0;
                float g = 2.0 - abs(hue * 6.0 - 2.0);
                float b = 2.0 - abs(hue * 6.0 - 4.0);

                float maxSpeed = 60.0f / 0.15f; // Admit that 15% of a move the viewport by second at 60 fps is really fast
                float absoluteLength = saturate(length(mv.xy) * maxSpeed);
                float3 color = float3(r, g, b) * lerp(kMinIntensity, kMaxIntensity, absoluteLength);
                color = saturate(color);

                // Grid subdivisions - should be dynamic
                const float kGrid = 64.0;

                float arrowSize = 500;
                float4 screenSize = float4(arrowSize, arrowSize, 1.0 / arrowSize, 1.0 / arrowSize);

                // Arrow grid (aspect ratio is kept)
                float aspect = screenSize.y * screenSize.z;
                float rows = floor(kGrid * aspect);
                float cols = kGrid;
                float2 size = screenSize.xy / float2(cols, rows);
                float body = min(size.x, size.y) / sqrt(2.0);
                float2 positionSS = i.uv;
                positionSS *= screenSize.xy;
                float2 center = (floor(positionSS / size) + 0.5) * size;
                positionSS -= center;

                // Sample the center of the cell to get the current arrow vector
                float2 mv_arrow = 0.0f;
#if DONT_USE_NINE_TAP_FILTER
                mv_arrow = SampleMotionVectors(center * screenSize.zw);
#else
                for (int i = -1; i <= 1; ++i) for (int j = -1; j <= 1; ++j)
                    mv_arrow += SampleMotionVectors((center + float2(i, j)) * screenSize.zw);
                mv_arrow /= 9.0f;
#endif
                mv_arrow.y *= -1;

                // Skip empty motion
                float d = 0.0;
                if (any(mv_arrow))
                {
                    // Rotate the arrow according to the direction
                    mv_arrow = normalize(mv_arrow);
                    float2x2 rot = float2x2(mv_arrow.x, -mv_arrow.y, mv_arrow.y, mv_arrow.x);
                    positionSS = mul(rot, positionSS);

                    d = DrawArrow(positionSS, body, 0.25 * body, 0.5, 2.0, 1.0);
                    d = 1.0 - saturate(d);
                }

                // Explicitly handling the case where mv == float2(0, 0) as atan2(mv.x, mv.y) above would be atan2(0,0) which
                // is undefined and in practice can be incosistent between compilers (e.g. NaN on FXC and ~pi/2 on DXC)
                if(!any(mv))
                    color = float3(0, 0, 0);
                    
                return float4(color + d.xxx, 1);
            }
            ENDCG
        }
    }
}
