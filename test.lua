models.player.Skull.Player.hOutline:setPrimaryRenderType("CUTOUT_CULL")
models.player.Skull.Player.bOutline:setPrimaryRenderType("CUTOUT_CULL")
models.player.Skull.Player.Right.rOutline:setPrimaryRenderType("CUTOUT_CULL")
models.player.Skull.Player.Left.lOutline:setPrimaryRenderType("CUTOUT_CULL")
--models.player.Skull.Player:setScale(0.75)
models.player.Skull.Player:setSecondaryRenderType("EMISSIVE_SOLID")
models.player.Skull.Server.outline:setPrimaryRenderType("CUTOUT_CULL")
models.player.Skull.Server:setSecondaryRenderType("EMISSIVE_SOLID")
models.player.Skull.Gear.group:setPrimaryRenderType("CUTOUT_CULL")
 models.player.Skull.Gear:setScale(1.33)
models.player.Skull.Gear.bone:setSecondaryRenderType("EMISSIVE_SOLID")
local cubes = {
    models.player.Skull.Player.h.Head,
    models.player.Skull.Player.b.Body,
    models.player.Skull.Player.Left.Left,
    models.player.Skull.Player.Right.Right,
    models.player.Skull.Server.cube,
    models.player.Skull.Icons,
}
for _, child in pairs(models.player.Skull.Gear.bone:getChildren()) do
    cubes[#cubes+1] = child
end
for _, cube in ipairs(cubes) do
cube:setPrimaryRenderType("EMISSIVE_SOLID")
end
function events.skull_render(delta, block, item, entity, ctx)
    if item then

        local dat = item.tag["minecraft:custom_data"]
        if dat and dat.type then
            models.player.Skull.Player:setVisible(dat.type == "player")
            models.player.Skull.Server:setVisible(dat.type == "server")
            models.player.Skull.Gear:setVisible(dat.type == "gear")
        else
            models.player.Skull.Player:setVisible(false)
            models.player.Skull.Server:setVisible(false)
            models.player.Skull.Gear:setVisible(false)
        end
    end
end