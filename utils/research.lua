
-- First part of this file describes the dialog to oversee research.
-- Second part contains functions for the dialog to choose the researched unit.
-- The last part contains the informational Research Complete Messages.

-- This function returns for a [message] one [option] entry.
-- In the English language,
-- name_standalone should start with a capital letter,
-- name_embedded should be in lower-case.
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


function anl.offer_agriculture()
    local _ = wesnoth.textdomain 'wesnoth-anl'
    -- po: short version, will be part of a sentence
    local short_variant = _'agriculture'
    _ = wesnoth.textdomain 'wesnoth-ANLEra'
    -- po: standalone text, can be longer, should start with a capital letter
    local long_variant = _ 'Agriculture'
    return anl.research_field(long_variant, short_variant, _'Farmers produce +1 gold', 'farming', 'items/flower4.png')
end


function anl.offer_mining()
    local _ = wesnoth.textdomain 'wesnoth-anl'
    -- po: short version, will be part of a sentence
    local short_variant = _ 'mining'
    _ = wesnoth.textdomain 'wesnoth-ANLEra'
    -- po: standalone text, can be longer, should start with a capital letter
    local long_variant = _ 'Mining'
    return anl.research_field(long_variant, short_variant, _'Miners produce +1 gold', 'mining', 'items/gold-coins-small.png')
end


function anl.offer_philosophy()
    local _ = wesnoth.textdomain 'wesnoth-ANLEra'
    return anl.research_field(_'Philosophy', _'philosophy', _'Scholars improve their research methods', 'philosophy', 'items/book3.png')
end


function anl.offer_warfare()
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


-- Message dialog to oversee research.
function anl.research_menu(undo_forbidden)
    local _ = wesnoth.textdomain 'wesnoth-anl'
    local rc
    local options = { _ 'Continue as before'}

    table.insert(options, anl.offer_agriculture())
    table.insert(options, anl.offer_mining())
    table.insert(options, anl.offer_philosophy())

    -- Checking if there are more units researchable than currently choosable.
    -- Reusing the function anl.determine_faction for this.
    -- Only offer then to research more units.
    local x, researchable, ready
    x, researchable = anl.determine_faction(wml.variables['unit'].type)
    available = wml.variables['player_' .. wesnoth.current.side .. '.warfare.troop_available']
    available = available +1
    if researchable[available] ~= nil then
        table.insert(options, anl.offer_warfare())
    end

    _ = wesnoth.textdomain 'wesnoth-ANLEra'

    -- Show the actual message diaglog.
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

    if rc > 1 then
        anl.update_research_target(options[rc].saveslot, options[rc].language_name, undo_forbidden)
    else
        if not undo_forbidden then
            wesnoth.wml_actions.allow_undo{}
        end
    end
end


local drakish_units = {'Drake Fighter', 'Drake Clasher', 'Drake Burner', 'Drake Glider', 'Saurian Skirmisher', 'Saurian Augur' }
local dwarvish_units = {'Dwarvish Fighter', 'Dwarvish Guardsman', 'Dwarvish Scout', 'Dwarvish Thunderer', 'Dwarvish Ulfserker', 'Gryphon Rider'}
local elvish_units = {'Elvish Archer', 'Elvish Fighter', 'Elvish Scout', 'Wose'}
local human_units = {'Spearman', 'Fencer', 'Heavy Infantryman', 'Sergeant', 'Bowman', 'Horseman', 'Cavalryman'}
local orcish_units = {'Orcish Grunt', 'Orcish Archer', 'Orcish Assassin', 'Troll Whelp', 'Wolf Rider'}
local outlaw_units = {'Thug', 'Thief', 'Footpad', 'Poacher'}
local undead_units = {'Skeleton', 'Skeleton Archer', 'Vampire Bat', 'Ghost', 'Ghoul'}
local special_units = {'Giant Mudcrawler'} -- fixme: it isn't useful


-- This functions returns a table containing an entry for each [message][option]
-- In difference to the function at the begining of the file, it does not keep additional
-- information in this table, but returns a second table to determine later
-- what each [message][option] is supposed to do.
function anl.build_recruit_options(choosable)
    local _ = wesnoth.textdomain 'wesnoth-ANLEra'
    local options

    if choosable[2] ~= nil then
        -- po: Text for the option to cancel. Decide later which unit to choose.
        options = {_ 'Choose later'}
    else
        -- po: Text for the option to cancel. Just one unit is left to be chosen.
        options = {_ 'No, maybe not.'}
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
function anl.type_adv_tree(search_type, current_type, exclude_set)
    if search_type == current_type then
        return true
    end

    -- Tracking the checked unit types to avoid possible endless recursion.
    -- (would need to be a strange unit type which can somehow advance to itself)
    if exclude_set == nil then exclude_set = {} end
    exclude_set[current_type] = true

    for i, v in ipairs(wesnoth.unit_types[current_type].advances_to) do
        if not exclude_set[v] then
            if anl.type_adv_tree(search_type, v, exclude_set) then
                return true
            end
        end
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

    elseif anl.type_adv_tree(mage_type, 'ANLEra Dwarvish Annalist') then
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

    -- Show a different text if only one unit is left.
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

    rc = wesnoth.synchronize_choice( function()
            return { value = wesnoth.show_message_dialog( {
                                 title = _ 'Study Complete',
                                 message = text(),
                                 portrait = wml.variables['unit'].profile,
                                 }, options )} end
        ).value

    if rc > 1 then
        wesnoth.wml_actions.allow_recruit({
            side = wesnoth.current.side,
            type = choosable[rc-1] })

        wml.variables['player_' .. wesnoth.current.side .. '.warfare.troop_available'] = 
        wml.variables['player_' .. wesnoth.current.side .. '.warfare.troop_available'] - 1
        -- fixme: this is only needed for one other place in the code.
        wml.variables['player_' .. wesnoth.current.side .. '.troops'] =
        wml.variables['player_' .. wesnoth.current.side .. '.troops'] + 1

        if (choosable[2] == nil) and (wml.variables['player_' .. wesnoth.current.side .. '.research.current_target'] == 'warfare') then
            _ = wesnoth.textdomain 'wesnoth-ANLEra'
            wesnoth.unsynced( function ()
                wesnoth.show_message_dialog( {
                title = _ 'Study Complete',
                -- fixme: Could reformulate the string: research all units is clear to the player, but is weird from story perspective.
                message = _ 'We researched all units. It would be wise to change the research target now.',
                portrait = wml.variables['unit'].profile,
                }) end
            )
            anl.research_menu(true)
        end
    else
        wesnoth.wml_actions.allow_undo{}
    end
end


-- Research Complete Messages.
-- These are shown at the start of a player's turn.
-- This function is called from an [event] written in WML.
function anl.research_complete()

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
                -- It's +1 more, which for level 1 units is 100% more.
                -- po: shown after accomplishing the research project the first time
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
anl.researchable_units.special_units = special_units

return anl
