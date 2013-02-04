--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Nefarian", 754, 174)
if not mod then return end
mod:RegisterEnableMob(41270, 41376)

--------------------------------------------------------------------------------
-- Locals
--

local phase, deadAdds, shadowBlazeTimer = 1, 0, 35
local cinderTargets = mod:NewTargetList()
local powerTargets = mod:NewTargetList()
local phase3warned = false
local shadowblazeHandle, lastBlaze = nil, 0

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:NewLocale("enUS", true)
if L then
	L.phase = "Phases"
	L.phase_desc = "Warnings for the Phase changes."

	L.discharge_bar = "~Discharge"

	L.phase_two_trigger = "Curse you, mortals! Such a callous disregard for one's possessions must be met with extreme force!"

	L.phase_three_trigger = "I have tried to be an accommodating host"

	L.crackle_trigger = "The air crackles with electricity!"
	L.crackle_message = "Electrocute soon!"

	L.shadowblaze_trigger = "Flesh turns to ash!"
	L.shadowblaze_message = "Fire under YOU!"

	L.onyxia_power_message = "Explosion soon!"

	L.chromatic_prototype = "Chromatic Prototype" -- 3 adds name
end
L = mod:GetLocale()

--------------------------------------------------------------------------------
-- Initialization
--

function mod:GetOptions()
	return {
		77939, 78999, 81272, {81007, "FLASHSHAKE"},
		{79339, "FLASHSHAKE", "SAY", "PROXIMITY"}, "berserk",
		"phase", "bosskill"
	}, {
		[77939] = "ej:3283", -- Onyxia
		[78999] = "normal",
		[79339] = "heroic",
		phase = "general"
	}
end

function mod:OnBossEnable()
	self:Yell("PhaseTwo", L["phase_two_trigger"])
	self:Yell("PhaseThree", L["phase_three_trigger"])
	self:Yell("ShadowblazeCorrection", L["shadowblaze_trigger"])

	--Not bad enough that there is no cast trigger, there's also OVER NINE THOUSAND id's
	self:Log("SPELL_DAMAGE", "LightningDischarge", "*")
	self:Log("SPELL_MISSED", "LightningDischarge", "*")

	self:Log("SPELL_AURA_APPLIED", "ExplosiveCindersApplied", 79339)
	self:Log("SPELL_AURA_REMOVED", "ExplosiveCindersRemoved", 79339)

	self:Log("SPELL_DAMAGE", "PersonalShadowBlaze", 81007)
	self:Log("SPELL_MISSED", "PersonalShadowBlaze", 81007)

	self:Emote("Electrocute", L["crackle_trigger"])

	self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "CheckBossStatus")

	self:Death("Win", 41376)
	self:Death("PrototypeDeaths", 41948) -- Chromatic Prototype
end

function mod:OnEngage()
	self:Berserk(630) -- is it really?
	self:Bar(77939, L["discharge_bar"], 30, 77939)
	phase, deadAdds, shadowBlazeTimer = 1, 0, 35
	phase3warned = false
	self:RegisterUnitEvent("UNIT_POWER_FREQUENT", "PowerCheck", "boss1", "boss2")
	shadowblazeHandle, lastBlaze = nil, 0
end

--------------------------------------------------------------------------------
-- Event Handlers
--

do
	local prev = 0
	local discharge = mod:SpellName(77939)
	function mod:LightningDischarge(args)
		if args.spellName ~= discharge then return end
		local t = GetTime()
		if (t - prev) > 10 then
			prev = t
			self:Bar(77939, L["discharge_bar"], 21, args.spellId)
		end
	end
end

do
	local prev = 0
	function mod:PersonalShadowBlaze(args)
		local t = GetTime()
		if (t - prev) > 1 and UnitIsUnit(args.destName, "player") then
			prev = t
			self:LocalMessage(args.spellId, L["shadowblaze_message"], "Personal", args.spellId, "Info")
			self:FlashShake(args.spellId)
		end
	end
end

function mod:Electrocute()
	self:Message(81272, L["crackle_message"], "Urgent", 81272, "Alert")
	self:Bar(81272, 81272, 5, 81272) -- Electrocute
