-- <<

local _ = wesnoth.textdomain 'wesnoth-ANLEra'

-- This is a standalone extension for ANLEra.
-- About every 2 turns, AI sides will receive new recruits.

-- The main purpose of this file is to show ONE SINGLE message,
-- which covers the new recruits of all AI sides.
-- It will also unlock said recruits and add a bit of gold.

-- This single function and (sub-functions) contains all the logic.
-- It is called from a WML event, and the new recruits are given as first argument.
function anl.extra_units(recruits, gold)
    gold = gold or 15

    -- The Lua map »recruits« (= is a 2-column table)
    -- has one entry for each faction,
    -- in which the new recruits (one or multiple) are listed.
    -- See the end of the file to see how it looks.

    -- Function to proof-checks if the new recruits are really new.
    -- Sometimes a unit is already recruitable.
    local function recruits_are_new(side)
        for i, new_one in ipairs(recruits[side.faction]) do
            local is_new = true
            for i, exisiting_one in ipairs(side.recruit) do
                if new_one == exisiting_one then
                    is_new = false
                    break
                end
            end
            if is_new then 
                return true
            end
        end
        return false
    end


    -- Returns a translated string with the new recruits of a faction.
    local function new_recruits(faction)
        local translated_names = {}
        for i, unit in ipairs(recruits[faction]) do
            table.insert(translated_names, wesnoth.unit_types[unit].name)
        end
        return wesnoth.format_conjunct_list('', translated_names)
    end


    -- Not using the faction name provided by the game, because
    -- a) It is often (but not always) in plural, might gramatically not be correct.
    -- b) It would be translated, in difference to the rest of the string.
    -- So, custom strings for each faction.
    -- $new_recruits however will be a translated string.
    local function faction_message(faction, plural)
        if faction == 'ANLEra_Drakes' and plural then
            return _ 'many^Drakes from sides $sides can now recruit: $new_recruits'
        elseif faction == 'ANLEra_Drakes' then
            return _ 'one^Drakes from side $sides can now recruit: $new_recruits'

        elseif faction == 'ANLEra_Dwarves' and plural then
            return _ 'many^Dwarves from sides $sides can now recruit: $new_recruits'
        elseif faction == 'ANLEra_Dwarves' then
            return _ 'one^Dwarves from side $sides can now recruit: $new_recruits'

        elseif faction == 'ANLEra_Elves' and plural then
            return _ 'many^Elves from sides $sides can now recruit: $new_recruits'
        elseif faction == 'ANLEra_Elves' then
            return _ 'one^Elves from side $sides can now recruit: $new_recruits'

        elseif faction == 'ANLEra_Humans' and plural then
            return _ 'many^Humans from sides $sides can now recruit: $new_recruits'
        elseif faction == 'ANLEra_Humans' then
            return _ 'one^Humans from side $sides can now recruit: $new_recruits'

        elseif faction == 'ANLEra_Orcs' and plural then
            return _ 'many^Orcs from sides $sides can now recruit: $new_recruits'
        elseif faction == 'ANLEra_Orcs' then
            return _ 'one^Orcs from side $sides can now recruit: $new_recruits'

        elseif faction == 'ANLEra_Outlaws' and plural then
            return _ 'many^Outlaws from sides $sides can now recruit: $new_recruits'
        elseif faction == 'ANLEra_Outlaws' then
            return _ 'one^Outlaws from side $sides can now recruit: $new_recruits'

        elseif faction == 'ANLEra_Undead' and plural then
            return _ 'many^Undead from sides $sides can now recruit: $new_recruits'
        elseif faction == 'ANLEra_Undead' then
            return _ 'one^Undead from side $sides can now recruit: $new_recruits'

        elseif faction == 'ANLEra_Dunefolk' and plural then
            return _ 'many^The Dunefolk from sides $sides can now recruit: $new_recruits'
        elseif faction == 'ANLEra_Dunefolk' then
            return _ 'one^The Dunefolk from side $sides can now recruit: $new_recruits'

        else
            -- Extension point:
            -- If this function is added by another add-on,
            -- then strings for more factions can be added.
            if anl.more_faction_messages ~= nil then
                return anl.more_faction_messages(faction, plural)
            end

            -- Dummy fallback.
            if plural then
                return _ 'many^Sides $sides can now recruit: $new_recruits'
            else
                return _ 'one^Side $sides can now recruit: $new_recruits'
            end
        end
    end

    -- End of helper funtion definitions. From here on is code.

    -- Adding the new recruits for all AI-sides which are still alive.
    local got_units = {}
    local alive_sides = wesnoth.get_sides({ {'has_unit', { canrecruit = true }} })

    for i, side in ipairs(alive_sides) do
        -- side.controller may have a different value on other clients, let all clients use the value from one client.
        local is_ai = wesnoth.synchronize_choice(
                          function()
                              if side.controller == 'ai' then
                                  return { value = true}
                              else
                                  return { value = false}
                              end
                          end
                      ).value

        if is_ai and not(side.lost) and recruits[side.faction] ~= nil then

            -- Bonus check: are the new recruits really new?
            -- Checking this only for the message, gold is given anyways.
            if recruits_are_new(side) then
                -- Keep track of factions and their sides for the message.
                if  got_units[side.faction] == nil then
                    got_units[side.faction] = {}
                end
                table.insert(got_units[side.faction], side.side)

                -- Set this, in case control is switched between human and ai side later.
                -- Not needed though.
                if  wml.variables['player_' .. side.side] ~= nil then
                    wml.variables['player_' .. side.side .. '.troops'] =
                    wml.variables['player_' .. side.side .. '.troops'] + 1
                end
            end

            -- Add new recruits. Might be more than one.
            for i,unit in ipairs(recruits[side.faction]) do
                wesnoth.wml_actions.allow_recruit{
                    side=side.side,
                    type=unit
                }
            end

            -- And some gold.
            wesnoth.wml_actions.gold{
                side=side.side,
                amount=gold
            }
        end
    end


    -- Creating the message.
    -- One line for each faction, which mentions the faction, side number(s) and recruit(s).
    local message = ''

    -- Using the Lua function pairs is not OOS safe, but that's okay, worst thing to happen
    -- is, that the lines in the message are sorted differently on clients.
    for faction, s in pairs(got_units) do
        if message ~= '' then
            message = message .. '\n'
        end

        local more_than_one = s[2] ~= nil
        message = message .. wesnoth.format(faction_message(faction, more_than_one),
                                            { sides = s,
                                              new_recruits = new_recruits(faction)}
                                           )
    end

    if message ~= '' then
        wesnoth.show_message_dialog( {
            title = _ 'New recruits for AI-controlled sides:',
            portrait = 'wesnoth-icon.png',
            message = message
        })
    end
