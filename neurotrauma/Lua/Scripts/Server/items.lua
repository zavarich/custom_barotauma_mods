Hook.Add("item.applyTreatment", "NT.itemused", function(item, usingCharacter, targetCharacter, limb)
	if -- invalid use, dont do anything
		item == nil
		or usingCharacter == nil
		or targetCharacter == nil
		or limb == nil
	then
		return
	end

	if not HF.HasAffliction(targetCharacter, "luabotomy") then
		HF.SetAffliction(targetCharacter, "luabotomy", 1)
	end

	local identifier = item.Prefab.Identifier.Value

	local methodtorun = NT.ItemMethods[identifier] -- get the function associated with the identifier
	if methodtorun ~= nil then
		-- run said function
		methodtorun(item, usingCharacter, targetCharacter, limb)
		return
	end

	-- startswith functions
	for key, value in pairs(NT.ItemStartsWithMethods) do
		if HF.StartsWith(identifier, key) then
			value(item, usingCharacter, targetCharacter, limb)
			return
		end
	end
end)
-- TODO: some items trigger afflictions after a single human update, to fix, trigger them immediately for consistency
-- storing all of the item-specific functions in a table
NT.ItemMethods = {} -- with the identifier as the key
NT.ItemStartsWithMethods = {} -- with the start of the identifier as the key

-- misc

NT.ItemMethods.healthscanner = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = HF.NormalizeLimbType(limb.type)

	local containedItem = item.OwnInventory.GetItemAt(0)
	if containedItem == nil then
		return
	end
	local hasVoltage = containedItem.Condition > 0

	if hasVoltage then
		--set base color values
		local BaseColor = "127,255,255"
		local NameColor = "127,255,255"
		local LowColor = "127,255,255"
		local MedColor = "127,255,255"
		local HighColor = "127,255,255"
		local VitalColor = "127,255,255"
		local RemovalColor = "127,255,255"
		local CustomColor = "127,255,255"

		if NTConfig.Get("NTSCAN_enablecoloredscanner", 1) then
			BaseColor = table.concat(NTConfig.Get("NTSCAN_basecolor", 1), ",")
			NameColor = table.concat(NTConfig.Get("NTSCAN_namecolor", 1), ",")
			LowColor = table.concat(NTConfig.Get("NTSCAN_lowcolor", 1), ",")
			MedColor = table.concat(NTConfig.Get("NTSCAN_medcolor", 1), ",")
			HighColor = table.concat(NTConfig.Get("NTSCAN_highcolor", 1), ",")
			VitalColor = table.concat(NTConfig.Get("NTSCAN_vitalcolor", 1), ",")
			RemovalColor = table.concat(NTConfig.Get("NTSCAN_removalcolor", 1), ",")
			CustomColor = table.concat(NTConfig.Get("NTSCAN_customcolor", 1), ",")
		end

		local LowMedThreshold = NTConfig.Get("NTSCAN_lowmedThreshold", 1)
		local MedHighThreshold = NTConfig.Get("NT_medhighThreshold", 1)

		local VitalCategory = NTConfig.Get("NTSCAN_VitalCategory", 1)
		local RemovalCategory = NTConfig.Get("NTSCAN_RemovalCategory", 1)
		local CustomCategory = NTConfig.Get("NTSCAN_CustomCategory", 1)
		local PressureCategory = { "bloodpressure" }
		local IgnoredCategory = NTConfig.Get("NTSCAN_IgnoredCategory", 1)

		HF.GiveItem(targetCharacter, "ntsfx_selfscan")
		containedItem.Condition = containedItem.Condition - 5
		HF.AddAffliction(targetCharacter, "radiationsickness", 1, usingCharacter)
		HF.AddAffliction(usingCharacter, "radiationsickness", 0.6)

		-- print readout of afflictions
		local startReadout = "‖color:"
			.. BaseColor
			.. "‖"
			.. "Affliction readout for "
			.. "‖color:end‖"
			.. "‖color:"
			.. NameColor
			.. "‖"
			.. targetCharacter.Name
			.. "‖color:end‖"
			.. "‖color:"
			.. BaseColor
			.. "‖"
			.. " on limb "
			.. HF.LimbTypeToString(limbtype)
			.. ":\n"
			.. "‖color:end‖"
		local LowPressureReadout = ""
		local HighPressureReadout = ""
		local LowStrengthReadout = ""
		local MediumStrengthReadout = ""
		local HighStrengthReadout = ""
		local VitalReadout = ""
		local RemovalReadout = ""
		local CustomReadout = ""

		local afflictionlist = targetCharacter.CharacterHealth.GetAllAfflictions()
		local afflictionsdisplayed = 0
		for value in afflictionlist do
			local strength = HF.Round(value.Strength)
			local prefab = value.Prefab
			local limb = targetCharacter.CharacterHealth.GetAfflictionLimb(value)
			local afflimbtype = LimbType.Torso

			if not prefab.LimbSpecific then
				afflimbtype = prefab.IndicatorLimb
			elseif limb ~= nil then
				afflimbtype = limb.type
			end

			afflimbtype = HF.NormalizeLimbType(afflimbtype)

			if strength >= prefab.ShowInHealthScannerThreshold and afflimbtype == limbtype then
				if --low readout
					(strength < LowMedThreshold)
					and not HF.TableContains(VitalCategory, value.Identifier)
					and not HF.TableContains(RemovalCategory, value.Identifier)
					and not HF.TableContains(PressureCategory, value.Identifier)
					and not HF.TableContains(CustomCategory, value.Identifier)
					and not HF.TableContains(IgnoredCategory, value.Identifier)
				then
					LowStrengthReadout = LowStrengthReadout
						.. "\n"
						.. value.Prefab.Name.Value
						.. ": "
						.. strength
						.. "%"
				end

				if --medium readout
					(strength >= LowMedThreshold)
					and (strength < MedHighThreshold)
					and not HF.TableContains(VitalCategory, value.Identifier)
					and not HF.TableContains(RemovalCategory, value.Identifier)
					and not HF.TableContains(PressureCategory, value.Identifier)
					and not HF.TableContains(CustomCategory, value.Identifier)
					and not HF.TableContains(IgnoredCategory, value.Identifier)
				then
					MediumStrengthReadout = MediumStrengthReadout
						.. "\n"
						.. value.Prefab.Name.Value
						.. ": "
						.. strength
						.. "%"
				end

				if --high readout
					(strength >= MedHighThreshold)
					and not HF.TableContains(VitalCategory, value.Identifier)
					and not HF.TableContains(RemovalCategory, value.Identifier)
					and not HF.TableContains(PressureCategory, value.Identifier)
					and not HF.TableContains(CustomCategory, value.Identifier)
					and not HF.TableContains(IgnoredCategory, value.Identifier)
				then
					HighStrengthReadout = HighStrengthReadout
						.. "\n"
						.. value.Prefab.Name.Value
						.. ": "
						.. strength
						.. "%"
				end

				if --vital readout
					HF.TableContains(VitalCategory, value.Identifier)
					and not HF.TableContains(IgnoredCategory, value.Identifier)
				then
					VitalReadout = VitalReadout .. "\n" .. value.Prefab.Name.Value .. ": " .. strength .. "%"
				end

				if --removed readout
					HF.TableContains(RemovalCategory, value.Identifier)
					and not HF.TableContains(IgnoredCategory, value.Identifier)
				then
					RemovalReadout = RemovalReadout .. "\n" .. value.Prefab.Name.Value .. ": " .. strength .. "%"
				end

				if --custom readout
					HF.TableContains(CustomCategory, value.Identifier)
					and not HF.TableContains(IgnoredCategory, value.Identifier)
				then
					CustomReadout = CustomReadout .. "\n" .. value.Prefab.Name.Value .. ": " .. strength .. "%"
				end

				if --bloodpressure readout
					HF.TableContains(PressureCategory, value.Identifier)
					and ((strength > 130) or (strength < 70))
					and not HF.TableContains(IgnoredCategory, value.Identifier)
				then
					HighPressureReadout = HighPressureReadout
						.. "\n"
						.. value.Prefab.Name.Value
						.. ": "
						.. strength
						.. "%"
				elseif HF.TableContains(PressureCategory, value.Identifier) then
					LowPressureReadout = LowPressureReadout
						.. "\n"
						.. value.Prefab.Name.Value
						.. ": "
						.. strength
						.. "%"
				end

				afflictionsdisplayed = afflictionsdisplayed + 1
			end
		end

		-- add a message in case there is nothing to display
		if afflictionsdisplayed <= 0 then
			LowStrengthReadout = LowStrengthReadout .. "\nNo afflictions! Good work!"
		end

		Timer.Wait(function()
			HF.DMClient(
				HF.CharacterToClient(usingCharacter),

				startReadout
					.. "‖color:"
					.. LowColor
					.. "‖"
					.. LowPressureReadout
					.. "‖color:end‖"
					.. "‖color:"
					.. HighColor
					.. "‖"
					.. HighPressureReadout
					.. "‖color:end‖"
					.. "‖color:"
					.. LowColor
					.. "‖"
					.. LowStrengthReadout
					.. "‖color:end‖"
					.. "‖color:"
					.. MedColor
					.. "‖"
					.. MediumStrengthReadout
					.. "‖color:end‖"
					.. "‖color:"
					.. HighColor
					.. "‖"
					.. HighStrengthReadout
					.. "‖color:end‖"
					.. "‖color:"
					.. VitalColor
					.. "‖"
					.. VitalReadout
					.. "‖color:end‖"
					.. "‖color:"
					.. RemovalColor
					.. "‖"
					.. RemovalReadout
					.. "‖color:end‖"
					.. "‖color:"
					.. CustomColor
					.. "‖"
					.. CustomReadout
					.. "‖color:end‖"
			)
		end, 2000)
	end
