if SERVER then
	AddCSLuaFile()
else
	local surface = surface
	local math = math

	RADAR_CUSTOM = {}
	RADAR_CUSTOM.targets = {}
	RADAR_CUSTOM.enable = false
	RADAR_CUSTOM.duration = 30
	RADAR_CUSTOM.endtime = 0
	RADAR_CUSTOM.repeating = true
	RADAR_CUSTOM.samples = {}
	RADAR_CUSTOM.samples_count = 0

	function RADAR_CUSTOM:EndScan()
		self.enable = false
		self.endtime = CurTime()
	end

	function RADAR_CUSTOM:Clear()
		self:EndScan()
		self.samples = {}

		self.samples_count = 0
	end

	function RADAR_CUSTOM:Timeout()
		self:EndScan()

		if self.repeating and LocalPlayer() and LocalPlayer():HasEquipmentItem(EQUIP_RADAR_CUSTOM) then
			RunConsoleCommand("ttt_radar_custom_scan")
		end
	end

	function RADAR_CUSTOM.Bought(is_item, id)
		if is_item and id == EQUIP_RADAR_CUSTOM then
			RunConsoleCommand("ttt_radar_custom_scan")
		end
	end

	hook.Add("TTTBoughtItem", "RadarCustomBoughtItem", RADAR_CUSTOM.Bought)

	hook.Add("HUDPaint", "RadarCustomHUDPaint", function()
		local client = LocalPlayer()

		if hook.Run("HUDShouldDraw", "TTTRadarCustom") then
			RADAR_CUSTOM:Draw(client)
		end
	end)

	local function DrawTarget(tgt, size, offset, no_shrink)
		local scrpos = tgt.pos:ToScreen() -- sweet
		local sz = (IsOffScreen(scrpos) and not no_shrink) and size * 0.5 or size

		scrpos.x = math.Clamp(scrpos.x, sz, ScrW() - sz)
		scrpos.y = math.Clamp(scrpos.y, sz, ScrH() - sz)

		if IsOffScreen(scrpos) then return end

		surface.DrawTexturedRect(scrpos.x - sz, scrpos.y - sz, sz * 2, sz * 2)

		-- Drawing full size?
		if sz == size then
			local text = math.ceil(LocalPlayer():GetPos():Distance(tgt.pos))
			local w, h = surface.GetTextSize(text)

			-- Show range to target
			surface.SetTextPos(scrpos.x - w * 0.5, scrpos.y + (offset * sz) - h * 0.5)
			surface.DrawText(text)

			if tgt.t then
				-- Show time
				text = util.SimpleTime(tgt.t - CurTime(), "%02i:%02i")
				w, h = surface.GetTextSize(text)

				surface.SetTextPos(scrpos.x - w * 0.5, scrpos.y + sz * 0.5)
				surface.DrawText(text)
			elseif tgt.nick then
				-- Show nickname
				text = tgt.nick
				w, h = surface.GetTextSize(text)

				surface.SetTextPos(scrpos.x - w * 0.5, scrpos.y + sz * 0.5)
				surface.DrawText(text)
			end
		end
	end

	local indicator = surface.GetTextureID("effects/select_ring")
	local sample_scan = surface.GetTextureID("vgui/ttt/sample_scan")

	local GetPTranslation = LANG.GetParamTranslation
	local FormatTime = util.SimpleTime

	local near_cursor_dist = 180

	function RADAR_CUSTOM:Draw(client)
		if not client then return end

		surface.SetFont("HudSelectionText")

		-- Samples
		if self.samples_count ~= 0 then
			surface.SetTexture(sample_scan)
			surface.SetTextColor(200, 50, 50, 255)
			surface.SetDrawColor(255, 255, 255, 240)

			for _, sample in pairs(self.samples) do
				DrawTarget(sample, 16, 0.5, true)
			end
		end

		-- Player radar_custom
		if not self.enable then return end

		surface.SetTexture(indicator)

		local remaining = math.max(0, RADAR_CUSTOM.endtime - CurTime())
		local alpha_base = 50 + 180 * (remaining / RADAR_CUSTOM.duration)

		local mpos = Vector(ScrW() * 0.5, ScrH() * 0.5, 0)

		local role, alpha, scrpos, md
		for _, tgt in pairs(RADAR_CUSTOM.targets) do
			alpha = alpha_base

			scrpos = tgt.pos:ToScreen()
			if scrpos.visible then
				md = mpos:Distance(Vector(scrpos.x, scrpos.y, 0))

				if md < near_cursor_dist then
					alpha = math.Clamp(alpha * (md / near_cursor_dist), 40, 230)
				end

				role = tgt.role or ROLE_INNOCENT

				if TTT2 then
					local roleData = GetRoleByIndex(role)
					local c = roleData.radarColor

					if c then
						surface.SetDrawColor(c.r, c.g, c.b, alpha)
						surface.SetTextColor(c.r, c.g, c.b, alpha)
					elseif role == ROLE_DETECTIVE or roleData.baserole == ROLE_DETECTIVE then
						surface.SetDrawColor(0, 0, 255, alpha)
						surface.SetTextColor(0, 0, 255, alpha)
					elseif role == ROLE_INNOCENT or roleData.baserole == ROLE_INNOCENT then
						surface.SetDrawColor(0, 255, 0, alpha)
						surface.SetTextColor(0, 255, 0, alpha)
					elseif role == ROLE_TRAITOR or roleData.baserole == ROLE_TRAITOR then
						surface.SetDrawColor(255, 0, 0, alpha)
						surface.SetTextColor(255, 0, 0, alpha)
					else
						surface.SetDrawColor(120, 120, 120, alpha)
						surface.SetTextColor(120, 120, 120, alpha)
					end
				else
					if role == ROLE_DETECTIVE then
						surface.SetDrawColor(0, 0, 255, alpha)
						surface.SetTextColor(0, 0, 255, alpha)
					elseif role == ROLE_INNOCENT then
						surface.SetDrawColor(0, 255, 0, alpha)
						surface.SetTextColor(0, 255, 0, alpha)
					else
						surface.SetDrawColor(255, 0, 0, alpha)
						surface.SetTextColor(255, 0, 0, alpha)
					end
				end

				DrawTarget(tgt, 24, 0)
			end
		end

		-- Time until next scan
		surface.SetFont("TabLarge")
		surface.SetTextColor(255, 0, 0, 230)

		local text = GetPTranslation("radar_hud", {time = FormatTime(remaining, "%02i:%02i")})
		local _, h = surface.GetTextSize(text)

		surface.SetTextPos(36, ScrH() - 140 - h)
		surface.DrawText(text)
	end

	net.Receive("TTT_Radar_Custom", function(len)
		local num_targets = net.ReadUInt(8)

		RADAR_CUSTOM.targets = {}

		for i = 1, num_targets do
			local r = net.ReadUInt(TTT2 and ROLE_BITS or 2)

			local pos = Vector()
			pos.x = net.ReadInt(32)
			pos.y = net.ReadInt(32)
			pos.z = net.ReadInt(32)

			table.insert(RADAR_CUSTOM.targets, {role = r, pos = pos})
		end

		RADAR_CUSTOM.enable = true
		RADAR_CUSTOM.endtime = CurTime() + RADAR_CUSTOM.duration

		timer.Create("radarcustomtimeout", RADAR_CUSTOM.duration + 1, 1, function()
			RADAR_CUSTOM:Timeout()
		end)
	end)
end