end

function mod:PrototypeDeaths()
	deadAdds = deadAdds + 1
	if self:Heroic() and not phase3warned then
		self:StopBar(CL["phase"]:format(phase))
		phase = 3
		self:Message("phase", CL["phase"]:format(phase), "Attention", 81007)
		phase3warned = true
	end
	if deadAdds == 3 and not phase3warned then
		self:StopBar(CL["phase"]:format(phase))
		phase = 3
		self:Message("phase", CL["phase"]:format(phase), "Attention", 81007)
		phase3warned = true
	end
end

function mod:PhaseTwo()
	phase = 2
	self:Message("phase", CL["phase"]:format(phase), "Attention", 78621)
	if self:Difficulty() == 6 then
		-- Heroic 25man (diff 4) probably 4 minutes
		self:Bar("phase", CL["phase"]:format(phase), 240, 78621) -- random guessed number
	else
		-- Normal 10man (diff 1) probably 3 minutes
		-- Normal 25man (diff 2) confirmed 3 minutes
		self:Bar("phase", CL["phase"]:format(phase), 180, 78621)
	end
	-- XXX Heroic 10man (diff 3) - no idea.
end

local function nextBlaze()
	if shadowBlazeTimer > 10 and mod:Heroic() then
		shadowBlazeTimer = shadowBlazeTimer - 5
	elseif shadowBlazeTimer > 15 and not mod:Heroic() then
		shadowBlazeTimer = shadowBlazeTimer - 5
	end
	mod:Message(81007, 81007, "Important", 81007, "Alarm") -- Shadowblaze
	mod:Bar(81007, 81007, shadowBlazeTimer, 81007) -- Shadowblaze
	lastBlaze = GetTime()
	shadowblazeHandle = mod:ScheduleTimer(nextBlaze, shadowBlazeTimer)
end

function mod:ShadowblazeCorrection()
	self:CancelTimer(shadowblazeHandle)
	if (GetTime() - lastBlaze) <= 3 then
		shadowblazeHandle = mod:ScheduleTimer(nextBlaze, shadowBlazeTimer)
	elseif (GetTime() - lastBlaze) >= 6 then
		nextBlaze()
	end
	lastBlaze = GetTime()
end

function mod:PhaseThree()
	self:StopBar(CL["phase"]:format(phase))
	if not phase3warned then
		phase = 3
		self:Message("phase", CL["phase"]:format(phase), "Attention", 78621)
		phase3warned = true
	end
	self:Bar(81007, 81007, 12, 81007) -- Shadowblaze
	shadowblazeHandle = self:ScheduleTimer(nextBlaze, 12)
end

do
	local scheduled = nil
	local function cinderWarn(spellName, spellId)
		mod:TargetMessage(spellId, spellName, cinderTargets, "Urgent", spellId, "Info")
		scheduled = nil
	end
	function mod:ExplosiveCindersApplied(args)
		cinderTargets[#cinderTargets + 1] = args.destName
		if UnitIsUnit(args.destName, "player") then
			self:FlashShake(args.spellId)
			self:Say(args.spellId)
			self:Bar(args.spellId, args.spellName, 8, args.spellId)
			self:OpenProximity(args.spellId, 10) -- assumed
		end
		if not scheduled then
			scheduled = true
			self:ScheduleTimer(cinderWarn, 0.3, args.spellName, args.spellId)
		end
	end
end

function mod:ExplosiveCindersRemoved(args)
	if UnitIsUnit(args.destName, "player") then
		self:CloseProximity(args.spellId)
	end
end

do
	local onyxia = EJ_GetSectionInfo(3283)
	function mod:PowerCheck(unit)
		if UnitName(unit) == onyxia then
			local power = UnitPower(unit, ALTERNATE_POWER_INDEX)
			if power > 80 then
				self:Message(78999, L["onyxia_power_message"], "Attention", 78999)
				self:UnregisterUnitEvent("UNIT_POWER_FREQUENT", "boss1", "boss2")
			end
		end
	end
end

