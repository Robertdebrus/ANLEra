-- << magic marker. For Lua it's a comment, for the WML preprocessor an opening quotation sign.

--
-- First part of this file describes the dialog to oversee research.
--
-- Second part contains the functions for the dialog to choose the researched unit,
-- and others which are used to determine which units are still be researchable (and if there are some left)
--
-- The last part contains the informational Research Complete Messages,
-- which are displayed a turn start.
--

-- This function returns for a [message] one [option] entry.
-- This is purely a helper function for the ones defined after it.
-- In the English language,
-- name_standalone should start with a capital letter,
-- name_embedded should be in lower-case (it will be part of a sentence).
-- It's also a possibility is to use a long and a short name.
function anl.research_field(name_standalone, name_embedded, description, saveslot, image)
    local _ = wesnoth.textdomain 'wesnoth-ANLEra'

    return { label = "<span color='green'>" .. name_standalone .. "</span>\n" .. 
                 description .."\n" .. 
                 _ "Study Progress: " ..
                 wml.variables['player_' .. wesnoth.current.side .. '.' .. saveslot ..  '.progress']
                 .. '/' ..
                 wml.variables['player_' .. wesnoth.current.side .. '.' .. saveslot .. '.target'],
             image = image,
             -- More values, not for the [message][option], but for us!
             -- With that, we  can later check what the choosen option means.
             saveslot = saveslot,
             language_name = name_embedded }
end


-- Text for farming option:
function anl.offer_agriculture()
    local _ = wesnoth.textdomain 'wesnoth-anl'
    -- po: short version, will be part of a sentence
    local short_variant = _'agriculture'
    _ = wesnoth.textdomain 'wesnoth-ANLEra'
    -- po: standalone text, can be longer, should start with a capital letter
    local long_variant = _ 'Agriculture'
    return anl.research_field(long_variant, short_variant, _'Farmers produce +1 gold', 'farming', 'items/flower4.png')
end


-- Text for mining option.
function anl.offer_mining()
    local _ = wesnoth.textdomain 'wesnoth-anl'
    -- po: short version, will be part of a sentence
    local short_variant = _ 'mining'
    _ = wesnoth.textdomain 'wesnoth-ANLEra'
    -- po: standalone text, can be longer, should start with a capital letter
    local long_variant = _ 'Mining'
    return anl.research_field(long_variant, short_variant, _'Miners produce +1 gold', 'mining', 'items/gold-coins-small.png')
end


-- Experimental option, taken over from Undead Empire add-on.
function anl.offer_philosophy()
    local _ = wesnoth.textdomain 'wesnoth-ANLEra'
    return anl.research_field(_'Philosophy', _'philosophy', _'Scholars improve their research methods', 'philosophy', 'items/book3.png')
end


-- Text for unit research option:
function anl.offer_warfare()
    -- Special case – adding some flavor by naming it differently:
    if wesnoth.sides[wesnoth.current.side].faction == 'ANLEra_Undead' then
        local _ = wesnoth.textdomain 'wesnoth-ANLEra'
        -- po: specific to undead
        return anl.research_field(_'The Art of Necromancy', _'necromancy', _'Allows you to summon a new type of unit', 'warfare', 'wesnoth-icon.png~SCALE(72,72)')
    else
        local _ = wesnoth.textdomain 'wesnoth-anl'
        -- po: short version, will be part of a sentence
        local short_variant = _'warfare'
        _ = wesnoth.textdomain 'wesnoth-ANLEra'
        -- po: standalone text, can be longer, should start with a capital letter
        local long_variant = _ 'Warfare'
        return anl.research_field(long_variant, short_variant, _'Allows you to recruit a new type of unit', 'warfare', 'wesnoth-icon.png~SCALE(72,72)')
    end
end


-- Helper function setting the variables after the dialogue was answered:
function anl.update_research_target(project, name, undo_forbidden)
    if  wml.variables['player_' .. wesnoth.current.side .. '.research.current_target'] ~= project then
        wml.variables['player_' .. wesnoth.current.side .. '.research.current_target']  = project
        wml.variables['player_' .. wesnoth.current.side .. '.research.target_language_name'] = name
    else
        -- Allowing undo if the new research project is the old one.
        -- Except if undoing is not allowed due to other reasons.
        if not undo_forbidden then
            wesnoth.wml_actions.allow_undo{}
        end
    end
