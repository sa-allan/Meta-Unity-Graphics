using System.Collections;
using NUnit.Framework;
using Unity.Testing.VisualEffectGraph;
using UnityEngine.TestTools;


namespace UnityEngine.VFX.Test
{
    [TestFixture]
    [PrebuildSetup("SetupGraphicsTestCases")]
    public class VFXRuntimeTests
    {
        AssetBundle m_AssetBundle;

        [OneTimeSetUp]
        public void SetUp()
        {
            m_AssetBundle = AssetBundleHelper.Load("scene_in_assetbundle");
        }

        [UnityTest, Description("Cover UUM-20944")]
        public IEnumerator Indirect_Mesh_Rendering_With_Null_IndexBuffer()
        {
            UnityEngine.SceneManagement.SceneManager.LoadScene("Packages/com.unity.testing.visualeffectgraph/Scenes/022_Repro_Crash_Null_Indexbuffer.unity");
            yield return null;

            var vfxComponents = Resources.FindObjectsOfTypeAll<VisualEffect>();
            Assert.AreEqual(1u, vfxComponents.Length);
            var currentVFX = vfxComponents[0];

            var meshID = Shader.PropertyToID("Mesh");
            Assert.IsTrue(currentVFX.HasMesh(meshID));

            int maxFrame = 32;
            while (currentVFX.aliveParticleCount == 0 && maxFrame-- > 0)
            {
                yield return null;
            }
            Assert.IsTrue(maxFrame > 0);

            var mesh = new Mesh
            {
                vertices = new[]
                {
                    new Vector3(0, 0, 0),
                    new Vector3(1, 0, 0),
                    new Vector3(1, 1, 0)
                }
            };
            mesh.subMeshCount = 1;
            mesh.SetSubMesh(0, new Rendering.SubMeshDescriptor { vertexCount = 3 }, Rendering.MeshUpdateFlags.DontRecalculateBounds);

            currentVFX.SetMesh(meshID, mesh);
            maxFrame = 8;
            while (maxFrame-- > 0)
            {
                //The crash was in this case
                yield return null;
            }
        }

        [OneTimeTearDown]
        public void TearDown()
        {
            AssetBundleHelper.Unload(m_AssetBundle);
        }
    }
}