end
NT.HematologyDetectable = {
	"sepsis",
	"immunity",
	"acidosis",
	"alkalosis",
	"bloodloss",
	"bloodpressure",
	"afimmunosuppressant",
	"afthiamine",
	"afadrenaline",
	"afstreptokinase",
	"afantibiotics",
	"afsaline",
	"afringerssolution",
	"afpressuredrug",
}
NT.ItemMethods.bloodanalyzer = function(item, usingCharacter, targetCharacter, limb)
	-- only work if no cooldown
	if item.Condition < 50 then
		return
	end

	local limbtype = limb.type

	local success = HF.GetSkillRequirementMet(usingCharacter, "medical", 30)
	local bloodlossinduced = 1
	if not success then
		bloodlossinduced = 3
	end
	HF.AddAffliction(targetCharacter, "bloodloss", bloodlossinduced, usingCharacter)

	-- spawn donor card
	local containedItem = item.OwnInventory.GetItemAt(0)
	local hasCartridge = containedItem ~= nil
		and (containedItem.Prefab.Identifier.Value == "bloodcollector" or containedItem.HasTag("donorCard"))
	if hasCartridge then
		HF.RemoveItem(containedItem)
		local bloodtype = NT.GetBloodtype(targetCharacter)
		local targetIDCard = targetCharacter.Inventory.GetItemAt(0)
		if targetIDCard ~= nil and targetIDCard.OwnInventory.GetItemAt(0) == nil then
			-- put the donor card into the id card
			HF.PutItemInsideItem(targetIDCard, bloodtype .. "card")
		else
			-- put it in the analyzer instead
			HF.PutItemInsideItem(item, bloodtype .. "card")
		end
	end

	local LowPressureReadout = ""
	local HighPressureReadout = ""
	local LowStrengthReadout = ""
	local MediumStrengthReadout = ""
	local HighStrengthReadout = ""
	local VitalReadout = ""
	local RemovalReadout = ""
	local CustomReadout = ""

	--set base color values
	local BaseColor = "127,255,255"
	local NameColor = "127,255,255"
	local LowColor = "127,255,255"
	local MedColor = "127,255,255"
	local HighColor = "127,255,255"
	local VitalColor = "127,255,255"
	local RemovalColor = "127,255,255"
	local CustomColor = "127,255,255"

	if NTConfig.Get("NTSCAN_enablecoloredscanner", 1) then
		BaseColor = table.concat(NTConfig.Get("NTSCAN_basecolor", 1), ",")
		NameColor = table.concat(NTConfig.Get("NTSCAN_namecolor", 1), ",")
		LowColor = table.concat(NTConfig.Get("NTSCAN_lowcolor", 1), ",")
		MedColor = table.concat(NTConfig.Get("NTSCAN_medcolor", 1), ",")
		HighColor = table.concat(NTConfig.Get("NTSCAN_highcolor", 1), ",")
		VitalColor = table.concat(NTConfig.Get("NTSCAN_vitalcolor", 1), ",")
		RemovalColor = table.concat(NTConfig.Get("NTSCAN_removalcolor", 1), ",")
		CustomColor = table.concat(NTConfig.Get("NTSCAN_customcolor", 1), ",")
	end

	local LowMedThreshold = NTConfig.Get("NTSCAN_lowmedThreshold", 1)
	local MedHighThreshold = NTConfig.Get("NT_medhighThreshold", 1)

	local VitalCategory = NTConfig.Get("NTSCAN_VitalCategory", 1)
	local RemovalCategory = NTConfig.Get("NTSCAN_RemovalCategory", 1)
	local CustomCategory = NTConfig.Get("NTSCAN_CustomCategory", 1)
	local PressureCategory = { "bloodpressure" }
	local IgnoredCategory = NTConfig.Get("NTSCAN_IgnoredCategory", 1)

	-- print readout of afflictions
	local bloodtype = AfflictionPrefab.Prefabs[NT.GetBloodtype(targetCharacter)].Name.Value
	local startReadout = "‖color:"
		.. NameColor
		.. "‖"
		.. "Bloodtype: "
		.. bloodtype
		.. "‖color:end‖"
		.. "‖color:"
		.. BaseColor
		.. "‖"
		.. "\nAffliction readout for the blood of "
		.. "‖color:end‖"
		.. "‖color:"
		.. NameColor
		.. "‖"
		.. targetCharacter.Name
		.. ":\n"
		.. "‖color:end‖"
	local afflictionlist = targetCharacter.CharacterHealth.GetAllAfflictions()
	local afflictionsdisplayed = 0
	for value in afflictionlist do
		local strength = HF.Round(value.Strength)
		local prefab = value.Prefab

		if strength > 2 and HF.TableContains(NT.HematologyDetectable, prefab.Identifier.Value) then
			-- add the affliction to the readout
			if --low readout
				(strength < LowMedThreshold)
				and not HF.TableContains(IgnoredCategory, value.Identifier)
				and not HF.TableContains(PressureCategory, value.Identifier)
			then
				LowStrengthReadout = LowStrengthReadout .. "\n" .. value.Prefab.Name.Value .. ": " .. strength .. "%"
			end

			if --medium readout
				(strength >= LowMedThreshold)
				and (strength < MedHighThreshold)
				and not HF.TableContains(IgnoredCategory, value.Identifier)
				and not HF.TableContains(PressureCategory, value.Identifier)
			then
				MediumStrengthReadout = MediumStrengthReadout
					.. "\n"
					.. value.Prefab.Name.Value
					.. ": "
					.. strength
					.. "%"
			end

			if --high readout
				(strength >= MedHighThreshold)
				and not HF.TableContains(IgnoredCategory, value.Identifier)
				and not HF.TableContains(PressureCategory, value.Identifier)
			then
				HighStrengthReadout = HighStrengthReadout .. "\n" .. value.Prefab.Name.Value .. ": " .. strength .. "%"
			end

			if --vital readout
				HF.TableContains(VitalCategory, value.Identifier)
				and not HF.TableContains(IgnoredCategory, value.Identifier)
				and not HF.TableContains(PressureCategory, value.Identifier)
			then
				VitalReadout = VitalReadout .. "\n" .. value.Prefab.Name.Value .. ": " .. strength .. "%"
			end

			if --removed readout
				HF.TableContains(RemovalCategory, value.Identifier)
				and not HF.TableContains(IgnoredCategory, value.Identifier)
				and not HF.TableContains(PressureCategory, value.Identifier)
			then
				RemovalReadout = RemovalReadout .. "\n" .. value.Prefab.Name.Value .. ": " .. strength .. "%"
			end

			if --custom readout
				HF.TableContains(CustomCategory, value.Identifier)
				and not HF.TableContains(IgnoredCategory, value.Identifier)
				and not HF.TableContains(PressureCategory, value.Identifier)
			then
				CustomReadout = CustomReadout .. "\n" .. value.Prefab.Name.Value .. ": " .. strength .. "%"
			end

			if --bloodpressure readout
				HF.TableContains(PressureCategory, value.Identifier)
				and ((strength > 130) or (strength < 70))
				and not HF.TableContains(IgnoredCategory, value.Identifier)
			then
				HighPressureReadout = HighPressureReadout .. "\n" .. value.Prefab.Name.Value .. ": " .. strength .. "%"
			elseif
				HF.TableContains(PressureCategory, value.Identifier)
				and not HF.TableContains(IgnoredCategory, value.Identifier)
			then
				LowPressureReadout = LowPressureReadout .. "\n" .. value.Prefab.Name.Value .. ": " .. strength .. "%"
			end

			afflictionsdisplayed = afflictionsdisplayed + 1
		end
	end

	-- add a message in case there is nothing to display
	if afflictionsdisplayed <= 0 then
		LowStrengthReadout = LowStrengthReadout .. "\nNo blood pressure detected..."
	end

	HF.DMClient(
		HF.CharacterToClient(usingCharacter),
		startReadout
			.. "‖color:"
			.. LowColor
			.. "‖"
			.. LowPressureReadout
			.. "‖color:end‖"
			.. "‖color:"
			.. HighColor
			.. "‖"
			.. HighPressureReadout
			.. "‖color:end‖"
			.. "‖color:"
			.. LowColor
			.. "‖"
			.. LowStrengthReadout
			.. "‖color:end‖"
			.. "‖color:"
			.. MedColor
			.. "‖"
			.. MediumStrengthReadout
			.. "‖color:end‖"
			.. "‖color:"
			.. HighColor
			.. "‖"
			.. HighStrengthReadout
			.. "‖color:end‖"
			.. "‖color:"
			.. VitalColor
			.. "‖"
			.. VitalReadout
			.. "‖color:end‖"
			.. "‖color:"
			.. RemovalColor
			.. "‖"
			.. RemovalReadout
			.. "‖color:end‖"
			.. "‖color:"
			.. CustomColor
			.. "‖"
			.. CustomReadout
			.. "‖color:end‖"
	)
end

-- trauma shears and diving knife
NT.CuttableAfflictions = { "bandaged", "dirtybandage" }
NT.TraumashearsAfflictions = { "gypsumcast" }
NT.ItemMethods.traumashears = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = HF.NormalizeLimbType(limb.type)

	-- don't work on stasis
	if HF.HasAffliction(targetCharacter, "stasis", 0.1) then
		return
	end

	-- does the target have any cuttable afflictions?
	local cuttables = HF.CombineArrays(NT.CuttableAfflictions, NT.TraumashearsAfflictions)
	local canCut = false
	for val in cuttables do
		local prefab = AfflictionPrefab.Prefabs[val]
		if prefab ~= nil then
			if prefab.LimbSpecific then
				if HF.HasAfflictionLimb(targetCharacter, val, limbtype, 0.1) then
					canCut = true
					break
				end
			elseif limbtype == prefab.IndicatorLimb then
				if HF.HasAffliction(targetCharacter, val, 0.1) then
					canCut = true
					break
				end
			end
		end
	end

	if canCut then
		if HF.GetSkillRequirementMet(usingCharacter, "medical", 10) then
			HF.GiveItem(targetCharacter, "ntsfx_scissors")

			-- remove 8% fracture so that they dont scream again
			if
				NT.LimbIsBroken(targetCharacter, limbtype)
				and HF.HasAfflictionLimb(targetCharacter, "gypsumcast", limbtype, 0.1)
			then
				NT.BreakLimb(targetCharacter, limbtype, -8)
			end

			-- remove cuttables
			for val in cuttables do
				local prefab = AfflictionPrefab.Prefabs[val]
				if prefab ~= nil then
					if prefab.LimbSpecific then
						HF.SetAfflictionLimb(targetCharacter, val, limbtype, 0, usingCharacter)
					elseif limbtype == prefab.IndicatorLimb then
						HF.SetAffliction(targetCharacter, val, 0, usingCharacter)
					end
				end
			end
		else
			HF.AddAfflictionLimb(targetCharacter, "bleeding", limbtype, 15, usingCharacter)
			HF.AddAfflictionLimb(targetCharacter, "lacerations", limbtype, 10, usingCharacter)
		end
	end
end
NT.ItemStartsWithMethods.divingknife = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = limb.type

	-- don't work on stasis
	if HF.HasAffliction(targetCharacter, "stasis", 0.1) then
		return
	end

	-- does the target have any cuttable afflictions?
	local canCut = false
	for val in NT.CuttableAfflictions do
		local prefab = AfflictionPrefab.Prefabs[val]
		if prefab ~= nil then
			if prefab.LimbSpecific then
				if HF.HasAfflictionLimb(targetCharacter, val, limbtype, 0.1) then
					canCut = true
					break
				end
			elseif HF.NormalizeLimbType(limbtype) == prefab.IndicatorLimb then
				if HF.HasAffliction(targetCharacter, val, 0.1) then
					canCut = true
					break
				end
			end
		end
	end

	if canCut then
		if HF.GetSkillRequirementMet(usingCharacter, "medical", 30) then
			HF.GiveItem(targetCharacter, "ntsfx_bandage")
			-- remove cuttables
			for val in NT.CuttableAfflictions do
				local prefab = AfflictionPrefab.Prefabs[val]
				if prefab ~= nil then
					if prefab.LimbSpecific then
						HF.SetAfflictionLimb(targetCharacter, val, limbtype, 0, usingCharacter)
					elseif HF.NormalizeLimbType(limbtype) == prefab.IndicatorLimb then
						HF.SetAffliction(targetCharacter, val, 0, usingCharacter)
					end
				end
			end
		else
			HF.AddAfflictionLimb(targetCharacter, "bleeding", limbtype, 15, usingCharacter)
			HF.AddAfflictionLimb(targetCharacter, "lacerations", limbtype, 10, usingCharacter)
		end
	end
end

NT.ItemMethods.gypsum = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = HF.NormalizeLimbType(limb.type)

	-- don't work on stasis
	if HF.HasAffliction(targetCharacter, "stasis", 0.1) then
		return
	end

	if
		HF.HasAfflictionLimb(targetCharacter, "bandaged", limbtype, 0.1)
		and not HF.HasAfflictionLimb(targetCharacter, "gypsumcast", limbtype, 0.1)
		and not HF.HasAfflictionLimb(targetCharacter, "surgeryincision", limbtype, 1)
		and HF.LimbIsExtremity(limbtype)
	then
		if HF.GetSkillRequirementMet(usingCharacter, "medical", 40) then
			HF.SetAfflictionLimb(targetCharacter, "bandaged", limbtype, 0, usingCharacter)
			HF.SetAfflictionLimb(targetCharacter, "gypsumcast", limbtype, 100, usingCharacter)
			NT.BreakLimb(targetCharacter, limbtype, -20)
			HF.GiveSkillScaled(usingCharacter, "medical", 6000)
			HF.RemoveItem(item)
		else
			HF.RemoveItem(item)
		end
	end
end

-- treatment items

NT.SutureAfflictions = {
	bonecut = { xpgain = 0, case = "surgeryincision" },
	drilledbones = { xpgain = 0, case = "surgeryincision" },

	ll_arterialcut = { xpgain = 3, case = "retractedskin" },
	rl_arterialcut = { xpgain = 3, case = "retractedskin" },
	la_arterialcut = { xpgain = 3, case = "retractedskin" },
	ra_arterialcut = { xpgain = 3, case = "retractedskin" },
	h_arterialcut = { xpgain = 3, case = "retractedskin" },
	t_arterialcut = { xpgain = 6, case = "retractedskin" },
	arteriesclamp = { xpgain = 0, case = "retractedskin" },
	tamponade = { xpgain = 3, case = "retractedskin" },
	internalbleeding = { xpgain = 3, case = "retractedskin" },
	stroke = { xpgain = 6, case = "retractedskin" },

	clampedbleeders = {},
	surgeryincision = {},
	retractedskin = {},
}
NT.ItemMethods.suture = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = HF.NormalizeLimbType(limb.type)

	if HF.GetSkillRequirementMet(usingCharacter, "medical", 30) then
		-- in field use
		local healeddamage = 0
		healeddamage = healeddamage
			+ HF.Clamp(HF.GetAfflictionStrengthLimb(targetCharacter, limbtype, "lacerations", 0), 0, 20)
		healeddamage = healeddamage
			+ HF.Clamp(HF.GetAfflictionStrengthLimb(targetCharacter, limbtype, "bitewounds", 0), 0, 20)
		healeddamage = healeddamage
			+ HF.Clamp(HF.GetAfflictionStrengthLimb(targetCharacter, limbtype, "explosiondamage", 0), 0, 20)
		healeddamage = healeddamage
			+ HF.Clamp(HF.GetAfflictionStrengthLimb(targetCharacter, limbtype, "gunshotwound", 0), 0, 20)
		healeddamage = healeddamage
			+ HF.Clamp(HF.GetAfflictionStrengthLimb(targetCharacter, limbtype, "bleeding", 0) / 10, 0, 40)
		healeddamage = healeddamage
			+ HF.Clamp(HF.GetAfflictionStrengthLimb(targetCharacter, limbtype, "bleedingnonstop", 0) / 10, 0, 40)

		HF.AddAfflictionLimb(targetCharacter, "lacerations", limbtype, -20, usingCharacter)
		HF.AddAfflictionLimb(targetCharacter, "bitewounds", limbtype, -20, usingCharacter)
		HF.AddAfflictionLimb(targetCharacter, "explosiondamage", limbtype, -20, usingCharacter)
		HF.AddAfflictionLimb(targetCharacter, "gunshotwound", limbtype, -20, usingCharacter)
		HF.AddAfflictionLimb(targetCharacter, "bleeding", limbtype, -40, usingCharacter)
		HF.AddAfflictionLimb(targetCharacter, "suturedw", limbtype, healeddamage)

		HF.GiveSkillScaled(usingCharacter, "medical", healeddamage * 100)

		-- terminating surgeries
		-- amputations
		if HF.HasAfflictionLimb(targetCharacter, "bonecut", limbtype, 1) then
			NT.SurgicallyAmputateLimbAndGenerateItem(usingCharacter, targetCharacter, limbtype)
		end
		HF.AddAffliction(targetCharacter, "tshocktimeout", -100)

		-- the other stuff
		local function removeAfflictionPlusGainSkill(affidentifier, skillgain)
			if HF.HasAfflictionLimb(targetCharacter, affidentifier, limbtype) then
				HF.SetAfflictionLimb(targetCharacter, affidentifier, limbtype, 0, usingCharacter)

				HF.GiveSurgerySkill(usingCharacter, skillgain)
			end
		end
		local function removeAfflictionNonLimbSpecificPlusGainSkill(affidentifier, skillgain)
			if HF.HasAffliction(targetCharacter, affidentifier) then
				HF.SetAffliction(targetCharacter, affidentifier, 0, usingCharacter)

				HF.GiveSurgerySkill(usingCharacter, skillgain)
			end
		end

		for key, value in pairs(NT.SutureAfflictions) do
			local prefab = AfflictionPrefab.Prefabs[key]
			if prefab ~= nil and (value.case == nil or HF.HasAfflictionLimb(targetCharacter, value.case, limbtype)) then
				if value.func ~= nil then
					value.func(item, usingCharacter, targetCharacter, limb)
				else
					local skillgain = value.xpgain or 0
					if prefab.LimbSpecific then
						removeAfflictionPlusGainSkill(key, skillgain)
					elseif prefab.IndicatorLimb == limbtype then
						removeAfflictionNonLimbSpecificPlusGainSkill(key, skillgain)
					end
				end
			end
		end
	else
		HF.AddAfflictionLimb(targetCharacter, "internaldamage", limbtype, 6)
	end