end


-- The main message dialog for the overseeing research.
-- This is the one function in this file which is called from the WML [set_menu_item].
-- It's the entry point where everything else is set up, by calling other functions etc.
function anl.research_menu(undo_forbidden)
    local _ = wesnoth.textdomain 'wesnoth-anl'
    local rc

    -- Set up the message dialog:
    local options = {}
    table.insert(options, { label = _ 'Continue as before' } )
    table.insert(options, anl.offer_agriculture() )
    table.insert(options, anl.offer_mining() )
    table.insert(options, anl.offer_philosophy() )

    -- Checking if there are more units researchable than currently choosable.
    -- Reusing the function anl.determine_faction for this.
    -- Only offer then to research more units.
    local unused, researchable, available
    unused, researchable = anl.determine_faction(wml.variables['unit'].type)
    -- Test if there are still units left to be researched, if »troop_available« units are choosen.
    -- »troop_available« = researched-but-not-yet-choosen-units (player didn't use the right-click menu)
    available = wml.variables['player_' .. wesnoth.current.side .. '.warfare.troop_available'] +1
    if researchable[available] ~= nil then
        table.insert(options, anl.offer_warfare())
    end

    _ = wesnoth.textdomain 'wesnoth-ANLEra'

    -- Show the actual message diaglog:
    rc = wesnoth.synchronize_choice( function()
        return { value = wesnoth.show_message_dialog( {
                            title = _ 'Research',
                            -- po: "g" denotes the unit for gold
                            message = wesnoth.format( _ 'We are currently studying $project_name|. To which end would you have our scholars devote their minds?\n\nOur farms produce $farming_level|g\nOur mines produce $mining_level|g\n',
                                {project_name  = wml.variables['player_' .. wesnoth.current.side .. '.research.target_language_name'],
                                 farming_level = wml.variables['player_' .. wesnoth.current.side .. '.farming.gold'],
                                 mining_level  = wml.variables['player_' .. wesnoth.current.side .. '.mining.gold']}),
                            portrait = wml.variables['unit'].profile,
                            }, options) } end
        ).value

    -- Handle the choice from the message dialog:
    if rc > 1 then
        anl.update_research_target(options[rc].saveslot, options[rc].language_name, undo_forbidden)
    else
        if not undo_forbidden then
            wesnoth.wml_actions.allow_undo{}
        end
    end
end


--
-- Part 2: Functions for the choosing a unit.
--
-- How does this work? Several functions are chained together.
-- 1)  anl.choose_new_recruit    is called from WML
-- 2)  anl.determine_faction     is called from there. Based on the researching unit it determines the faction.
-- 3b) anl.type_adv_tree         is used inside that function as helper function.
-- 4)  anl.determine_choosable_recruits returns the complement of the side's recruits and the researchable units.
-- 5)  anl.build_recruit_options builds from that informtion a table which conatins the data for wesnoth.show_message_dialog

--        The name of the functions 2,3,4,5 are reflecting what they do, but not why they are called.
--       (anl.determine_faction is called because we want either to craft a table for the message_dialog,
--        or to know if the list has entries, but we don't care about the faction directly.)
--        but that task is in the end done by on of the functions.
--        Maybe a better solution is to have a dummy function 1b.
--
-- These functions (except number 1) are also used at other places:
--  B) By WML [set_menu_item][show_if]: The right click menu is not shown if all has been researched.
--  C) By above anl.research_menu. Warfare option is not offered if all has been researched.


-- Side note on unimportant design decisions:
-- · The recruits are not dependent on the faction, but the faction of the researching unit.
--   If one in any way gets a researcher from another faction one can research these factions units.
-- · If a unit would be obtainable through both research and negotiation it would cause no problems.

