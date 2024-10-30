local entities = {}
local bottleFlavor = nil
local bottleContents = nil
local effectStrength = 0

-- SHARING WHIPPETS

local function takeGas(flavor, contents)
    local duration = GetAnimDuration('mp_common', 'givetake1_a') * 1000
    Core.Natives.PlayAnim(cache.ped, 'mp_common', 'givetake1_a', duration, 16, 0.0)
    SetTimeout(duration * 0.5, function()
        TriggerEvent('r_whippets:holdGas', flavor, contents)
        debug('[DEBUG] - took gas')
    end)
end

local function handoverGas()
    local duration = GetAnimDuration('mp_common', 'givetake1_a') * 1000
    local shared = lib.callback.await('r_whippets:shareGasWithNearestPlayer', false, bottleFlavor, bottleContents)
    if not shared then debug('[DEBUG] - sharing failed') return end
    Core.Natives.PlayAnim(cache.ped, 'mp_common', 'givetake1_a', duration, 16, 0.0)
    Core.Target.RemoveGlobalPlayer()
    DeleteEntity(entities.gasBottle)
    HideControlsUi()
    bottleFlavor = nil
    bottleContents = nil
    entities.gasBottle = nil
    debug('[DEBUG] - shared gas')
end

RegisterNetEvent('r_whippets:takeGas', function(flavor, contents)
    takeGas(flavor, contents)
end)

-- USE WHIPPETS

local function storeGas()
    local netId = NetworkGetNetworkIdFromEntity(entities.gasBottle)
    Core.Natives.PlayAnim(cache.ped, 'melee@holster', 'holster', 1000, 49, 0.0)
    local stored = lib.callback.await('r_whippets:storeGas', false, bottleFlavor, bottleContents, netId)
    if stored then
        HideControlsUi()
        DeleteEntity(entities.gasBottle)
        Core.Target.RemoveGlobalPlayer()
        bottleFlavor = nil
        bottleContents = nil
        entities.gasBottle = nil
        debug('[DEBUG] - stored gas')
    end
end

local function disableAllControls(duration)
    CreateThread(function()
        local start = GetGameTimer()
        while GetGameTimer() - start < duration do
            DisableAllControlActions(0)
            Wait(0)
        end
    end)
end

local function passout()
    HideControlsUi()
    disableAllControls(5000)
    SetPedToRagdoll(cache.ped, 5000, 5000, 0, 0, 0, 0)
    DoScreenFadeOut(750)
    Core.Framework.Notify(_L('passout'), 'info')
    SetTimeout(5000, function()
        DoScreenFadeIn(500)
        Wait(1000)
        Core.Natives.PlayAnim(cache.ped, 'amb@world_human_drinking@coffee@male@base', 'base', -1, 49, 0.0)
        ShowControlsUi(bottleContents)
    end)
end

local function decreaseEffectStrength()
    local oldStrength = effectStrength * 100
    local newStrength = (effectStrength * 100) - 20
    for i = oldStrength, newStrength, -1 do
        SetTimecycleModifier('BlackOut')
        effectStrength = math.max((i * 0.01) * 1.0, 0.0)
        SetTimecycleModifierStrength(effectStrength);
        Wait(0)
    end
    if effectStrength <= 0.0 then
        SetTimecycleModifier('default')
        effectStrength = 0
    end
    debug('[DEBUG] - decreased effect strength')
end

local function increaseEffectStrength(duration)
    local oldStrength = effectStrength * 100
    local newStrength = (effectStrength * 100) + 20
    for i = oldStrength, newStrength do
        SetTimecycleModifier('BlackOut')
        effectStrength = (i * 0.01) * 1.0
        SetTimecycleModifierStrength(effectStrength);
        Wait(0)
    end
    if effectStrength >= 1.0 then
        passout()
    end
    SetTimeout((duration * 5) * 1000, function()
        decreaseEffectStrength()
    end)
    debug('[DEBUG] - increased effect strength')
end

local function useGas()
    bottleContents = bottleContents - 50
    local duration = 6.2666664123535
    UpdateUiProgressBar(bottleContents)
    if lib.progressCircle({
            duration = duration * 600,
            label = _L('using_gas'),
            position = 'bottom',
            useWhileDead = false,
            canCancel = false,
            disable = {
                car = true,
                combat = true,
            },
            anim = {
                dict = 'amb@world_human_drinking@coffee@male@idle_a',
                clip = 'idle_a',
            },
        }) then
        debug('[DEBUG] - used gas')
        increaseEffectStrength(duration)
        if bottleContents <= 0 then
            Wait(1000)
            bottleFlavor = nil
            bottleContents = nil
            Core.Framework.Notify(_L('empty_bottle'), 'info')
            DeleteEntity(entities.gasBottle)
            HideControlsUi()
        else
            local ptFxCoords = GetPedBoneCoords(cache.ped, 47495, 0.0, 0.0, 0.0)
            Core.Natives.PlayPtFxLooped(ptFxCoords, 'core', 'ent_amb_smoke_gaswork', 0.1, 1000)
            Core.Natives.PlayAnim(cache.ped, 'amb@world_human_drinking@coffee@male@base', 'base', -1, 49, 0.0)
        end
    end
end

local function startListeningForInput()
    CreateThread(function()
        local listening = true
        while listening and bottleContents do
            DisableFrontendThisFrame()
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 140, true)
            if IsControlJustPressed(0, 38) then
                useGas()
            elseif IsControlJustPressed(0, 73) then
                storeGas()
                SetTimeout(500, function()
                    listening = false
                end)
            end
            Wait(0)
        end
    end)
end

local function holdGas(flavor, contents)
    bottleFlavor = flavor
    bottleContents = contents
    local prop = Flavors[flavor].bottleProp
    entities.gasBottle = Core.Natives.CreateProp(prop, GetEntityCoords(cache.ped), GetEntityHeading(cache.ped), true)
    AttachEntityToEntity(entities.gasBottle, cache.ped, GetPedBoneIndex(cache.ped, 28422), -0.0089, -0.0009, -0.0678, -4.1979, 10.7573, -13.8231, true, true, false, true, 2, true)
    Core.Natives.PlayAnim(cache.ped, 'amb@world_human_drinking@coffee@male@base', 'base', -1, 49, 0.0)
    Core.Target.AddGlobalPlayer({
        label = _L('share_gas'),
        name = 'share_gas',
        icon = 'fas fa-user-astronaut',
        distance = 1.0,
        onSelect = function()
            handoverGas()
        end
    })
    ShowControlsUi(contents)
    startListeningForInput()
    debug('[DEBUG] - pulled out gas')
end

RegisterNetEvent('r_whippets:holdGas', function(flavor, contents)
    holdGas(flavor, contents)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        StopAnimTask(cache.ped, 'amb@world_human_drinking@coffee@male@base', 'base', 1.0)
        SetTimecycleModifier('default')
        HideControlsUi()
        for _, entity in pairs(entities) do
            DeleteEntity(entity)
        end
    end
end)