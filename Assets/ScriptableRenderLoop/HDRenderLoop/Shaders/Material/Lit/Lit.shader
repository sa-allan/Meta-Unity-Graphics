Shader "Unity/Lit"
{
    Properties
    {
        // Following set of parameters represent the parameters node inside the MaterialGraph.
        // They are use to fill a SurfaceData. With a MaterialGraph this should not exist.

        // Reminder. Color here are in linear but the UI (color picker) do the conversion sRGB to linear
        _BaseColor("BaseColor", Color) = (1,1,1,1)
        _BaseColorMap("BaseColorMap", 2D) = "white" {}

        _Metalic("_Metalic", Range(0.0, 1.0)) = 0
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5
        _MaskMap("MaskMap", 2D) = "white" {}

        _SpecularOcclusionMap("SpecularOcclusion", 2D) = "white" {}

        _NormalMap("NormalMap", 2D) = "bump" {}
        [Enum(TangentSpace, 0, ObjectSpace, 1)] _NormalMapSpace("NormalMap space", Float) = 0

        _HeightMap("HeightMap", 2D) = "black" {}
        _HeightScale("Height Scale", Float) = 1
        _HeightBias("Height Bias", Float) = 0
        [Enum(Parallax, 0, Displacement, 1)] _HeightMapMode("Heightmap usage", Float) = 0

        _SubSurfaceRadius("SubSurfaceRadius", Range(0.0, 1.0)) = 0
        _SubSurfaceRadiusMap("SubSurfaceRadiusMap", 2D) = "white" {}
        //_Thickness("Thickness", Range(0.0, 1.0)) = 0
        //_ThicknessMap("ThicknessMap", 2D) = "white" {}
        //_SubSurfaceProfile("SubSurfaceProfile", Float) = 0

        //_CoatCoverage("CoatCoverage", Range(0.0, 1.0)) = 0
        //_CoatCoverageMap("CoatCoverageMapMap", 2D) = "white" {}

        //_CoatRoughness("CoatRoughness", Range(0.0, 1.0)) = 0
        //_CoatRoughnessMap("CoatRoughnessMap", 2D) = "white" {}

        // _DistortionVectorMap("DistortionVectorMap", 2D) = "white" {}
        // _DistortionBlur("DistortionBlur", Range(0.0, 1.0)) = 0

        // Following options are for the GUI inspector and different from the input parameters above
        // These option below will cause different compilation flag.

        _DiffuseLightingMap("DiffuseLightingMap", 2D) = "black" {}
        _EmissiveColor("EmissiveColor", Color) = (0, 0, 0)
        _EmissiveColorMap("EmissiveColorMap", 2D) = "white" {}
        _EmissiveIntensity("EmissiveIntensity", Float) = 0

        [ToggleOff]     _DistortionOnly("Distortion Only", Float) = 0.0
        [ToggleOff]     _DistortionDepthTest("Distortion Only", Float) = 0.0

        [ToggleOff]  _AlphaCutoffEnable("Alpha Cutoff Enable", Float) = 0.0
        _AlphaCutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

        // Blending state
        [HideInInspector] _SurfaceType("__surfacetype", Float) = 0.0
        [HideInInspector] _BlendMode ("__blendmode", Float) = 0.0
        [HideInInspector] _SrcBlend ("__src", Float) = 1.0
        [HideInInspector] _DstBlend ("__dst", Float) = 0.0
        [HideInInspector] _ZWrite ("__zw", Float) = 1.0
        [HideInInspector] _CullMode("__cullmode", Float) = 2.0
        // Material Id
        [HideInInspector] _MaterialId("_MaterialId", FLoat) = 0

        [Enum(Mask Alpha, 0, BaseColor Alpha, 1)] _SmoothnessTextureChannel("Smoothness texture channel", Float) = 1
        [Enum(Use Emissive Color, 0, Use Emissive Mask, 1)] _EmissiveColorMode("Emissive color mode", Float) = 1
        [Enum(None, 0, DoubleSided, 1, DoubleSidedLigthingFlip, 2, DoubleSidedLigthingMirror, 3)] _DoubleSidedMode("Double sided mode", Float) = 0
    }

    HLSLINCLUDE

    #pragma target 5.0
    #pragma only_renderers d3d11 // TEMP: unitl we go futher in dev

    #pragma shader_feature _ALPHATEST_ON
    #pragma shader_feature _ _DOUBLESIDED_LIGHTING_FLIP _DOUBLESIDED_LIGHTING_MIRROR
    #pragma shader_feature _NORMALMAP
    #pragma shader_feature _NORMALMAP_TANGENT_SPACE
    #pragma shader_feature _MASKMAP
    #pragma shader_feature _SPECULAROCCLUSIONMAP
    #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
    #pragma shader_feature _EMISSIVE_COLOR
    #pragma shader_feature _EMISSIVE_COLOR_MAP
    #pragma shader_feature _HEIGHTMAP
    #pragma shader_feature _HEIGHTMAP_AS_DISPLACEMENT

    #include "LitTemplate.hlsl"

    ENDHLSL

    SubShader
    {
        Tags { "RenderType"="Opaque" "PerformanceChecks"="False" }
        LOD 300

        // ------------------------------------------------------------------
        //  Deferred pass
        Pass
        {
            Name "GBuffer"  // Name is not used
            Tags { "LightMode" = "GBuffer" } // This will be only for opaque object based on the RenderQueue index

            Cull  [_CullMode]

            HLSLPROGRAM

            #pragma vertex VertDefault
            #pragma fragment FragDeferred

            #if SHADER_STAGE_FRAGMENT

            void FragDeferred(  PackedVaryings packedInput,
                                OUTPUT_GBUFFER(outGBuffer)
                                #ifdef VELOCITY_IN_GBUFFER
                                , OUTPUT_GBUFFER_VELOCITY(outGBuffer)
                                #endif
                                , OUTPUT_GBUFFER_BAKE_LIGHTING(outGBuffer)
                                )
            {
                Varyings input = UnpackVaryings(packedInput);
                float3 V = GetWorldSpaceNormalizeViewDir(input.positionWS);
                float3 positionWS = input.positionWS;

                SurfaceData surfaceData;
                BuiltinData builtinData;
                GetSurfaceAndBuiltinData(input, surfaceData, builtinData);

                BSDFData bsdfData = ConvertSurfaceDataToBSDFData(surfaceData);
                Coordinate coord = GetCoordinate(input.positionHS.xy, _ScreenSize.zw);
                PreLightData preLightData = GetPreLightData(V, positionWS, coord, bsdfData);

                ENCODE_INTO_GBUFFER(surfaceData, outGBuffer);
                #ifdef VELOCITY_IN_GBUFFER
                ENCODE_VELOCITY_INTO_GBUFFER(builtinData.velocity, outGBuffer);
                #endif
                ENCODE_BAKE_LIGHTING_INTO_GBUFFER(GetBakedDiffuseLigthing(preLightData, surfaceData, builtinData, bsdfData), outGBuffer);
            }

            #endif

            ENDHLSL
        }

        // ------------------------------------------------------------------
        //  Debug pass
        Pass
        {
            Name "Debug"
            Tags { "LightMode" = "DebugView" }

            Cull[_CullMode]

            HLSLPROGRAM

            #pragma vertex VertDefault
            #pragma fragment FragDebug

            #include "Color.hlsl"

            int _DebugViewMaterial;

            #if SHADER_STAGE_FRAGMENT

            float4 FragDebug( PackedVaryings packedInput ) : SV_Target
            {
                Varyings input = UnpackVaryings(packedInput);
                SurfaceData surfaceData;
                BuiltinData builtinData;
                GetSurfaceAndBuiltinData(input, surfaceData, builtinData);

                BSDFData bsdfData = ConvertSurfaceDataToBSDFData(surfaceData);

                float3 result = float3(1.0, 1.0, 0.0);
                bool needLinearToSRGB = false;

                GetVaryingsDataDebug(_DebugViewMaterial, input, result, needLinearToSRGB);
                GetBuiltinDataDebug(_DebugViewMaterial, builtinData, result, needLinearToSRGB);
                GetSurfaceDataDebug(_DebugViewMaterial, surfaceData, result, needLinearToSRGB);
                GetBSDFDataDebug(_DebugViewMaterial, bsdfData, result, needLinearToSRGB); // TODO: This required to initialize all field from BSDFData...

                // TEMP!
                // For now, the final blit in the backbuffer performs an sRGB write
                // So in the meantime we apply the inverse transform to linear data to compensate.
                if (!needLinearToSRGB)
                    result = SRGBToLinear(max(0, result));

                return float4(result, 0.0);
            }

            #endif

            ENDHLSL
        }

        // ------------------------------------------------------------------
        //  forward pass
        Pass
        {
            Name "Forward" // Name is not used
            Tags { "LightMode" = "Forward" } // This will be only for transparent object based on the RenderQueue index

            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
            Cull [_CullMode]

            HLSLPROGRAM

            #pragma vertex VertDefault
            #pragma fragment FragForward

            #if SHADER_STAGE_FRAGMENT

            float4 FragForward(PackedVaryings packedInput) : SV_Target
            {
                Varyings input = UnpackVaryings(packedInput);
                float3 V = GetWorldSpaceNormalizeViewDir(input.positionWS);
                float3 positionWS = input.positionWS;

                SurfaceData surfaceData;
                BuiltinData builtinData;
                GetSurfaceAndBuiltinData(input, surfaceData, builtinData);

                BSDFData bsdfData = ConvertSurfaceDataToBSDFData(surfaceData);
                Coordinate coord = GetCoordinate(input.positionHS.xy, _ScreenSize.zw);
                PreLightData preLightData = GetPreLightData(V, positionWS, coord, bsdfData);

                float4 diffuseLighting;
                float4 specularLighting;
                ForwardLighting(V, positionWS, preLightData, bsdfData, diffuseLighting, specularLighting);

                diffuseLighting.rgb += GetBakedDiffuseLigthing(preLightData, surfaceData, builtinData, bsdfData);

                return float4(diffuseLighting.rgb + specularLighting.rgb, builtinData.opacity);
            }

            #endif

            ENDHLSL
        }
    }

    CustomEditor "LitGUI"
}
