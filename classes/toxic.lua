require("util.class")
require("util.table")
require("util.help")
require("classes.config")

local stat = 10000

function commandHandler(event)
    local parameter = event.parameter
    if parameter ~= nil then
        if parameter == "kills" then
            game.print{"Pollution-kills"}
            if tlen(global.kills) > 0 then
                for player, kills in pairs(global.kills) do
                    game.print(player .. " - " .. kills)
                end
            else
                game.print{"Zero-players"}
            end
        end
    end
end

conf = Config()

Toxic = class(function(self)
    self.name = "Toxic Pollution"
    self.inventory = {
        defines.inventory.player_main,
        defines.inventory.player_quickbar,
        defines.inventory.player_trash
    }
    self.Signals = {
        ["yellow-gas-mask"] =   {type="virtual", name="signal-yellow-gas-mask"},
        ["red-gas-mask"] =      {type="virtual", name="signal-red-gas-mask"},
        ["red-armor"] =         {type="virtual", name="signal-red-armor"}
    }
    self.multiplier = {
        time = 5 * Minute,
        max = 60
    }
end)

function Toxic:init()
    self:initGlobals()
    if (game) then
        for _ , item in pairs(game.item_prototypes) do
            if (item.type == "armor") then
                if (global.MaxDurability < item.durability) then
                    global.MaxDurability = item.durability
                end
                if (item.resistances and item.resistances.toxin) then
                    global.armors[item.name] = {
                        base = Config:AbsorbMultiplier() * math.min(tonumber(string.format("%.2f", item.resistances.toxin.percent)), 0.9),
                        resist = item.resistances.toxin.percent
                    }
                else
                    global.armors[item.name] = {
                        base = 0,
                        resist = 0
                    }
                end
                global.armors[item.name].current = global.armors[item.name].base
            end
        end
        for _, force in pairs(game.forces) do
            global.TechBonus[force.name] = Config:ForceBaseValue()
            for _, tech in pairs(force.technologies) do
                if (tech.researched == true) then self:UpdateTech(tech.name, force) end
            end
        end
        self:initForce()
        self:initKillerFish()
    end
end

function Toxic:initGlobals()
    if (global.MaxDurability == nil) then global.MaxDurability = 0 end
    if (global.armors == nil) then global.armors = {} end
    if (global.TechBonus == nil) then global.TechBonus = {} end
    if (global.PlayersData == nil) then global.PlayersData = {} end
    if (global.kills == nil) then
        global.kills = {}
    else
        if type(global.kills) == "number" then global.kills = {} end
    end
end

function Toxic:initForce()
    if not game.forces.pollution then
        game.create_force("pollution")
    end
end

function Toxic:initCommands()
    commands.add_command("pollution", "toxic pollution commands", commandHandler)
end

function Toxic:initKillerFish()
    if (global.killer == nil) then
        global.killer = game.surfaces[1].create_entity{name = "pollution", position = {x = 1, y = 1}, force = game.forces.pollution }
        global.killer.active = false
    end
end

function Toxic:migrate(version)
    local Major, Minor, Patch = string.match(version, "(%d)%.(%d)%.(%d)")
    Major = tonumber(Major)
    Minor = tonumber(Minor)
    Patch = tonumber(Patch)
    if (Major == 0 and Minor >= 2 and Patch >= 7) then
        if (global.armorMaxDurability ~= nil) then
            global.armorMaxDurability = nil
        end
        if (global.armorsAbsorb ~= nil) then
            global.armorsAbsorb = nil
        end
        if (global.techAbsorb ~= nil) then
            global.techAbsorb = nil
        end
    end
end

function Toxic:AddAlert(player, signal, message)
    if player.character then
        local alerts = player.get_alerts{entity = player.character, type = defines.alert_type.custom, surface = player.surface }
        for _, alert in pairs(alerts) do
            if alert.icon == self.Signals[signal] then
                return
            end
        end
        player.add_custom_alert(player.character, self.Signals[signal], message, false)
    end
end

function Toxic:RemoveAlert(player, signal)
    if player.character then
        player.remove_alert{entity = player.character, surface = player.surface, icon = self.Signals[signal] }
    end
end

function Toxic:GetPollution(player)
    return math.floor(player.surface.get_pollution({player.position.x, player.position.y}))
end

function Toxic:GetPlayerArmor(player)
    local inv = player.get_inventory(defines.inventory.player_armor)
    local count = inv.get_item_count()
    if count > 0 then
        return count, inv[1]
    else
        return count, nil
    end
end

function Toxic:GetArmorAbsorb(armor)
    local a = global.armors[armor]
    if a ~= nil then
        return a.current
    end
    return 0
end

function Toxic:UpdateTech(tech, force)
    local n = string.match(tech, "armor%-absorb%-(%d)")
    if n ~= "" then
        local bonus = Config:ForceBaseValue() + tonumber(n) * Config:TechBonus()
        global.TechBonus[force.name] = bonus
        self:ReCalculateAbsorb(force.name)
        return true
    else
        return false
    end