end
NT.ItemMethods.tourniquet = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = HF.NormalizeLimbType(limb.type)

	if
		HF.GetSkillRequirementMet(usingCharacter, "medical", 30)
		and not HF.HasAfflictionLimb(targetCharacter, "arteriesclamp", limbtype, 1)
	then
		if NT.LimbIsArterialCut(targetCharacter, limbtype) then
			if HF.LimbIsExtremity(limbtype) then
				HF.SetAfflictionLimb(targetCharacter, "arteriesclamp", limbtype, 100, usingCharacter)
				HF.GiveSkillScaled(usingCharacter, "medical", 6000)
			elseif limbtype == LimbType.Head then
				HF.SetAffliction(targetCharacter, "oxygenlow", 200, usingCharacter)
				HF.AddAffliction(targetCharacter, "cerebralhypoxia", 15, usingCharacter)
			end
			HF.RemoveItem(item)
		end
	else
		HF.AddAfflictionLimb(targetCharacter, "blunttrauma", limbtype, 6, usingCharacter)
	end
end
NT.ItemMethods.emptybloodpack = function(item, usingCharacter, targetCharacter, limb)
	if item.Condition <= 0 then
		return
	end

	if targetCharacter.Bloodloss <= 31 then
		local success = HF.GetSkillRequirementMet(usingCharacter, "medical", 30)
		local bloodlossinduced = 30
		if not success then
			bloodlossinduced = 40
		end

		local bloodtype = NT.GetBloodtype(targetCharacter)

		-- add acidosis, alkalosis and sepsis to the bloodpack if the donor has them
		local function postSpawnFunc(args)
			local tags = {}

			if args.acidosis > 0 then
				table.insert(tags, "acid:" .. tostring(HF.Round(args.acidosis)))
			elseif args.alkalosis > 0 then
				table.insert(tags, "alkal:" .. tostring(HF.Round(args.alkalosis)))
			end
			if args.sepsis > 0 then
				table.insert(tags, "sepsis")
			end

			local tagstring = ""
			for index, value in ipairs(tags) do
				tagstring = tagstring .. value
				if index < #tags then
					tagstring = tagstring .. ","
				end
			end

			args.item.Tags = tagstring
		end
		local params = {
			acidosis = HF.GetAfflictionStrength(targetCharacter, "acidosis"),
			alkalosis = HF.GetAfflictionStrength(targetCharacter, "alkalosis"),
			sepsis = HF.GetAfflictionStrength(targetCharacter, "sepsis"),
		}

		-- move towards isotonic
		HF.SetAffliction(targetCharacter, "acidosis", HF.GetAfflictionStrength(targetCharacter, "acidosis", 0) * 0.9)
		HF.SetAffliction(targetCharacter, "alkalosis", HF.GetAfflictionStrength(targetCharacter, "alkalosis", 0) * 0.9)

		HF.AddAffliction(targetCharacter, "bloodloss", bloodlossinduced, usingCharacter)

		local bloodpackIdentifier = "bloodpack" .. bloodtype
		if bloodtype == "ominus" then
			bloodpackIdentifier = "antibloodloss2"
		end

		HF.GiveItemPlusFunction(bloodpackIdentifier, postSpawnFunc, params, usingCharacter)
		item.Condition = 0
		--HF.RemoveItem(item)
		HF.GiveItem(targetCharacter, "ntsfx_syringe")
	end
end
NT.ItemMethods.propofol = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = limb.type
	local anesthesiastrength = HF.GetAfflictionStrength(targetCharacter, "anesthesia", 0)
	local anesthesiaGained = 1

	if HF.HasTalent(usingCharacter, "ntsp_properfol") then
		anesthesiaGained = 15
	end

	if anesthesiastrength < 15 then
		HF.AddAffliction(targetCharacter, "anesthesia", anesthesiaGained, usingCharacter)
	else
		anesthesiaGained = 15 - anesthesiastrength
		HF.AddAffliction(targetCharacter, "anesthesia", anesthesiaGained, usingCharacter)
	end

	HF.RemoveItem(item)
	HF.GiveItem(targetCharacter, "ntsfx_syringe")
end
NT.ItemMethods.streptokinase = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = limb.type

	HF.AddAffliction(targetCharacter, "heartattack", -100, usingCharacter)
	HF.AddAffliction(targetCharacter, "hemotransfusionshock", -100, usingCharacter)
	HF.AddAffliction(targetCharacter, "afstreptokinase", 50, usingCharacter)

	-- make stroke worse if present
	local hasStroke = HF.HasAffliction(targetCharacter, "stroke")
	if hasStroke then
		HF.AddAffliction(targetCharacter, "stroke", 5, usingCharacter)
		HF.AddAffliction(targetCharacter, "cerebralhypoxia", 10, usingCharacter)
	end

	HF.RemoveItem(item)
	HF.GiveItem(targetCharacter, "ntsfx_syringe")
end
NT.ItemMethods.adrenaline = function(item, usingCharacter, targetCharacter, limb)
	HF.AddAffliction(targetCharacter, "afadrenaline", 55, usingCharacter)
	HF.AddAffliction(targetCharacter, "adrenalinerush", 8, usingCharacter)
	if HF.HasAffliction(targetCharacter, "cardiacarrest", 0.1) then
		HF.AddAffliction(targetCharacter, "cardiacarrest", -100, usingCharacter)
		HF.AddAffliction(targetCharacter, "fibrillation", 20, usingCharacter)
	end
	HF.RemoveItem(item)
	HF.GiveItem(targetCharacter, "ntsfx_syringe")
end
local function limbHasThirdDegreeBurns(char, limbtype)
	return HF.GetAfflictionStrengthLimb(char, limbtype, "burn", 0) > 50
end
NT.ItemMethods.ointment = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = limb.type

	local success = HF.BoolToNum(HF.GetSkillRequirementMet(usingCharacter, "medical", 10), 1)

	HF.AddAfflictionLimb(targetCharacter, "ointmented", limbtype, 60 * (success + 1), usingCharacter)
	if not limbHasThirdDegreeBurns(targetCharacter, limbtype) then
		HF.AddAfflictionLimb(targetCharacter, "burn", limbtype, -7.2 - success * 4.8, usingCharacter)
	end
	HF.AddAfflictionLimb(targetCharacter, "infectedwound", limbtype, -24 - success * 48, usingCharacter)

	-- HF.RemoveItem(item)
	item.Condition = item.Condition - 12.5
	HF.GiveItem(targetCharacter, "ntsfx_ointment")
end
NT.ItemMethods.antibleeding1 = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = limb.type
	local success = HF.BoolToNum(HF.GetSkillRequirementMet(usingCharacter, "medical", 10), 1)
	local hasmedexp = HF.BoolToNum(HF.HasTalent(usingCharacter, "medicalexpertise"))
	HF.AddAfflictionLimb(targetCharacter, "dirtybandage", limbtype, -100, usingCharacter)
	HF.AddAfflictionLimb(targetCharacter, "bandaged", limbtype, 36 + success * 12 + hasmedexp * 12, usingCharacter)
	HF.AddAfflictionLimb(targetCharacter, "bleeding", limbtype, -18 - success * 6 - hasmedexp * 6, usingCharacter)
	HF.RemoveItem(item)
	HF.GiveItem(targetCharacter, "ntsfx_bandage")
end
NT.ItemMethods.antibleeding2 = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = limb.type
	local success = HF.BoolToNum(HF.GetSkillRequirementMet(usingCharacter, "medical", 22), 1)
	HF.AddAfflictionLimb(targetCharacter, "dirtybandage", limbtype, -100, usingCharacter)
	HF.AddAfflictionLimb(targetCharacter, "bandaged", limbtype, 50 + success * 50, usingCharacter)
	HF.AddAfflictionLimb(targetCharacter, "bleeding", limbtype, -24 - success * 24, usingCharacter)
	if HF.HasAfflictionLimb(targetCharacter, "retractedskin", limbtype) then
		-- remove all burn if applied during surgery
		local affAmount = HF.GetAfflictionStrengthLimb(targetCharacter, limbtype, "burn")
		local healedamount = math.min(affAmount, 200)
		HF.AddAfflictionLimb(targetCharacter, "burn", limbtype, -healedamount, usingCharacter)
		if NTSP ~= nil and NTConfig.Get("NTSP_enableSurgerySkill", true) then
			HF.GiveSkillScaled(usingCharacter, "surgery", healedamount * 300)
		else
			HF.GiveSkillScaled(usingCharacter, "medical", healedamount * 150)
		end
	elseif not limbHasThirdDegreeBurns(targetCharacter, limbtype) then
		-- remove normal amount of burn if not third degree
		HF.AddAfflictionLimb(targetCharacter, "burn", limbtype, -12 - success * 12, usingCharacter)
	end
	HF.RemoveItem(item)
	HF.GiveItem(targetCharacter, "ntsfx_bandage")
end

NT.ItemMethods.defibrillator = function(item, usingCharacter, targetCharacter, limb)
	if item.Condition <= 0 then
		return
	end

	local containedItem = item.OwnInventory.GetItemAt(0)
	if containedItem == nil then
		return
	end
	local hasVoltage = containedItem.Condition > 0
	-- if defib user in water = shock the user with 93 strength electricshock aff (3 second stun) + electrocution vanilla sound effect
	if not hasVoltage then
		return
	end
	HF.GiveItem(targetCharacter, "ntsfx_manualdefib")
	-- about to get deepfried if underwater (TODO)
	--local unsafe = HF.GetOuterWearIdentifier(targetCharacter) ~= "emergencysuit" and targetCharacter.InWater
	--local unsafeArrestRoll = unsafe
	--	and HF.Chance(HF.Clamp(0.3, (1 - (HF.GetSkillLevel(usingCharacter, "medical") / 100)) ^ 2 * 8.5, 1))
	--if unsafe then
	-- shock therapy the surrounding characters
	--	containedItem.Condition = containedItem.Condition - 10
	--	if containedItem.Prefab.Identifier.Value ~= "fulguriumbatterycell" then
	--		containedItem.Condition = containedItem.Condition - 10
	--	end
	--	Timer.Wait(function()
	--		for _, character in pairs(Character.CharacterList) do
	--			local distance = HF.DistanceBetween(item.worldPosition, character.worldPosition)
	--			if
	--				distance <= 300 and character.CanSeeTarget(usingCharacter) and HF.Chance(0.3)
	--				or character == targetCharacter
	--			then
	--				local limbtypes = {
	--					LimbType.Torso,
	--					LimbType.Head,
	--					LimbType.LeftArm,
	--					LimbType.RightArm,
	--					LimbType.LeftLeg,
	--					LimbType.RightLeg,
	--				}
	--				for type in limbtypes do
	--					if math.random() < 0.5 then
	--						HF.AddAfflictionLimb(character, "burn", type, math.random(15, 20), usingCharacter)
	--						HF.AddAfflictionLimb(character, "spasm", type, 10)
	--					end
	--				end
	--				HF.SetAffliction(character, "electricshock", 100, usingCharacter)
	--				HF.AddAffliction(character, "traumaticshock", 25, usingCharacter)
	--			end
	--		end
	--	end, 2000)
	--end
	containedItem.Condition = containedItem.Condition - 10
	if containedItem.Prefab.Identifier.Value ~= "fulguriumbatterycell" then
		containedItem.Condition = containedItem.Condition - 10
	end

	local successChance = (HF.GetSkillLevel(usingCharacter, "medical") / 100) ^ 2
	local arrestSuccessChance = (HF.GetSkillLevel(usingCharacter, "medical") / 100) ^ 4
	local arrestFailChance = (1 - (HF.GetSkillLevel(usingCharacter, "medical") / 100)) ^ 2 * 0.3

	Timer.Wait(function()
		HF.AddAffliction(targetCharacter, "stun", 2, usingCharacter)
		if HF.Chance(successChance) then
			HF.SetAffliction(targetCharacter, "tachycardia", 0, usingCharacter)
			HF.SetAffliction(targetCharacter, "fibrillation", 0, usingCharacter)
		end
		if HF.Chance(arrestSuccessChance) then
			HF.SetAffliction(targetCharacter, "cardiacarrest", 0, usingCharacter)
		end
	end, 2000)
