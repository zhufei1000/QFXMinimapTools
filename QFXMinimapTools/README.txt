QFX Minimap Tools

这是一个原创轻量级小地图整合插件：
- 参考 Leatrix Plus 的小地图设置思路：默认方形小地图、缩放、自动解除屏幕边缘限制、隐藏插件菜单。
- 参考 MinimapStats 的显示内容方向：位置、坐标、时间、系统信息、耐久、地下城难度。
- 参考 MinimapButtonButton 的按钮收纳交互方向：一个主按钮收纳其它小地图按钮。

注意：本插件没有复制 Leatrix Plus、MinimapStats、MinimapButtonButton 的源码或素材。
原因是上传的 MinimapStats 与 MinimapButtonButton 许可证不允许修改版/派生版重新分发。

命令：
/qfmt
/qmini

安装：
把 QFXMinimapTools 文件夹放入 World of Warcraft/_retail_/Interface/AddOns/ 后重载游戏。


1.0.1 修复：
- 默认启用方形小地图。
- 方形模式隐藏原生圆形边框/覆盖材质，避免圆形与方形重叠。
- 小地图自动贴近屏幕边缘改为默认行为，不再放入设置。
- 收纳主按钮默认显示在小地图右上方；收纳框为空时会显示提示文字。
- 增强 LibDBIcon / LibMapButton / 附近命名按钮扫描。


1.0.2 修复：
- 方形小地图默认清理原生顶部标题、时间、追踪、缩放和难度徽章等覆盖层，避免顶部残留。
- QFX 收纳触发按钮改为小地图左侧边线上的 Q 字，不再显示圆形按钮框。
- 坐标移动到小地图底线内侧上方；副本难度移动到小地图左上角；系统信息与耐久保留在底部外侧，减少重叠。
- 方形边框改为简洁黑边，更接近干净方形小地图效果。


1.0.3 修复：
- 小地图自动贴边改为直接锚定真实 Minimap 到 UIParent 右上角，避免现代客户端 MinimapCluster 顶部隐藏区域造成的空白。
- 增加分辨率 / UI 缩放变化后的自动重新贴边。
- 收纳展开改为无背景图标网格，默认从小地图左侧向外展开，更接近参考插件。
- 修复部分按钮被收纳后展开为空或无法点击的问题。
- 增加“按钮选择”面板，可勾选决定某个小地图按钮是否进入 Q 收纳。
- FPS / 延迟默认改为 MinimapStats 风格：%fps | %home，例如 60FPS | 14MS。
- 坐标与系统信息改到底部左右分区，减少重叠；耐久默认关闭，与 MinimapStats 默认一致。


1.0.4 修复：
- 自动贴边保留边框粗细的内缩距离，避免方形边框被屏幕裁掉。
- 小地图缩放改为缩放真实 Minimap，设置上限提高到 2.0，修复超过 1.0 后不明显变化的问题。
- 收纳展开框改为跟随左侧 Q 触发按钮，拖动 Q 后展开位置会一起移动。
- 收纳扫描改为只收纳当前显示在小地图上/小地图附近的按钮，不再默认全局枚举扫描，减少误收纳。


1.0.5
- Auto top-right snap now leaves a safer inset so the square border is visible.
- Button bag icons get enlarged hit areas and transparent cell proxies for easier mouse selection.
- FPS/MS text changed to spaced format: 30 FPS    10 MS.


1.0.6
- FPS/MS text changed to: 30 FPS | 10 MS, with white numbers and MinimapStats-like purple unit labels.
- Default minimap scale changed to 1.20.
- Added minimap position lock/unlock. Unlock to drag the square minimap; once moved, the saved manual position is used.
- Added reset minimap position, restoring the default automatic top-right snap.


1.0.8
- 新增“小地图外框跟随动作条外框”。插件会尝试读取当前动作条按钮的边框纹理/颜色，并同步到方形小地图外框。
- 增加动作条皮肤延迟刷新与事件刷新，用来兼容登录后才改动作条外观的插件。
- 说明：如果动作条插件完全自绘且不使用标准按钮纹理/Backdrop，可能只能部分跟随，需要后续做专门适配。


1.0.8
- Added a robust Options > AddOns entry with buttons to open QFX settings and reset minimap position.
- Added delayed retry so the addon still appears if Blizzard Settings loads late.
- 增加 ESC - 选项 - 插件 内的 QFX 小地图工具入口，可在里面打开设置界面。


1.0.9
- 移除“小地图外框跟随动作条外框”功能，避免不同动作条皮肤插件兼容不稳定。
- 小地图外框改为固定颜色预设：黑色、银白色、深灰色、金色、职业色。
- 默认外框仍然是黑色，可在设置界面一键切换为银白色等样式。
- 新增开放皮肤 API：其他插件可以读取、设置、注册小地图外框样式。
  示例：QFXMinimapTools:SetBorderPreset("SILVER")
  示例：QFXMinimapTools:SetBorderColor(0.8, 0.8, 0.75, 1)
  示例：QFXMinimapTools:RegisterBorderPreset("MY_SKIN", "My Skin", 1, 0.6, 0.2, 1)


1.0.10
- 修复外框颜色选择后不明显变化的问题：不再依赖 Backdrop 边框贴图染色，改为使用四条可染色的实体边线实时刷新。
- 外框颜色选择从一排按钮改为下拉菜单。
- 保留开放皮肤 API，外部插件设置颜色/预设后也会立即刷新实体边线。


