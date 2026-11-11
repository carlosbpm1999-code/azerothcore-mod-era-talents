-- mod-era-talents: Gladiator Stance (932848, form 23) -> its passive 932849 (rage +10 % from damage dealt).
-- The core applies the stock stance passives only for forms 17/18/19 (AuraEffect::HandleShapeshiftBoosts:
-- 2457/71/2458 -> 21156/7376/7381), never for form 23, so this hand-written row links them instead.
-- type 2 = SPELL_LINK_AURA (Aura::HandleAuraSpecificMods, SpellAuras.cpp: AddAura on apply, RemoveAura on remove): 932849 is applied
-- together with 932848's aura and removed when it goes (leaving the stance), with no cast of its own.
-- Both spells are generated from era-data/vanilla/warrior.yaml (GLADIATOR helpers block).
-- Idempotent (DELETE + INSERT).
-- UNDO (manual, after ./backup.sh; then restart the worldserver):
-- DELETE FROM `spell_linked_spell` WHERE `spell_trigger` = 932848 AND `spell_effect` = 932849 AND `type` = 2;

DELETE FROM `spell_linked_spell` WHERE `spell_trigger` = 932848 AND `spell_effect` = 932849 AND `type` = 2;
INSERT INTO `spell_linked_spell` (`spell_trigger`, `spell_effect`, `type`, `comment`) VALUES
(932848, 932849, 2, 'Era Gladiator Stance - passive (rage from damage dealt)');
