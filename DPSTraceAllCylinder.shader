Shader "chinosk6/Transparent/DPSTraceAllCylinder"
{
    Properties
    {
        // 圆柱体半径（完全由配置控制，与模型无关）
        _CylinderRadius("Cylinder Radius", Range(0,0.5)) = 0.5

        // 渐变方向（普通配置）：大于 0.5 时沿圆柱高度渐变，否则按圆周渐变
        _VerticalGradient("Vertical Gradient (0: Circular, 1: Vertical)", Float) = 0

        // 控制末端与光源点之间的距离（圆柱顶端距离目标光源的间隙）
        _EndGap("End Gap", Range(0,1)) = 0.0

        [Space(10)]

        // 动态滚动效果及滚动速度（滚动效果在不同渐变模式下分别处理）
        _Dynamic("Dynamic Gradient", Float) = 0
        _ScrollSpeed("Scroll Speed", Range(0,100)) = 1

        // 高级渐变配置（用于颜色插值）
        _UseCustomGradient("Use Custom Gradient", Float) = 0
        _GradColor1("Gradient Color 1", Color) = (1, 0, 0, 1)
        _GradColor2("Gradient Color 2", Color) = (0, 1, 0, 1)
        _GradColor3("Gradient Color 3", Color) = (0, 0, 1, 1)

        [Space(10)]

        // 封口配置：当 _UseCapTexture>0.5 时使用贴图，否则封口颜色与侧面渐变一致
        _CapColor("Cap Color", Color) = (1,1,1,1)
        _UseCapTexture("Use Cap Texture", Float) = 0
        _CapTexture("Cap Texture", 2D) = "white" {}

        // 是否生成起点（底部）封口（默认关闭）
        _RenderBottomCap("Render Bottom Cap", Float) = 0

        // 分段数（用于侧面和封口），范围 4～16，较低的值可优化性能
        _Segments("Segments", Range(3,16)) = 8

        _MainTex ("Fallback Texture", 2D) = "black" {}
    }

    SubShader
    {
        Tags { "VRCFallback"="Hidden" "RenderType"="Transparent" "Queue"="Transparent" }
        Cull Off
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha

        // Pass 1：物体本体（全透明）
        Pass
        {
            Tags { "VRCFallback"="Hidden" }
            Name "Invisible"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata { float4 vertex : POSITION; };
            struct v2f { float4 pos : SV_POSITION; };

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target { return fixed4(0, 0, 0, 0); }
            ENDCG
        }

        // Pass 2：圆柱生成与封口
        // 使用几何着色器处理多光源，每个符合条件的光源生成一根圆柱（侧面+封口）
        Pass
        {
            Tags { "VRCFallback"="Hidden" "LightMode"="Always" }
            Name "Cylinders"
            Cull Off
            ZTest LEqual
            ZWrite On

            CGPROGRAM
            #pragma vertex CylinderVS
            #pragma geometry CylinderGS
            #pragma fragment CylinderPS
            #pragma target 4.0
            #include "UnityCG.cginc"

            // 侧面和封口参数
            uniform float _CylinderRadius;
            uniform float _VerticalGradient;  // >0.5：垂直渐变；否则：圆周渐变
            uniform float _Dynamic;
            uniform float _ScrollSpeed;
            uniform float _UseCustomGradient;
            uniform float4 _GradColor1;
            uniform float4 _GradColor2;
            uniform float4 _GradColor3;
            uniform float _EndGap;
            uniform float _Segments;          // 传入为 float，但实际作为整数使用
            
            // 封口配置
            uniform float4 _CapColor;
            uniform sampler2D _CapTexture;
            uniform float _UseCapTexture;
            // 可配置项：是否生成底部封口
            uniform float _RenderBottomCap;

            // 内置光源（最多 4 个，使用内置数组）
            // unity_LightColor, unity_4LightAtten0, unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0, unity_WorldToObject 均由 Unity 内部提供

            // 输入结构（仅传递顶点位置）
            struct appdata { float4 vertex : POSITION; };

            // 输出结构，扩展了 cap 标记和封口 UV
            struct GSOutput
            {
                float4 pos : SV_POSITION;
                float t : TEXCOORD0;   // 用于渐变（侧面根据角度或高度）
                float cap : TEXCOORD1; // 0：侧面，1：底封口，2：顶封口
                float2 uvCap : TEXCOORD2; // 封口 UV
            };

            // 顶点着色器：直接传递顶点位置
            GSOutput CylinderVS(appdata v)
            {
                GSOutput o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.t = 0;
                o.cap = 0;
                o.uvCap = float2(0,0);
                return o;
            }

            // 几何着色器：对每个符合条件的光源生成圆柱体侧面和封口
            // 这里使用 maxvertexcount 足够容纳 4 光源情况下所有输出（侧面 + 封口）
            [maxvertexcount(128)]
            void CylinderGS(point GSOutput input[1], inout TriangleStream<GSOutput> triStream)
            {
                float3 basePos = float3(0,0,0);
                // 遍历内置4个光源
                for (int i = 0; i < 4; i++)
                {
                    // 判断光源条件（沿用原逻辑）
                    if (length(unity_LightColor[i].rgb) < 0.01)
                    {
                        float lightAtten = unity_4LightAtten0[i];
                        float rangeVal = (0.005 * sqrt(1000000 - lightAtten)) / sqrt(lightAtten);
                        float modVal = fmod(rangeVal, 0.1);
                        if (abs(modVal - 0.01) < 0.005 || abs(modVal - 0.02) < 0.005)
                        {
                            // 获取光源位置（内置变量）
                            float4 lightWorldPos = float4(
                                unity_4LightPosX0[i],
                                unity_4LightPosY0[i],
                                unity_4LightPosZ0[i],
                                1.0);
                            // 转换到物体空间
                            float3 tipPosOrig = mul(unity_WorldToObject, lightWorldPos).xyz;
                            float3 dir = tipPosOrig - basePos;
                            float height = length(dir);
                            if (height < 0.001) continue;
                            dir = normalize(dir);
                            // 调整末端，留出 _EndGap
                            float newHeight = height - _EndGap;
                            if(newHeight < 0.001) continue;
                            float3 topPos = basePos + dir * newHeight;
                            
                            // 计算局部坐标系
                            float3 up = (abs(dot(dir, float3(0,1,0))) < 0.99) ? float3(0,1,0) : float3(1,0,0);
                            float3 right = normalize(cross(dir, up));
                            up = normalize(cross(right, dir));

                            // 将 _Segments 转为整型值
                            int segments = (int)_Segments;
                            float angleStep = 6.2831853 / segments;

                            // 生成侧面：使用三角带，依次输出底环和顶环顶点
                            for (int j = 0; j <= segments; j++)
                            {
                                float angle = j * angleStep;
                                float cosA = cos(angle);
                                float sinA = sin(angle);
                                float3 offset = right * cosA * _CylinderRadius + up * sinA * _CylinderRadius;
                                GSOutput vOut;
                                // 底环顶点
                                vOut.pos = UnityObjectToClipPos(float4(basePos + offset, 1));
                                vOut.t = (_VerticalGradient > 0.5) ? 0.0 : (j / (float)segments);
                                vOut.cap = 0;
                                vOut.uvCap = float2(0,0);
                                triStream.Append(vOut);
                                // 顶环顶点
                                vOut.pos = UnityObjectToClipPos(float4(topPos + offset, 1));
                                vOut.t = (_VerticalGradient > 0.5) ? 1.0 : (j / (float)segments);
                                vOut.cap = 0;
                                vOut.uvCap = float2(0,0);
                                triStream.Append(vOut);
                            }
                            triStream.RestartStrip();

                            // 生成底部封口（三角扇面，cap = 1），仅当 _RenderBottomCap > 0.5 时生成
                            if (_RenderBottomCap > 0.5)
                            {
                                GSOutput center;
                                center.pos = UnityObjectToClipPos(float4(basePos, 1));
                                center.t = (_VerticalGradient > 0.5) ? 0.0 : 0.0;
                                center.cap = 1;
                                center.uvCap = float2(0.5, 0.5);
                                for (int j = 0; j < segments; j++)
                                {
                                    triStream.Append(center);
                                    float angle = j * angleStep;
                                    float cosA = cos(angle);
                                    float sinA = sin(angle);
                                    float3 pos = basePos + (right * cosA * _CylinderRadius + up * sinA * _CylinderRadius);
                                    GSOutput v;
                                    v.pos = UnityObjectToClipPos(float4(pos, 1));
                                    v.t = (_VerticalGradient > 0.5) ? 0.0 : (j / (float)segments);
                                    v.cap = 1;
                                    v.uvCap = float2(0.5 + 0.5*cosA, 0.5 + 0.5*sinA);
                                    triStream.Append(v);
                                    float angleNext = (j+1) * angleStep;
                                    float cosA2 = cos(angleNext);
                                    float sinA2 = sin(angleNext);
                                    pos = basePos + (right * cosA2 * _CylinderRadius + up * sinA2 * _CylinderRadius);
                                    v.pos = UnityObjectToClipPos(float4(pos, 1));
                                    v.t = (_VerticalGradient > 0.5) ? 0.0 : ((j+1) / (float)segments);
                                    v.cap = 1;
                                    v.uvCap = float2(0.5 + 0.5*cosA2, 0.5 + 0.5*sinA2);
                                    triStream.Append(v);
                                    triStream.RestartStrip();
                                }
                            }

                            // 生成顶部封口（三角扇面，cap = 2）
                            {
                                GSOutput center;
                                center.pos = UnityObjectToClipPos(float4(topPos, 1));
                                center.t = (_VerticalGradient > 0.5) ? 1.0 : 1.0;
                                center.cap = 2;
                                center.uvCap = float2(0.5, 0.5);
                                for (int j = 0; j < segments; j++)
                                {
                                    triStream.Append(center);
                                    float angle = j * angleStep;
                                    float cosA = cos(angle);
                                    float sinA = sin(angle);
                                    float3 pos = topPos + (right * cosA * _CylinderRadius + up * sinA * _CylinderRadius);
                                    GSOutput v;
                                    v.pos = UnityObjectToClipPos(float4(pos, 1));
                                    v.t = (_VerticalGradient > 0.5) ? 1.0 : (j / (float)segments);
                                    v.cap = 2;
                                    v.uvCap = float2(0.5 + 0.5*cosA, 0.5 + 0.5*sinA);
                                    triStream.Append(v);
                                    float angleNext = (j+1) * angleStep;
                                    float cosA2 = cos(angleNext);
                                    float sinA2 = sin(angleNext);
                                    pos = topPos + (right * cosA2 * _CylinderRadius + up * sinA2 * _CylinderRadius);
                                    v.pos = UnityObjectToClipPos(float4(pos, 1));
                                    v.t = (_VerticalGradient > 0.5) ? 1.0 : ((j+1) / (float)segments);
                                    v.cap = 2;
                                    v.uvCap = float2(0.5 + 0.5*cosA2, 0.5 + 0.5*sinA2);
                                    triStream.Append(v);
                                    triStream.RestartStrip();
                                }
                            }
                        }
                    }
                }
            }

            // 片元着色器：侧面部分根据动态/自定义渐变计算颜色，
            // 封口部分：若 _UseCapTexture 开启则采样贴图，否则与侧面采用相同渐变效果
            fixed4 CylinderPS(GSOutput input) : SV_Target
            {
                // 封口判断（cap 非 0）
                if (input.cap > 0.5)
                {
                    if (_UseCapTexture > 0.5)
                        return tex2D(_CapTexture, input.uvCap);
                    // 否则继续使用动态渐变计算，与侧面一致
                }
                float t = input.t;
                if (_Dynamic > 0.5)
                {
                    if (_VerticalGradient > 0.5)
                        t = frac(t * 0.9 + _Time.x * _ScrollSpeed);
                    else
                        t = frac(t + _Time.x * _ScrollSpeed);
                }
                float3 color;
                if (_UseCustomGradient > 0.5)
                {
                    if (t < 0.3333)
                    {
                        float tt = t / 0.3333;
                        color = lerp(_GradColor1.rgb, _GradColor2.rgb, tt);
                    }
                    else if (t < 0.6666)
                    {
                        float tt = (t - 0.3333) / 0.3333;
                        color = lerp(_GradColor2.rgb, _GradColor3.rgb, tt);
                    }
                    else
                    {
                        float tt = (t - 0.6666) / 0.3334;
                        color = lerp(_GradColor3.rgb, _GradColor1.rgb, tt);
                    }
                }
                else
                {
                    color = 0.5 + 0.5 * cos(6.28318 * t + float3(0.0, 2.094, 4.188));
                }
                return fixed4(color, 1);
            }
            ENDCG
        }
    }
    Fallback "Legacy Shaders/Transparent/VertexLit"
}
