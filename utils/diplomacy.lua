-- <<

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
        local _ = wesnoth.textdomain 'wesnoth-ANLEra'
        wesnoth.show_message_dialog(
            {
             title = _ 'Diplomatic Options',            -- this is part of wesnoth-anl
             message = _ 'I don’t have enough gold...', -- this not yet
             portrait = wml.variables['unit'].profile
            })
        return 1
    end

end


function anl.send_gold()

    -- calculating the options
    local _ = wesnoth.textdomain 'wesnoth-anl'
    local diplomacy_gold_text = { _'Back' }

    _ = wesnoth.textdomain 'wesnoth-ANLEra'
    for k,v in ipairs( anl.get_allies() ) do
        table.insert(diplomacy_gold_text, wesnoth.format(_'Send gold to $side_name from side $side_no|.',
                                         { side_name = v.side_name,
                                           side_no = v.side })
        )
    end

    -- sync
    local rc = wesnoth.synchronize_choice(
        function()
            return { value = anl.send_gold_dialog(diplomacy_gold_text) }
        end
    ).value
        

    -- The number returned is not the number of the side,
    -- but the number of the selected option!
    if rc == 1 then
        anl.diplomacy_menu()
    else

        -- send money
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
        anl.post_diplomacy()
    end
end


-- GUI for sending tech
function anl.send_tech_dialog(options)
    local _ = wesnoth.textdomain 'wesnoth-anl'
    return wesnoth.show_message_dialog(
        {
         title = _ 'Diplomatic Options',
         message = _ 'Who will you share knowledge with?',
         portrait = wml.variables['unit'].profile --items/book4.png
        }, options)
end


function anl.send_tech()
    local _ = wesnoth.textdomain 'wesnoth-anl'
    local options = { _'Back'}
    local list1 = {} -- Side will be saved here.
    local list2 = {} -- Tech number will be saved here.
    local own_farming = wml.variables['player_' .. wesnoth.current.side][1][2].gold
    local own_mining  = wml.variables['player_' .. wesnoth.current.side][2][2].gold
    local own_warfare = wml.variables['player_' .. wesnoth.current.side][3][2].target
    _ = wesnoth.textdomain 'wesnoth-ANLEra'

    for k,v in ipairs( anl.get_allies() ) do

        -- Compare own with allied tech, only offer option if one is more advanced.
        if wml.variables['player_' .. v.side] ~= nil and own_farming > wml.variables['player_' .. v.side][1][2].gold then
            table.insert(options, {
                label = wesnoth.format(_"<span color='green'>$side_name from side $side_no|</span>\nShare knowledge of agriculture",
                                      { side_name = v.side_name,
                                        side_no = v.side }),
                image = 'items/flower4.png',
            })
            table.insert(list1, v )
            table.insert(list2, 1 )
        end

        if wml.variables['player_' .. v.side] ~= nil and own_mining > wml.variables['player_' .. v.side][2][2].gold then
            table.insert(options, {
                label = wesnoth.format(_"<span color='green'>$side_name from side $side_no|</span>\nShare knowledge of mining",
                                      { side_name = v.side_name,
                                        side_no = v.side } ),
                image = 'items/gold-coins-small.png',
            })
            table.insert(list1, v )
            table.insert(list2, 2 )
        end

        if wml.variables['player_' .. v.side] ~= nil and own_warfare > wml.variables['player_' .. v.side][3][2].target then
            if wml.variables['player_' .. v.side][3][2].troops <= 5 then
                -- FIXME: not a precise messurement whether the other player has still researchable units, but workable.
                -- Every side can at least get 5.
                table.insert(options, {
                    label =  wesnoth.format(_"<span color='green'>$side_name from side $side_no|</span>\nShare knowledge of warfare",
                                           { side_name = v.side_name,
                                             side_no = v.side } ),
                    image = 'wesnoth-icon.png~SCALE(72,72)',
                })
                table.insert(list1, v )
                table.insert(list2, 3 )
            end
        end

        -- Explicitely skipping philosophy. Doesn't make sense from the gameplay point of view.
    end

    -- sync
    local rc = wesnoth.synchronize_choice(
        function()
            return { value = anl.send_tech_dialog(options) }
        end
    ).value

    if rc == 1 then
        anl.diplomacy_menu()
    else
        -- send tech

        -- Field no. (rc-1) contains the chosen values.
        local side = list1[rc-1]
        local tech_option = list2[rc-1]
        local progress = wml.variables['player_' .. side.side][tech_option][2].progress
        _ = wesnoth.textdomain 'wesnoth-ANLEra'

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
        anl.post_diplomacy()
    end
