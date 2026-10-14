# Retail 12.1.5 compatibility review

## Sources

Reviewed the latest `zhufei1000/QFX-WoW-Addon-UI-Skill` main commit `5fc9ec88c30784a26794da49c1c5eb11b43cc646`, especially `wow-12.1.0-live-api-final-zhCN.md`, and the matching generated documentation and FrameXML from Gethe/wow-ui-source Live **12.1.5.70391**, commit `18c6d677b605b312f3d813d498404631fb941977`.

## Result and changes

- Added `120105` to the TOC Interface list while retaining existing entries.
- Preserved the local addon version **1.0.68** and SavedVariables `QFXMinimapToolsDB`.
- `Modules/Stats.lua` now checks `C_Secrets.ShouldUnitIdentityBeSecret` before querying a GUID, and rejects secret GUIDs before parsing, comparing or caching them.
- Phase display can only learn a phase ID from a public GUID. A restricted identity leaves the existing public cache unchanged; without a public cached value, the phase text remains unavailable.
- Minimap controls, player-only flight queries, addon-compartment integration and performance API fallbacks were reviewed. The absent `C_AddOns.GetAddOnCPUUsage` / `GetAddOnMemoryUsage` entries are already capability-guarded and retain their existing global fallback paths.
- Current local source updates that predate this review are included in the source synchronization. Unrelated archive deletions and old test folders are excluded from the commit.

## Validation and limits

- All **14** TOC-loaded Lua files passed `luac -p`; every TOC file reference exists.
- Regression tests passed for public, restricted, secret and nil GUIDs, including confirmation that restricted identities are never queried and secret GUIDs are never cached.
- No SavedVariables schema migration, addon version increment, release tag or formal release was created.
- Neither reviewed addon was installed in the current Retail AddOns folder, so no client files were synchronized.

Static checks and stubbed regression tests do not establish in-game taint safety. In game, check login/reload, settings, button collection, gliding/landing and combat transitions. Verify phase display with public and restricted target/mouseover identities.

## Rollback

Restore the pre-review TOC and `Modules/Stats.lua` from the local source snapshot, or revert the compatibility commit if rolling back all synchronized source changes is intended. No database migration prevents rollback.