end


local turn7={}
local turn9={}
local turn11={}
local turn13={}
local turn15={}
local turn17={}
local turn21={}
local turn23={}

turn7['ANLEra_Drakes']={'Drake Glider'}
turn9['ANLEra_Drakes']={'Drake Fighter'}
turn11['ANLEra_Drakes']={'Drake Burner'}
turn13['ANLEra_Drakes']={'Drake Clasher'}
turn15['ANLEra_Drakes']={'Drake Flare'}
turn17['ANLEra_Drakes']={'Fire Drake', 'Drake Arbiter', 'Drake Warrior'}
turn21['ANLEra_Drakes']={'ANLEra Drake Shaman'}
turn23['ANLEra_Drakes']={'Drake Thrasher'}

turn7['ANLEra_Dwarves']={'Dwarvish Scout'}
turn9['ANLEra_Dwarves']={'Dwarvish Fighter'}
turn11['ANLEra_Dwarves']={'Dwarvish Thunderer'}
turn13['ANLEra_Dwarves']={'Dwarvish Guardsman'}
turn15['ANLEra_Dwarves']={'Dwarvish Ulfserker'}
turn17['ANLEra_Dwarves']={'Dwarvish Steelclad','Dwarvish Thunderguard'}
turn21['ANLEra_Dwarves']={'Dwarvish Pathfinder'}
turn23['ANLEra_Dwarves']={'Dwarvish Stalwart'}

