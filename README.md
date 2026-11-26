# Find U (寻找另一半) — 3D Godot 4.3 Edition

一款温馨治愈风 3D 寻人冒险小游戏，使用 **Godot 4.3 (GDScript + Procedural 3D / Shaders / Procedural Audio)** 构建。
我将利用这个小游戏记录我和赵睿的点点滴滴。

## 关卡一览
1. **第 1 关：微光蘑菇森林** — 点亮微光蘑菇与音符石阶，拾取信物，解开溪上断桥花藤重逢。
2. **第 2 关：萤火环林（小跳蛙）** — 穿越荆棘栅栏与护城河吊桥，赶跑胆小鬼最怕的小跳蛙。
3. **第 3 关：炽热秋枫林（长凳奶茶）** — 躲避火焰寻得全糖珍珠奶茶，在长凳上悄悄哄好生气的 TA。
4. **第 4 关：云巅飞瀑（大鹈鹕大追击）** — 纵身跃下悬崖飞瀑俯卧滑降追击叼走 TA 的大鹈鹕，触发四档情绪重逢。
5. **第 5 关：微光拼豆屋（手作重逢）** — 在温暖手作小店滑动画制 `19×19` 精致像素拼豆头像，顶住算术突袭并熨烫定型、360° 展示成品后推门赠礼。

## 运行与导出
- **引擎版本**：Godot `v4.3-stable`（`gl_compatibility` 渲染后端）
- **开发运行**：在 Godot 4.3 中打开 `project.godot` 直接运行 `scenes/Main.tscn`
- **无头校验**：
  ```bash
  Godot_v4.3-stable_win64_console.exe --headless --path . --script res://tests/verify_all.gd
  ```
- **导出 Windows 可执行程序**：
  ```bash
  Godot_v4.3-stable_win64_console.exe --headless --path . --export-release "Windows Desktop" "../findyou/dist/FindYou_Godot.exe"
  ```
