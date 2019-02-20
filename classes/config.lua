require("util.class")

Config = class(function(self)
    self.name = "Config"
    self.minPollution = settings.startup["min-pollution-to-damage"].value
    self.absorbMultiplier = settings.startup["armor-absorb-multiplier"].value
    self.isAutoEquip = settings.startup["auto-equip-armor"].value
end)

function Config:MinPollution()
    return self.minPollution
end

function Config:AbsorbMultiplier()
    return self.absorbMultiplier
end

function Config:IsAutoEquip()
    return self.isAutoEquip
end

function Config:ForceBaseValue()
    return 1.0
end

function Config:TechBonus()
    return 0.2
end

function Config:TickInterval()
    return 60
end