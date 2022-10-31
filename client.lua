local WaitingOnBar = false
local height_wanted = 0.0

CreateThread(function()
    Citizen.InvokeNative(0x144da052257ae7d8, true) --NETWORK_ALLOW_REMOTE_SYNCED_SCENE_LOCAL_PLAYER_REQUESTS
    while not RequestScriptAudioBank("DLC_HEIST3/ARCADE_GENERAL_01", 0) do Wait(0) end
    while not RequestScriptAudioBank( "DLC_HEIST3/ARCADE_GENERAL_02", 0) do Wait(0) end
    while not RequestScriptAudioBank("DLC_TUNER/DLC_Tuner_Arcade_General", 0) do Wait(0) end

    print("Scene Sync Enabled | Sounds Requested")
end)


RegisterCommand('spawnlove', function()
    local coords = GetEntityCoords(PlayerPedId())
    CreateObject(`ch_prop_arcade_love_01a`, coords.x, coords.y, coords.z - 1, true, true, false)
end)

function GetNearestPlayerToMe()
    local players = GetActivePlayers()
    local closestPlayer, closestDistance = nil, 100000
    local myPos = GetEntityCoords(PlayerPedId())
    local myPlayerId = PlayerId()
    for i = 1, #players do
        local player = players[i]
        if player ~= myPlayerId then
            local ped = GetPlayerPed(player)
            local pos = GetEntityCoords(ped)
            local distance = #(pos - myPos)
            if distance < closestDistance then
                closestPlayer, closestDistance = player, distance
            end 
        end
    end
    if closestPlayer then
        return closestPlayer, closestDistance
    end
    return false, false
end

local function CreateNamedRenderTargetForModel(name, model)
	local handle = 0
	if not IsNamedRendertargetRegistered(name) then
		RegisterNamedRendertarget(name, 0)
	end
	if not IsNamedRendertargetLinked(model) then
		LinkNamedRendertarget(model)
	end
	if IsNamedRendertargetRegistered(name) then
		handle = GetNamedRendertargetRenderId(name)
	end
	return handle
end

local function LoveBar(percentage)
    CreateThread(function()
        shoulddraw = true -- Temp Var
        local handle = CreateNamedRenderTargetForModel('Arc_Love_01a', `ch_prop_arcade_love_01a`)
        local height = 1.0
        if percentage > 3.0 then percentage = 3.0 end
        height_wanted = percentage

        print('Attempting to Play Sound')
        local coords = GetEntityCoords(PlayerPedId())
        local soundid = GetSoundId()
        PlaySoundFromCoord(soundid, 'Calculate_Outcome', coords.x, coords.y, coords.z, 'DLC_H3_LoveMachine_Sounds', false, 20, false)
        SetVariableOnSound(soundid, 'Time', percentage * 2)
        ReleaseSoundId(soundid)

        CreateThread(function()
            while true do
                Wait(50)
                height = height + 0.01
                if height >= height_wanted then
                    -- height = 1.0
                    WaitingOnBar = false
                    SetTimeout(7000, function()
                        shoulddraw = false
                    end)
                    break
                end
            end
        end)
        while shoulddraw do
            SetTextRenderId(handle) -- Sets the render target to the handle we grab above
            SetScriptGfxAlign(73, 73)
            SetScriptGfxDrawOrder(4)
            SetScriptGfxDrawBehindPausemenu(false)
            DrawRect(0.0, 1.5, 2.0, height, 247, 112, 164, 255)
            ResetScriptGfxAlign()
            SetTextRenderId(GetDefaultScriptRendertargetRenderId()) -- Resets the render target
            Citizen.Wait(0)
        end
    end)
end

RegisterNetEvent('aj-love:client:StartLoveBar', function(percentage)
    print('Hitting event: aj-love:client:StartLoveBar')
    LoveBar(percentage)
end)


local Prefect = {'friendzoned_perfect', 'mutual_perfect'}
local Good = {'average_better', 'bad_better', 'good_better', 'mutual_good', 'perfect_better'}
local Average = {'mutual_average', 'mutual_bad'}
local Bad = {'average_worse', 'bad_worse', 'friendzoned_worst', 'good_worse', 'mutual_worst', 'worst_worse'}

