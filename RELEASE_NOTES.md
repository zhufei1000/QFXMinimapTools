# QFXMinimapTools 1.0.74

- Deep memory and CPU optimization. Login no longer deep-copies the entire defaults tree, removing a large, short-lived garbage spike.
- Cache native queue, mail, crafting-order and difficulty frame lists plus calendar invite candidates instead of rebuilding temporary tables on every refresh.
- Cache indicator, utility-row and native-control layout state so unchanged refreshes skip repeated anchoring and texture scans.
- Replace the per-frame flight OnUpdate watcher with a dynamically paced C_Timer ticker, and stop polling in instances, rest areas, taxis, vehicles or when the gathering-only rule cannot trigger.
- Cache class accent colours and text style state; hidden stats no longer query coordinates or instance data. The default FPS/latency format now uses a direct fast path.
- Reuse bag layout tables and cached button names; cache the addon memory tooltip list for 5 seconds.
- Compatible with Retail 12.1.5 and WoW Forever 1.60.1.

简体中文：本次主要进行内存与 CPU 深度优化。登录时不再深拷贝整套默认配置，消除大量临时表造成的垃圾回收峰值；原生队列、邮件、制造订单、难度徽章列表与日历邀请候选改为缓存；指示器列、底部工具行和原生控件加入布局状态缓存，输入未变化时跳过重复锚定与纹理扫描；飞行检测从每帧 OnUpdate 改为 C_Timer 动态频率轮询，并在副本、休息区、出租飞行、载具或无法触发采集规则时停止无效轮询；缓存职业色与文字样式，隐藏的统计项不再计算坐标和副本信息，FPS/延迟默认格式走快速路径；收纳框复用布局表并缓存按钮名，插件内存列表缓存 5 秒。兼容正式服 12.1.5 与魔兽世界无限 1.60.1。

繁體中文：本次主要進行記憶體與 CPU 深度最佳化。登入時不再深拷貝整套預設設定，消除大量暫存表造成的垃圾回收高峰；原生佇列、郵件、製造訂單、難度徽章清單與行事曆邀請候選改為快取；指示器列、底部工具列和原生控制項加入版面狀態快取，輸入未變更時跳過重複錨定與紋理掃描；飛行偵測從每幀 OnUpdate 改為 C_Timer 動態頻率輪詢，並在副本、休息區、計程飛行、載具或無法觸發採集規則時停止無效輪詢；快取職業色與文字樣式，隱藏的統計項目不再計算座標和副本資訊，FPS/延遲預設格式走快速路徑；收納框重複使用版面表並快取按鈕名稱，插件記憶體清單快取 5 秒。相容正式服 12.1.5 與魔獸世界無限 1.60.1。
