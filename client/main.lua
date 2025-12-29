RegisterNUICallback("getAllXP", function(_, cb)
    local data = lib.callback.await("stressy-levels:getAllXP", false)
    cb(data)
end)

RegisterNUICallback("close", function(_, cb)
    SetNuiFocus(false, false)
    cb(true)
end)

RegisterCommand("levels", function()
    SetNuiFocus(true, true)
    SendNUIMessage({ type = "levels:open" })
end)

RegisterKeyMapping("levels", "Open Levels UI", "keyboard", "F3")