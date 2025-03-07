Shader "chinosk6/DPSTraceAllCylinder"
{
    Properties
    {
        _MainTex("MainTex", 2D) = "white" {}
        _Color("Color", Color) = (0,0,0,0)
        _Metallic("Metallic", 2D) = "black" {}
        _Smoothness("Smoothness", Range( 0 , 1)) = 1
        _BumpMap("Normal Map", 2D) = "bump" {}
        _Emission("Emission", 2D) = "black" {}
        _EmissionPower("EmissionPower", Range( 0 , 3)) = 1
        _Occlusion("Occlusion", 2D) = "white" {}
        [Header(Penetration Entry Deformation)]_Squeeze("Squeeze Minimum Size", Range( 0 , 0.2)) = 0
        _SqueezeDist("Squeeze Smoothness", Range( 0 , 0.1)) = 0
        _BulgePower("Bulge Amount", Range( 0 , 1)) = 0
        _BulgeOffset("Bulge Length", Range( 0 , 0.3)) = 0
        _Length("Length of Penetrator Model", Range( 0 , 3)) = 0
        [Header(Alignment Adjustment)]_EntranceStiffness("Entrance Stiffness", Range( 0.01 , 1)) = 0.01
        [Header(Resting Curvature)]_Curvature("Curvature", Range( -1 , 1)) = 0
        _ReCurvature("ReCurvature", Range( -1 , 1)) = 0
        [Header(Movement)]_Wriggle("Wriggle Amount", Range( 0 , 1)) = 0
        _WriggleSpeed("Wriggle Speed", Range( 0.1 , 30)) = 0.28
        [Header(Toon Shading (Check to activate))]_CellShadingSharpness("Cell Shading Sharpness", Range( 0 , 1)) = 0
        _ToonSpecularSize("ToonSpecularSize", Range( 0 , 1)) = 0
        _ToonSpecularIntensity("ToonSpecularIntensity", Range( 0 , 1)) = 0
        [Toggle(_TOONSHADING_ON)] _ToonShading("Toon Shading", Float) = 0
        [Header(Advanced)]_OrificeChannel("OrificeChannel Please Use 0", Float) = 0
        [HideInInspector] _texcoord( "", 2D ) = "white" {}
        [HideInInspector] __dirty( "", Int ) = 1

        // 圆柱体半径属性
        _CylinderRadius("Cylinder Radius", Range(0,0.5)) = 0.5
        // 透明度，用于控制 Lighting 渲染的透明度
        _Opacity("Opacity", Range(0,1)) = 1
    }

    SubShader
    {
        // 修改为透明 Pass
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        Cull Back
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha
        CGPROGRAM
        #include "UnityPBSLighting.cginc"
        #include "UnityShaderVariables.cginc"
        #include "UnityCG.cginc"
        #pragma target 3.0
        #pragma multi_compile __ _TOONSHADING_ON
        #pragma surface surf StandardCustomLighting keepalpha noshadow vertex:vertexDataFunc 

        struct Input
        {
            float2 uv_texcoord;
            float3 worldNormal;
            INTERNAL_DATA
            float3 worldPos;
        };

        struct SurfaceOutputCustomLightingCustom
        {
            half3 Albedo;
            half3 Normal;
            half3 Emission;
            half Metallic;
            half Smoothness;
            half Occlusion;
            half Alpha;
            Input SurfInput;
            UnityGIInput GIData;
        };

        uniform sampler2D _MainTex;
        uniform float4 _MainTex_ST;
        uniform float4 _Color;
        uniform sampler2D _BumpMap;
        uniform float4 _BumpMap_ST;
        uniform sampler2D _Emission;
        uniform float4 _Emission_ST;
        uniform float _EmissionPower;
        uniform sampler2D _Metallic;
        uniform float4 _Metallic_ST;
        uniform float _Smoothness;
        uniform sampler2D _Occlusion;
        uniform float4 _Occlusion_ST;
        uniform float _CellShadingSharpness;
        uniform float _ToonSpecularSize;
        uniform float _ToonSpecularIntensity;

        // 新增透明度 uniform
        uniform float _Opacity;

        #define RALIV_PENETRATOR;

        #include "../Plugins/RalivDPS_Defines.cginc"
        #include "../Plugins/RalivDPS_Functions.cginc"

        void vertexDataFunc( inout appdata_full v, out Input o )
        {
            UNITY_INITIALIZE_OUTPUT( Input, o );
            o.uv_texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
            o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
            o.worldNormal = v.normal;
        }

        inline half4 LightingStandardCustomLighting( inout SurfaceOutputCustomLightingCustom s, half3 viewDir, UnityGI gi )
        {
            UnityGIInput data = s.GIData;
            Input i = s.SurfInput;
            half4 c = 0;
            SurfaceOutputStandard s393 = (SurfaceOutputStandard)0;
            float2 uv_MainTex = i.uv_texcoord * _MainTex_ST.xy + _MainTex_ST.zw;
            float4 tex2DNode145 = tex2D(_MainTex, uv_MainTex);
            float4 temp_output_146_0 = (tex2DNode145 * _Color);
            s393.Albedo = temp_output_146_0.rgb;
            float2 uv_BumpMap = i.uv_texcoord * _BumpMap_ST.xy + _BumpMap_ST.zw;
            float3 tex2DNode147 = UnpackNormal(tex2D(_BumpMap, uv_BumpMap));
            s393.Normal = WorldNormalVector(i, tex2DNode147);
            float2 uv_Emission = i.uv_texcoord * _Emission_ST.xy + _Emission_ST.zw;
            float4 tex2DNode283 = tex2D(_Emission, uv_Emission);
            s393.Emission = (tex2DNode283 * _EmissionPower).rgb;
            float2 uv_Metallic = i.uv_texcoord * _Metallic_ST.xy + _Metallic_ST.zw;
            float4 tex2DNode148 = tex2D(_Metallic, uv_Metallic);
            s393.Metallic = tex2DNode148.r;
            s393.Smoothness = (tex2DNode148.a * _Smoothness);
            float2 uv_Occlusion = i.uv_texcoord * _Occlusion_ST.xy + _Occlusion_ST.zw;
            s393.Occlusion = tex2D(_Occlusion, uv_Occlusion).r;

            data.light = gi.light;

            UnityGI gi393 = gi;
            #ifdef UNITY_PASS_FORWARDBASE
            Unity_GlossyEnvironmentData g393 = UnityGlossyEnvironmentSetup(s393.Smoothness, data.worldViewDir, s393.Normal, float3(0,0,0));
            gi393 = UnityGlobalIllumination(data, s393.Occlusion, s393.Normal, g393);
            #endif

            float3 surfResult393 = LightingStandard(s393, viewDir, gi393).rgb;
            surfResult393 += s393.Emission;

            #ifdef UNITY_PASS_FORWARDADD
                surfResult393 -= s393.Emission;
            #endif

            #if defined(LIGHTMAP_ON) && (UNITY_VERSION < 560 || (defined(LIGHTMAP_SHADOW_MIXING) && !defined(SHADOWS_SHADOWMASK) && defined(SHADOWS_SCREEN)))
                float4 ase_lightColor = 0;
            #else
                float4 ase_lightColor = _LightColor0;
            #endif
            float3 newWorldNormal396 = (WorldNormalVector(i, tex2DNode147));
            float3 ase_worldPos = i.worldPos;
            #if defined(LIGHTMAP_ON) && UNITY_VERSION < 560
                float3 ase_worldlightDir = 0;
            #else
                float3 ase_worldlightDir = normalize(UnityWorldSpaceLightDir(ase_worldPos));
            #endif
            float dotResult5_g1 = dot(newWorldNormal396, ase_worldlightDir);
            float temp_output_402_0 = (_CellShadingSharpness * 10.0);
            UnityGI gi411 = gi;
            float3 diffNorm411 = WorldNormalVector(i, tex2DNode147);
            gi411 = UnityGI_Base(data, 1, diffNorm411);
            float3 indirectDiffuse411 = gi411.indirect.diffuse + diffNorm411 * 0.0001;
            float temp_output_470_0 = (1.0 - _ToonSpecularSize);
            float temp_output_457_0 = (temp_output_470_0 * temp_output_470_0);
            float3 normalizeResult446 = normalize(reflect(-ase_worldlightDir, newWorldNormal396));
            float3 ase_worldViewDir = normalize(UnityWorldSpaceViewDir(ase_worldPos));
            float dotResult418 = dot(normalizeResult446, ase_worldViewDir);
            float saferPower437 = max(dotResult418, 0.0001);
            float temp_output_437_0 = pow(saferPower437, 20.0);
            float smoothstepResult449 = smoothstep(temp_output_457_0, (temp_output_457_0 + (((1.1 - temp_output_457_0) * 0.5))), temp_output_437_0);
            #ifdef _TOONSHADING_ON
                float4 staticSwitch436 = ((ase_lightColor * max(saturate((-temp_output_402_0 + ((dotResult5_g1*0.5 + 0.5) - 0.0) * ((temp_output_402_0 + 1.0) - -temp_output_402_0) / (1.0 - 0.0))), 0.1) * temp_output_146_0) + (float4(indirectDiffuse411, 0.0) * temp_output_146_0) + (ase_lightColor * saturate(smoothstepResult449) * _ToonSpecularIntensity));
            #else
                float4 staticSwitch436 = float4(surfResult393, 0.0);
            #endif
            c.rgb = staticSwitch436.rgb;
            c.a = _Opacity;
            return c;
        }

        inline void LightingStandardCustomLighting_GI(inout SurfaceOutputCustomLightingCustom s, UnityGIInput data, inout UnityGI gi)
        {
            s.GIData = data;
        }

        void surf(Input i, inout SurfaceOutputCustomLightingCustom o)
        {
            o.SurfInput = i;
            o.Normal = float3(0,0,1);
            float2 uv_MainTex = i.uv_texcoord * _MainTex_ST.xy + _MainTex_ST.zw;
            float4 tex2DNode145 = tex2D(_MainTex, uv_MainTex);
            float4 temp_output_146_0 = (tex2DNode145 * _Color);
            o.Albedo = temp_output_146_0.rgb;
        }
        ENDCG

        // 圆柱生成部分保持不变
        Pass
        {
            Name "Cylinders"
            Tags { "LightMode"="Always" }
            Cull Off
            ZTest LEqual
            ZWrite On
            CGPROGRAM
            #pragma vertex CylinderVS
            #pragma geometry CylinderGS
            #pragma fragment CylinderPS
            #pragma target 4.0

            uniform float _CylinderRadius;
            uniform float _Length;

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct GSOutput
            {
                float4 pos : SV_POSITION;
                float t : TEXCOORD0;
            };

            GSOutput CylinderVS(appdata v)
            {
                GSOutput o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.t = 0;
                return o;
            }

            [maxvertexcount(136)]
            void CylinderGS(point GSOutput input[1], inout TriangleStream<GSOutput> triStream)
            {
                bool foundLight = false;
                float3 basePos = float3(0, 0, 0);
                for (int i = 0; i < 4; i++)
                {
                    if (length(unity_LightColor[i].rgb) < 0.01)
                    {
                        float lightAtten = unity_4LightAtten0[i];
                        float range = (0.005 * sqrt(1000000 - lightAtten)) / sqrt(lightAtten);
                        float modVal = fmod(range, 0.1);
                        if (abs(modVal - 0.01) < 0.005 || abs(modVal - 0.02) < 0.005)
                        {
                            foundLight = true;
                            float4 lightWorldPos = float4(
                                unity_4LightPosX0[i],
                                unity_4LightPosY0[i],
                                unity_4LightPosZ0[i],
                                1
                            );
                            float3 tipPos = mul(unity_WorldToObject, lightWorldPos).xyz;
                            float3 dir = tipPos - basePos;
                            float height = length(dir);
                            if (height < 0.001) continue;
                            dir = normalize(dir);
                            float3 up = abs(dot(dir, float3(0,1,0))) < 0.99 ? float3(0,1,0) : float3(1,0,0);
                            float3 right = normalize(cross(dir, up));
                            up = normalize(cross(right, dir));

                            const int segments = 16;
                            for (int j = 0; j <= segments; j++)
                            {
                                float angle = (j / (float)segments) * 6.2831853;
                                float cosA = cos(angle);
                                float sinA = sin(angle);
                                float3 offset = right * cosA * _CylinderRadius + up * sinA * _CylinderRadius;

                                GSOutput vOut;
                                float3 posBase = basePos + offset;
                                vOut.pos = UnityObjectToClipPos(float4(posBase, 1));
                                vOut.t = 0.0;
                                triStream.Append(vOut);
                                float3 posTip = tipPos + offset;
                                vOut.pos = UnityObjectToClipPos(float4(posTip, 1));
                                vOut.t = 1.0;
                                triStream.Append(vOut);
                            }
                            triStream.RestartStrip();
                        }
                    }
                }
                if (!foundLight)
                {
                    GSOutput v;
                    v.pos = float4(-10000, -10000, 0, 1);
                    v.t = 0.0;
                    triStream.Append(v);
                    triStream.Append(v);
                    triStream.Append(v);
                    triStream.RestartStrip();
                }
            }

            fixed4 CylinderPS(GSOutput input) : SV_Target
            {
                float t = input.t;
                float3 color = 0.5 + 0.5 * cos(6.28318 * t + float3(0.0, 2.094, 4.188));
                return fixed4(color, 1);
            }
            ENDCG
        }
    }

}
