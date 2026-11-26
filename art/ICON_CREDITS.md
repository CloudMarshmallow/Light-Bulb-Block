# 图标素材来源（ICON CREDITS）

- 游戏图标 `icon.png`：由 `tools/build_icon.gd` 程序合成。
  - 灯泡矢量图形来自 [game-icons.net](https://game-icons.net/) 的 "light-bulb" 图标（作者 Delapouite），
    授权协议 **CC BY 3.0**：https://creativecommons.org/licenses/by/3.0/
  - 背景圆角底、方块网格、琥珀染色与底部方块为程序绘制，无外部素材。
  - 下载来源（镜像）：https://svgicons.com/icon/69895/light-bulb
- 金币图标 `art/icons/coin.png`：由 `tools/build_coin.gd` 合成。
  - 金币矢量图形来自 [game-icons.net](https://game-icons.net/) 的 "two-coins" 图标，
    授权协议 **CC BY 3.0**：https://creativecommons.org/licenses/by/3.0/
  - 通过 [Iconify API](https://api.iconify.design/game-icons/two-coins.svg) 获取原始 SVG，程序渲染为 96×96。
- 商店购物车图标 `art/icons/shop.png`：由 `tools/build_shop_icon.gd` 合成。
  - 矢量图形来自 **Material Symbols** 的 "shopping-cart" 图标，
    授权协议 **Apache-2.0**：https://github.com/google/material-design-icons/blob/master/LICENSE
  - 通过 [Iconify API](https://api.iconify.design/material-symbols/shopping-cart.svg) 获取原始 SVG，
    渲染为 32×32 并做 alpha 阈值化，与其它像素图标风格一致。
- 其余 UI 图标（撤销/提示/时钟/日历/无限等）为 `tools/gen_icons.gd` 程序绘制，无第三方素材。
- 背景图由用户提供照片经像素化处理（`tools/pixelate_bg.gd`）。
- 音效/BGM 由 Godot 技能脚本 `make_sfx.py` / `make_music.py` 合成。
