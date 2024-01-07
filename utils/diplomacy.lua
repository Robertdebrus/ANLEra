-- << magic marker. For Lua it's a comment, for the WML preprocessor an opening quotation sign.

--[[
This file contains:
* the diplomacy menu and submenus
* code to determine who/what is listed in the submenus
* code to determine offered negotiation options
* code to choose a new recruit

Structure of the menu:
 -> (1) Aborting  [always displayed]
 -> (2) Send Gold [always displayed] -> Submenu
 -> (3) Send Tech [always displayed] -> Submenu
 -> (…) Varying number of negotiation options [not all displayed]
    (…) Dwarves
    (…) Elves
    (…) Drakes
    (…) Undead
    (…) Humans
    (…) -- removed --
    (…) Meervolk
    (…) Heroes (Lvl2)


Functions in this file:

* Not related to negotation:
anl.get_allies()                          -> Helper function for submenus
anl.post_diplomacy()                      -> Exit-function
anl.send_gold_dialog(diplomacy_gold_text) -> Text for submenu
anl.send_gold()                           -> Submenu
anl.send_tech_dialog(options)             -> Text for submenu
anl.send_tech()                           -> Submenu

* Related to negotiation:
anl.can_negotiate_with(other_faction)     -> Helper function, disable negotiation
                                             * based on faction id
                                             * if all units of a faction are obtained
anl.negotiation_option(who, desc, id, leader_option, image) -> Helper function, returns one table entry
anl.diplomacy_options()                   -> Creates table with all options to choose from

* Additionally triggered if negotiation is complete:
anl.determine_choosable_recruits(partner) -> Filter out already recruitable units before choose_new_unit
anl.choose_new_unit (v)                   -> Menu to choose new unit

* This is the one place which loads all the code
anl.diplomacy_dialog(options)             -> Text for main dialog
anl.diplomacy_menu()                      -> Main dialog, called from WML


These two functions do partially fullfil the same purpose:
anl.can_negotiate_with
anl.determine_choosable_recruits (also used by research.lua)
--]]



-- Used for sending gold or tech.
-- This lists only the allied sides, excluding the own and leaderless or defeated ones.
function anl.get_allies()
    local b = {}
    for k,v in ipairs(wesnoth.get_sides({ {'has_unit', { canrecruit = true }} } )) do
        if v.side ~= wesnoth.current.side then
            if not wesnoth.is_enemy(v.side, wesnoth.current.side) then
                if not v.lost then
                    table.insert(b, v)
                end
            end
        end
    end
    return b
end


-- Used in all cases, except when aborting.
function anl.post_diplomacy()
    wesnoth.wml_actions.modify_unit(
        {
            {
                'filter', { 
                              x = wml.variables['x1'],
                              y = wml.variables['y1']
                          }
            },
            {
                'status', {
                              worked_this_turn = true
                          }
            },
            moves = 0
        }
    )
    
end


-- The displayed dialogue:
function anl.send_gold_dialog(diplomacy_gold_text)
    if wesnoth.sides[wesnoth.current.side].gold >= 20 then
        local _ = wesnoth.textdomain 'wesnoth-anl'
        return wesnoth.show_message_dialog(
            {
             title = _ 'Diplomatic Options',
             message = _ 'Who will you donate funds to?',
             portrait = wml.variables['unit'].profile --items/gold-coins-small.png
            },
            diplomacy_gold_text
         )
    else
        -- Friendly returning.
        local _ = wesnoth.textdomain 'wesnoth-ANLEra'
        wesnoth.show_message_dialog(
            {
             title = _ 'Diplomatic Options',            -- this is part of wesnoth-anl
             message = _ 'I don’t have enough gold...', -- this not yet
             portrait = wml.variables['unit'].profile
            })
        -- Same effect as the cancel button, option number 1.
        return 1
    end

end


