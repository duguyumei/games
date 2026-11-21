# Unity 复刻路线 v0.1

> 2026-11-21 用户裁定：**切 Unity 重来**（原 Godot 线封存不删——qi-forge-2 仓转知识库；`~/Documents/vc_decomp/` 证据库永远不动，工作一律在拷贝上做）。
> 用途口径：**本地研究/学习复刻**——不发布、不分发；qi-forge-2 仓「他作素材不入仓」红线沿用。
> 勘验日：2026-11-21（详见 §二）；本文＝总路线＋第 0–2 步操作单，后续步骤随进度升版。

## 一、重建原理（为什么这条路能 1:1 到底）

AssetRipper 本次导出用的是 **DummyDll 模式**：游戏主代码已还原为 `Plugins/Pancake.dll`（全类型/字段/方法签名，方法体空壳），第三方依赖 DOTween(Pro)/UniTask/Sirenix(Odin)/MasterAudio/InputSystem/DamageNumbersPro 等全套 DLL 同在。

- **资产侧零手术**：prefab/场景对脚本的引用＝`{fileID: 类全名哈希, guid: DLL 的 .meta GUID}`——只要类名/命名空间/DLL GUID 不变，**替换 DLL 内容＝引用自动生效**，不需要逐 prefab 重挂。
- **代码侧＝填体**：Pancake.dll 反编译成 C# 源（ILSpy；声明全真）→ 按 Ghidra 伪码（`~/Documents/vc_decomp/ghidra_decomp/` 2117 类 fail=0）逐方法填体 → 编回同名 DLL 放回 Plugins/ → Unity 重载。**循环推进，填到哪跑到哪**。
- 证据层级不变：伪码＝汇编便捷视图，行为存疑处仍 lldb 实机对拍（Steam 原版在库）。

## 二、工程勘验（2026-11-21 实测）

| 项 | 实测值 |
|---|---|
| 精确版本 | **6000.0.62f1**（ProjectSettings/ProjectVersion.txt） |
| 顶层 | Assets／Packages／ProjectSettings（标准三件） |
| 体积 | 2.0 GB |
| Packages | 仅引擎内置模块（无商店包依赖）；TMP 以 Assets 内文件夹形式自带 |
| Plugins/ | Pancake.dll（主代码）、__Generated.dll、Nosebleed.PlatformManager.*、Nosebleed.Library.Tweens.Runtime、DOTween.dll＋DOTweenPro.dll、UniTask、Sirenix.Utilities＋OdinInspector.Modules（**Odin 序列化器在位**→CardConfig 的 SerializedBytes 可反序列化）、DarkTonic.MasterAudio、Unity.InputSystem(+ForUI/RebindingUI)、DamageNumbersPro、Coffee.SoftMaskForUGUI、Eflatun.SceneReference、DelaunatorSharp、UImGui、GUIAnimatorFREE、Unity.Addressables/ResourceManager/Collections/Burst.Unsafe/VisualScripting.Core/2D.*… |
| 独立 .cs stub | 仅 37 个（第三方 demo/杂件＋AssemblyInfo），无编译错误源 |
| Assets 分类 | AnimationClip/AnimatorController/AudioClip/Material/Mesh/MonoBehaviour(SO)/GameObject(prefab)/Shader/Sprite/Texture2D/TextMesh Pro/_GameAssets/StreamingAssets… |

## 三、步骤总表

| 步 | 内容 | 状态 |
|---|---|---|
| 0 | 装 Unity Hub＋精确 6000.0.62f1＋Personal 许可 | ✅ 2026-11-21 完成（Hub 下载 404＝国内被 302 到 unitychina 旧版缺失→官方 API 直链装 pkg；本体在 /Applications/Unity/Unity.app，Hub 未登记不影响） |
| 1 | 拷贝工程→首次打开→验收「组件真实解析」 | ✅ 工程在 ~/Documents/qi-unity；首开安全模式一次性现象，复开零编译错误 |
| 2 | 基线验收：SC_Game 场景/Hierarchy/Console 截图归档 | ✅ **判定通过**：SC_Game 打开、Card_RewardChest 的 CardView 真实解析、字段与 csall 清单逐一对上（:2556-2594 含五戳记/wild 视觉组） |
| 3 | 填体循环工具链：ILSpy 导出 Pancake.dll→可编译 csproj→空体回编→替换 DLL | ✅ 2026-11-21 收官（详 §三A 收官段；0 错误出 DLL＋零手术替换验收过） |
| 4 | L0 底座填体（NBUtil/TransformMover2D/StateMachine/Singleton/AssetDatabase/Variables） | 对应原批1 前置 |
| 5 | 卡牌六件套填体（CardConfig/CardModel/CardPileModel/视图族/PlayerModel/CardEffect） | 对应原批1-5 |
| 6 | 战斗环/状态机/遭遇/敌方/武器 | 原批6 |
| 7 | 地牢/地图、奖励、元进度、存档 | 原批7-10 |
| 8 | 全链可跑验收（对拍原版行为） | 长期 |

## 三A、第 3 步工具链攻坚实录（2026-11-21）