end
NT.ItemMethods.aed = function(item, usingCharacter, targetCharacter, limb)
	if item.Condition <= 0 then
		return
	end

	local containedItem = item.OwnInventory.GetItemAt(0)
	if containedItem == nil then
		return
	end
	local hasVoltage = containedItem.Condition > 0

	if hasVoltage then
		local actionRequired = HF.HasAffliction(targetCharacter, "tachycardia", 5)
			or HF.HasAffliction(targetCharacter, "fibrillation", 1)
			or HF.HasAffliction(targetCharacter, "cardiacarrest")

		if not actionRequired then
			HF.GiveItem(targetCharacter, "ntsfx_defib2")
		else
			HF.GiveItem(targetCharacter, "ntsfx_defib1")

			containedItem.Condition = containedItem.Condition - 10
			if containedItem.Prefab.Identifier.Value ~= "fulguriumbatterycell" then
				containedItem.Condition = containedItem.Condition - 10
			end
			-- about to get deepfried if underwater (TODO)
			--local unsafe = HF.GetOuterWearIdentifier(targetCharacter) ~= "emergencysuit" and targetCharacter.InWater
			--local unsafeArrestRoll = unsafe and HF.Chance(0.3)
			--if unsafe then
			--	-- shock therapy the surrounding characters
			--	containedItem.Condition = containedItem.Condition - 10
			--	if containedItem.Prefab.Identifier.Value ~= "fulguriumbatterycell" then
			--		containedItem.Condition = containedItem.Condition - 10
			--	end
			--	Timer.Wait(function()
			--		for _, character in pairs(Character.CharacterList) do
			--			local distance = HF.DistanceBetween(item.worldPosition, character.worldPosition)
			--			if
			--				distance <= 300 and character.CanSeeTarget(usingCharacter) and HF.Chance(0.3)
			--				or character == targetCharacter
			--			then
			--				local limbtypes = {
			--					LimbType.Torso,
			--					LimbType.Head,
			--					LimbType.LeftArm,
			--					LimbType.RightArm,
			--					LimbType.LeftLeg,
			--					LimbType.RightLeg,
			--				}
			--				for type in limbtypes do
			--					if math.random() < 0.5 then
			--						HF.AddAfflictionLimb(character, "burn", type, math.random(15, 20), usingCharacter)
			--						HF.AddAfflictionLimb(character, "spasm", type, 10)
			--					end
			--				end
			--				HF.SetAffliction(character, "electricshock", 100, usingCharacter)
			--				HF.AddAffliction(character, "traumaticshock", 25, usingCharacter)
			--			end
			--		end
			--	end, 2000)
			--end
			local arrestSuccessChance = HF.Clamp((HF.GetSkillLevel(usingCharacter, "medical") / 200), 0.2, 0.4)

			Timer.Wait(function()
				HF.AddAffliction(targetCharacter, "stun", 2, usingCharacter)
				HF.SetAffliction(targetCharacter, "tachycardia", 0, usingCharacter)
				HF.SetAffliction(targetCharacter, "fibrillation", 0, usingCharacter)
				if HF.Chance(arrestSuccessChance) then
					HF.SetAffliction(targetCharacter, "cardiacarrest", 0, usingCharacter)
				end
			end, 3200)
		end
	end
end
NT.ItemMethods.blahaj = function(item, usingCharacter, targetCharacter, limb)
	-- HF.GiveItem(targetCharacter,"ntsfx_squeak") -- this seems to be unnecessary due to the sound effect already being triggered by the xml side of things
	HF.AddAffliction(targetCharacter, "psychosis", -2, usingCharacter)
end

-- surgery

NT.ItemMethods.advscalpel = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = limb.type

	-- don't work on stasis
	if HF.HasAffliction(targetCharacter, "stasis", 0.1) then
		return
	end

	if
		HF.CanPerformSurgeryOn(targetCharacter)
		and not HF.HasAfflictionLimb(targetCharacter, "surgeryincision", limbtype, 1)
	then
		if HF.GetSurgerySkillRequirementMet(usingCharacter, 30) then
			HF.AddAfflictionLimb(
				targetCharacter,
				"surgeryincision",
				limbtype,
				1 + HF.GetSurgerySkill(usingCharacter) / 2,
				usingCharacter
			)
			HF.SetAfflictionLimb(targetCharacter, "suturedi", limbtype, 0, usingCharacter)
			HF.SetAfflictionLimb(targetCharacter, "gypsumcast", limbtype, 0, usingCharacter)
			HF.SetAfflictionLimb(targetCharacter, "bandaged", limbtype, 0, usingCharacter)
		else
			HF.AddAfflictionLimb(targetCharacter, "bleeding", limbtype, 15, usingCharacter)
			HF.AddAfflictionLimb(targetCharacter, "lacerations", limbtype, 10, usingCharacter)
		end

		HF.GiveItem(targetCharacter, "ntsfx_slash")
	end
end
NT.ItemMethods.advhemostat = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = limb.type

	-- don't work on stasis
	if HF.HasAffliction(targetCharacter, "stasis", 0.1) then
		return
	end

	if
		HF.CanPerformSurgeryOn(targetCharacter)
		and HF.HasAfflictionLimb(targetCharacter, "surgeryincision", limbtype, 99)
		and not HF.HasAfflictionLimb(targetCharacter, "clampedbleeders", limbtype, 1)
	then
		HF.AddAfflictionLimb(
			targetCharacter,
			"clampedbleeders",
			limbtype,
			1 + HF.GetSurgerySkill(usingCharacter) / 2,
			usingCharacter
		)
	end
end
NT.ItemMethods.advretractors = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = limb.type

	-- don't work on stasis
	if HF.HasAffliction(targetCharacter, "stasis", 0.1) then
		return
	end

	if
		HF.CanPerformSurgeryOn(targetCharacter)
		and HF.HasAfflictionLimb(targetCharacter, "clampedbleeders", limbtype, 99)
		and not HF.HasAfflictionLimb(targetCharacter, "retractedskin", limbtype, 1)
	then
		if HF.GetSurgerySkillRequirementMet(usingCharacter, 30) then
			HF.AddAfflictionLimb(
				targetCharacter,
				"retractedskin",
				limbtype,
				1 + HF.GetSurgerySkill(usingCharacter) / 2,
				usingCharacter
			)
		else
			HF.AddAfflictionLimb(targetCharacter, "internaldamage", limbtype, 10, usingCharacter)
		end
	end
end
NT.ItemMethods.surgicaldrill = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = limb.type

	-- don't work on stasis
	if HF.HasAffliction(targetCharacter, "stasis", 0.1) then
		return
	end

	if
		HF.CanPerformSurgeryOn(targetCharacter)
		and HF.HasAfflictionLimb(targetCharacter, "retractedskin", limbtype, 99)
		and not HF.HasAfflictionLimb(targetCharacter, "drilledbones", limbtype, 1)
	then
		if HF.GetSurgerySkillRequirementMet(usingCharacter, 45) then
			HF.AddAfflictionLimb(
				targetCharacter,
				"drilledbones",
				limbtype,
				1 + HF.GetSurgerySkill(usingCharacter) / 2,
				usingCharacter
			)
		else
			HF.AddAfflictionLimb(targetCharacter, "burn", limbtype, 12, usingCharacter)
			HF.AddAfflictionLimb(targetCharacter, "internaldamage", limbtype, 10, usingCharacter)
		end
	end
end
NT.ItemMethods.surgerysaw = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = HF.NormalizeLimbType(limb.type)

	-- don't work on stasis
	if HF.HasAffliction(targetCharacter, "stasis", 0.1) then
		return
	end

	if
		HF.CanPerformSurgeryOn(targetCharacter)
		and HF.HasAfflictionLimb(targetCharacter, "retractedskin", limbtype, 99)
		and not HF.HasAfflictionLimb(targetCharacter, "bonecut", limbtype, 1)
	then
		if HF.GetSurgerySkillRequirementMet(usingCharacter, 50) then
			if limbtype ~= LimbType.Torso then
				HF.AddAfflictionLimb(
					targetCharacter,
					"bonecut",
					limbtype,
					1 + HF.GetSurgerySkill(usingCharacter) / 2,
					usingCharacter
				)
			end
		else
			HF.AddAfflictionLimb(targetCharacter, "bleeding", limbtype, 15, usingCharacter)
			HF.AddAfflictionLimb(targetCharacter, "internaldamage", limbtype, 6, usingCharacter)
			HF.AddAfflictionLimb(targetCharacter, "lacerations", limbtype, 4, usingCharacter)
		end
	end
end
NT.ItemMethods.tweezers = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = limb.type

	-- don't work on stasis
	if HF.HasAffliction(targetCharacter, "stasis", 0.1) then
		return
	end

	local usecase = ""
	if
		HF.CanPerformSurgeryOn(targetCharacter)
		and HF.HasAfflictionLimb(targetCharacter, "retractedskin", limbtype, 99)
	then
		usecase = "surgery"
	elseif
		HF.HasAfflictionLimb(targetCharacter, "gunshotwound", limbtype, 1)
		or HF.HasAfflictionLimb(targetCharacter, "explosiondamage", limbtype, 1)
	then
		usecase = "ghetto"
	end

	if usecase ~= "" then
		if HF.GetSurgerySkillRequirementMet(usingCharacter, 30) then
			HF.AddAfflictionLimb(targetCharacter, "lacerations", limbtype, 5, usingCharacter)

			if usecase == "ghetto" then
				HF.AddAffliction(targetCharacter, "traumaticshock", 5, usingCharacter)
			end

			local function healAfflictionGiveSkill(identifier, healamount, skillgain)
				local affAmount = HF.GetAfflictionStrengthLimb(targetCharacter, limbtype, identifier)
				local healedamount = math.min(affAmount, healamount)
				HF.AddAfflictionLimb(targetCharacter, identifier, limbtype, -healamount, usingCharacter)

				if NTSP ~= nil and usecase == "surgery" and NTConfig.Get("NTSP_enableSurgerySkill", true) then
					HF.GiveSkillScaled(usingCharacter, "surgery", healedamount * skillgain)
				else
					HF.GiveSkillScaled(usingCharacter, "medical", healedamount * skillgain / 2)
				end
			end

			local foreignbody = HF.GetAfflictionStrengthLimb(targetCharacter, limbtype, "foreignbody", 0)
			local scrapdropchance = math.min(foreignbody, 5) / 5 * 0.05 -- 5% chance to drop scrap
			if HF.Chance(scrapdropchance) then
				HF.GiveItem(usingCharacter, "scrap")
			end

			local tohealamount = math.random(3, 10)
			healAfflictionGiveSkill("foreignbody", tohealamount, 600)

			if usecase == "surgery" then
				healAfflictionGiveSkill("internaldamage", tohealamount, 3)
				healAfflictionGiveSkill("blunttrauma", tohealamount, 3)
			end
		else
			HF.AddAfflictionLimb(targetCharacter, "internaldamage", limbtype, 6, usingCharacter)
		end
	else
		local sedated = HF.CanPerformSurgeryOn(targetCharacter)

		-- pinchy pinchy!
		HF.AddAfflictionLimb(targetCharacter, "bleeding", limbtype, 1, usingCharacter)
		HF.AddAfflictionLimb(targetCharacter, "lacerations", limbtype, 0.5, usingCharacter)
		if not sedated then
			HF.AddAfflictionLimb(targetCharacter, "pain_extremity", limbtype, 5, usingCharacter)
			HF.AddAffliction(targetCharacter, "stun", 0.1, usingCharacter)
		end

		-- don't rip off peoples faces
		if limbtype == LimbType.Head then
			HF.AddAfflictionLimb(targetCharacter, "bleeding", limbtype, 3, usingCharacter)
			HF.AddAfflictionLimb(targetCharacter, "lacerations", limbtype, 2, usingCharacter)
			if not sedated then
				HF.AddAfflictionLimb(targetCharacter, "pain_extremity", limbtype, 5, usingCharacter)
			end
		end
	end
end