-- Option to send 20 gold to an ally (if any)
function anl.send_gold()

    -- Calculating the options - whom can we send gold? (Only to alive allies).
    local _ = wesnoth.textdomain 'wesnoth-anl'
    local diplomacy_gold_text = { _'Back' }

    _ = wesnoth.textdomain 'wesnoth-ANLEra'
    for k,v in ipairs( anl.get_allies() ) do
        table.insert(diplomacy_gold_text, wesnoth.format(_'Send gold to $side_name from side $side_no|.',
                                         { side_name = v.side_name,
                                           side_no = v.side })
        )
    end

    -- Decide about sending gold and sync your decision to the other clients.
    local rc = wesnoth.synchronize_choice(
        function()
            return { value = anl.send_gold_dialog(diplomacy_gold_text) }
        end
    ).value
        

    -- The number returned is not the number of the side,
    -- but the number of the selected option!
    if rc == 1 then
        -- Aborting, due to no money or due to cancel-button.
        anl.diplomacy_menu()
    else

        -- Send money.
        wesnoth.wml_actions.gold{
            side = anl.get_allies()[ rc-1 ].side,
            amount = 20,
        }
        wesnoth.wml_actions.gold{
            side = wesnoth.current.side,
            amount = -20,
        }
         _ = wesnoth.textdomain 'wesnoth-ANLEra'
        wesnoth.wml_actions.message{
            side = wesnoth.current.side,
            canrecruit = true,
            message = wesnoth.format(_'I hereby donate 20 gold to the coffers of $player_name from side $side|.', 
                                    { player_name = anl.get_allies()[ rc-1 ].side_name ,
                                      side = anl.get_allies()[ rc-1 ].side })
        }

        if anl.post_diplomacy then anl.post_diplomacy() end
    end
end


-- The displayed dialogue for sending tech.
function anl.send_tech_dialog(options)
    local _ = wesnoth.textdomain 'wesnoth-anl'
    return wesnoth.show_message_dialog(
        {
         title = _ 'Diplomatic Options',
         message = _ 'Who will you share knowledge with?',
         portrait = wml.variables['unit'].profile --items/book4.png
        }, options)
end


