using System;
using System.Collections.Generic;
using System.Reflection;
using CharacterDataMonitor;
using Game.Views.EventWindow;
using GameData.Domains.Character;
using GameData.Domains.TaiwuEvent.DisplayEvent;
using HarmonyLib;
using TaiwuModdingLib.Core.Plugin;
using UnityEngine;

namespace TaiwuBehaviorOptionSort;

[PluginConfig("TaiwuBehaviorOptionSort.Frontend", "cc", "0.1.5")]
public sealed class TaiwuBehaviorOptionSortPlugin : TaiwuRemakePlugin
{
    private const string PrioritizeSameBehaviorOptionsKey = "PrioritizeSameBehaviorOptions";
    private const string SingleOptionHotkeyCompatKey = "SingleOptionHotkeyCompat";
    private const string MoveSideOptionsAfterNormalOptionsKey = "MoveSideOptionsAfterNormalOptions";

    private static Harmony? s_harmony;

    internal static bool PrioritizeSameBehaviorOptions { get; private set; } = true;

    internal static bool SingleOptionHotkeyCompat { get; private set; } = true;

    internal static bool MoveSideOptionsAfterNormalOptions { get; private set; } = true;

    public override void Initialize()
    {
        LoadSettings();
        s_harmony = new Harmony(ModIdStr + ".BehaviorOptionSort");
        s_harmony.PatchAll(typeof(TaiwuBehaviorOptionSortPlugin).Assembly);
        Debug.Log("[TaiwuBehaviorOptionSort] initialized.");
    }

    public override void OnModSettingUpdate()
    {
        LoadSettings();
    }

    public override void Dispose()
    {
        s_harmony?.UnpatchSelf();
        s_harmony = null;
        Debug.Log("[TaiwuBehaviorOptionSort] disposed.");
    }

    private void LoadSettings()
    {
        bool prioritizeSameBehaviorOptions = true;
        if (ModManager.GetSetting(ModIdStr, PrioritizeSameBehaviorOptionsKey, ref prioritizeSameBehaviorOptions))
        {
            PrioritizeSameBehaviorOptions = prioritizeSameBehaviorOptions;
        }
        else
        {
            PrioritizeSameBehaviorOptions = true;
        }

        bool singleOptionHotkeyCompat = true;
        if (ModManager.GetSetting(ModIdStr, SingleOptionHotkeyCompatKey, ref singleOptionHotkeyCompat))
        {
            SingleOptionHotkeyCompat = singleOptionHotkeyCompat;
        }
        else
        {
            SingleOptionHotkeyCompat = true;
        }

        bool moveSideOptionsAfterNormalOptions = true;
        if (ModManager.GetSetting(ModIdStr, MoveSideOptionsAfterNormalOptionsKey, ref moveSideOptionsAfterNormalOptions))
        {
            MoveSideOptionsAfterNormalOptions = moveSideOptionsAfterNormalOptions;
        }
        else
        {
            MoveSideOptionsAfterNormalOptions = true;
        }

        Debug.Log($"[TaiwuBehaviorOptionSort] settings updated. {PrioritizeSameBehaviorOptionsKey}={PrioritizeSameBehaviorOptions}, {SingleOptionHotkeyCompatKey}={SingleOptionHotkeyCompat}, {MoveSideOptionsAfterNormalOptionsKey}={MoveSideOptionsAfterNormalOptions}");
    }
}

[HarmonyPatch(typeof(ViewEventWindow), "Update")]
internal static class ViewEventWindowUpdatePatch
{
    private static readonly MethodInfo? DataGetter = AccessTools.PropertyGetter(typeof(ViewEventWindow), "Data");
    private static readonly MethodInfo? SelectOptionByIndexMethod = AccessTools.Method(
        typeof(ViewEventWindow),
        "SelectOptionByIndex",
        new[] { typeof(int), typeof(bool) });

    private static bool Prefix(ViewEventWindow __instance)
    {
        if (!TaiwuBehaviorOptionSortPlugin.SingleOptionHotkeyCompat)
        {
            return true;
        }

        if (!Input.GetKeyUp(KeyCode.Alpha1) && !Input.GetKeyUp(KeyCode.Escape))
        {
            return true;
        }

        TaiwuEventDisplayData? data = GetData(__instance);
        if (data?.EventOptionInfos == null || data.EventOptionInfos.Count != 1)
        {
            return true;
        }

        bool onlyOptionIsEscOption = data.EscOptionIndex == 0;
        bool shouldHandleAlpha1 = Input.GetKeyUp(KeyCode.Alpha1) && onlyOptionIsEscOption;
        bool shouldHandleEsc = Input.GetKeyUp(KeyCode.Escape) && !onlyOptionIsEscOption;
        if (!shouldHandleAlpha1 && !shouldHandleEsc)
        {
            return true;
        }

        if (SelectOptionByIndexMethod == null)
        {
            return true;
        }

        try
        {
            object? result = SelectOptionByIndexMethod.Invoke(__instance, new object[] { 0, true });
            return !(result is bool selected && selected);
        }
        catch (Exception ex)
        {
            Debug.LogError("[TaiwuBehaviorOptionSort] failed to select the only event option: " + ex);
            return true;
        }
    }

    internal static TaiwuEventDisplayData? GetData(ViewEventWindow viewEventWindow)
    {
        return DataGetter?.Invoke(viewEventWindow, null) as TaiwuEventDisplayData;
    }
}