NT.ItemMethods.organscalpel_liver = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = limb.type

	local removed = HF.GetAfflictionStrength(targetCharacter, "liverremoved", 0)
	if limbtype == LimbType.Torso and HF.HasAfflictionLimb(targetCharacter, "retractedskin", limbtype, 1) then
		if removed <= 0 then
			if HF.GetSurgerySkillRequirementMet(usingCharacter, 40) then
				HF.SetAffliction(targetCharacter, "liverremoved", 100, usingCharacter)
			else
				HF.AddAfflictionLimb(targetCharacter, "bleeding", limbtype, 15, usingCharacter)
				HF.AddAfflictionLimb(targetCharacter, "organdamage", limbtype, 5, usingCharacter)
				HF.AddAffliction(targetCharacter, "liverdamage", 20, usingCharacter)
			end

			HF.GiveItem(targetCharacter, "ntsfx_slash")
		else -- organ extraction
			local damage = HF.GetAfflictionStrength(targetCharacter, "liverdamage", 0)
			if damage == 100 then
				return
			elseif HF.GetSurgerySkillRequirementMet(usingCharacter, 50) then
				HF.SetAffliction(targetCharacter, "liverdamage", 100, usingCharacter)

				HF.AddAffliction(targetCharacter, "organdamage", (100 - damage) / 5, usingCharacter)
				local transplantidentifier = "livertransplant_q1"
				if NTC.HasTag(usingCharacter, "organssellforfull") then
					transplantidentifier = "livertransplant"
				end
				if damage < 90 then
					-- add acidosis, alkalosis and sepsis to the bloodpack if the donor has them
					local function postSpawnFunc(args)
						local tags = {}

						if args.acidosis > 0 then
							table.insert(tags, "acid:" .. tostring(HF.Round(args.acidosis)))
						elseif args.alkalosis > 0 then
							table.insert(tags, "alkal:" .. tostring(HF.Round(args.alkalosis)))
						end
						if args.sepsis > 10 then
							table.insert(tags, "sepsis")
						end

						local tagstring = ""
						for index, value in ipairs(tags) do
							tagstring = tagstring .. value
							if index < #tags then
								tagstring = tagstring .. ","
							end
						end

						args.item.Tags = tagstring
						args.item.Condition = args.condition
					end
					local params = {
						acidosis = HF.GetAfflictionStrength(targetCharacter, "acidosis"),
						alkalosis = HF.GetAfflictionStrength(targetCharacter, "alkalosis"),
						sepsis = HF.GetAfflictionStrength(targetCharacter, "sepsis"),
						condition = 100 - damage,
					}

					HF.GiveItemPlusFunction(transplantidentifier, postSpawnFunc, params, usingCharacter)
				end
			end
		end
	end
end
NT.ItemMethods.organscalpel_lungs = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = limb.type

	local removed = HF.GetAfflictionStrength(targetCharacter, "lungremoved", 0)
	if limbtype == LimbType.Torso and HF.HasAfflictionLimb(targetCharacter, "retractedskin", limbtype, 1) then
		if removed <= 0 then
			if HF.GetSurgerySkillRequirementMet(usingCharacter, 50) then
				HF.SetAffliction(targetCharacter, "lungremoved", 100, usingCharacter)
			else
				HF.AddAfflictionLimb(targetCharacter, "bleeding", limbtype, 15, usingCharacter)
				HF.AddAfflictionLimb(targetCharacter, "organdamage", limbtype, 5, usingCharacter)
				HF.AddAffliction(targetCharacter, "lungdamage", 20, usingCharacter)
			end

			HF.GiveItem(targetCharacter, "ntsfx_slash")
		else -- organ extraction
			local damage = HF.GetAfflictionStrength(targetCharacter, "lungdamage", 0)
			if damage == 100 then
				return
			else
				HF.SetAffliction(targetCharacter, "lungdamage", 100, targetCharacter)
				HF.SetAffliction(targetCharacter, "respiratoryarrest", 100, targetCharacter)

				HF.SetAffliction(targetCharacter, "pneumothorax", 0, targetCharacter)
				HF.SetAffliction(targetCharacter, "needlec", 0, targetCharacter)

				HF.AddAffliction(targetCharacter, "organdamage", (100 - damage) / 5, targetCharacter)
				local transplantidentifier = "lungtransplant_q1"
				if NTC.HasTag(usingCharacter, "organssellforfull") then
					transplantidentifier = "lungtransplant"
				end
				if damage < 90 then
					-- add acidosis, alkalosis and sepsis to the bloodpack if the donor has them
					local function postSpawnFunc(args)
						local tags = {}

						if args.acidosis > 0 then
							table.insert(tags, "acid:" .. tostring(HF.Round(args.acidosis)))
						elseif args.alkalosis > 0 then
							table.insert(tags, "alkal:" .. tostring(HF.Round(args.alkalosis)))
						end
						if args.sepsis > 10 then
							table.insert(tags, "sepsis")
						end

						local tagstring = ""
						for index, value in ipairs(tags) do
							tagstring = tagstring .. value
							if index < #tags then
								tagstring = tagstring .. ","
							end
						end

						args.item.Tags = tagstring
						args.item.Condition = args.condition
					end
					local params = {
						acidosis = HF.GetAfflictionStrength(targetCharacter, "acidosis"),
						alkalosis = HF.GetAfflictionStrength(targetCharacter, "alkalosis"),
						sepsis = HF.GetAfflictionStrength(targetCharacter, "sepsis"),
						condition = 100 - damage,
					}

					HF.GiveItemPlusFunction(transplantidentifier, postSpawnFunc, params, usingCharacter)
				end
			end
		end
	end
end
NT.ItemMethods.organscalpel_heart = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = limb.type

	local removed = HF.GetAfflictionStrength(targetCharacter, "heartremoved", 0)
	if limbtype == LimbType.Torso and HF.HasAfflictionLimb(targetCharacter, "retractedskin", limbtype, 1) then
		if removed <= 0 then
			if HF.GetSurgerySkillRequirementMet(usingCharacter, 60) then
				HF.SetAffliction(targetCharacter, "heartremoved", 100, usingCharacter)
			else
				HF.AddAfflictionLimb(targetCharacter, "bleeding", limbtype, 15, usingCharacter)
				HF.AddAfflictionLimb(targetCharacter, "organdamage", limbtype, 5, usingCharacter)
				HF.AddAffliction(targetCharacter, "heartdamage", 20, usingCharacter)
			end

			HF.GiveItem(targetCharacter, "ntsfx_slash")
		else -- organ extraction
			local damage = HF.GetAfflictionStrength(targetCharacter, "heartdamage", 0)
			if damage == 100 then
				return
			else
				HF.SetAffliction(targetCharacter, "heartdamage", 100, targetCharacter)
				HF.SetAffliction(targetCharacter, "cardiacarrest", 100, targetCharacter)

				HF.SetAffliction(targetCharacter, "tamponade", 0, targetCharacter)
				HF.SetAffliction(targetCharacter, "heartattack", 0, targetCharacter)
				HF.AddAffliction(targetCharacter, "organdamage", (100 - damage) / 5, targetCharacter)
				local transplantidentifier = "hearttransplant_q1"
				if NTC.HasTag(usingCharacter, "organssellforfull") then
					transplantidentifier = "hearttransplant"
				end
				if damage < 90 then
					-- add acidosis, alkalosis and sepsis to the bloodpack if the donor has them
					local function postSpawnFunc(args)
						local tags = {}

						if args.acidosis > 0 then
							table.insert(tags, "acid:" .. tostring(HF.Round(args.acidosis)))
						elseif args.alkalosis > 0 then
							table.insert(tags, "alkal:" .. tostring(HF.Round(args.alkalosis)))
						end
						if args.sepsis > 10 then
							table.insert(tags, "sepsis")
						end

						local tagstring = ""
						for index, value in ipairs(tags) do
							tagstring = tagstring .. value
							if index < #tags then
								tagstring = tagstring .. ","
							end
						end

						args.item.Tags = tagstring
						args.item.Condition = args.condition
					end
					local params = {
						acidosis = HF.GetAfflictionStrength(targetCharacter, "acidosis"),
						alkalosis = HF.GetAfflictionStrength(targetCharacter, "alkalosis"),
						sepsis = HF.GetAfflictionStrength(targetCharacter, "sepsis"),
						condition = 100 - damage,
					}

					HF.GiveItemPlusFunction(transplantidentifier, postSpawnFunc, params, usingCharacter)
				end
			end
		end
	end
end
NT.ItemMethods.organscalpel_kidneys = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = limb.type

	local removed = HF.GetAfflictionStrength(targetCharacter, "kidneyremoved", 0)
	if limbtype == LimbType.Torso and HF.HasAfflictionLimb(targetCharacter, "retractedskin", limbtype, 1) then
		if removed <= 0 then
			if HF.GetSurgerySkillRequirementMet(usingCharacter, 30) then
				HF.SetAffliction(targetCharacter, "kidneyremoved", 100, usingCharacter)
			else
				HF.AddAfflictionLimb(targetCharacter, "bleeding", limbtype, 15, usingCharacter)
				HF.AddAfflictionLimb(targetCharacter, "organdamage", limbtype, 5, usingCharacter)
				HF.AddAffliction(targetCharacter, "kidneydamage", 20, usingCharacter)
			end

			HF.GiveItem(targetCharacter, "ntsfx_slash")
		else -- organ extraction, one-by-one
			local damage = HF.GetAfflictionStrength(targetCharacter, "kidneydamage", 0)
			if damage == 100 then
				return
			else
				local transplantidentifier = "kidneytransplant_q1"
				if NTC.HasTag(usingCharacter, "organssellforfull") then
					transplantidentifier = "kidneytransplant"
				end
				if damage < 50 then
					HF.SetAffliction(targetCharacter, "kidneydamage", 50, usingCharacter)
					HF.AddAffliction(targetCharacter, "organdamage", (100 - damage) / 5, usingCharacter)
					-- add acidosis, alkalosis and sepsis to the bloodpack if the donor has them
					local function postSpawnFunc(args)
						local tags = {}

						if args.acidosis > 0 then
							table.insert(tags, "acid:" .. tostring(HF.Round(args.acidosis)))
						elseif args.alkalosis > 0 then
							table.insert(tags, "alkal:" .. tostring(HF.Round(args.alkalosis)))
						end
						if args.sepsis > 10 then
							table.insert(tags, "sepsis")
						end

						local tagstring = ""
						for index, value in ipairs(tags) do
							tagstring = tagstring .. value
							if index < #tags then
								tagstring = tagstring .. ","
							end
						end

						args.item.Tags = tagstring
						args.item.Condition = args.condition
					end
					local params = {
						acidosis = HF.GetAfflictionStrength(targetCharacter, "acidosis"),
						alkalosis = HF.GetAfflictionStrength(targetCharacter, "alkalosis"),
						sepsis = HF.GetAfflictionStrength(targetCharacter, "sepsis"),
						condition = 100,
					}

					HF.GiveItemPlusFunction(transplantidentifier, postSpawnFunc, params, usingCharacter)
					damage = damage + 50
				elseif damage < 95 then
					HF.SetAffliction(targetCharacter, "kidneydamage", 100, usingCharacter)
					HF.AddAffliction(targetCharacter, "organdamage", (100 - damage) / 5, usingCharacter)
					-- add acidosis, alkalosis and sepsis to the bloodpack if the donor has them
					local function postSpawnFunc(args)
						local tags = {}

						if args.acidosis > 0 then
							table.insert(tags, "acid:" .. tostring(HF.Round(args.acidosis)))
						elseif args.alkalosis > 0 then
							table.insert(tags, "alkal:" .. tostring(HF.Round(args.alkalosis)))
						end
						if args.sepsis > 10 then
							table.insert(tags, "sepsis")
						end

						local tagstring = ""
						for index, value in ipairs(tags) do
							tagstring = tagstring .. value
							if index < #tags then
								tagstring = tagstring .. ","
							end
						end

						args.item.Tags = tagstring
						args.item.Condition = args.condition
					end
					local params = {
						acidosis = HF.GetAfflictionStrength(targetCharacter, "acidosis"),
						alkalosis = HF.GetAfflictionStrength(targetCharacter, "alkalosis"),
						sepsis = HF.GetAfflictionStrength(targetCharacter, "sepsis"),
						condition = 100 - (damage - 50) * 2,
					}

					HF.GiveItemPlusFunction(transplantidentifier, postSpawnFunc, params, usingCharacter)
				end
			end
		end
	end
end
NT.ItemMethods.organscalpel_brain = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = limb.type

	local removed = HF.GetAfflictionStrength(targetCharacter, "brainremoved", 0)
	if limbtype == LimbType.Head and HF.HasAfflictionLimb(targetCharacter, "retractedskin", limbtype, 1) then
		if removed <= 0 then
			if HF.GetSurgerySkillRequirementMet(usingCharacter, 100) then
				HF.SetAffliction(targetCharacter, "brainremoved", 100, usingCharacter)
			else
				HF.AddAfflictionLimb(targetCharacter, "bleeding", limbtype, 15, usingCharacter)
				HF.AddAffliction(targetCharacter, "cerebralhypoxia", 50, usingCharacter)
			end

			HF.GiveItem(targetCharacter, "ntsfx_slash")
		else -- organ extraction
			local damage = HF.GetAfflictionStrength(targetCharacter, "cerebralhypoxia", 0)
			if damage == 100 then
				return
			else
				HF.AddAffliction(targetCharacter, "cerebralhypoxia", 100, usingCharacter)

				if NTSP ~= nil then
					if HF.HasAffliction(targetCharacter, "artificialbrain") then
						HF.SetAffliction(targetCharacter, "artificialbrain", 0, usingCharacter)
						damage = 100
					end
				end

				if damage < 90 then
					local postSpawnFunction = function(item, donor, client)
						item.Condition = 100 - damage
						if client ~= nil then
							item.Description = client.Name
						end
					end

					if SERVER then
						-- use server spawn method
						local prefab = ItemPrefab.GetItemPrefab("braintransplant")
						local client = HF.CharacterToClient(targetCharacter)
						Entity.Spawner.AddItemToSpawnQueue(
							prefab,
							usingCharacter.WorldPosition,
							nil,
							nil,
							function(item)
								usingCharacter.Inventory.TryPutItem(item, nil, { InvSlotType.Any })
								postSpawnFunction(item, targetCharacter, client)
							end
						)

						if client ~= nil then
							client.SetClientCharacter(nil)
						end
					else
						-- use client spawn method
						local item = Item(ItemPrefab.GetItemPrefab("braintransplant"), usingCharacter.WorldPosition)
						usingCharacter.Inventory.TryPutItem(item, nil, { InvSlotType.Any })
						postSpawnFunction(item, targetCharacter, nil)
					end
				end
			end
		end
	end