-- Option to increase an allies research by 1 point.
-- (As if the leader unit would be an researcher unit of the ally.)
-- If philosophy was researched, the bonus will be higher,
function anl.send_tech()
    local _ = wesnoth.textdomain 'wesnoth-anl'
    local options = { { label = _ 'Back' } }
    local list1 = {} -- Side will be saved here.
    local list2 = {} -- Tech number will be saved here.
    local own_farming = wml.variables['player_' .. wesnoth.current.side][1][2].gold
    local own_mining  = wml.variables['player_' .. wesnoth.current.side][2][2].gold
    local own_warfare = wml.variables['player_' .. wesnoth.current.side][3][2].target
    _ = wesnoth.textdomain 'wesnoth-ANLEra'

    -- Check who qualifies to receive tech (only allive allies, who are behind us in technology).
    -- Check for all techs.
    for k,v in ipairs( anl.get_allies() ) do

        -- Compare own with allied tech, only offer option if one is more advanced.
        if wml.variables['player_' .. v.side] ~= nil and own_farming > wml.variables['player_' .. v.side][1][2].gold then
            table.insert(options, {
                label = wesnoth.format(_"<span color='green'>$side_name from side $side_no|</span>\nShare knowledge of agriculture",
                                      { side_name = v.side_name,
                                        side_no = v.side }),
                -- Cropping to have not 72px heigh, which would then use more space than the label text.
                -- Can use 18,28,35,16 for cropping, but a bit extra to align.
                image = 'items/flower4.png~CROP(12,28,49,16)',
            })
            table.insert(list1, v )
            table.insert(list2, 1 )
        end

        if wml.variables['player_' .. v.side] ~= nil and own_mining > wml.variables['player_' .. v.side][2][2].gold then
            table.insert(options, {
                label = wesnoth.format(_"<span color='green'>$side_name from side $side_no|</span>\nShare knowledge of mining",
                                      { side_name = v.side_name,
                                        side_no = v.side } ),
                -- Can use 22,25,33,30 for cropping, but uses different values to align.
                image = 'items/gold-coins-small.png~CROP(13,25,49,30)',
            })
            table.insert(list1, v )
            table.insert(list2, 2 )
        end

        if wml.variables['player_' .. v.side] ~= nil and own_warfare > wml.variables['player_' .. v.side][3][2].target then
            if wml.variables['player_' .. v.side].troops <= 5 then
                -- FIXME: not a precise messurement whether the other player has still researchable units, but workable.
                -- Every side can at least get 5.
                table.insert(options, {
                    label =  wesnoth.format(_"<span color='green'>$side_name from side $side_no|</span>\nShare knowledge of warfare",
                                           { side_name = v.side_name,
                                             side_no = v.side } ),
                    -- With 49px it will not use more space than already used by the label text.
                    image = 'wesnoth-icon.png~SCALE(49,49)',
                })
                table.insert(list1, v )
                table.insert(list2, 3 )
            end
        end

        -- Explicitely skipping philosophy. Doesn't make sense from the gameplay point of view.
    end

    -- Decide about sending thech and sync your decision to the other clients.
    local rc = wesnoth.synchronize_choice(
        function()
            return { value = anl.send_tech_dialog(options) }
        end
    ).value

    if rc == 1 then
        -- Canceled.
        anl.diplomacy_menu()
    else
        -- Send tech.

        -- Field no. (rc-1) contains the chosen values.
        local side = list1[rc-1]
        local tech_option = list2[rc-1]
        local progress = wml.variables['player_' .. side.side][tech_option][2].progress
        _ = wesnoth.textdomain 'wesnoth-ANLEra'

        -- Gold:
        if tech_option == 1 then
            wml.variables['player_' .. side.side .. '.farming.progress'] = progress +1 +
            wml.variables['player_' .. wesnoth.current.side .. '.philosophy.bonus']

            wesnoth.wml_actions.message{
                side = wesnoth.current.side,
                canrecruit = true,
                message = wesnoth.format(_ '$side_name from side $side_no|, since our wisdom exceeds yours I have instructed my scholars to further your understanding of agriculture.',
                                         { side_name = side.side_name,
                                           side_no = side.side })
            }

        -- Mining:
        elseif tech_option == 2 then
            wml.variables['player_' .. side.side .. '.mining.progress'] = progress +1 +
            wml.variables['player_' .. wesnoth.current.side .. '.philosophy.bonus']

            wesnoth.wml_actions.message{
                side = wesnoth.current.side,
                canrecruit = true,
                message = wesnoth.format(_ '$side_name from side $side_no|, since the wisdom of my people exceeds yours I have instructed my scholars to aid you in your efforts to learn the science of mining.',
                                        { side_name = side.side_name,
                                          side_no = side.side })
            }

        -- Warfare:
        elseif tech_option == 3 then
            wml.variables['player_' .. side.side .. '.warfare.progress'] = progress +1 +
            wml.variables['player_' .. wesnoth.current.side .. '.philosophy.bonus']

            wesnoth.wml_actions.message{
                side = wesnoth.current.side,
                canrecruit = true,
                message = wesnoth.format(_ '$side_name from side $side_no|, you know worryingly little about the arts of war. I feel an obligation to instruct you in this vital matter.',
                                        { side_name = side.side_name,
                                          side_no = side.side })
            }
        end

        if anl.post_diplomacy then anl.post_diplomacy() end
    end
end


-- Functions for the main GUI, letting you choose between:
-- sending gold, sending tech or negotiation options.

-- Units up for negotiation
local dwarvish_units = {'Dwarvish Fighter', 'Dwarvish Guardsman', 'Dwarvish Scout', 'Dwarvish Thunderer', 'Dwarvish Ulfserker'}
local elvish_units = {'Elvish Archer', 'Elvish Fighter', 'Elvish Scout'}
local drakish_units = {'Drake Fighter', 'Drake Clasher', 'Drake Burner', 'Drake Glider'}
local undead_units
if wesnoth.unit_types['Skeleton Rider'] == nil then
    undead_units = {'Skeleton', 'Skeleton Archer', 'Vampire Bat', 'Ghost', 'Ghoul'}
