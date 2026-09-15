# reference/demonic-mahjong —— 《我在地府打麻将》研究标本

用户正版购买的商业闭源游戏（Steam, Unity 6000.3.21f1 Il2Cpp）。**仅作个人研究：只产出设计笔记，零代码、零资源、零反编译产物进入 `forbidden-gamble/` 源码树。**

## 产物

- `我地麻_架构与规则分析.md` —— 主分析报告（规则/架构/内容层/对我们的启示）
- `work/` —— 工具与中间产物：
  - `Il2CppDumper/`（Perfare 上游 + PR #903 v35-v39 支持补丁，自行编译；产物在其 `Il2CppDumper/bin/Release/net8.0/`：`dump.cs` 128 万行、`DummyDll/`、`stringliteral.json`、`script.json`）
  - `GameAssembly_arm64.dylib`（lipo 抽出的 arm64 切片，91MB）
  - `meta_cjk.txt`（global-metadata.dat 中文串 1187 条）
  - `monoscripts.txt`（2163 个 MonoScript 清单：程序集/命名空间/类/所在bundle）
  - `bundle_census.txt`、`textassets/`（Addressables 解包普查与 TextAsset）
  - `pr903/`（API 内联拉取的补丁文件）
  - `extract_cjk.py`、`dump_bundles.py`（抽取脚本）

## 复现管线（macOS arm64）

1. `brew install --cask dotnet-sdk`（需 sudo）
2. Il2CppDumper 源码 + PR #903 补丁（`patch <目标文件> <补丁>` 逐文件打）→ `dotnet build -c Release -f net8.0`，运行时加 `DOTNET_ROLL_FORWARD=Major`
3. `lipo -thin arm64 GameAssembly.dylib -o GameAssembly_arm64.dylib`（上游工具遇 FAT 二进制会交互卡死）
4. `dotnet Il2CppDumper.dll <arm64dylib> <global-metadata.dat> <已存在的输出目录>`（**输出目录必须预先 mkdir**，否则静默落 exe 旁）
5. `python3 -m venv + pip install UnityPy` 解 `Data/StreamingAssets/aa/StandaloneOSX/*.bundle`

## 尚未解出（需要 TypeTreeGenerator + DummyDll 生成 typetree 后 UnityPy 解析）

手牌张数/牌山构成/GameConfig 实例数值/番种番数表/难度数值——均在 ScriptableObject 资产里。