-- List of researchable units.
-- Unlike the old WML way, it is not saved which units have been researched,
-- instead the sides current recruits are compared against these ones:
local drakish_units = {'Drake Fighter', 'Drake Clasher', 'Drake Burner', 'Drake Glider', 'Saurian Skirmisher', 'Saurian Augur' }
local dwarvish_units = {'Dwarvish Fighter', 'Dwarvish Guardsman', 'Dwarvish Scout', 'Dwarvish Thunderer', 'Dwarvish Ulfserker', 'Gryphon Rider'}
local elvish_units = {'Elvish Archer', 'Elvish Fighter', 'Elvish Scout', 'Wose'}
local human_units = {'Spearman', 'Fencer', 'Heavy Infantryman', 'Sergeant', 'Bowman', 'Horseman', 'Cavalryman'}
local orcish_units = {'Orcish Grunt', 'Orcish Archer', 'Orcish Assassin', 'Troll Whelp', 'Wolf Rider'}
-- https://www.reddit.com/r/wesnoth/comments/15799mv/myrline_the_outcasts
local outlaw_units = {'Thug', 'Thief', 'Footpad', 'Poacher', 'Wolf', 'Young Ogre'}
local undead_units
if wesnoth.unit_types['Skeleton Rider'] == nil then
    undead_units = {'Skeleton', 'Skeleton Archer', 'Vampire Bat', 'Ghost', 'Ghoul'}
else
    undead_units = {'Skeleton', 'Skeleton Archer', 'Vampire Bat', 'Ghost', 'Ghoul', 'Skeleton Rider'}
end
local dunefolk_units = {'Dune Burner', 'Dune Soldier', 'Dune Skirmisher', 'Dune Rover', 'Dune Rider'}
local special_units = {'Giant Mudcrawler', 'Great Icemonax'}


-- This functions returns a table containing an entry for each [message][option]
-- In difference to the function at the begining of the file, it does not keep additional
-- information in this table, but returns a second table to determine later
-- what each [message][option] is supposed to do.
-- Fixme: use the same approach with just one table.
function anl.build_recruit_options(choosable)
    local _ = wesnoth.textdomain 'wesnoth-ANLEra'
    local options

    if choosable[2] ~= nil then
        -- po: Text for the option to cancel. Decide later which unit to choose.
        options = { { label = _ 'Choose later.' } }
    else
        -- po: Text for the option to cancel. Just one unit is left to be chosen.
        options = { { label = _ 'No, maybe not.' } }
    end

    for i, v in ipairs(choosable) do
        -- We know the unit type's id, but want to display image and name.
        table.insert(options, {
            label = wesnoth.unit_types[v].name,
            image = wesnoth.unit_types[v].image .. '~TC(' .. wesnoth.current.side .. ', magenta)',
        })
    end

    return options, choosable
end