else
    undead_units = {'Skeleton', 'Skeleton Archer', 'Vampire Bat', 'Ghost', 'Ghoul', 'Skeleton Rider'}
end
local human_units = {'Spearman', 'Fencer', 'Heavy Infantryman', 'Sergeant', 'Bowman', 'Horseman'}
local outlaw_units = {'Thug', 'Thief', 'Footpad', 'Poacher'}
local dunefolk_units = {'Dune Burner', 'Dune Soldier', 'Dune Skirmisher', 'Dune Rover', 'Dune Rider'}
local merfolk_units
if wesnoth.unit_types['Merman Citizen'] == nil then
    merfolk_units = {'Merman Fighter', 'Merman Hunter', 'Mermaid Initiate', 'ANLEra Merman Citizen'}
else
    merfolk_units = {'Merman Fighter', 'Merman Hunter', 'Mermaid Initiate', 'Merman Citizen'}
end
local hero_units = {'Elvish Hero', 'White Mage', 'Revenant', 'Dwarvish Berserker'}


-- Checks whether the player can negotiate with that faction.
-- Reasons to not:
-- -> Player has the same faction (checked via faction ID).
-- -> Player can already recruit all the units of the faction.
function anl.can_negotiate_with(other_faction)
    if wesnoth.sides[wesnoth.current.side].faction == other_faction then return false end

    -- This faction's already available recruits.
    local recruits = wesnoth.sides[wesnoth.current.side].recruit
    -- This faction's possible new ones.
    local partner = {}
    -- Find the units which can be negotiated.
    if other_faction == 'ANLEra_Dwarves' then
        partner = dwarvish_units
    elseif other_faction == 'ANLEra_Elves' then
        partner = elvish_units
    elseif other_faction == 'ANLEra_Drakes' then
        partner = drakish_units
    elseif other_faction == 'ANLEra_Undead' then
        partner = undead_units
    elseif other_faction == 'ANLEra_Humans' then
        partner = human_units
    elseif other_faction == 'ANLEra_Outlaws' then
        partner = outlaw_units
    elseif other_faction == 'ANLEra_Dunefolk' then
        partner = dunefolk_units
    elseif other_faction == 'Merfolk' then
        partner = merfolk_units
    elseif other_faction == 'Heroes' then
        partner = hero_units
    else
        -- Extension point:
        -- If this function is added by another add-on,
        -- then strings for more factions can be added.
        if anl.can_negotiate_with_even_more ~= nil then
            partner = anl.can_negotiate_with_even_more(other_faction)
        end
    end

    -- Not needed, only to catch potential coding mistake.
    if partner[1] == nil then
        wesnoth.message( 'ANL', other_faction .. ' has no units for negotiation')
        return false
    end

    -- Check if there are still recruits up for negotiation.
    local v_found = false
    for k,v in ipairs(partner) do

        for k,w in ipairs(recruits) do
            if v == w then
                v_found = true
                break
            end
        end

        -- There's still someone available who is not yet recruitable.
        if v_found == false then return true
        else v_found = false end
    end

    -- Partners is a subset of recruits.
    return false
end