**工作区**：`~/Documents/vc_work/Pancake_src/`（ilspycmd 11.2 反编译产出：1254 个 .cs＋Pancake.csproj，5.8MB；方法体全空壳＝填体工作法理想起点）。工具：dotnet 10（Homebrew 已有）＋`dotnet tool install -g ilspycmd`（注意 PATH 要加 ~/.dotnet/tools）。

**编译配置四轮组合拳（结论定案）**：
| 组合 | BCL | 引用 | 结果 |
|---|---|---|---|
| 1 | netstandard2.1 | 真引擎模块＋dummy 兄弟件 | ❌ CS0311（dummy 的 net40 mscorlib 身份 vs netstandard System.Object 打架） |
| 2 | DummyDll mscorlib（FrameworkPathOverride） | 全 dummy | ❌ Roslyn NRE 崩溃（dotnet10 编译器读 dummy 属性元数据抛 NullReferenceException） |
| 3 | **Mono 4.7.1-api（编辑器自带 MonoBleedingEdge）** | **全 dummy（引擎模块也用 dump_out/DummyDll 版）** | ✅ **只剩一族错**：CS0617（CreateAssetMenu 命名参数） |
| 4 | Mono BCL＋netstandard 门面 | 真引擎＋dummy＋门面 | ❌ netstandard 门面与 mscorlib 双 System.Object 身份→CS0104/CS0311 回潮 |

**CS0617 病根（已留档）**：DummyDll 的 `CreateAssetMenuAttribute.fileName/menuName` 被 Il2CppDumper 导成**只写属性**（getter 丢失），命名参数要求可读写属性。修法＝175 处 `[CreateAssetMenu(fileName=…, menuName=…)]` 压平为 `[CreateAssetMenu]`（该特性纯编辑器菜单、无运行时语义、不进序列化）——批量改动走 Edit 工具（**钩子铁规：.cs 文件禁 Bash/sed 写，只能 Read+Edit**）。

**收官（2026-11-21 16:57，M1 完成）**：

- **终局编译配置（组合七·定案，后续一律照此）**：`Contents/NetCoreRuntime/dotnet exec Contents/DotNetSdkRoslyn/csc.dll @rsp` ＋ `/nostdlib` ＋ **BCL＝netstandard2.1 闭包**（`NetStandard/ref/2.1.0/netstandard.dll` ＋ `compat/2.1.0/shims/netstandard/*` ＋ `shims/netfx/*`）＋ 引用＝DummyDll 全套（**剔除 mscorlib/System/System.Core 与 Pancake 自身**）＋ `/langversion:preview`（C#11 自动默认字段）＋ 源＝`find … -name '*.cs' -not -path '*/obj/*' -not -path '*/bin/*'`。响应文件存 `/tmp/pancake4.rsp`（1378 行）。
- **关键病根四则（踩坑记录，复用价值最高）**：① **dummy mscorlib 被 Roslyn 4.3 静默拒载**（ILSpy 11 能读≠csc 能用；症状 CS0518 九万错；.NET 10 Roslyn 则直接 NRE 崩溃）——BCL 必须走 netstandard 闭包；② **CS0311 族＝反编译把约束 `UnityEngine.Object` 剥成裸 `Object`**，被解析成 System.Object——六件泛型类约束全部限定；③ **CS0721 族＝反编译剥掉可空泛型参数**（`Nullable` 应为 `Vector3?`/`Color?`）——13 个 Direction＋DamageEffect/EnemyView/WeaponCollision 按原签名还原；④ **带空格的烂尾文件名会炸响应文件参数流**（子代理被杀留了 9 个 `XXX 2.cs`，rsp 逐行解析被拆成两个参数）——已全删；教训：探针实验必须踩到目标错误类别（`tail -3` 曾把 CS0518 截掉骗过我）。
- **修复总账**：175 处 CreateAssetMenu 压平；13 件 C#12 主构造坏件按 `CSharp11_0` 单类型重反编译＋角括号标识符转义（`_003C_003E` 制）；约 30 文件别名/限定修复（`Object`/`Random`/`UnityEvent`/`MinMaxGradient`/`Particle`/`Awaitable.Awaiter`/`UnityEngine.Random.State`）；3 件状态机改显式接口实现（`void IAsyncStateMachine.MoveNext()`）；3 处 out 参数补 `default` 赋值。
- **结果**：1254 源文件 **0 错误**编出 1.4M `Pancake.dll`（`~/Documents/vc_work/Pancake_out/`）；原 dummy 备份至 `~/Documents/vc_work/Pancake.dll.orig-dummy`（**勿放 Assets 内**——`.dll` 后缀会被 Unity 当插件二次导入＝同类型重复地雷，已拆）。
- **替换验证（用户 F5 级验收·截图在案）**：`.meta` GUID 一字未动；无 Safe Mode、无 Missing Script、无 Could not load type；`Card_View(Script)` 及全部字段引用完好；Console 一条 NRE＝空方法体的预期现象（填体进度条）。**零手术替换闭环成立。**
- **填体循环（日常一条龙）**：改 `vc_work/Pancake_src` 源码 → `cd Pancake_src && dotnet exec $U/DotNetSdkRoslyn/csc.dll @/tmp/pancake4.rsp` → `cp ../Pancake_out/Pancake.dll ~/Documents/qi-unity/Assets/Plugins/` → 点 Unity 聚焦重载。

