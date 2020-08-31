
--
-- Extending / overriding some of the lua code from diplomacy.lua
--
-- The code in diplomacy.lua can be modifed long-term, to make things here easier.
--

local options_offered = {}

function anl.diplomacy_options()
    local _ = wesnoth.textdomain 'wesnoth-anl'
    local x = { _ 'Back',
                { label = _ "<span color='green'>Donate Funds</span>\nGive 20 gold to another player",
                  image = 'items/gold-coins-small.png' },
                { label = _ "<span color='green'>Share Knowledge</span>\nHelp an ally with their research",
                  image = 'items/book4.png' },
              }
    _ = wesnoth.textdomain 'wesnoth-Undead_Empire'

    table.insert(x, anl.negotiation_option(_'Negotiate with the Saurians',
                                           _'Lets you recruit a healer or skirmisher',
                                            'ANLEra_Saurians', 11,
                                            'units/saurians/flanker/flanker.png~TC(' .. wesnoth.current.side ..', magenta)'))
    table.insert(x, anl.negotiation_option(_'Negotiate with the Orcs',
                                           _'Lets you recruit an orcish unit',
                                            'ANLEra_Orcs', 9,
                                            'units/orcs/sovereign.png~TC(' .. wesnoth.current.side ..', magenta)'))
    table.insert(x, anl.negotiation_option(_'Negotiate with the Nagas',
                                           _'Lets you recruit units of the Naga folk',
                                            'UE_Naga', 10,
                                            'units/nagas/myrmidon.png~TC(' .. wesnoth.current.side ..', magenta)'))
    return x
end


local saurian_units = {'Saurian Skirmisher', 'Saurian Augur'}
local orcish_units = {'Orcish Archer', 'Orcish Assassin', 'Wolf Rider', 'Orcish Grunt', 'Troll Whelp', 'Orcish Leader', 'Goblin Impaler', 'Goblin Rouser'}
local naga_units = {}
if wesnoth.unit_types['Naga Dirkfang'] == nil then
    naga_units = {'Naga Fighter'}
else
    naga_units = {'Naga Fighter', 'Naga Dirkfang'}
end


-- Currently the faction id MUST be different from the ones in diplomacy.lua,
-- except if the the unit pool is identical.
function anl.can_negotiate_with_even_more(other_faction)
    if other_faction == 'ANLEra_Orcs' then
        return orcish_units
    elseif other_faction == 'ANLEra_Saurians' then
        return saurian_units
    elseif other_faction == 'UE_Naga' then
        return naga_units
    else
        return {}
    end
end


function anl.choose_new_recruit(v, choosable, speaker, message)
    local _ = wesnoth.textdomain 'wesnoth-Undead_Empire'
    if v == 9 then
        choosable = anl.determine_choosable_recruits(orcish_units)
        speaker = 'portraits/orcs/warlord.png'
        -- po: Orcs
        message = _'Our talks are complete — Which of our kin do you wish to recruit?'
    elseif v == 10 then
        choosable = anl.determine_choosable_recruits(naga_units)
        speaker = 'portraits/nagas/naga-hunter.png'
        -- po: Nagas
        message = _'An agreement has been reached — we will supply you with recruits!'
    elseif v == 3 then
        choosable = anl.determine_choosable_recruits(saurian_units)
        speaker = 'portraits/saurians/augur.png'
        if choosable[2] == nil then
            -- po: Saurians
            message = _'Our talks are complete — we will send you more specialits.'
        else
            -- po: Saurians
            message = _ 'Your success will be our success — in exchange for a habitat we will fight alongside your units. We will conquer this area, no doubt. Together we will prevail and rule over these lands!\n\nAs discussed, we will supply you with specialized units: Are it skrimishers or healers which your army needs?'
        end
    end
    return choosable, speaker, message
end
