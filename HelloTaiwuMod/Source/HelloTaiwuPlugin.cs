using TaiwuModdingLib.Core.Plugin;
using UnityEngine;

namespace HelloTaiwuMod;

[PluginConfig("HelloTaiwuMod", "cc", "0.1.0")]
public sealed class HelloTaiwuPlugin : TaiwuRemakePlugin
{
    public override void Initialize()
    {
        Debug.Log("[HelloTaiwuMod] initialized.");
    }

    public override void Dispose()
    {
        Debug.Log("[HelloTaiwuMod] disposed.");
    }

    public override void OnModSettingUpdate()
    {
        Debug.Log("[HelloTaiwuMod] settings updated.");
    }

    public override void OnEnterNewWorld()
    {
        Debug.Log("[HelloTaiwuMod] entered new world.");
    }

    public override void OnLoadedArchiveData()
    {
        Debug.Log("[HelloTaiwuMod] archive data loaded.");
    }
}