end


-- Functions for the main GUI, letting you choose between:
-- sending gold, sending tech or negotiation options.

local dwarvish_units = {'Dwarvish Fighter', 'Dwarvish Guardsman', 'Dwarvish Scout', 'Dwarvish Thunderer', 'Dwarvish Ulfserker'}
local elvish_units = {'Elvish Archer', 'Elvish Fighter', 'Elvish Scout'}
local drakish_units = {'Drake Fighter', 'Drake Clasher', 'Drake Burner', 'Drake Glider'}
local undead_units = {'Skeleton', 'Skeleton Archer', 'Vampire Bat', 'Ghost', 'Ghoul'}
local human_units = {'Spearman', 'Fencer', 'Heavy Infantryman', 'Sergeant', 'Bowman', 'Horseman'}
local outlaw_units = {'Thug', 'Thief', 'Footpad', 'Poacher'}
local merfolk_units = {'Merman Fighter', 'Merman Hunter', 'Mermaid Initiate', 'ANLEra Merman Citizen'}
local hero_units = {'Elvish Hero', 'White Mage', 'Revenant', 'Dwarvish Berserker'}
local options_offered


function anl.can_negotiate_with(other_faction)
    if wesnoth.sides[wesnoth.current.side].faction == other_faction then return false end

    -- This faction's already available recruits
    local recruits = wesnoth.sides[wesnoth.current.side].recruit
    -- This faction's possible new ones
    local partner = {}
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

    -- Check if there are still recruits up for negotiation.
    local v_found = false
    for k,v in ipairs(partner) do

        for k,w in ipairs(recruits) do
            if v == w then
                v_found = true
            end
        end

        -- There's still someone available who is not yet recruitable.
        if v_found == false then return true
        else v_found = false end
    end

    -- Partners is a subset of recruits.
    return false
end


-- Data is currently stored in a wml variable of the form:
-- player_3.leader_option_1.progress
--
-- Which is in Lua:
-- wml.variables['player_3'][6][2].progress
-- (6 because the 6.th tag), while 2 is hardcoded
--
-- Dynamically:
-- wml.variables['player_' .. wesnoth.current.side][6 + leader_option][2].progress
--
-- Without hardcoding the position of the leader_option_1 tag in the lua table:
-- wml.variables['player_' .. wesnoth.current.side .. '.leader_option_' .. leader_option .. '.progress']
--
-- Need to build a string with 3 lines and 2 such variables
function anl.negotiation_option(who, desc, id, leader_option, image)
    if not anl.can_negotiate_with(id) then return nil end

    local function negotiation_option_text(who, desc, leader_option)
        local _ = wesnoth.textdomain 'wesnoth-ANLEra'
        return "<span color='green'>" .. who .. "</span>" .. '\n' .. desc .. '\n' .. _'Negotiation Progress: ' ..
        wml.variables['player_' .. wesnoth.current.side .. '.leader_option_' .. leader_option .. '.progress']
        .. '/' ..
        wml.variables['player_' .. wesnoth.current.side .. '.leader_option_' .. leader_option .. '.target']
    end

    -- For knowing afterwards which options were displayed in the GUI.
    table.insert(options_offered, leader_option)

    return { label = negotiation_option_text(who, desc, leader_option),
             image = image }
end


