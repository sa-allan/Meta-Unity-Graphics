using UnityEditor.Rendering.HighDefinition;

using static UnityEngine.Rendering.HighDefinition.HDMaterialProperties;

namespace UnityEngine.Rendering.HighDefinition
{
    internal static class UnlitAPI
    {
        // All Validate functions must be static. It allows to automatically update the shaders with a script if code changes
        internal static void ValidateMaterial(Material material)
        {
            material.SetupBaseUnlitKeywords();
            material.SetupBaseUnlitPass();

            if (material.HasProperty(kEmissiveColorMap))
                CoreUtils.SetKeyword(material, "_EMISSIVE_COLOR_MAP", material.GetTexture(kEmissiveColorMap));

            // All the bits exclusively related to lit are ignored inside the BaseLitGUI function.
            BaseLitAPI.SetupStencil(material, receivesSSR: false, useSplitLighting: false);
        }
    }
}
