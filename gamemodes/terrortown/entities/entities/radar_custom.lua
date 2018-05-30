-- just server file

util.AddNetworkString("TTT_Radar_Custom")

--

local chargetime = 30

local math = math

concommand.Add("ttt_radar_custom_scan", function(ply, cmd, args)
   if IsValid(ply) and ply:IsTerror() then
      if not ply:HasEquipmentItem(EQUIP_RADAR) and ply:HasEquipmentItem(EQUIP_RADAR_CUSTOM) then
         if (ply.radar_custom_charge or 0) > CurTime() then
            LANG.Msg(ply, "radar_charging")
            
            return
         end

         ply.radar_custom_charge = CurTime() + chargetime

         local scan_ents = player.GetAll()
         table.Add(scan_ents, ents.FindByClass("ttt_decoy"))

         local targets = {}
         
         for _, p in pairs(scan_ents) do
            if IsValid(p) and ply ~= p then
                if p:IsPlayer() and p:IsTerror() and not p:GetNWBool("disguised", false) or not p:IsPlayer() then
                    local pos = p:LocalToWorld(p:OBBCenter())

                    -- Round off, easier to send and inaccuracy does not matter
                    pos.x = math.Round(pos.x)
                    pos.y = math.Round(pos.y)
                    pos.z = math.Round(pos.z)

                    local role = p:IsPlayer() and p:GetRole() or 0

                    if not p:IsPlayer() then
                       -- Decoys appear as innocents for non-traitors
                       if not ply:IsTraitor() then
                          role = ROLE_INNOCENT
                       end
                    elseif not ROLES and role ~= ROLE_INNOCENT and role ~= ply:GetRole() 
                    or ROLES and role ~= ROLE_INNOCENT
                    then
                       if not ROLES then
                          role = ROLE_INNOCENT
                       else
                          local rd = GetRoleByIndex(role)
                          
                          if ply:GetRoleData().team ~= TEAM_TRAITOR then
                             role = ROLE_INNOCENT
                          elseif not rd.visibleForTraitors then
                             role = rd.team == TEAM_TRAITOR and ROLE_TRAITOR or ROLE_INNOCENT
                          end
                       end
                    end

                    table.insert(targets, {role = role, pos = pos})
                end
            end
         end

         net.Start("TTT_Radar_Custom")
         net.WriteUInt(#targets, 8)
         
         for _, tgt in pairs(targets) do
            net.WriteUInt(tgt.role, ROLES and ROLE_BITS or 2)
            net.WriteInt(tgt.pos.x, 32)
            net.WriteInt(tgt.pos.y, 32)
            net.WriteInt(tgt.pos.z, 32)
         end
         
         net.Send(ply)
      else
         LANG.Msg(ply, "radar_not_owned")
      end
   end
end)
