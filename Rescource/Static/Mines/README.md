# 矿石采集点

对应 `../Material/item*.png` 的 14 个矿点。由内置 image_gen 根据参考图生成，再以最近邻采样导出低分辨率精灵，并匹配对应素材与 item306 岩石的原有色板。

当前为去除外轮廓描边版本，保留内部岩石明暗与矿脉。编辑提示词见 `outline_removal_prompt.txt`，最初带描边的生成原图保存在 `source/mines_outlined_original.png`。

- `mine_item*.png`：14 张独立 PNG，32×32，透明背景，底部基线一致。
- `mines_atlas_32.png`：224×64 图集，7 列 × 2 行，每格 32×32。
- `mines_preview_4x.png`：图集的 4 倍最近邻放大预览。
- `generation_prompt.txt`：完整生成提示词。
- `source/`：生成原图和参考图；通过 `.gdignore` 排除 Godot 导入。

图集从左到右、从上到下对应：

| 第一行 | 第二行 |
| --- | --- |
| item296 淡黄青绿晶矿 | item311 赤橙矿脉 |
| item301 青色块状矿 | item312 铜色矿 |
| item302 青色细矿脉 | item313 橙金矿 |
| item303 细长青晶矿 | item314 冷白矿脉 |
| item304 银白矿块 | item320 粉橙熔火矿 |
| item305 银白晶簇 | item329 青色碎晶矿 |
| item306 普通岩石 | item341 青绿大晶矿 |

Godot 中使用 Nearest 纹理过滤；图集按 32×32 切分，保持整数倍缩放。

如需重新导出，使用 Windows PowerShell：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Rescource\Static\Mines\export_mines.ps1
```
