-- mod-era-talents: Gladiator Stance shapeshift form (form 23, Stances bit 0x400000) — server row.
-- Fills the EMPTY row 23 of SpellShapeshiftForm.dbc (3.3.5a ships rows 23/24 blank and no spell uses them);
-- the core loads spellshapeshiftform_dbc on top of the DBC file and a DB row overrides the file row
-- (DBCDatabaseLoader.cpp: "If exist in DBC file override from DB").
-- Values mirror the warrior stances 17/18/19: Flags 7 (SHAPESHIFT_FLAG_STANCE | ...) so spells without a stance
-- requirement stay castable, CreatureType -1, no model, no preset spells. BonusActionBar 4 (action bar page 10;
-- the warrior stances use 1/2/3) and the names are client-only (the server ignores them) but are kept equal to
-- the client row built by the esES patch tool (tools-propias/patch-esES/formas-esES.tsv).
-- Phase 1: no spell uses form 23 yet (the stance spell comes with the Gladiator branch).
-- Idempotent (DELETE + INSERT).

DELETE FROM `spellshapeshiftform_dbc` WHERE `ID` = 23;
INSERT INTO `spellshapeshiftform_dbc` (`ID`, `BonusActionBar`,
  `Name_Lang_enUS`, `Name_Lang_enGB`, `Name_Lang_koKR`, `Name_Lang_frFR`, `Name_Lang_deDE`, `Name_Lang_enCN`,
  `Name_Lang_zhCN`, `Name_Lang_enTW`, `Name_Lang_zhTW`, `Name_Lang_esES`, `Name_Lang_esMX`, `Name_Lang_ruRU`,
  `Name_Lang_ptPT`, `Name_Lang_ptBR`, `Name_Lang_itIT`, `Name_Lang_Unk`, `Name_Lang_Mask`,
  `Flags`, `CreatureType`, `AttackIconID`, `CombatRoundTime`,
  `CreatureDisplayID_1`, `CreatureDisplayID_2`, `CreatureDisplayID_3`, `CreatureDisplayID_4`,
  `PresetSpellID_1`, `PresetSpellID_2`, `PresetSpellID_3`, `PresetSpellID_4`,
  `PresetSpellID_5`, `PresetSpellID_6`, `PresetSpellID_7`, `PresetSpellID_8`)
VALUES (23, 4,
  'Gladiator Stance', '', '', '', '', '',
  '', '', '', 'Actitud de Gladiador', '', '',
  '', '', '', '', 16712190,
  7, -1, 0, 0,
  0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0);

-- UNDO (manual, after ./backup.sh; then restart the worldserver):
-- DELETE FROM `spellshapeshiftform_dbc` WHERE `ID` = 23;
