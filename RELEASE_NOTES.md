# QFXMinimapTools 1.0.72

- Replace offset-silhouette thickening with four true vector stroke weights for calendar, mail, crafting-order and tracking icons, improving diagonal, curve and corner consistency.
- Replace the numeric 0–3 weight slider with named Thin, Regular, Medium and Bold choices in both the native and factory-rendered settings pages. Existing saved choices are preserved.
- Store each icon's four weights in a padded BLP strip with eight mip levels. Use the same selected region for the main icon and hover highlight, reducing each icon from six texture layers to two.
- Keep component size, spacing, colors, hover scaling and calendar date text behavior unchanged. Use distinct asset paths so the new strips do not reuse cached old textures.
- Retain Retail 12.1.5 and WoW Forever 1.60.1 support, existing settings and the icon license.

简体中文：地图组件图标改用四档真实矢量线宽，改善圆弧、斜线和边角的均匀程度。数字滑块改为“细、标准、中粗、粗”选项，每个图标由六层纹理减到两层；保留原有粗细选择、组件尺寸、间距、颜色及日历日期显示。

繁體中文：地圖元件圖示改用四檔真實向量線寬，改善圓弧、斜線與邊角的均勻程度。數字滑桿改為「細、標準、中粗、粗」選項，每個圖示由六層紋理減至兩層；保留原有粗細選擇、元件尺寸、間距、色彩及日曆日期顯示。
