if Game.IsMultiplayer and CLIENT then return end

local identifiers = {
   'periscope',
   'coilgun',
   'railgun',
   'doublecoilgun',
   'pulselaser',
   'flakcannon',
   'pulselaserloader',
   'chaingunloader',
   'coilgunloader',
   'flakcannonloader',
   'battery',
   'deconstructor',
   'engine',
   'fabricator',
   'junctionbox',
   'junctionbox_tutorial',
   'largeengine',
   'medicalfabricator',
   'oxygenerator',
   'pump',
   'smallpump',
   'reactor',
   'reactor1',
   'supercapacitor',
   'shuttlebattery',
   'shuttleengine',
   'shuttlenavterminal',
   'shuttleoxygenerator',
   'sonarmonitor',
   'statusmonitor',
   'reactor1wrecked',
   'railgunwrecked',
   'periscopewrecked',
   'railgunloaderwrecked',
   'railgunloadersingleverticalwrecked',
   'railgunloadersinglehorizontalwrecked',
   'coilgunwrecked',
   'coilgunloaderwrecked',
   'oxygeneratorwrecked',
   'shuttleoxygeneratorwrecked',
   'ventwrecked',
   'ladderwrecked',
   'fabricatorwrecked',
   'medicalfabricatorwrecked',
   'deconstructorwrecked',
   'enginewrecked',
   'largeenginewrecked',
   'shuttleenginewrecked',
   'doorwrecked',
   'windoweddoorwrecked',
   'hatchwrecked',
   'doorwbuttonswrecked',
   'windoweddoorwbuttonswrecked',
   'hatchwbuttonswrecked',
   'dockingportwrecked',
   'dockinghatchwrecked',
   'suppliescabinetwrecked',
   'mediumsteelcabinetwrecked',
   'mediumwindowedsteelcabinetwrecked',
   'steelcabinetwrecked',
   'securesteelcabinetwrecked',
   'railgunshellrackwrecked',
   'coilgunammoshelfwrecked',
   'medcabinetwrecked',
   'toxcabinetwrecked',
   'divingsuitlockerwrecked',
   'oxygentankshelf2wrecked',
   'extinguisherbracketwrecked',
   'weaponholderwrecked',
   'navterminalwrecked',
   'shuttlenavterminalwrecked',
   'statusmonitorwrecked',
   'sonartransducerwrecked',
   'junctionboxwrecked',
   'batterywrecked',
   'shuttlebatterywrecked',
   'supercapacitorwrecked',
   'chargingdockwrecked',
   'lightfluorescentm01wrecked',
   'lightfluorescentm02wrecked',
   'lightfluorescentm03wrecked',
   'lightfluorescentm04wrecked',
   'lightfluorescentl01wrecked',
   'lightfluorescentl02wrecked',
   'lighthalogenmm01wrecked',
   'lighthalogenmm02wrecked',
   'lighthalogenmm03wrecked',
   'lighthalogenm04wrecked',
   'lightleds01wrecked',
   'bunkwrecked',
   'pulselaserloaderwrecked',
   'chaingunloaderwrecked',
   'flakcannonloaderwrecked',
   'pulselaserwrecked',
   'chaingunwrecked',
   'flakcannonwrecked',
   'doublecoilgunwrecked',
}

Hook.Add('roundStart', 'makeInteractable', function()
   local items = {}
   for id in identifiers do
      local t = Util.GetItemsById(id)
      if t then
         for item in Util.GetItemsById(id) do
            if item.Submarine and item.Submarine.Info.IsWreck then
               table.insert(items, item)
            end
         end
      end
   end

   for item in items do
      if item.NonInteractable then
         item.NonInteractable = false
         if SERVER then
            Networking.CreateEntityEvent(item, Item.ChangePropertyEventData(item.SerializableProperties[Identifier('NonInteractable')], item))
         end
      end
   end
end)