-- An equivalent to WML's type_adv_tree.
-- Allows to not only compare against a unit,
-- but whether the unit can advance to this unit in any way.
-- WARNING: This is not necessarily Out-of-Sync safe:
-- wesnoth.unit_types[ … … …] might on another client be nil.
-- That by itself does not cause OoS, but take care.
--
function anl.type_adv_tree(search_type, current_type, exclude_set)
    if search_type == current_type then
        return true
    end

    -- Tracking the checked unit types to avoid possible endless recursion.
    -- (would need to be a strange unit type which can somehow advance to itself)
    if exclude_set == nil then exclude_set = {} end
    exclude_set[current_type] = true

    if wesnoth.unit_types[current_type] then
        for i, v in ipairs(wesnoth.unit_types[current_type].advances_to) do
            if not exclude_set[v] then
                if anl.type_adv_tree(search_type, v, exclude_set) then
                    return true
                end
            end
        end
    else
        -- Candidate for OoS: The type might not exist on all machines.
        -- Handling as false in that case, as it's more likely.
        -- (i.e. it's assumed the non-existent type is one which soes not advance to the on-map unit)
        -- Note: There's another unrelated canidate for issues here:
        -- The effects of the WML tag [modify_unit_type] are not seen by wesnoth.unit_types[… … …].
        return false
    end
end


-- The function anl.determine_choosable_recruits
-- is defined in diplomacy.lua (reusing the same function).
-- It removes already recruitable units from the table.


-- To add more factions exist two options:
-- Either overwrite this function or
-- define anl.determine_more_factions.
function anl.determine_faction(mage_type)

    local not_yet_researched_units = {}

    if anl.type_adv_tree(mage_type, 'ANLEra Drake Apprentice') then
        not_yet_researched_units = anl.determine_choosable_recruits(drakish_units)
    elseif anl.type_adv_tree(mage_type, 'Saurian Augur') then
        not_yet_researched_units = anl.determine_choosable_recruits(drakish_units)

    elseif anl.type_adv_tree(mage_type, 'ANLEra Dwarvish Witness') then
        not_yet_researched_units = anl.determine_choosable_recruits(dwarvish_units)

    elseif anl.type_adv_tree(mage_type, 'Elvish Shaman') then
        not_yet_researched_units = anl.determine_choosable_recruits(elvish_units)

    elseif anl.type_adv_tree(mage_type, 'Mage') then
        not_yet_researched_units = anl.determine_choosable_recruits(human_units)

    elseif anl.type_adv_tree(mage_type, 'ANLEra Novice Orcish Shaman') then
        not_yet_researched_units = anl.determine_choosable_recruits(orcish_units)

    elseif anl.type_adv_tree(mage_type, 'ANLEra Rogue Mage') then
        not_yet_researched_units = anl.determine_choosable_recruits(outlaw_units)

    elseif anl.type_adv_tree(mage_type, 'Dark Adept') then
        not_yet_researched_units = anl.determine_choosable_recruits(undead_units)

    elseif anl.type_adv_tree(mage_type, 'Dune Herbalist') then
        not_yet_researched_units = anl.determine_choosable_recruits(dunefolk_units)

    elseif anl.type_adv_tree(mage_type, 'Mermaid Initiate') then
        not_yet_researched_units = anl.determine_choosable_recruits(special_units)
    else

        -- Extension point:
        -- If this function is added by another add-on,
        -- then more factions can be supported.
        if anl.determine_more_factions ~= nil then
            not_yet_researched_units = anl.determine_more_factions(mage_type)
        else
            local _ = wesnoth.textdomain 'wesnoth-ANLEra'
            wesnoth.message( 'ANL', _'Researching is not fully supported for this unit.')
            wesnoth.message( 'ANL', _'This is likely a bug. Researcher’s type is ' .. (mage_type or _'NOT GIVEN'))
            -- It's a bug because this menu shouldn't be offered then,
            -- so this unit was enabled for the menu but not here.
            return
        end
    end

    -- Note: this function has two return values.
    return anl.build_recruit_options(not_yet_researched_units)
end


-- Message dialog to choose the researched unit.
function anl.choose_new_recruit()

    local rc
    local options
    local choosable

    options, choosable = anl.determine_faction(wml.variables['unit'].type)

    if choosable == nil then
        -- An error message was just shown.
        wesnoth.wml_actions.allow_undo{}
        return
    end

    if choosable[1] == nil then
        local _ = wesnoth.textdomain 'wesnoth-ANLEra'
        wesnoth.message('ANL', _'No units left to be researched. It’s a bug that this option was offered to you.')
        wesnoth.wml_actions.allow_undo{}
        return
    end

    local _ = wesnoth.textdomain 'wesnoth-anl'

    -- For flavor: show a different text if only one unit is left.
    local function text()
        if choosable[2] == nil then
            local _ = wesnoth.textdomain 'wesnoth-ANLEra'
            -- po: Only one unit to choose from. Similar string in textdomain wesnoth-anl.
            return _ 'Would you like to be able to recruit this unit?'
        else
            local _ = wesnoth.textdomain 'wesnoth-anl'
            return _ 'Which type of unit would you like to be able to recruit?'
        end
    end

    -- Show the dialog:
    rc = wesnoth.synchronize_choice( function()
            return { value = wesnoth.show_message_dialog( {
                                 title = _ 'Study Complete',
                                 message = text(),
                                 portrait = wml.variables['unit'].profile,
                                 }, options )} end
        ).value

    -- Handle the result:
    if rc > 1 then
        wesnoth.wml_actions.allow_recruit({
            side = wesnoth.current.side,
            type = choosable[rc-1] })

        wml.variables['player_' .. wesnoth.current.side .. '.warfare.troop_available'] =
        wml.variables['player_' .. wesnoth.current.side .. '.warfare.troop_available'] - 1
        -- Fixme: this is old ugly code and only needed for one other place in the code.
        -- Namely it's checked with the give_tech diplomacy option,
        -- trying to not offer the options for factions which might not anymore be able
        -- to research units. It's checking this value.
        wml.variables['player_' .. wesnoth.current.side .. '.troops'] =
        wml.variables['player_' .. wesnoth.current.side .. '.troops'] + 1

        -- If there's was only unit left to be researched (which has just been researched now),
        -- then it makes most  likely no more sense to continue researching new units.
        -- An exception would be if the faction has other researchers who can still research units belonging to other factions.
        if (choosable[2] == nil) and (wml.variables['player_' .. wesnoth.current.side .. '.research.current_target'] == 'warfare') then
            _ = wesnoth.textdomain 'wesnoth-ANLEra'
            wesnoth.unsynced( function ()
                wesnoth.show_message_dialog( {
                -- Fixme: current title is not giving any meaningful information.
                title = _ 'Study Complete',
                -- Fixme: Could reformulate the string: researched all units is clear to the player, but is weird from story perspective.
                message = _ 'We researched all units. It would be wise to change the research target now.',
                portrait = wml.variables['unit'].profile,
                }) end
            )
            -- Prompt the player to choose a new research target. Disallow undoing.
            anl.research_menu(true)
        end
    else
        -- Option 1 is always the option to abort:
        wesnoth.wml_actions.allow_undo{}
    end
end


--
-- Part 3: Messages at turn start.
--


-- Research Complete Messages.
-- These are shown at the start of a player's turn.
-- This function is called from an [event] written in WML.
function anl.research_complete()

    -- Safety check: If the WML variable does not exist, skip this all.
    if wml.variables['player_' .. wesnoth.current.side] == nil then
        return
    end

    local _ = wesnoth.textdomain 'wesnoth-ANLEra'
    local side = wesnoth.sides[wesnoth.current.side]
    local increased = false


    -- farming resarch
    while wml.variables['player_' .. side.side .. '.farming.progress'] >=
          wml.variables['player_' .. side.side .. '.farming.target']
    do
        wml.variables['player_' .. side.side .. '.farming.gold'] =
        wml.variables['player_' .. side.side .. '.farming.gold'] +1
        wml.variables['player_' .. side.side .. '.farming.progress'] =
        wml.variables['player_' .. side.side .. '.farming.progress'] -
        wml.variables['player_' .. side.side .. '.farming.target']
        wml.variables['player_' .. side.side .. '.farming.target'] =
        wml.variables['player_' .. side.side .. '.farming.target'] +1
        increased = true
    end

    if increased then
        wesnoth.wml_actions.message{
            speaker = 'narrator',
            caption = _ 'Study Complete',
            image = 'items/flower4.png',
            message = wesnoth.format(_ '$side_name|’s farms produce now $amount gold.',
                                    { side_name = side.side_name,
                                      side_no = side.side,
                                      amount = wml.variables['player_' .. side.side .. '.farming.gold'] })
        }
        increased = false
    end


    -- mining resarch
    while wml.variables['player_' .. side.side .. '.mining.progress'] >=
          wml.variables['player_' .. side.side .. '.mining.target']
    do
        wml.variables['player_' .. side.side .. '.mining.gold'] =
        wml.variables['player_' .. side.side .. '.mining.gold'] +1
        wml.variables['player_' .. side.side .. '.mining.progress'] =
        wml.variables['player_' .. side.side .. '.mining.progress'] -
        wml.variables['player_' .. side.side .. '.mining.target']
        wml.variables['player_' .. side.side .. '.mining.target'] =
        wml.variables['player_' .. side.side .. '.mining.target'] +1
        increased = true
    end

    if increased then
        wesnoth.wml_actions.message{
            speaker = 'narrator',
            caption = _ 'Study Complete',
            image = 'items/gold-coins-small.png',
            message = wesnoth.format(_ '$side_name|’s mines produce now $amount gold.',
                                    { side_name = side.side_name,
                                      side_no = side.side,
                                      amount = wml.variables['player_' .. side.side .. '.mining.gold'] })
        }
        increased = false
    end


    -- warfare research
    while wml.variables['player_' .. side.side .. '.warfare.progress'] >=
          wml.variables['player_' .. side.side .. '.warfare.target']
    do
        wml.variables['player_' .. side.side .. '.warfare.troop_available'] =
        wml.variables['player_' .. side.side .. '.warfare.troop_available'] +1
        wml.variables['player_' .. side.side .. '.warfare.progress'] =
        wml.variables['player_' .. side.side .. '.warfare.progress'] -
        wml.variables['player_' .. side.side .. '.warfare.target']
        wml.variables['player_' .. side.side .. '.warfare.target'] =
        wml.variables['player_' .. side.side .. '.warfare.target'] +1
        increased = true
    end

    if increased then
        if wml.variables['player_' .. side.side .. '.warfare.troop_available'] == 1 then
            wesnoth.wml_actions.message{
                speaker = 'narrator',
                caption = _ 'Study Complete',
                image = 'wesnoth-icon.png',
                -- po: one new unit available
                message = wesnoth.format(_ '$side_name|, we have finished researching warfare. Right-click on a researcher in a university to select a unit to recruit.',
                                        { side_name = side.side_name,
                                          side_no = side.side })
            }
        else
            wesnoth.wml_actions.message{
                speaker = 'narrator',
                caption = _ 'Study Complete',
                image = 'wesnoth-icon.png',
                -- po: multiple new units available
                message = wesnoth.format(_ '$side_name|, we have finished researching warfare. Right-click on a researcher in a university to select new units to recruit.',
                                        { side_name = side.side_name,
                                          side_no = side.side })
            }
        end
        increased = false
    end


    -- philisophy research
    while wml.variables['player_' .. side.side .. '.philosophy.progress'] >=
          wml.variables['player_' .. side.side .. '.philosophy.target']
    do
        wml.variables['player_' .. side.side .. '.philosophy.bonus'] =
        wml.variables['player_' .. side.side .. '.philosophy.bonus'] +1
        wml.variables['player_' .. side.side .. '.philosophy.progress'] =
        wml.variables['player_' .. side.side .. '.philosophy.progress'] -
        wml.variables['player_' .. side.side .. '.philosophy.target']
        wml.variables['player_' .. side.side .. '.philosophy.target'] =
        wml.variables['player_' .. side.side .. '.philosophy.target'] *2 +1
        increased = true
    end

    if increased then
        -- For flavor, change the message image for undead.
        local function book(faction)
            if faction == 'ANLEra_Undead' then
                return 'items/book5.png'
            else
                return 'items/book3.png'
            end
        end

        -- It's a bit hard to explain research points, as that does not exist in the real world.
        -- Having a 2nd message leaves more room.
        -- Anybody working on a PhD and having a better explanation?

        if wml.variables['player_' .. side.side .. '.philosophy.bonus'] == 1 then
            wesnoth.wml_actions.message{
                speaker = 'narrator',
                caption = _ 'Study Complete',
                image = book(side.faction),
                -- It's +1 more, which for level 1 units is 100% more. Ignoring that for L2 it's not 100%.
                -- po: shown after accomplishing the philisophy research project the first time
                message = wesnoth.format(_ 'By coordinating research efforts and creating dedicated teams $side_name|’s scholars managed to double their research results.',
                                        { side_name = side.side_name,
                                          side_no = side.side,
                                          amount = wml.variables['player_' .. side.side .. '.philosophy.bonus'] })
            }
        else
            wesnoth.wml_actions.message{
                speaker = 'narrator',
                caption = _ 'Study Complete',
                image = book(side.faction),
                -- po: shown the 2nd and later times after completing philisophy research
                message = wesnoth.format(_ 'The scienific progress of $side_name|’s scholars is by now at $amount|00%.',
                                        { side_name = side.side_name,
                                          side_no = side.side,
                                          amount = wml.variables['player_' .. side.side .. '.philosophy.bonus'] +1 })
            }
        end
        increased = false
    end
end


-- Making them available in case another add-on wants to use them.
anl.researchable_units = {}
anl.researchable_units.drakish_units = drakish_units
anl.researchable_units.dwarvish_units = dwarvish_units
anl.researchable_units.elvish_units = elvish_units
anl.researchable_units.human_units = human_units
anl.researchable_units.orcish_units = orcish_units
anl.researchable_units.outlaw_units = outlaw_units
anl.researchable_units.undead_units = undead_units
anl.researchable_units.dunefolk_units = dunefolk_units
anl.researchable_units.special_units = special_units

return anl

-- Magic marker. For Lua it's a comment, for the WML preprocessor a closing quotation sign. >>