-- Why are the variables so long/strange?
-- It's using the same variables like the WML code.
--
-- Data is currently stored in a wml variable of the form:
-- player_3.leader_option_1.progress
--
-- Which is in Lua:
-- wml.variables['player_3'][6][2].progress
-- (6 because the 6.th tag, while 2 is hardcoded by the Wesnoth engine.)
--
-- Dynamically, if using an index as part of the tag name:
-- wml.variables['player_' .. wesnoth.current.side][6 + leader_option][2].progress
--
-- Without hardcoding the position of the leader_option_1 tag in the lua table:
-- wml.variables['player_' .. wesnoth.current.side .. '.leader_option_' .. leader_option .. '.progress']
--
-- Need to build a string with 3 lines and 2 such variables
function anl.negotiation_option(who, desc, id, leader_option, image)

    -- Check if we want this first.
    if not anl.can_negotiate_with(id) then return nil end

    -- Helper function for formatting the text.
    local function negotiation_option_text(who, desc, leader_option)
        local _ = wesnoth.textdomain 'wesnoth-ANLEra'
        return "<span color='green'>" .. who .. "</span>" .. '\n' .. desc .. '\n' .. _'Negotiation Progress: ' ..
        wml.variables['player_' .. wesnoth.current.side .. '.' .. leader_option .. '.progress']
        .. '/' ..
        wml.variables['player_' .. wesnoth.current.side .. '.' .. leader_option .. '.target']
    end


    -- Return a Lua table describing the option with information for displaying.
    return { label = negotiation_option_text(who, desc, leader_option),
             image = image,
             -- Technical information to save for later,
             -- for knowing afterwards which options were displayed in the GUI.
             -- i.e. leader_option_1 are the dwarves.
             ally = leader_option }
end


-- This function contains all the text and images for the diplomacy menu.
-- Previous functions decide if the options will be active to chose from.
function anl.diplomacy_options()
    local _ = wesnoth.textdomain 'wesnoth-anl'
    local x = { { label = _ 'Back' },
                { label = _ "<span color='green'>Donate Funds</span>\nGive 20 gold to another player",
                  image = 'items/gold-coins-small.png' },
                { label = _ "<span color='green'>Share Knowledge</span>\nHelp an ally with their research",
                  image = 'items/book4.png' },
              }
    _ = wesnoth.textdomain 'wesnoth-ANLEra'

    table.insert(x, anl.negotiation_option(_'Negotiate with the Dwarves',
                                           _'Lets you recruit a Dwarvish unit',
                                            'ANLEra_Dwarves', 'leader_option_1',
                                            'units/dwarves/lord.png~TC(' .. wesnoth.current.side ..', magenta)'))

    table.insert(x, anl.negotiation_option(_'Negotiate with the Elves',
                                           _'Lets you recruit an Elvish unit',
                                            'ANLEra_Elves', 'leader_option_2',
                                            'units/elves-wood/marshal.png~TC(' .. wesnoth.current.side ..', magenta)'))

    table.insert(x, anl.negotiation_option(_'Negotiate with the Dunefolk',
                                           _'Lets you recruit a Dunefolk unit',
                                            'ANLEra_Dunefolk', 'leader_option_9',
                                            'units/dunefolk/herbalist/alchemist.png~TC(' .. wesnoth.current.side ..' ,magenta)'))

    table.insert(x, anl.negotiation_option(_'Negotiate with the Drakes',
                                           _'Lets you recruit a Drake unit',
                                            'ANLEra_Drakes', 'leader_option_3',
                                            'units/drakes/flameheart.png~TC(' .. wesnoth.current.side ..', magenta)'))

    table.insert(x, anl.negotiation_option(_'Search for a Necromancer',
                                           _'Lets you recruit an Undead unit',
                                            'ANLEra_Undead', 'leader_option_4',
                                            'units/undead-necromancers/ancient-lich.png~TC(' .. wesnoth.current.side ..', magenta)'))

    table.insert(x, anl.negotiation_option(_'Contact the Loyalists',
                                           _'Lets you recruit a Loyalist unit',
                                            'ANLEra_Humans', 'leader_option_5',
                                            'units/human-loyalists/marshal.png~TC(' .. wesnoth.current.side ..', magenta)'))

    if false then
    table.insert(x, anl.negotiation_option(_'Integrate the Outlaws',
                                           _'Lets you recruit an Outlaw unit',
                                            'ANLEra_Outlaws', 'leader_option_6',
                                            'units/human-outlaws/highwayman.png~TC(' .. wesnoth.current.side ..' ,magenta)'))
    end

    table.insert(x, anl.negotiation_option(_'Strengthen the bond with the Merfolk',
                                           _'You can obtain Merfolk builders and researchers',
                                            'Merfolk', 'leader_option_7',
                                            'units/merfolk/hoplite.png~TC(' .. wesnoth.current.side ..',magenta)'))

    table.insert(x, anl.negotiation_option(_'Hire Mercenaries',
                                           _'Lets you recruit a level 2 unit',
                                            'Heroes', 'leader_option_8',
                                            'units/elves-wood/champion.png~TC(' .. wesnoth.current.side ..',magenta)'))

    return x