**让步清单（骨架与原版的编译级偏离，全部无运行时语义）**：① 175 处 CreateAssetMenu 参数压平（纯编辑器菜单）；② WeaponTargeting 的 using 拼写修正（反编译输出笔误 APIMoving→APIUpdating）；③ `PixelateRenderFeature.SetupRenderPasses` 暂注释（dummy 元数据缺 in 参数 modreq；**填体轮须恢复**）；④ 别名补写属编译必需（程序集不记录 using）；⑤ out 参数补值/空体 return 属占位（填体时被真体覆盖）；⑥ Token/Address 注记属性只存在于 13 件重反编译文件（引用 Il2CppDummyDll.dll，运行时无语义）。

**里程碑表**：M1 工具链闭环 ✅（2026-11-21）→ M2 第一张卡活（L0 底座＋卡牌六件套最小环：抽牌进手/扇形显示/点击打出）→ M3 一场战斗能打完 → M4 地牢能走 → M5 局外循环。**范围修正（2026-11-21 类全量清单勘误，取代前述「StateMachine 住 Core.Runtime」的说法）**：StateMachine 框架（`Nosebleed.StateMachine` 6 类 85 法）与 View 基类（View/GameView）**住 Pancake.dll 本体、M1 骨架已在位**；姊妹 DLL 实际体量＝Core.Runtime 设计 26 类/132 法（Singleton/ServiceLocator/MessageBox/NBLog）＋Tweens 11 类＋PlatformManager 家族 56 类——均为小件，不在 M2 卡牌链关键路径。工作面全账见 `references/吸血鬼爬行者_类全量清单_v0.1.md`（1,828 设计类型，一类不漏）。

## 四、第 0 步操作单（macOS·亲手做）

1. 下载 Unity Hub：unity.com/download → Download for Mac → 装（拖进 Applications）。
2. 打开 Hub → 注册/登录 Unity 账号（免费）→ 按引导激活 **Personal** 许可（免费）。
3. 装编辑器：Hub 左侧 **Installs → Install Editor**。默认列表是最新版——**不要装最新**：
   - 在版本列表里找 **6000.0.62f1**（Unity 6.0 段）；
   - 列表没有就点底部「从版本存档安装／Archive」，或浏览器打开 `unity.com/releases/editor/whats-new/6000.0.62`，页面底部 Downloads 区点 **Unity Hub** 链接（`unityhub://…`）会自动跳回 Hub 直接装。
4. 模块勾选：默认即可（macOS 支持自带）；不必勾其他平台。
5. 完成＝Installs 列表出现 **6000.0.62f1**。

## 五、第 1 步操作单（拷贝＋首开）

1. 拷贝工程（保 vc_decomp 纯净）：终端执行
   `cp -R ~/Documents/vc_decomp/rip/ExportedProject ~/Documents/qi-unity`
   （2GB，几分钟；名字 qi-unity 可换）。
2. Hub → **Projects → Open → Add project from disk** → 选 `~/Documents/qi-unity`（含 Assets 的那层）→ 打开（提示版本匹配即正常）。
3. 首开预期（照单验收，别慌）：
   - 资产导入进度条较久（2GB，几分钟到十几分钟属正常）；
   - Console 若提示 **TextMesh Pro: Import TMP Essentials** → 点 **Import TMP Essentials**；
   - 个别 shader/材质警告可忽略；**不要**动任何资产。
4. **关键验收点**：Project 窗口搜 `SC_Game` 双击打开场景（`Assets/_GameAssets/Scenes/`）→ Hierarchy 展开任一 HUD/卡对象 → Inspector 看组件：
   - ✅ 成功＝显示真实类型名（CardModel／CardView／HandPileView…来自 Pancake.dll）＋序列化字段数值；
   - ❌ 失败＝大面积「**Script Missing**」或场景打不开 → Console 截图给我。

## 六、第 2 步操作单（基线归档）

- Hierarchy 截图三张：SC_Game 顶层树／HandPile 区展开／任一敌人对象。
- Console「Clear」后无红错截图一张。
- 过了这关 → 下一批我给**第 3 步工具链**（ILSpy 导出→csproj 修参→空体回编→DLL 替换循环）的逐步操作。

## 七、待办与待批

- 〔待批〕AGENTS.md 引擎篇改写（Godot→Unity 双轨口径：qi-forge-2＝封存知识库，qi-unity＝现役）。
- 〔待办〕Godot 线收口口径（现役线冻结于 commit ea398efb＋工作区态）。
- 〔待查〕Plugins 全量 DLL 清单归档（Animancer 是否在位未确认——首开后看 Inspector 里 AnimatedWeapon 组件是否解析即可知）。
- 〔原则〕vc_decomp 永不改；qi-unity 内改动全部可弃（坏了重拷）。