turn7['ANLEra_Elves']={'Elvish Scout'}
turn9['ANLEra_Elves']={'Elvish Fighter'}
turn11['ANLEra_Elves']={'Elvish Archer'}
turn13['ANLEra_Elves']={'Wose'}
turn15['ANLEra_Elves']={'Elvish Shaman'} -- default recruit
turn17['ANLEra_Elves']={'Elvish Captain', 'Elvish Marksman', 'Elder Wose'}
turn21['ANLEra_Elves']={'Elvish Druid'}
turn23['ANLEra_Elves']={'Elvish Hero'}

turn7['ANLEra_Humans']={'Sergeant'}
turn9['ANLEra_Humans']={'Spearman'}
turn11['ANLEra_Humans']={'Bowman'}
turn13['ANLEra_Humans']={'Heavy Infantryman'}
turn15['ANLEra_Humans']={'Fencer'}
turn17['ANLEra_Humans']={'Swordsman', 'Pikeman', 'Longbowman'}
turn21['ANLEra_Humans']={'Shock Trooper'}
turn23['ANLEra_Humans']={'Duelist'}

turn7['ANLEra_Orcs']={'Goblin Rouser'}
turn9['ANLEra_Orcs']={'Orcish Grunt'}
turn11['ANLEra_Orcs']={'Orcish Archer'}
turn13['ANLEra_Orcs']={'Troll Whelp'}
turn15['ANLEra_Orcs']={'Orcish Assassin'}
turn17['ANLEra_Orcs']={'Troll', 'Orcish Crossbowman', 'Orcish Warrior'}
turn21['ANLEra_Orcs']={'Orcish Slayer'}
turn23['ANLEra_Orcs']={'Goblin Knight'}

turn7['ANLEra_Outlaws']={'Footpad'}
turn9['ANLEra_Outlaws']={'Thug'}
turn11['ANLEra_Outlaws']={'Poacher'}
turn13['ANLEra_Outlaws']={'Thief'}
turn15['ANLEra_Outlaws']={'Outlaw'}
turn17['ANLEra_Outlaws']={'Bandit', 'Trapper'}
turn21['ANLEra_Outlaws']={'Rogue'}
turn23['ANLEra_Outlaws']={'ANLEra Shadow Mage'}

turn7['ANLEra_Undead']={'Soulless'}
turn9['ANLEra_Undead']={'Skeleton'}
turn11['ANLEra_Undead']={'Skeleton Archer'}
turn13['ANLEra_Undead']={'Ghoul'}
turn15['ANLEra_Undead']={'Dark Adept'} -- default recruit
turn17['ANLEra_Undead']={'Necrophage', 'Bone Shooter', 'Revenant'}
turn21['ANLEra_Undead']={'Dark Sorcerer'}
turn23['ANLEra_Undead']={'Deathblade'}

-- commented out units are not available in wesnoth 1.14
turn7['ANLEra_Dunefolk']={'Dune Rider'}
turn9['ANLEra_Dunefolk']={'Dune Soldier'}
turn11['ANLEra_Dunefolk']={'Dune Rover'}
turn13['ANLEra_Dunefolk']={'Dune Burner'}
turn15['ANLEra_Dunefolk']={'Dune Skirmisher'}
turn17['ANLEra_Dunefolk']={'Dune Spearguard', 'Dune Swordsman', 'Dune Explorer'} --'Dune Captain'
turn21['ANLEra_Dunefolk']={'Dune Scorcher'} -- 'Dune Alchemist', 'Dune Strider'
turn23['ANLEra_Dunefolk']={'Dune Raider', 'Dune Sunderer'} -- 'Dune Horse Archer'

-- Making them available:
anl.ai_units = {}
anl.ai_units.turn7=turn7
anl.ai_units.turn9=turn9
anl.ai_units.turn11=turn11
anl.ai_units.turn13=turn13
anl.ai_units.turn15=turn15
anl.ai_units.turn17=turn17
anl.ai_units.turn21=turn21
anl.ai_units.turn23=turn23

return anl

-- >>
