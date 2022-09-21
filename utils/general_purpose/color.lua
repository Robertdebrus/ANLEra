-- <<
-- Players can choose a color in MP, but it might be that an AI side has the same color.
-- AI sides are mostly not shown in MP, so players cannot see or change their colors in advance.
-- This code will assign a new color if one is already taken.
--
-- Based on wesnoth.wml_actions.wc2_fix_colors from
-- wesnoth/data/campaigns/World_Conquest/lua/game_mechanics/color.lua
-- and
-- https://github.com/ProditorMagnus/Color_Modification/blob/master/color_mod.cfg

function anl.fix_colors()
    local all_sides = wesnoth.sides.find()
    local all_colors = {'gold', 'lightblue', 'brightgreen', 'red', 'blue', 'green', 'purple', 'black', 'brown', 'orange', 'white', 'teal', 'darkred', 'brightorange', 'lightred'}
    local free_colors = {}
    local taken_colors = {}
    local needs_color = {}

    for i, player in ipairs(all_sides) do
        if not taken_colors[player.color] then
            -- Remember the color
            taken_colors[player.color] = true
        else
            -- There is already a side with that color.
            -- Lets first look at all other sides as well
            -- and decide then what color to give to this side.
            table.insert(needs_color, player)
        end
    end

    -- Look which colors we can give
    for i, color in ipairs(all_colors) do
        if not taken_colors[color] then
            table.insert(free_colors, color)
        end
    end

    -- Change the color
    for i, player in ipairs(needs_color) do
        if free_colors[1] then
            wesnoth.sides.set_id(player.side, "", free_colors[1])
            table.remove(free_colors, 1)
        end
    end
end

return anl
-- >>
