if SERVER then
    AddCSLuaFile()
end

EQUIP_RADAR_CUSTOM = GenerateNewEquipmentID and GenerateNewEquipmentID() or 16
--[[
local radarcustom = {
	id = EQUIP_RADAR_CUSTOM,
	loadout = false,
	type = "item_passive",
	material = "vgui/ttt/icon_radar",
	name = "Radar",
	desc = "Let you see the position of other players.",
	hud = true
}
]]--
