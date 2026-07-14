# Neon Coast Club

Neon Coast Club 是一个使用 Godot 4 与 GDScript 开发的第一人称 3D 互动舞厅原型。项目融合 Y2K / 蒸汽波海岸场景、可交互道具、物理玩法、昼夜系统、多人实验功能，以及可从街机进入的 4K 下落式音游。

## 核心内容

- 第一人称移动、冲刺、跳跃、自由飞行和射线交互
- 程序化舞厅、海岸、夜景城市、灯光和动态昼夜变化
- 街机、CRT、扭蛋机、收藏品、物品栏和可投掷物理道具
- FPS 武器、换弹、瞄准、命中特效和基础 HUD
- Godot 多人联机、账号验证与大厅实验功能
- 模块化场景、脚本、Shader 和第三方素材许可记录

## 4K 音游系统

- 解析自定义 TXT 谱面和多难度配置
- 支持 Tap / Hold 音符与 `D / F / J / K` 四轨输入
- Critical、Perfect、Great、Good、Miss 多级判定
- Combo、ACC 与满分 1,000,000 的归一化计分
- 流速、Offset、音量等音游设置
- 选歌、游玩 HUD、暂停与结算流程
- 以音频播放时钟驱动音画同步

## 运行环境

- Godot 4.4 或更高版本
- 开发验证环境：Godot 4.7

克隆仓库后，用 Godot 导入根目录的 `project.godot`，然后运行主场景即可。

```bash
git clone https://github.com/CaptainLand/neon-coast-club.git
cd neon-coast-club
godot --editor project.godot
```

## 基本操作

| 操作 | 按键 |
| --- | --- |
| 移动 / 奔跑 | `WASD` / `Shift` |
| 跳跃 | `Space` |
| 交互、拾取 | `E` |
| 物品栏 | `1` - `5` / 鼠标滚轮 |
| 攻击、投掷 | 鼠标左键 / 右键 |
| 切换昼夜速度 | `T` |
| 自由飞行 | `F` |
| 获取或收起武器 | `B` |
| 换弹 | `R` |
| 暂停 | `Esc` |
| 全屏切换 | `F11` |
| 调试信息 | `F3` |

## 项目结构

```text
assets/       模型、贴图、音频、音游谱面与 UI 资源
scenes/       主场景、玩家和功能场景
scripts/      游戏、交互、网络、道具与音游逻辑
shaders/      海面、CRT、舞池、玻璃和视觉效果
docs/         设计与实现记录
project.godot Godot 项目入口
```

## 音乐与版权说明

公开仓库不包含以下本地演示音乐：

- `assets/audio/music/televisor_pinup.mp3`
- `assets/rhythm/aiae/aiae.mp3`

这些文件没有随源码再分发。需要完整音乐演示时，请将你拥有使用权的音频放到对应路径，或在项目中替换为自己的资源。谱面解析、音游逻辑与相关界面仍保留在仓库中。

第三方模型和音效的来源、作者及许可证见 [THIRD_PARTY_ASSETS.md](THIRD_PARTY_ASSETS.md)。未单独声明许可证的项目原创代码与内容保留所有权利。

## 项目状态

目前为持续开发中的个人游戏原型，主要用于验证 3D 场景交互、玩法原型、音游系统集成与 AI 辅助项目工作流。