end

NT.ItemMethods.osteosynthesisimplants = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = HF.NormalizeLimbType(limb.type)

	if
		HF.CanPerformSurgeryOn(targetCharacter) and HF.HasAfflictionLimb(targetCharacter, "drilledbones", limbtype, 99)
	then
		if HF.GetSurgerySkillRequirementMet(usingCharacter, 45) then
			-- the other stuff
			local function removeAfflictionPlusGainSkill(affidentifier, skillgain)
				if HF.HasAfflictionLimb(targetCharacter, affidentifier, limbtype) then
					HF.SetAfflictionLimb(targetCharacter, affidentifier, limbtype, 0, usingCharacter)

					if NTSP ~= nil and NTConfig.Get("NTSP_enableSurgerySkill", true) then
						HF.GiveSkillScaled(usingCharacter, "surgery", skillgain)
					else
						HF.GiveSkillScaled(usingCharacter, "medical", skillgain / 4)
					end
				end
			end
			local function removeAfflictionNonLimbSpecificPlusGainSkill(affidentifier, skillgain)
				if HF.HasAffliction(targetCharacter, affidentifier) then
					HF.SetAffliction(targetCharacter, affidentifier, 0, usingCharacter)

					if NTSP ~= nil and NTConfig.Get("NTSP_enableSurgerySkill", true) then
						HF.GiveSkillScaled(usingCharacter, "surgery", skillgain)
					else
						HF.GiveSkillScaled(usingCharacter, "medical", skillgain / 4)
					end
				end
			end

			local implantafflictions = {
				ll_fracture = { xpgain = 10000 },
				rl_fracture = { xpgain = 10000 },
				la_fracture = { xpgain = 10000 },
				ra_fracture = { xpgain = 10000 },
				h_fracture = { xpgain = 10000 },
				n_fracture = { xpgain = 10000 },
				t_fracture = { xpgain = 10000 },
				boneclamp = { xpgain = 0 },
				drilledbones = { xpgain = 0 },
			}

			for key, value in pairs(implantafflictions) do
				local prefab = AfflictionPrefab.Prefabs[key]
				if
					prefab ~= nil
					and (value.case == nil or HF.HasAfflictionLimb(targetCharacter, value.case, limbtype))
				then
					local skillgain = value.xpgain or 0
					if prefab.LimbSpecific then
						removeAfflictionPlusGainSkill(key, skillgain)
					elseif prefab.IndicatorLimb == limbtype then
						removeAfflictionNonLimbSpecificPlusGainSkill(key, skillgain)
					end
				end
			end

			HF.SetAfflictionLimb(targetCharacter, "bonegrowth", limbtype, 100, usingCharacter)
			item.Condition = item.Condition - 25
			if item.Condition <= 0 then
				HF.RemoveItem(item)
			end
		else
			HF.AddAfflictionLimb(targetCharacter, "bleeding", limbtype, 5, usingCharacter)
			HF.AddAfflictionLimb(targetCharacter, "internaldamage", limbtype, 5, usingCharacter)
		end
	end
end
NT.ItemMethods.spinalimplant = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = limb.type

	if
		HF.CanPerformSurgeryOn(targetCharacter)
		and HF.HasAfflictionLimb(targetCharacter, "retractedskin", limbtype, 50)
		and HF.HasAffliction(targetCharacter, "t_paralysis", 0.1)
	then
		if HF.GetSurgerySkillRequirementMet(usingCharacter, 45) then
			HF.SetAffliction(targetCharacter, "t_paralysis", 0, usingCharacter)
			HF.RemoveItem(item)

			if NTSP ~= nil and NTConfig.Get("NTSP_enableSurgerySkill", true) then
				HF.GiveSkillScaled(usingCharacter, "surgery", 12000)
			else
				HF.GiveSkillScaled(usingCharacter, "medical", 6000)
			end
		else
			HF.AddAfflictionLimb(targetCharacter, "bleeding", limbtype, 5, usingCharacter)
			HF.AddAfflictionLimb(targetCharacter, "internaldamage", limbtype, 5, usingCharacter)
		end
	end
end

NT.ItemMethods.endovascballoon = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = limb.type

	-- don't work on stasis
	if HF.HasAffliction(targetCharacter, "stasis", 0.1) then
		return
	end

	if
		limbtype == LimbType.Torso
		and HF.HasAfflictionLimb(targetCharacter, "surgeryincision", limbtype, 1)
		and HF.HasAffliction(targetCharacter, "t_arterialcut", 1)
	then
		HF.AddAffliction(targetCharacter, "balloonedaorta", 100, usingCharacter)
		HF.SetAffliction(targetCharacter, "internalbleeding", 0, usingCharacter)

		if NTSP ~= nil and NTConfig.Get("NTSP_enableSurgerySkill", true) then
			HF.GiveSkillScaled(usingCharacter, "surgery", 10000)
		else
			HF.GiveSkillScaled(usingCharacter, "medical", 5000)
		end

		if HF.Chance(NTC.GetMultiplier(usingCharacter, "balloonconsumechance")) then
			HF.RemoveItem(item)
		end
	end
end
NT.ItemMethods.medstent = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = limb.type

	-- don't work on stasis
	if HF.HasAffliction(targetCharacter, "stasis", 0.1) then
		return
	end

	if limbtype == LimbType.Torso and HF.HasAffliction(targetCharacter, "balloonedaorta", 1) then
		HF.SetAffliction(targetCharacter, "balloonedaorta", 0, usingCharacter)
		HF.SetAffliction(targetCharacter, "t_arterialcut", 0, usingCharacter)

		if NTSP ~= nil and NTConfig.Get("NTSP_enableSurgerySkill", true) then
			HF.GiveSkillScaled(usingCharacter, "surgery", 20000)
		else
			HF.GiveSkillScaled(usingCharacter, "medical", 10000)
		end
	end
end
NT.ItemMethods.drainage = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = limb.type

	-- don't work on stasis
	if HF.HasAffliction(targetCharacter, "stasis", 0.1) then
		return
	end

	if
		limbtype == LimbType.Torso
		and HF.HasAfflictionLimb(targetCharacter, "retractedskin", limbtype)
		and HF.HasAffliction(targetCharacter, "pneumothorax")
	then
		HF.SetAffliction(targetCharacter, "pneumothorax", 0, usingCharacter)
		HF.SetAffliction(targetCharacter, "needlec", 0, usingCharacter)

		if HF.Chance(NTC.GetMultiplier(usingCharacter, "drainageconsumechance")) then
			HF.RemoveItem(item)
		end

		if NTSP ~= nil and NTConfig.Get("NTSP_enableSurgerySkill", true) then
			HF.GiveSkillScaled(usingCharacter, "surgery", 12000)
		else
			HF.GiveSkillScaled(usingCharacter, "medical", 6000)
		end
	end
end
NT.ItemMethods.needle = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = limb.type

	-- don't work on stasis
	if HF.HasAffliction(targetCharacter, "stasis", 0.1) then
		return
	end

	if limbtype == LimbType.Torso and not HF.HasAfflictionLimb(targetCharacter, "retractedskin", limbtype) then
		if HF.GetSkillRequirementMet(usingCharacter, "medical", 20) then
			if
				HF.HasAffliction(targetCharacter, "pneumothorax")
				and not HF.HasAffliction(targetCharacter, "needlec", 0.1)
			then
				HF.GiveSkillScaled(usingCharacter, "medical", 4000)
			end
			HF.SetAffliction(targetCharacter, "needlec", 100, usingCharacter)
			HF.AddAffliction(targetCharacter, "pneumothorax", 1, usingCharacter)

			if HF.Chance(NTC.GetMultiplier(usingCharacter, "needleconsumechance")) then
				HF.RemoveItem(item)
			end
		else
			HF.AddAffliction(targetCharacter, "organdamage", 10, usingCharacter)
			HF.AddAfflictionLimb(targetCharacter, "bleeding", limbtype, 10, usingCharacter)
		end
	end
end

NT.ItemMethods.braintransplant = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = limb.type
	local conditionmodifier = 0
	if not HF.GetSurgerySkillRequirementMet(usingCharacter, 100) then
		conditionmodifier = -40
	end
	local workcondition = HF.Clamp(item.Condition + conditionmodifier, 0, 100)
	if
		HF.HasAffliction(targetCharacter, "brainremoved", 1)
		and limbtype == LimbType.Head
		and HF.HasAfflictionLimb(targetCharacter, "retractedskin", limbtype)
	then
		HF.AddAffliction(targetCharacter, "cerebralhypoxia", -workcondition, usingCharacter)
		HF.SetAffliction(targetCharacter, "brainremoved", 0, usingCharacter)

		-- give character control to the donor
		if SERVER then
			local donorclient = item.Description
			local client = HF.ClientFromName(donorclient)
			if client ~= nil then
				client.SetClientCharacter(targetCharacter)
			end
		end

		HF.RemoveItem(item)
	end
end

local function reattachLimb(item, user, target, limb, itemlimbtype)
	local limbtype = HF.NormalizeLimbType(limb.type)
	if limbtype ~= itemlimbtype then
		return
	end

	if HF.HasAfflictionLimb(target, "bonecut", limbtype, 99) then
		if not NT.LimbIsAmputated(target, limbtype) then
			NT.SurgicallyAmputateLimbAndGenerateItem(user, target, limbtype)
		end
		HF.SetAfflictionLimb(target, "bonecut", limbtype, 0, user)
		NT.SurgicallyAmputateLimb(target, limbtype, 0, 0)
		HF.RemoveItem(item)
	end
end
NT.ItemMethods.rarm = function(item, usingCharacter, targetCharacter, limb)
	reattachLimb(item, usingCharacter, targetCharacter, limb, LimbType.RightArm)
end
NT.ItemMethods.larm = function(item, usingCharacter, targetCharacter, limb)
	reattachLimb(item, usingCharacter, targetCharacter, limb, LimbType.LeftArm)
end
NT.ItemMethods.rleg = function(item, usingCharacter, targetCharacter, limb)
	reattachLimb(item, usingCharacter, targetCharacter, limb, LimbType.RightLeg)
end
NT.ItemMethods.lleg = function(item, usingCharacter, targetCharacter, limb)
	reattachLimb(item, usingCharacter, targetCharacter, limb, LimbType.LeftLeg)
end

-- bionic prosthetics
NT.ItemMethods.rarmp = NT.ItemMethods.rarm
NT.ItemMethods.larmp = NT.ItemMethods.larm
NT.ItemMethods.rlegp = NT.ItemMethods.rleg
NT.ItemMethods.llegp = NT.ItemMethods.lleg

local function InfuseBloodpack(item, packtype, usingCharacter, targetCharacter, limb)
	-- determine compatibility
	local packhasantibodyA = string.find(packtype, "a")
	local packhasantibodyB = string.find(packtype, "b")
	local packhasantibodyC = string.find(packtype, "c") -- NT Cybernetics cyberblood
	local packhasantibodyRh = string.find(packtype, "plus")

	local targettype = NT.GetBloodtype(targetCharacter)

	local targethasantibodyA = string.find(targettype, "a")
	local targethasantibodyB = string.find(targettype, "b")
	local targethasantibodyC = string.find(targettype, "c")
	local targethasantibodyRh = string.find(targettype, "plus")

	local compatible = (targethasantibodyRh or not packhasantibodyRh)
		and (targethasantibodyA or not packhasantibodyA)
		and (targethasantibodyB or not packhasantibodyB)
		and (targethasantibodyC or not packhasantibodyC)
	-- TODO: give always true to team of bots on enemy submarines for future medic AI logic

	local bloodloss = HF.GetAfflictionStrength(targetCharacter, "bloodloss", 0)
	local usefulFraction = HF.Clamp(bloodloss / 30, 0, 1)

	if compatible then
		HF.AddAffliction(targetCharacter, "bloodloss", -30, usingCharacter)
		HF.AddAffliction(targetCharacter, "bloodpressure", 30, usingCharacter)
		HF.GiveSkillScaled(usingCharacter, "medical", 4000 * HF.BoolToNum(bloodloss > 100))
	else
		HF.AddAffliction(targetCharacter, "bloodloss", -20, usingCharacter)
		HF.AddAffliction(targetCharacter, "bloodpressure", 30, usingCharacter)
		HF.GiveSkillScaled(usingCharacter, "medical", 4000 * HF.BoolToNum(bloodloss > 100))
		local immunity = HF.GetAfflictionStrength(targetCharacter, "immunity", 100)
		HF.AddAffliction(targetCharacter, "hemotransfusionshock", math.max(immunity - 6, 0), usingCharacter)
	end

	-- move towards isotonic
	HF.SetAffliction(
		targetCharacter,
		"acidosis",
		HF.GetAfflictionStrength(targetCharacter, "acidosis", 0) * HF.Lerp(1, 0.9, usefulFraction)
	)
	HF.SetAffliction(
		targetCharacter,
		"alkalosis",
		HF.GetAfflictionStrength(targetCharacter, "alkalosis", 0) * HF.Lerp(1, 0.9, usefulFraction)
	)

	-- check if acidosis, alkalosis or sepsis
	local tags = HF.SplitString(item.Tags, ",")
	for tag in tags do
		if tag == "sepsis" then
			HF.AddAffliction(targetCharacter, "sepsis", 1, usingCharacter)
		end

		if HF.StartsWith(tag, "acid") then
			local split = HF.SplitString(tag, ":")
			if split[2] ~= nil then
				HF.AddAffliction(targetCharacter, "acidosis", tonumber(split[2]) / 5 * usefulFraction, usingCharacter)
			end
		elseif HF.StartsWith(tag, "alkal") then
			local split = HF.SplitString(tag, ":")
			if split[2] ~= nil then
				HF.AddAffliction(targetCharacter, "alkalosis", tonumber(split[2]) / 5 * usefulFraction, usingCharacter)
			end
		end
	end

	item.Condition = 0
	--HF.RemoveItem(item)
	HF.GiveItem(usingCharacter, "emptybloodpack")
	HF.GiveItem(targetCharacter, "ntsfx_syringe")