local function EnterLove(MyPed, coords, heading)
    WaitingOnBar = true
    height_wanted = 0.0
    local closestPlayer, closestDistance = GetNearestPlayerToMe()

    local AnimRight = 'ANIM_HEIST@ARCADE@LOVE@MALE@RIGHT@'
    local AnimLeft = 'ANIM_HEIST@ARCADE@LOVE@MALE@LEFT@'
    RequestAnimDict(AnimRight)
    RequestAnimDict(AnimLeft)

    while not HasAnimDictLoaded(AnimRight) or not HasAnimDictLoaded(AnimLeft) do Wait(100) end

    local targetPed = GetPlayerPed(closestPlayer)
    if targetPed == 0 then return print('No one Close!') end

    local enterLeft = NetworkCreateSynchronisedScene(coords.x, coords.y, coords.z, 0.0, 0.0, heading, 2, true, false,  1.0, 0.0, 1.0)
    NetworkAddPedToSynchronisedScene(PlayerPedId(), enterLeft, AnimLeft, 'enter', 8.0, -8.0, 0, 0, 1000.0, 0)

    local enterRight = NetworkCreateSynchronisedScene(coords.x, coords.y, coords.z, 0.0, 0.0, heading, 2, true, false,  1.0, 0.0, 1.0)
    NetworkAddPedToSynchronisedScene(targetPed, enterRight, AnimRight, 'enter', 8.0, -8.0, 0, 0, 1000.0, 0)

    NetworkStartSynchronisedScene(enterLeft)
    NetworkStartSynchronisedScene(enterRight)

    CreateThread(function()
        while true do
            Wait(3)
            if IsControlJustPressed(0, 176) then
                break
            end
        end
        local waitingLeft = NetworkCreateSynchronisedScene(coords.x, coords.y, coords.z, 0.0, 0.0, heading, 2, false, true,  1.0, 0.0, 1.0)
        NetworkAddPedToSynchronisedScene(PlayerPedId(), waitingLeft, AnimLeft, 'anticipation', 8.0, -8.0, 0, 0, 1000.0, 0)
    
        local waitingRight = NetworkCreateSynchronisedScene(coords.x, coords.y, coords.z, 0.0, 0.0, heading, 2, false, true,  1.0, 0.0, 1.0)
        NetworkAddPedToSynchronisedScene(targetPed, waitingRight, AnimRight, 'anticipation', 8.0, -8.0, 0, 0, 1000.0, 0)
    
        NetworkStartSynchronisedScene(waitingLeft)
        NetworkStartSynchronisedScene(waitingRight)
        TriggerServerEvent('aj-love:server:CalculateLove', GetPlayerServerId(closestPlayer))
        while WaitingOnBar do Wait(100) end

        local NormalPercentage = height_wanted * 30
        if NormalPercentage > 95 then
            print('Playing Perfect Anim')
            ClapAnim = Prefect[math.random(1, #Prefect)]
        elseif NormalPercentage < 95 and NormalPercentage > 70 then
            print('Playing Good Anim')
            ClapAnim = Good[math.random(1, #Good)]
        elseif NormalPercentage < 70 and NormalPercentage > 45 then
            print('Playing Average Anim')
            ClapAnim = Average[math.random(1, #Average)]
        else
            print('Playing Bad Anim')
            ClapAnim = Bad[math.random(1, #Bad)]
        end

        local ClapLeft = NetworkCreateSynchronisedScene(coords.x, coords.y, coords.z, 0.0, 0.0, heading, 2, false, false,  1.0, 0.0, 1.0)
        NetworkAddPedToSynchronisedScene(PlayerPedId(), ClapLeft, AnimLeft, ClapAnim, 8.0, -8.0, 0, 0, 1000.0, 0)
    
        local ClapRight = NetworkCreateSynchronisedScene(coords.x, coords.y, coords.z, 0.0, 0.0, heading, 2, false, false,  1.0, 0.0, 1.0)
        NetworkAddPedToSynchronisedScene(targetPed, ClapRight, AnimRight, ClapAnim, 8.0, -8.0, 0, 0, 1000.0, 0)
    
        NetworkStartSynchronisedScene(ClapLeft)
        NetworkStartSynchronisedScene(ClapRight)
    end)
end

RegisterCommand('findlove', function()
    local coords = GetEntityCoords(PlayerPedId())
    local Object = GetClosestObjectOfType(coords.x, coords.y, coords.z, 1.0, `ch_prop_arcade_love_01a`)
    EnterLove(PlayerPedId(), GetEntityCoords(Object), GetEntityHeading(Object))
end)

RegisterCommand('c', function()
    ClearPedTasksImmediately(PlayerPedId())
end)