[HarmonyPatch(typeof(ViewEventWindow), "UpdateOptionScroll")]
internal static class ViewEventWindowUpdateOptionScrollPatch
{
    internal static bool ShowSingleOptionDualHotkey { get; private set; }

    private static void Prefix(ViewEventWindow __instance, ref IReadOnlyList<EventOptionInfo> optionInfos, ref int escOptionIndex)
    {
        ShowSingleOptionDualHotkey =
            TaiwuBehaviorOptionSortPlugin.SingleOptionHotkeyCompat &&
            optionInfos != null &&
            optionInfos.Count == 1;

        if (optionInfos == null || optionInfos.Count < 2)
        {
            return;
        }

        if (!TaiwuBehaviorOptionSortPlugin.PrioritizeSameBehaviorOptions &&
            !TaiwuBehaviorOptionSortPlugin.MoveSideOptionsAfterNormalOptions)
        {
            return;
        }

        List<EventOptionInfo>? eventOptionInfos = optionInfos as List<EventOptionInfo>;
        if (eventOptionInfos == null)
        {
            return;
        }

        sbyte taiwuBehaviorType = TaiwuBehaviorOptionSortPlugin.PrioritizeSameBehaviorOptions
            ? GetTaiwuBehaviorType()
            : (sbyte)(-1);

        var sortedItems = new List<(EventOptionInfo OptionInfo, int OriginalIndex, int SortGroup)>(eventOptionInfos.Count);
        bool orderChanged = false;
        for (int i = 0; i < eventOptionInfos.Count; i++)
        {
            EventOptionInfo optionInfo = eventOptionInfos[i];
            int sortGroup = GetSortGroup(optionInfo, i, escOptionIndex, taiwuBehaviorType);
            sortedItems.Add((optionInfo, i, sortGroup));
        }

        sortedItems.Sort((left, right) =>
        {
            int groupCompare = left.SortGroup.CompareTo(right.SortGroup);
            return groupCompare != 0 ? groupCompare : left.OriginalIndex.CompareTo(right.OriginalIndex);
        });

        for (int i = 0; i < sortedItems.Count; i++)
        {
            if (sortedItems[i].OriginalIndex != i)
            {
                orderChanged = true;
                break;
            }
        }

        if (!orderChanged)
        {
            return;
        }

        eventOptionInfos.Clear();
        int newEscOptionIndex = -1;
        for (int i = 0; i < sortedItems.Count; i++)
        {
            (EventOptionInfo optionInfo, int originalIndex, _) = sortedItems[i];
            eventOptionInfos.Add(optionInfo);
            if (originalIndex == escOptionIndex)
            {
                newEscOptionIndex = i;
            }
        }

        optionInfos = eventOptionInfos;
        if (newEscOptionIndex >= 0)
        {
            escOptionIndex = newEscOptionIndex;
            TaiwuEventDisplayData? data = ViewEventWindowUpdatePatch.GetData(__instance);
            if (data != null)
            {
                data.EscOptionIndex = (sbyte)newEscOptionIndex;
            }
        }
    }

    private static void Postfix()
    {
        ShowSingleOptionDualHotkey = false;
    }

    private static sbyte GetTaiwuBehaviorType()
    {
        DetailInfoMonitor? monitor = SingletonObject.getInstance<DetailInfoMonitor>();
        return monitor == null ? (sbyte)(-1) : BehaviorType.GetBehaviorType(monitor.Behavior);
    }

    private static bool IsExactBehaviorOption(EventOptionInfo optionInfo, sbyte taiwuBehaviorType)
    {
        if (optionInfo.Behavior == 0)
        {
            return false;
        }

        return ViewEventWindow.OptionBehaviorToCharacterBehavior(optionInfo.Behavior) == taiwuBehaviorType;
    }

    private static bool IsSideOption(EventOptionInfo optionInfo)
    {
        return optionInfo.OptionState == 1 || optionInfo.OptionState == 2;
    }

    private static int GetSortGroup(EventOptionInfo optionInfo, int originalIndex, int escOptionIndex, sbyte taiwuBehaviorType)
    {
        if (originalIndex == escOptionIndex)
        {
            return 4;
        }

        bool isSideOption =
            TaiwuBehaviorOptionSortPlugin.MoveSideOptionsAfterNormalOptions &&
            IsSideOption(optionInfo);
        bool isExactBehaviorOption =
            TaiwuBehaviorOptionSortPlugin.PrioritizeSameBehaviorOptions &&
            taiwuBehaviorType >= 0 &&
            IsExactBehaviorOption(optionInfo, taiwuBehaviorType);

        if (!isSideOption && isExactBehaviorOption)
        {
            return 0;
        }

        if (!isSideOption)
        {
            return 1;
        }

        return isExactBehaviorOption ? 2 : 3;
    }
}

[HarmonyPatch(typeof(EventWindowOption), "Setup")]
internal static class EventWindowOptionSetupPatch
{
    private static void Prefix(ref string commandKey)
    {
        if (ViewEventWindowUpdateOptionScrollPatch.ShowSingleOptionDualHotkey)
        {
            commandKey = $"{EventWindowCommandKit.Option1}/{EventWindowCommandKit.OptionExit}";
        }
    }
}