end

function Toxic:ReCalculateAbsorb(force)
    for _, armor in pairs(global.armors) do
        armor.current = armor.base * global.TechBonus[force]
    end
end

function Toxic:IncKills(player)
    local kills = global.kills[player] or 0
    kills = kills + 1
    global.kills[player] = kills
end

function Toxic:CalculateDamage(player, pollution, armor)
    local m = self:GetTimeMultiplier(player)
    if armor ~= nil then
        if m > 0 then

            return
        end
    end
    return ((pollution - absorb)/stat) ^ power
end

function Toxic:IsActiveAirFiltering()
    return game.active_mods["air-filtering-patched"] ~= nil
end

function Toxic:EquipArmorFromInventory(player, armor)
    if (armor.is_armor == false and Config:IsAutoEquip()) then
        local durability = global.MaxDurability
        local newArmor = {id = 0, index = 0 }
        for id, inventoryType in pairs(self.inventory) do
            local inventory = player.get_inventory(inventoryType)
            if inventory ~= nil then
                for i = 1, #inventory do
                    local item = inventory[i]
                    if (item.is_armor and item.durability <= durability) then
                        durability = item.durability
                        newArmor = {id = id, index = i }
                    end
                end
            end
        end
        if newArmor.id > 0 then
            armor.transfer_stack(player.get_inventory(self.inventory[newArmor.id])[newArmor.index])
        end
        if armor.is_armor then
            player.print{"Destroyed-armor-replaced", {"item-name." .. armor.name} }
        else
            player.print{"Armor-destroyed" }
        end
    end
end

function Toxic:IncTimeMultiplier(player, ticks)
    local data = global.PlayersData[player]
    if data == nil then
        data = { ticks = 0, multiplier = 1 }
    end
    if data.ticks < self.maxTime then
        data.ticks = data.ticks + ticks
        data = self:UpdateTimeMultiplier(data)
    end
    global.PlayersData[player] = data
end

function Toxic:DecTimeMultiplier(player, ticks)
    local data = global.PlayersData[player]
    if data ~= nil then
        data.ticks = data.ticks - ticks
        if data.ticks < 0 then data.ticks = 0 end
        data = self:UpdateTimeMultiplier(data)
        global.PlayersData[player] = data
    end
end

function Toxic:GetTimeMultiplier(player)
    local data = global.PlayersData[player]
    if data ~= nil then
        return data.multiplier
    end
    return 0
end

function Toxic:UpdateTimeMultiplier(data)
    local m = data.ticks/self.multiplier.time
    m = self.multiplier.max*m
    if m % 1 == 0 then data.multiplier = m end
    return data
end

function Toxic:OnTick()
    for _, player in pairs(game.players) do
        if (player.connected == true and player.character ~= nil) then
            local alert = 0
            local pollution = self:GetPollution(player)
            local newPollution = 0
            local damage = 0
            local absorb = Config:MinPollution()
            local armorCount, armor = self:GetPlayerArmor(player)
            if armorCount > 0 then absorb = absorb + self:GetArmorAbsorb(armor.name) end
            if (pollution > absorb) then
                newPollution = pollution - absorb
            end
            if (newPollution > 0) then
                self:IncTimeMultiplier(player.name, Config:TickInterval())
            else
                self:DecTimeMultiplier(player.name, Config:TickInterval())
            end
            damage = self:CalculateDamage(player.name, pollution, armor)
            if damage > 20 then
                alert = 2
            else
                alert = 1
            end
            if armor then
                if (armor.durability / game.item_prototypes[armor.name].durability < 0.25 and armorCount == 1) then
                    alert = 3
                end
                armor.drain_durability(damage)
                self:EquipArmorFromInventory(player, armor)
            else
                alert = 2
                damage = math.floor(pollution / absorb)
                if (player.character.health > damage) then
                    player.character.damage(damage, game.forces.pollution, "toxin")
                else
                    player.character.die(game.forces.pollution, global.killer)
                    self:IncKills(player.name)
                end
            end
            if alert == 1 then
                self:AddAlert(player, "yellow-gas-mask", {"High-pollution", pollution, string.format("%.2f", damage)})
            elseif alert == 2 then
                self:AddAlert(player, "red-gas-mask", {"Very-high-pollution", pollution, string.format("%.2f", damage)})
            elseif alert == 3 then
                self:AddAlert(player, "red-armor", {"Armor-worn-out", pollution, string.format("%.2f", damage)})
            else
                self:RemoveAlert(player, "yellow-gas-mask")
                self:RemoveAlert(player, "red-gas-mask")
                self:RemoveAlert(player, "red-armor")
            end
        end
    end
end

function Toxin:OnPlayerDied(event)
    local player = game.players[event.player_index]
    local entity = event.cause
    if (entity ~= nil and entity.name == "pollution") then
        self.IncKills(player.name)
    end
end