end


-- Filter already recruitable units out,
-- to not offer them for negotiation.
-- (BTW, we know that there will be at least 1 left, as the option was avaiable to choose)
-- (BTW, could also have saved this information in the function which determined if there are choosable units)
function anl.determine_choosable_recruits(faction_units)
    local recruits = wesnoth.sides[wesnoth.current.side].recruit
    local partner = {}

    -- Making a deep copy of the table.
    -- Otherwise removing items from the table would remove them
    -- from the same table which is used somewhere else.
    for k, v in pairs(faction_units) do
        partner[k]=v
    end

    -- Clear the partner's list from the ones already recruitable.
    for k, available_one in ipairs(recruits) do
        for i, new_one in ipairs(partner) do
            if available_one == new_one then
                table.remove(partner, i)
                -- Ignoring possisble duplicates, should not happen.
                break
            end
        end
    end

    return partner
end


-- The dialogue to choose the new unit.
-- Contains all the faction-specific text with portraits.
function anl.choose_new_unit (v)

    local speaker = ''
    local message = ''
    local choosable = {}
    local _ = wesnoth.textdomain 'wesnoth-ANLEra'

    -- TODO: make this a function, so UMC can overwrite it without overwriting the rest of this function.
    if v == 'leader_option_1' then
         _ = wesnoth.textdomain 'wesnoth-anl'
        choosable = anl.determine_choosable_recruits(dwarvish_units)
        speaker = 'portraits/dwarves/lord.png'
        message = _ 'Our talks are complete — the Dwarves will gladly fight by your side. Which of our brethren do you want to recruit?'
    elseif v == 'leader_option_2' then
         _ = wesnoth.textdomain 'wesnoth-anl'
        choosable = anl.determine_choosable_recruits(elvish_units)
        speaker = 'portraits/elves/high-lord.png'
        message = _ 'Our talks are complete — the Elves shall aid you in this battle. Which our of kin do you wish to recruit?'
    elseif v == 'leader_option_3' then
         _ = wesnoth.textdomain 'wesnoth-ANLEra' -- this is here only for wmlxgettext (Lua is already in this domain)
        choosable = anl.determine_choosable_recruits(drakish_units)
        speaker = 'portraits/drakes/flameheart.png'
        message = _ 'Our talks are complete — the Drakes will gladly fight by your side. Which of our brethren do you want to recruit?'
    elseif v == 'leader_option_4' then
        choosable = anl.determine_choosable_recruits(undead_units)
        speaker = 'portraits/undead/ancient-lich.png'
        message = _ 'Our talks are complete — I will summon the dead for you. Which of them do you want to come?'
    elseif v == 'leader_option_5' then
        choosable = anl.determine_choosable_recruits(human_units)
        speaker = 'portraits/humans/marshal-2.png'
        message = _ 'Our talks are complete — the Loyalists will gladly fight by your side. Which of our men do you want to recruit?'
    elseif v == 'leader_option_6' then
        choosable = anl.determine_choosable_recruits(outlaw_units)
        speaker = 'portraits/humans/huntsman.png'
        message = _ 'Our talks are complete — the Outlaws will gladly fight by your side. Which of our men do you want to recruit?'
    elseif v == 'leader_option_7' then
        choosable = anl.determine_choosable_recruits(merfolk_units)
        speaker = 'portraits/merfolk/hoplite.png'
        message = _ 'Our talks are complete — the Merfolk will gladly fight by your side. Which of our people do you want to recruit?'
    elseif v == 'leader_option_8' then
        choosable = anl.determine_choosable_recruits(hero_units)
        speaker = 'portraits/dwarves/lord.png'
        message = _ 'Our talks are complete — some Mercenaries will gladly fight by your side. Which of us do you want to recruit?'
    elseif v == 'leader_option_9' then
        choosable = anl.determine_choosable_recruits(dunefolk_units)
        speaker = 'portraits/dunefolk/herbalist.png'
        message = _ 'Our talks are complete — the Dunefolk will support you. Who could help you the best?'


    -- Extension point:
    -- If this function is added by another add-on,
    -- then strings for more factions can be added.
    elseif anl.choose_other_new_unit ~= nil then
        choosable, speaker, message = anl.choose_other_new_unit(v, choosable, speaker, message)
    else
        wesnoth.message('ANL', _'Function anl.choose_new_unit has no information about the faction.')
    end

    -- Build list of options.
    local options = {}
    for i,v in ipairs(choosable) do
        -- We have the unit type's id, but want to display image and name.
        table.insert(options, {
            label = wesnoth.unit_types[v].name,
            image = wesnoth.unit_types[v].image .. '~TC(' .. wesnoth.current.side .. ', magenta)',
        })
    end

    -- Choose and sync decision about choosen unit to the other clients.
    local rc = wesnoth.synchronize_choice( function()
            local rc = wesnoth.show_message_dialog( {
                    title = _ 'Negotiation Complete',
                    message = message,
                    portrait = speaker,
                    }, options)
            return { value = rc } end
        ).value

    -- This time, there is no canel option.
    -- Can be added.

    wesnoth.wml_actions.allow_recruit({
        side = wesnoth.current.side,
        type = choosable[rc] })