function anl.diplomacy_options()
    local _ = wesnoth.textdomain 'wesnoth-anl'
    local x = { _ 'Back',
                { label = _ "<span color='green'>Donate Funds</span>\nGive 20 gold to another player",
                  image = 'items/gold-coins-small.png' },
                { label = _ "<span color='green'>Share Knowledge</span>\nHelp an ally with their research",
                  image = 'items/book4.png' },
              }
    _ = wesnoth.textdomain 'wesnoth-ANLEra'

    table.insert(x, anl.negotiation_option(_'Negotiate with the Dwarves',
                                           _'Lets you recruit a Dwarvish unit',
                                            'ANLEra_Dwarves', 1,
                                            'units/dwarves/lord.png~TC(' .. wesnoth.current.side ..', magenta)'))

    table.insert(x, anl.negotiation_option(_'Negotiate with the Elves',
                                           _'Lets you recruit an Elvish unit',
                                            'ANLEra_Elves', 2,
                                            'units/elves-wood/marshal.png~TC(' .. wesnoth.current.side ..', magenta)'))
    
    table.insert(x, anl.negotiation_option(_'Negotiate with the Drakes',
                                           _'Lets you recruit a Drake unit',
                                            'ANLEra_Drakes', 3,
                                            'units/drakes/flameheart.png~TC(' .. wesnoth.current.side ..', magenta)'))

    table.insert(x, anl.negotiation_option(_'Negotiate with the Undead',
                                           _'Lets you recruit an Undead unit',
                                            'ANLEra_Undead', 4,
                                            'units/undead-necromancers/ancient-lich.png~TC(' .. wesnoth.current.side ..', magenta)'))

    table.insert(x, anl.negotiation_option(_'Negotiate with Loyalists',
                                           _'Lets you recruit a Loyalist unit',
                                            'ANLEra_Humans', 5,
                                            'units/human-loyalists/marshal.png~TC(' .. wesnoth.current.side ..', magenta)'))

    -- Planning to remove them from negotiation:
    if false then
    table.insert(x, anl.negotiation_option(_'Negotiate with the Outlaws',
                                           _'Lets you recruit a Outlaw unit',
                                            'ANLEra_Outlaws', 6, 'units/human-outlaws/highwayman.png~TC(1,magenta)')) end

    table.insert(x, anl.negotiation_option(_'Negotiate with the Merfolk',
                                           _'Lets you recruit a Merfolk unit',
                                            'Merfolk', 7,
                                            'units/merfolk/hoplite.png~TC(' .. wesnoth.current.side ..',magenta)'))

    table.insert(x, anl.negotiation_option(_'Negotiate with Mercenaries',
                                           _'Lets you recruit Mercenary units',
                                            'Heroes', 8,
                                            'units/elves-wood/champion.png~TC(' .. wesnoth.current.side ..',magenta)'))

    return x
end


function anl.determine_choosable_recruits(faction_units)
    local recruits = wesnoth.sides[wesnoth.current.side].recruit
    local partner = {}

    -- Making a deep copy of the table.
    -- Otherwise removing items from the table would remove them
    -- from the same table which is used somewhere else
    for k, v in pairs(faction_units) do
        partner[k]=v
    end

    -- Clear the partner's list from the ones already recruitable.
    for k, available_one in ipairs(recruits) do
        for i, new_one in ipairs(partner) do
            if available_one == new_one then
                table.remove(partner, i)
                -- ignoring possisble duplicates, should not happen
                break
            end
        end
    end

    return partner
end