end
NT.ItemMethods.antibloodloss2 = function(item, usingCharacter, targetCharacter, limb)
	if item.Condition <= 0 then
		return
	end

	InfuseBloodpack(item, "ominus", usingCharacter, targetCharacter, limb)
end
--NT.ItemMethods.stasisbag = function(item, usingCharacter, targetCharacter, limb)
--	local condition = item.Condition
--	if condition <= 0 or usingCharacter == targetCharacter then
--		return
--	end
--
--	local targetInventory = targetCharacter.Inventory
--	if targetInventory ~= nil then
--		if targetInventory.TryPutItem(item, 4, false, true, usingCharacter, true, true) then
--			HF.GiveItem(targetCharacter, "ntsfx_zipper")
--		else
--			local userInventory = usingCharacter.Inventory
--			local targetItem = HF.GetOuterWear(targetCharacter)
--			local lhand = HF.GetItemInLeftHand(usingCharacter)
--			local rhand = HF.GetItemInRightHand(usingCharacter)
--			if rhand ~= nil then
--				userInventory.TryPutItem(rhand, nil, { InvSlotType.Any })
--			end
--			if lhand ~= nil then
--				userInventory.TryPutItem(lhand, nil, { InvSlotType.Any })
--			end
--			userInventory.TryPutItem(targetItem, 5, true, true, usingCharacter, true, true)
--			if targetInventory.TryPutItem(item, 4, true, true, usingCharacter, true, true) then
--				HF.GiveItem(targetCharacter, "ntsfx_zipper")
--			end
--		end
--	end
--end
--NT.ItemMethods.emergencysuit = function(item, usingCharacter, targetCharacter, limb)
--	local condition = item.Condition
--	if condition <= 0 or usingCharacter == targetCharacter then
--		return
--	end
--
--	local targetInventory = targetCharacter.Inventory
--	if targetInventory ~= nil then
--		if targetInventory.TryPutItem(item, 4, false, true, usingCharacter, true, true) then
--			HF.GiveItem(targetCharacter, "ntsfx_zipper")
--		else
--			local userInventory = usingCharacter.Inventory
--			local targetItem = HF.GetOuterWear(targetCharacter)
--			local lhand = HF.GetItemInLeftHand(usingCharacter)
--			local rhand = HF.GetItemInRightHand(usingCharacter)
--			if rhand ~= nil then
--				userInventory.TryPutItem(rhand, nil, { InvSlotType.Any })
--			end
--			if lhand ~= nil then
--				userInventory.TryPutItem(lhand, nil, { InvSlotType.Any })
--			end
--			userInventory.TryPutItem(targetItem, 5, true, true, usingCharacter, true, true)
--			if targetInventory.TryPutItem(item, 4, true, true, usingCharacter, true, true) then
--				HF.GiveItem(targetCharacter, "ntsfx_zipper")
--			end
--		end
--	end
--end
NT.ItemMethods.autocpr = function(item, usingCharacter, targetCharacter, limb)
	local condition = item.Condition
	if targetCharacter.InWater then
		return
	end

	local targetInventory = targetCharacter.Inventory
	if targetInventory ~= nil then
		if targetInventory.TryPutItem(item, 4, true, true, usingCharacter, true, true) then
			HF.GiveItem(targetCharacter, "ntsfx_zipper")
		else
			local userInventory = usingCharacter.Inventory
			local targetItem = HF.GetOuterWear(targetCharacter)
			local lhand = HF.GetItemInLeftHand(usingCharacter)
			local rhand = HF.GetItemInRightHand(usingCharacter)
			if rhand ~= nil then
				if not userInventory.TryPutItem(rhand, nil, { InvSlotType.Any }) then
					rhand.Drop(usingCharacter, true)
				end
			end
			if lhand ~= nil then
				if not userInventory.TryPutItem(lhand, nil, { InvSlotType.Any }) then
					lhand.Drop(usingCharacter, true)
				end
			end
			userInventory.TryPutItem(targetItem, 5, true, true, usingCharacter, true, true)
			if targetInventory.TryPutItem(item, 4, true, true, usingCharacter, true, true) then
				HF.GiveItem(targetCharacter, "ntsfx_zipper")
			end
		end
	end
end
NT.ItemMethods.gelipack = function(item, usingCharacter, targetCharacter, limb)
	if item.Condition <= 25 then
		return
	end
	local limbtype = limb.type
	local success = HF.BoolToNum(HF.GetSkillRequirementMet(usingCharacter, "medical", 40), 1)
	HF.AddAfflictionLimb(targetCharacter, "iced", limbtype, 75 + success * 25, usingCharacter)
	HF.GiveItem(targetCharacter, "ntsfx_bandage")

	item.Condition = item.Condition - 35
end

-- startswith region begins

-- transplants

NT.ItemStartsWithMethods.livertransplant = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = limb.type
	local conditionmodifier = 0
	if not HF.GetSurgerySkillRequirementMet(usingCharacter, 40) then
		conditionmodifier = -40
	end
	local damage = HF.GetAfflictionStrength(targetCharacter, "liverdamage", 0)
	local workcondition = HF.Clamp(item.Condition + conditionmodifier, 0, 100)
	if
		HF.HasAffliction(targetCharacter, "liverremoved", 1)
		and limbtype == LimbType.Torso
		and HF.HasAfflictionLimb(targetCharacter, "retractedskin", limbtype, 99)
	then
		if damage == 100 then
			HF.AddAffliction(targetCharacter, "liverdamage", -workcondition, usingCharacter)
			HF.AddAffliction(targetCharacter, "organdamage", -workcondition / 5, usingCharacter)
			HF.SetAffliction(targetCharacter, "liverremoved", 0, usingCharacter)
			HF.RemoveItem(item)
		else -- swap the organs and its generic and specific organ damage, avoiding unintentionally reducing the patients health
			local newdamage = HF.Clamp((100 - damage) - workcondition, -100, 100)
			HF.SetAffliction(targetCharacter, "liverdamage", 100 - workcondition, usingCharacter)
			HF.SetAffliction(targetCharacter, "liverremoved", 0, usingCharacter)
			HF.AddAffliction(targetCharacter, "organdamage", newdamage / 5, usingCharacter)
			local transplantidentifier = "livertransplant_q1"
			if NTC.HasTag(usingCharacter, "organssellforfull") then
				transplantidentifier = "livertransplant"
			end
			if damage < 90 then
				-- add acidosis, alkalosis and sepsis to the bloodpack if the donor has them
				local function postSpawnFunc(args)
					local tags = {}

					if args.acidosis > 0 then
						table.insert(tags, "acid:" .. tostring(HF.Round(args.acidosis)))
					elseif args.alkalosis > 0 then
						table.insert(tags, "alkal:" .. tostring(HF.Round(args.alkalosis)))
					end
					if args.sepsis > 10 then
						table.insert(tags, "sepsis")
					end

					local tagstring = ""
					for index, value in ipairs(tags) do
						tagstring = tagstring .. value
						if index < #tags then
							tagstring = tagstring .. ","
						end
					end

					args.item.Tags = tagstring
					args.item.Condition = args.condition
				end
				local params = {
					acidosis = HF.GetAfflictionStrength(targetCharacter, "acidosis"),
					alkalosis = HF.GetAfflictionStrength(targetCharacter, "alkalosis"),
					sepsis = HF.GetAfflictionStrength(targetCharacter, "sepsis"),
					condition = 100 - damage,
				}
				local inventorySpot = nil
				local parentInventory = item.ParentInventory
				if parentInventory then
					inventorySpot = parentInventory.FindIndex(item)
				end

				HF.SpawnItemPlusFunction(transplantidentifier, postSpawnFunc, params, parentInventory, inventorySpot)
				HF.RemoveItem(item)
			end
		end
		local rejectionchance = HF.Clamp(
			(HF.GetAfflictionStrength(targetCharacter, "immunity", 0) - 10)
				/ 150
				* NTC.GetMultiplier(usingCharacter, "organrejectionchance"),
			0,
			1
		)
		if HF.Chance(rejectionchance) and NTConfig.Get("NT_organRejection", false) then
			HF.SetAffliction(targetCharacter, "liverdamage", 100)
		end
	end
end
NT.ItemStartsWithMethods.hearttransplant = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = limb.type
	local conditionmodifier = 0
	if not HF.GetSurgerySkillRequirementMet(usingCharacter, 40) then
		conditionmodifier = -40
	end
	local damage = HF.GetAfflictionStrength(targetCharacter, "heartdamage", 0)
	local workcondition = HF.Clamp(item.Condition + conditionmodifier, 0, 100)
	if
		HF.HasAffliction(targetCharacter, "heartremoved", 1)
		and limbtype == LimbType.Torso
		and HF.HasAfflictionLimb(targetCharacter, "retractedskin", limbtype, 99)
	then
		if damage == 100 then
			HF.AddAffliction(targetCharacter, "heartdamage", -workcondition, usingCharacter)
			HF.AddAffliction(targetCharacter, "organdamage", -workcondition / 5, usingCharacter)
			HF.SetAffliction(targetCharacter, "heartremoved", 0, usingCharacter)
			HF.RemoveItem(item)
		else -- swap the organs and its generic and specific organ damage, avoiding unintentionally reducing the patients health
			local newdamage = HF.Clamp((100 - damage) - workcondition, -100, 100)
			HF.SetAffliction(targetCharacter, "heartdamage", 100 - workcondition, targetCharacter)
			HF.SetAffliction(targetCharacter, "heartremoved", 0, usingCharacter)
			HF.SetAffliction(targetCharacter, "cardiacarrest", 100, targetCharacter)

			HF.SetAffliction(targetCharacter, "tamponade", 0, targetCharacter)
			HF.SetAffliction(targetCharacter, "heartattack", 0, targetCharacter)
			HF.AddAffliction(targetCharacter, "organdamage", newdamage / 5, targetCharacter)
			local transplantidentifier = "hearttransplant_q1"
			if NTC.HasTag(usingCharacter, "organssellforfull") then
				transplantidentifier = "hearttransplant"
			end
			if damage < 90 then
				-- add acidosis, alkalosis and sepsis to the bloodpack if the donor has them
				local function postSpawnFunc(args)
					local tags = {}

					if args.acidosis > 0 then
						table.insert(tags, "acid:" .. tostring(HF.Round(args.acidosis)))
					elseif args.alkalosis > 0 then
						table.insert(tags, "alkal:" .. tostring(HF.Round(args.alkalosis)))
					end
					if args.sepsis > 10 then
						table.insert(tags, "sepsis")
					end

					local tagstring = ""
					for index, value in ipairs(tags) do
						tagstring = tagstring .. value
						if index < #tags then
							tagstring = tagstring .. ","
						end
					end

					args.item.Tags = tagstring
					args.item.Condition = args.condition
				end
				local params = {
					acidosis = HF.GetAfflictionStrength(targetCharacter, "acidosis"),
					alkalosis = HF.GetAfflictionStrength(targetCharacter, "alkalosis"),
					sepsis = HF.GetAfflictionStrength(targetCharacter, "sepsis"),
					condition = 100 - damage,
				}
				local inventorySpot = nil
				local parentInventory = item.ParentInventory
				if parentInventory then
					inventorySpot = parentInventory.FindIndex(item)
				end

				HF.SpawnItemPlusFunction(transplantidentifier, postSpawnFunc, params, parentInventory, inventorySpot)
				HF.RemoveItem(item)
			end
		end
		local rejectionchance = HF.Clamp(
			(HF.GetAfflictionStrength(targetCharacter, "immunity", 0) - 10)
				/ 150
				* NTC.GetMultiplier(usingCharacter, "organrejectionchance"),
			0,
			1
		)
		if HF.Chance(rejectionchance) and NTConfig.Get("NT_organRejection", false) then
			HF.SetAffliction(targetCharacter, "heartdamage", 100)
		end
	end