1.0.11
- 小地图外框默认颜色改为深灰色；旧版默认黑色会自动迁移为深灰色。
- 插件设置界面加入“界面语言”下拉菜单：跟随客户端 / 中文 / English。
- Q 收纳触发字稍微放大，鼠标悬停与点击更容易。
- 外框颜色选择下拉菜单改为带箭头的下拉样式，不再像普通按钮。


1.0.12
- “方形小地图”选项说明缩短为“需/RL”，英文说明同步缩短。
- 设置面板标题改到左上方，避免和界面语言选择重叠。
- 下拉选择控件优先使用暴雪原生下拉菜单模板，颜色选择会显示正常下拉箭头。


1.0.13
- 小地图左下角固定保留暴雪排副本队列眼睛按钮，不再被收纳功能收走。
- 队列眼睛显示时，FPS / 延迟文字会自动向右让位，避免重叠。
- 外框颜色选择改为标签换行 + 下方下拉菜单的排版，英文界面下不会因为标题过长挤压控件。
- 设置界面下方控件整体下移，给颜色下拉菜单留出空间。


1.0.14
- 设置界面改为统一两列网格模型：标题、复选框、下拉菜单、滑块、输入框和按钮统一左对齐。
- 同一行的文字与控件使用固定标签宽度和固定控件起点，中文/英文切换后不会再横向错位。
- 下方按钮收纳区域改为整行布局，输入框和底部按钮统一宽度与间距。


1.0.15 修复：
- 设置界面中标签和控件的距离缩短，保留约两个中文字符的间距。
- 左下角排副本眼睛缩小为原来约一半，避免占用小地图内容区域。


1.0.17
- 左下角排副本眼睛继续使用暴雪原生 QueueStatusButton，仅缩放和重新定位，保留查看队列、离开队列/副本等原有交互。
- 进一步压缩设置界面标签与控件之间的间距，改为约两个英文字符/一个中文字符。

1.0.17 性能提示调整：
- FPS / 延迟文字的鼠标悬停提示改为性能信息，不再重复显示左键/右键说明。
- 悬停 FPS / 延迟时显示当前帧数、本地延迟、世界延迟，以及部分插件的内存占用。
- 新增“关闭插件 CPU Profiling（全局，需/RL）”开关，默认开启；会尝试关闭 scriptProfile 与 Blizzard AddOn Profiler，避免游戏持续统计所有插件 CPU。


1.0.20
- 修正 CPU 开关语义：现在控制的是 WoW 全局插件 CPU Profiling，不再只是隐藏本插件的 CPU 数值。
- 默认尝试关闭 scriptProfile=0，并注册/设置 addonProfilerEnabled=0。
- 悬停 FPS / 延迟时显示 scriptProfile 与 Blizzard AddOn Profiler 当前状态；如客户端锁定会提示。
- 若用户关闭该保护开关用于诊断，会提示需要 /reload 后 CPU 统计才完整生效。


1.0.21 修复：
- 小地图左下角排副本眼睛不再被套用方形动作按钮外框。
- 优先保留暴雪自带圆形外框；如果客户端没有暴露原生外框，则使用类似 LibDBIcon 的小地图圆形外框。
- 副本难度标记同步改为圆形小地图风格外框。


1.0.30
- 恢复方形小地图下的暴雪原生追踪菜单放大镜，可继续打开矿物、草药等追踪选项。
- 放大镜固定在小地图右上角，并去掉外层圆框，只保留简洁图标。
- 右上角时间文字会自动向左让位，避免与追踪按钮重叠。


1.0.33
- 移除初始化载入提示。
- ESC → 插件列表图标替换为原创金色 Q 图标。


1.0.35
- 新增“野外飞行居中小地图”模式：仅野外飞行时将小地图移动到顶部中间并放大。
- 休息区、副本、地下城、载具和航线飞行保持原布局。
- 飞行时隐藏边框，并提供透明度、飞行缩放、飞行垂直位置调节。
- 飞行时仅保留地图名称、排队眼睛、邮件提示、Q 收纳按钮、追踪开关；其他插件文字信息暂时隐藏。
- 下坐骑后自动恢复原有位置、大小和显示状态。


1.0.39
- 按 QFX UI Skill 方向重构目录：Core / Modules / UI 分层，后续维护更清晰。
- 设置界面重建为左侧分页 + 右侧内容区：总览、小地图、显示内容、按钮收纳、野外飞行、高级。
- 常用开关集中到“总览”，详细设置放到对应分页，减少界面拥挤和误操作。
- 继续使用暴雪原生控件；滑条保持当前值居中下方、最小/最大同一行的统一规范。


1.0.40
- 修复重构设置界面底部“恢复默认 / 重载界面”按钮锚点错误，避免按钮跑到 UI 外面。
- “野外飞行居中”内新增专业检测：默认勾选“仅学会草药学或采矿时启用居中”。
- 插件会检测角色是否已学习草药学或采矿；检测到后飞行居中才会触发。取消勾选后恢复旧版“野外飞行即居中”的行为。
- 设置内加入检测状态文字，方便确认当前角色是否满足触发条件。


1.0.41
- Added support for World of Warcraft 12.0.7.
- Updated TOC Interface to 120007.
- Kept 1.0.40 UI and gathering-profession flight centering behavior unchanged.

1.0.42
- Compatibility package for both 12.0.5 and 12.0.7 clients.
- TOC Interface now lists both 120005 and 120007.
- No functional changes from 1.0.41.
