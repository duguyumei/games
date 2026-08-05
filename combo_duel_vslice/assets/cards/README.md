# 真气整卡图片接入

将 52 张完整牌图放在本目录，文件名使用基础真气 ID：

```text
wind_A.png
wind_2.png
forest_K.png
fire_10.png
mountain_Q.png
```

属性前缀固定为 `wind`、`forest`、`fire`、`mountain`；牌阶为
`2`～`10`、`J`、`Q`、`K`、`A`。支持 PNG、WebP 和 JPG，优先读取 PNG。

牌图按完整扑克牌画面接入；程序只保留选择金框、悬浮抬升和点击交互，不再叠加
占位牌阶、属性徽记或真气值文字。缺少对应图片时才显示程序生成的占位牌面。