end
NT.ItemStartsWithMethods.lungtransplant = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = limb.type
	local conditionmodifier = 0
	if not HF.GetSurgerySkillRequirementMet(usingCharacter, 40) then
		conditionmodifier = -40
	end
	local damage = HF.GetAfflictionStrength(targetCharacter, "lungdamage", 0)
	local workcondition = HF.Clamp(item.Condition + conditionmodifier, 0, 100)
	if
		HF.HasAffliction(targetCharacter, "lungremoved", 1)
		and limbtype == LimbType.Torso
		and HF.HasAfflictionLimb(targetCharacter, "retractedskin", limbtype, 99)
	then
		if damage == 100 then
			HF.AddAffliction(targetCharacter, "lungdamage", -workcondition, usingCharacter)
			HF.AddAffliction(targetCharacter, "organdamage", -workcondition / 5, usingCharacter)
			HF.SetAffliction(targetCharacter, "lungremoved", 0, usingCharacter)
			HF.RemoveItem(item)
		else -- swap the organs and its generic and specific organ damage, avoiding unintentionally reducing the patients health
			local newdamage = HF.Clamp((100 - damage) - workcondition, -100, 100)
			HF.SetAffliction(targetCharacter, "lungdamage", 100 - workcondition, targetCharacter)
			HF.SetAffliction(targetCharacter, "lungremoved", 0, usingCharacter)
			HF.SetAffliction(targetCharacter, "respiratoryarrest", 100, targetCharacter)

			HF.SetAffliction(targetCharacter, "pneumothorax", 0, targetCharacter)
			HF.SetAffliction(targetCharacter, "needlec", 0, targetCharacter)

			HF.AddAffliction(targetCharacter, "organdamage", newdamage / 5, targetCharacter)
			local transplantidentifier = "lungtransplant_q1"
			if NTC.HasTag(usingCharacter, "organssellforfull") then
				transplantidentifier = "lungtransplant"
			end
			if damage < 90 then
				-- add acidosis, alkalosis and sepsis to the bloodpack if the donor has them
				local function postSpawnFunc(args)
					local tags = {}

					if args.acidosis > 0 then
						table.insert(tags, "acid:" .. tostring(HF.Round(args.acidosis)))
					elseif args.alkalosis > 0 then
						table.insert(tags, "alkal:" .. tostring(HF.Round(args.alkalosis)))
					end
					if args.sepsis > 10 then
						table.insert(tags, "sepsis")
					end

					local tagstring = ""
					for index, value in ipairs(tags) do
						tagstring = tagstring .. value
						if index < #tags then
							tagstring = tagstring .. ","
						end
					end

					args.item.Tags = tagstring
					args.item.Condition = args.condition
				end
				local params = {
					acidosis = HF.GetAfflictionStrength(targetCharacter, "acidosis"),
					alkalosis = HF.GetAfflictionStrength(targetCharacter, "alkalosis"),
					sepsis = HF.GetAfflictionStrength(targetCharacter, "sepsis"),
					condition = 100 - damage,
				}
				local inventorySpot = nil
				local parentInventory = item.ParentInventory
				if parentInventory then
					inventorySpot = parentInventory.FindIndex(item)
				end

				HF.SpawnItemPlusFunction(transplantidentifier, postSpawnFunc, params, parentInventory, inventorySpot)
				HF.RemoveItem(item)
			end
		end
		local rejectionchance = HF.Clamp(
			(HF.GetAfflictionStrength(targetCharacter, "immunity", 0) - 10)
				/ 150
				* NTC.GetMultiplier(usingCharacter, "organrejectionchance"),
			0,
			1
		)
		if HF.Chance(rejectionchance) and NTConfig.Get("NT_organRejection", false) then
			HF.SetAffliction(targetCharacter, "lungdamage", 100)
		end
	end
end
NT.ItemStartsWithMethods.kidneytransplant = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = limb.type
	local conditionmodifier = 0
	if not HF.GetSurgerySkillRequirementMet(usingCharacter, 40) then
		conditionmodifier = -40
	end
	local damage = HF.GetAfflictionStrength(targetCharacter, "kidneydamage", 0) -- floating point number really fucks the logic I made here so I just floor it
	local workcondition = HF.Clamp(item.Condition + conditionmodifier, 0, 100)
	if
		HF.HasAffliction(targetCharacter, "kidneyremoved", 1)
		and limbtype == LimbType.Torso
		and HF.HasAfflictionLimb(targetCharacter, "retractedskin", limbtype, 99)
	then
		local rejectionchance = HF.Clamp(
			(HF.GetAfflictionStrength(targetCharacter, "immunity", 0) - 10)
				/ 150
				* NTC.GetMultiplier(usingCharacter, "organrejectionchance"),
			0,
			1
		)
		if HF.Chance(rejectionchance) and NTConfig.Get("NT_organRejection", false) then
			HF.RemoveItem(item)
			return
		end
		if damage > 50 then
			Timer.Wait(function()
				HF.SetAffliction(targetCharacter, "kidneyremoved", 0, usingCharacter)
			end, 3000)
			HF.AddAffliction(targetCharacter, "kidneydamage", -workcondition / 2, usingCharacter)
			HF.AddAffliction(targetCharacter, "organdamage", -workcondition / 5, usingCharacter)
			HF.RemoveItem(item)
		else
			local newdamage = HF.Clamp(((100 - damage) - workcondition) / 2, -100, 100)
			HF.SetAffliction(targetCharacter, "kidneyremoved", 0, usingCharacter)
			HF.SetAffliction(targetCharacter, "kidneydamage", 50 - workcondition / 2, usingCharacter)
			HF.AddAffliction(targetCharacter, "organdamage", newdamage / 5, usingCharacter)
			local transplantidentifier = "kidneytransplant_q1"
			if NTC.HasTag(usingCharacter, "organssellforfull") then
				transplantidentifier = "kidneytransplant"
			end
			HF.RemoveItem(item)
			if damage < 45 then -- swap the organs and its generic and specific organ damage, to avoid unintentionally reducing the patients health
				-- add acidosis, alkalosis and sepsis to the bloodpack if the donor has them
				local function postSpawnFunc(args)
					local tags = {}

					if args.acidosis > 0 then
						table.insert(tags, "acid:" .. tostring(HF.Round(args.acidosis)))
					elseif args.alkalosis > 0 then
						table.insert(tags, "alkal:" .. tostring(HF.Round(args.alkalosis)))
					end
					if args.sepsis > 10 then
						table.insert(tags, "sepsis")
					end

					local tagstring = ""
					for index, value in ipairs(tags) do
						tagstring = tagstring .. value
						if index < #tags then
							tagstring = tagstring .. ","
						end
					end

					args.item.Tags = tagstring
					args.item.Condition = args.condition
				end
				local params = {
					acidosis = HF.GetAfflictionStrength(targetCharacter, "acidosis"),
					alkalosis = HF.GetAfflictionStrength(targetCharacter, "alkalosis"),
					sepsis = HF.GetAfflictionStrength(targetCharacter, "sepsis"),
					condition = 100 - damage * 2,
				}
				local inventorySpot = nil
				local parentInventory = item.ParentInventory
				if parentInventory then
					inventorySpot = parentInventory.FindIndex(item)
				end

				HF.SpawnItemPlusFunction(transplantidentifier, postSpawnFunc, params, parentInventory, inventorySpot)
			end
		end
		--elseif damage < 100 then -- same as above with slight damage adjustments
		--	local newdamage = HF.Clamp(((100 - damage) - workcondition) / 2, -100, 100)
		--	HF.SetAffliction(targetCharacter, "kidneyremoved", 0, usingCharacter)
		--	HF.SetAffliction(targetCharacter, "kidneydamage", 100 - workcondition / 2, usingCharacter)
		--	HF.AddAffliction(targetCharacter, "organdamage", newdamage / 10, usingCharacter) -- (100 - damage) / 5
		--	local transplantidentifier = "kidneytransplant_q1"
		--	if NTC.HasTag(usingCharacter, "organssellforfull") then
		--		transplantidentifier = "kidneytransplant"
		--	end
		--	HF.RemoveItem(item)
		--	if damage < 95 then
		--		-- add acidosis, alkalosis and sepsis to the bloodpack if the donor has them
		--		local function postSpawnFunc(args)
		--			local tags = {}
		--
		--			if args.acidosis > 0 then
		--				table.insert(tags, "acid:" .. tostring(HF.Round(args.acidosis)))
		--			elseif args.alkalosis > 0 then
		--				table.insert(tags, "alkal:" .. tostring(HF.Round(args.alkalosis)))
		--			end
		--			if args.sepsis > 10 then
		--				table.insert(tags, "sepsis")
		--			end
		--
		--			local tagstring = ""
		--			for index, value in ipairs(tags) do
		--				tagstring = tagstring .. value
		--				if index < #tags then
		--					tagstring = tagstring .. ","
		--				end
		--			end
		--
		--			args.item.Tags = tagstring
		--			args.item.Condition = args.condition
		--		end
		--		local params = {
		--			acidosis = HF.GetAfflictionStrength(targetCharacter, "acidosis"),
		--			alkalosis = HF.GetAfflictionStrength(targetCharacter, "alkalosis"),
		--			sepsis = HF.GetAfflictionStrength(targetCharacter, "sepsis"),
		--			condition = 100 - (damage - 50) * 2,
		--		}
		--		local inventorySpot = nil
		--		local parentInventory = item.ParentInventory
		--		if parentInventory then
		--			inventorySpot = parentInventory.FindIndex(item)
		--		end
		--
		--		HF.SpawnItemPlusFunction(transplantidentifier, postSpawnFunc, params, parentInventory, inventorySpot)
		--	end
		--end
	end
end

-- misc

NT.ItemStartsWithMethods.wrench = function(item, usingCharacter, targetCharacter, limb)
	local limbtype = HF.NormalizeLimbType(limb.type)
	if NT.LimbIsDislocated(targetCharacter, limbtype) then
		local skillrequired = 60
		if
			HF.HasAffliction(targetCharacter, "analgesia", 0.5)
			or HF.HasAffliction(targetCharacter, "afadrenaline", 0.5)
		then
			skillrequired = skillrequired - 30
		end

		if HF.GetSkillRequirementMet(usingCharacter, "medical", skillrequired) then
			NT.DislocateLimb(targetCharacter, limbtype, -1000)
			HF.GiveSkillScaled(usingCharacter, "medical", 4000)
		else
			NT.BreakLimb(targetCharacter, limbtype, 1)
		end

		if not HF.HasAffliction(targetCharacter, "analgesia", 0.5) then
			HF.AddAffliction(targetCharacter, "severepain", 5, usingCharacter)
		end
	elseif not HF.HasAffliction(targetCharacter, "sym_unconsciousness", 0.1) then
		local outerWearId = HF.GetOuterWearIdentifier(targetCharacter)
		if outerWearId == "stasisbag" or outerWearId == "bodybag" or outerWearId == "autocpr" then
			local usingInventory = usingCharacter.Inventory
			local equippedOuterItem = HF.GetOuterWear(targetCharacter)
			if usingInventory.TryPutItem(equippedOuterItem, nil, { InvSlotType.Any }) then
				HF.GiveItem(targetCharacter, "ntsfx_velcro")
			end
		end
	end
end
NT.ItemMethods.heavywrench = NT.ItemStartsWithMethods.wrench
NT.ItemMethods.repairpack = NT.ItemStartsWithMethods.wrench

NT.ItemStartsWithMethods.bloodpack = function(item, usingCharacter, targetCharacter, limb)
	if item.Condition <= 0 then
		return
	end

	local identifier = item.Prefab.Identifier.Value
	local packtype = string.sub(identifier, string.len("bloodpack") + 1)
	InfuseBloodpack(item, packtype, usingCharacter, targetCharacter, limb)
end

-- make it so that the person dragging the wearer of a body bag can drag fast
-- fast dragging may start a little late
Hook.Add("bodybag.dragfast", "bodybag.dragfast", function(effect, deltaTime, item, targets, worldPosition)
	local target = nil

	for key in targets do
		target = key
	end

	if target == nil then
		return
	end

	local dragger = target.SelectedBy
	if dragger == nil then
		return
	end
	HF.SetAffliction(dragger, "stretchers", 100)
end)

-- this exists purely for NT metabolism
Hook.Add("NT.RotOrgan", "NT.RotOrgan", function(effect, deltaTime, item, targets, worldPosition)
	if item then
		NT.RotOrgan(item)
	end
end)
function NT.RotOrgan(item)
	HF.RemoveItem(item)
end
NT.FixCondition = {
	"healthscanner",
	"bloodanalyzer",
	"defibrillator",
	"antisepticspray",
	"bvm",
	"autocpr",
}
function NT.RefreshCondition()
	for item in Item.ItemList do
		if HF.TableContains(NT.FixCondition, item.Prefab.Identifier.Value) then
			item.Condition = 100
		end
	end
end
Timer.Wait(function()
	NT.RefreshCondition()
end, 1000)
Hook.Add("roundStart", "NT.RoundStart.ConditionItems", function()
	Timer.Wait(function()
		NT.RefreshCondition()
	end, 10000)
end)