end


-- The main message dialog.
function anl.diplomacy_dialog(options)
    local _ = wesnoth.textdomain 'wesnoth-anl'
    return wesnoth.show_message_dialog(
            {
             title = _ 'Diplomatic Options',
             message = _ 'What shall I do?',
             portrait = wml.variables['unit'].profile
            }, options
    )
end


-- The true and only diplomancy GUI, the only Lua function from this file,
-- which is called by WML's [set_menu_item].
function anl.diplomacy_menu()

    -- Get all the data.
    local choices = anl.diplomacy_options()

    -- Make a choice and sync it to the other clients.
    local rc = wesnoth.synchronize_choice(
        function()
            return { value = anl.diplomacy_dialog(choices) }
        end
    ).value 

    if rc == nil then wesnoth.message('ANL', "Lua does strange things.") end

    -- Handle the choice.
    if rc ~= 1 then
        if rc == 2 then
            anl.send_gold()
        elseif rc == 3 then
            anl.send_tech()
        else
            -- Negotiate, but with whom?
            -- Reconstruct what the rc from the GUI means.

            local value  = wml.variables['player_' .. wesnoth.current.side .. '.' .. choices[rc].ally .. '.progress']
            local target = wml.variables['player_' .. wesnoth.current.side .. '.' .. choices[rc].ally .. '.target']
            if ( target <= value +1) then
                -- you have a new recruit !
                anl.choose_new_unit(choices[rc].ally)
                -- and reset
                wml.variables['player_' .. wesnoth.current.side .. '.' .. choices[rc].ally .. '.progress'] =
                value +1 -target
            else
                -- increase
                wml.variables['player_' .. wesnoth.current.side .. '.' .. choices[rc].ally .. '.progress'] =
                value +1
            end

            if anl.post_diplomacy then anl.post_diplomacy() end
        end
    end
end


-- Make them available in case other add-ons want to use or modify them.
anl.negotiable_units = {}
anl.negotiable_units.drakish_units = drakish_units
anl.negotiable_units.dwarvish_units = dwarvish_units
anl.negotiable_units.elvish_units = elvish_units
anl.negotiable_units.human_units = human_units
anl.negotiable_units.outlaw_units = outlaw_units
anl.negotiable_units.undead_units = undead_units
anl.negotiable_units.dunefolk_units = dunefolk_units
anl.negotiable_units.merfolk_units = merfolk_units
anl.negotiable_units.hero_units = hero_units

return anl

-- Magic marker. For Lua it's a comment, for the WML preprocessor a closing quotation sign. >>