function anl.choose_new_unit (v)

    local speaker = ''
    local message = ''
    local choosable = {}
    local _ = wesnoth.textdomain 'wesnoth-ANLEra'

    -- TODO: make this a fuction, so umc can overwrite it without overwriting the rest of this function
    if v == 1 then
         _ = wesnoth.textdomain 'wesnoth-anl'
        choosable = anl.determine_choosable_recruits(dwarvish_units)
        speaker = 'portraits/dwarves/lord.png'
        message = _ 'Our talks are complete — the Dwarves will gladly fight by your side. Which of our brethren do you want to recruit?'
    elseif v == 2 then
         _ = wesnoth.textdomain 'wesnoth-anl'
        choosable = anl.determine_choosable_recruits(elvish_units)
        speaker = 'portraits/elves/high-lord.png'
        message = _ 'Our talks are complete — the Elves shall aid you in this battle. Which our of kin do you wish to recruit?'
    elseif v == 3 then
         _ = wesnoth.textdomain 'wesnoth-ANLEra' -- this is here only for wmlxgettext (Lua is already in this domain)
        choosable = anl.determine_choosable_recruits(drakish_units)
        speaker = 'portraits/drakes/flameheart.png'
        message = _ 'Our talks are complete — the Drakes will gladly fight by your side. Which of our brethren do you want to recruit?'
    elseif v == 4 then
        choosable = anl.determine_choosable_recruits(undead_units)
        speaker = 'portraits/undead/ancient-lich.png'
        message = _ 'Our talks are complete — I will summon the dead for you. Which of them do you want to come?'
    elseif v == 5 then
        choosable = anl.determine_choosable_recruits(human_units)
        speaker = 'portraits/humans/marshal-2.png'
        message = _ 'Our talks are complete — the Loyalists will gladly fight by your side. Which of our men do you want to recruit?'
    elseif v == 6 then
        choosable = anl.determine_choosable_recruits(outlaw_units)
        speaker = 'portraits/humans/huntsman.png'
        message = _ 'Our talks are complete — the Outlaws will gladly fight by your side. Which of our men do you want to recruit?'
    elseif v == 7 then
        choosable = anl.determine_choosable_recruits(merfolk_units)
        speaker = 'portraits/merfolk/hoplite.png'
        message = _ 'Our talks are complete — the Merfolk will gladly fight by your side. Which of our people do you want to recruit?'
    elseif v == 8 then
        choosable = anl.determine_choosable_recruits(hero_units)
        speaker = 'portraits/dwarves/lord.png'
        message = _ 'Our talks are complete — some Mercenaries will gladly fight by your side. Which of us do you want to recruit?'
    end

    -- Extension point:
    -- If this function is added by another add-on,
    -- then strings for more factions can be added.
    if anl.choose_other_new_unit ~= nil then
        choosable, speaker, message = anl.choose_other_new_unit(v, choosable, speaker, message)
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

    local rc = wesnoth.synchronize_choice( function()
            local rc = wesnoth.show_message_dialog( {
                    title = _ 'Negotiation Complete',
                    message = message,
                    portrait = speaker,
                    }, options)
            return { value = rc } end
        ).value

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


function anl.diplomacy_menu()

    -- Reset helper variable
    options_offered = {}

    local negotiation_options = anl.diplomacy_options()

    local rc = wesnoth.synchronize_choice(
        function()
            return { value = anl.diplomacy_dialog(negotiation_options) }
        end
    ).value 


    if rc ~= 1 then
        if rc == 2 then
            anl.send_gold()
        elseif rc == 3 then
            anl.send_tech()
        else
            -- Negotiate, but with whom?
            -- Reconstruct what the rc from the GUI means.
            -- rc:   Number of selected option.
            -- rc-3: Number of selected negotiation option (1-3 are are always listed).
            -- options_offered[rc-3]: The real number of the leader option.
            --                        It may be higher, as rc-3 does not count the not displayed ones.

            local value  = wml.variables['player_' .. wesnoth.current.side .. '.leader_option_' .. options_offered[ rc -3 ] .. '.progress']
            local target = wml.variables['player_' .. wesnoth.current.side .. '.leader_option_' .. options_offered[ rc -3 ] .. '.target']
            if ( target <= value +1) then
                -- you have a new recruit !
                anl.choose_new_unit(options_offered[rc -3])
                -- and reset
                wml.variables['player_' .. wesnoth.current.side .. '.leader_option_' .. options_offered[ rc -3 ] .. '.progress'] = value +1 - target
            else
                -- increase
                wml.variables[ 'player_' .. wesnoth.current.side .. '.leader_option_' .. options_offered[ rc -3 ] .. '.progress'] = value +1
            end

            anl.post_diplomacy()
        end
    end
end


-- Make them available in case other add-on want to use them.
anl.negotiable_units = {}
anl.negotiable_units.drakish_units = drakish_units
anl.negotiable_units.dwarvish_units = dwarvish_units
anl.negotiable_units.elvish_units = elvish_units
anl.negotiable_units.human_units = human_units
anl.negotiable_units.outlaw_units = outlaw_units
anl.negotiable_units.undead_units = undead_units
anl.negotiable_units.merfolk_units = merfolk_units
anl.negotiable_units.hero_units = hero_units

return anl

-- >>
