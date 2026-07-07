-- =========================== PHẦN 30: CÁC HÀM GỐC CÒN LẠI ===========================
function BRPlayerCharacterBase:HandleOnMovementModeChangedNew()
    local EMovementMode = import("EMovementMode")
    if Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Swimming and self:CheckBaseIsMoveable() then
        self.CharacterMovement:SetBase(nil, "", true)
    end
    if self.Role == ENetRole.ROLE_AutonomousProxy and Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Walking and UI_Manager.UI_Config_InGame.ParachuteOpenUI then
        UI_Manager.CloseUI(UI_Manager.UI_Config_InGame.ParachuteOpenUI)
    end
end

function BRPlayerCharacterBase:HandleOnAttachedToVehicle(targetVehicle)
    if not slua.isValid(targetVehicle) then return end
    if self.Role == ENetRole.ROLE_SimulatedProxy then
        self:ClearAttachToVehicleTimer()
        self.nUpdatePlayerAttachToVehicleCount = 0
        self.nUpdatePlayerAttachToVehicleTimer = self:AddGameTimer(5, true, function()
            if slua.isValid(self.Object) and slua.isValid(targetVehicle) then
                self:UpdatePlayerAttachToVehicle(targetVehicle)
            end
        end)
        self.nFixMeshContainerTimer = self:AddGameTimer(3, true, function()
            if slua.isValid(self.Object) and slua.isValid(targetVehicle) then
                self:FixMeshContainerOffsetIfNeeded(targetVehicle)
            end
        end)
    end
end

function BRPlayerCharacterBase:HandleOnDetachedFromVehicle(uLastVehicle)
    if not slua.isValid(uLastVehicle) then return end
    if self.Role == ENetRole.ROLE_SimulatedProxy then
        self:ClearAttachToVehicleTimer()
        self.nUpdatePlayerAttachToVehicleCount = 0
    end
end

function BRPlayerCharacterBase:UpdatePlayerAttachToVehicle(targetVehicle)
    if not slua.isValid(self.Object) or not slua.isValid(targetVehicle) then return end
    if not (slua.isValid(self.CapsuleComponent) and slua.isValid(self.Mesh)) or not slua.isValid(self.MeshContainer) then return end
    if not slua.isValid(self:GetCurrentVehicle()) then return end
    if Game:IsDriver(self.Object) then return end
    if not self.nUpdatePlayerAttachToVehicleCount then self.nUpdatePlayerAttachToVehicleCount = 0 end
    
    local ESTEPoseState = import("ESTEPoseState")
    local isStanding = self.PoseState == ESTEPoseState.Stand
    local capsuleLoc = self.CapsuleComponent:GetRelativeTransform():GetLocation()
    local meshLoc = self.Mesh:GetRelativeTransform():GetLocation()
    local meshContainerZ = self.MeshContainer:GetRelativeTransform():GetLocation().Z
    local capsuleRadius = self.CapsuleComponent:GetScaledCapsuleRadius()
    local capsuleHalfHeight = self.CapsuleComponent:GetScaledCapsuleHalfHeight()
    local targetZ = -1 * self.StandHalfHeight
    local stdRadius = self.StandRadius
    local stdHalfHeight = self.StandHalfHeight
    local zeroVec = FVector(0, 0, 0)
    local expectedCapsuleLoc = FVector(0, 0, self.StandHalfHeight)
    local tolerance = 1.0
    local isCapsuleLocCorrect = capsuleLoc:Equals(expectedCapsuleLoc, tolerance)
    local isMeshLocCorrect = meshLoc:Equals(zeroVec, tolerance)
    local isMeshContainerZCorrect = tolerance > math.abs(meshContainerZ - targetZ)
    local isRadiusCorrect = tolerance > math.abs(capsuleRadius - stdRadius)
    local isHalfHeightCorrect = tolerance > math.abs(capsuleHalfHeight - stdHalfHeight)
    local isAllCorrect = isStanding and isCapsuleLocCorrect and isMeshLocCorrect and isMeshContainerZCorrect and isRadiusCorrect and isHalfHeightCorrect
    
    if not isAllCorrect then self.nUpdatePlayerAttachToVehicleCount = self.nUpdatePlayerAttachToVehicleCount + 1 else self.nUpdatePlayerAttachToVehicleCount = 0 end
    
    if self.nUpdatePlayerAttachToVehicleCount >= 3 and not isAllCorrect then
        local PlayerController = GameplayData.GetPlayerController()
        if PlayerController.ReportCrashKitFeature and PlayerController.ReportCrashKitFeature.ReportCharacterAttachedOnVehicleException then
            local errorMsg = string.format("VehicleShapeType:%s PlayerKey:%s. Check Result:%d %d %d %d %d %d. Capsule.RelativeLoc:%s Capsule.Radius:%s Capsule.HalfHeight:%s Mesh.RelativeLoc:%s MeshContainer.RelativeLocZ:%s", 
                tostring(targetVehicle.VehicleShapeType), tostring(self.PlayerKey), 
                isStanding and 1 or 0, isCapsuleLocCorrect and 1 or 0, isMeshLocCorrect and 1 or 0, 
                isMeshContainerZCorrect and 1 or 0, isRadiusCorrect and 1 or 0, isHalfHeightCorrect and 1 or 0, 
                capsuleLoc:ToString(), tostring(capsuleRadius), tostring(capsuleHalfHeight), meshLoc:ToString(), tostring(meshContainerZ))
            PlayerController.ReportCrashKitFeature:ReportCharacterAttachedOnVehicleException(errorMsg)
        end
        self.nUpdatePlayerAttachToVehicleCount = 0
    end
end

function BRPlayerCharacterBase:FixMeshContainerOffsetIfNeeded(targetVehicle)
    if not slua.isValid(self.Object) or not slua.isValid(targetVehicle) then return end
    if not slua.isValid(self.MeshContainer) then return end
    if not slua.isValid(self:GetCurrentVehicle()) then return end
    if Game:IsDriver(self.Object) then return end
    local tolerance = 1.0
    local targetZ = -1 * self.StandHalfHeight
    local currentZ = self.MeshContainer:GetRelativeTransform():GetLocation().Z
    if tolerance <= math.abs(currentZ - targetZ) then
        self:SetMeshContainerOffsetZ(targetZ)
    end
end

function BRPlayerCharacterBase:ClearAttachToVehicleTimer()
    if self.nUpdatePlayerAttachToVehicleTimer then
        self:RemoveGameTimer(self.nUpdatePlayerAttachToVehicleTimer)
        self.nUpdatePlayerAttachToVehicleTimer = nil
    end
    if self.nFixMeshContainerTimer then
        self:RemoveGameTimer(self.nFixMeshContainerTimer)
        self.nFixMeshContainerTimer = nil
    end
end

function BRPlayerCharacterBase:CharacterAttrChangeEvent(uPawn, AttrName, AttrVal)
    BRPlayerCharacterBase.__super.CharacterAttrChangeEvent(self, uPawn, AttrName, AttrVal)
    if self.Object ~= uPawn then return end
    if self.Role == ENetRole.ROLE_AutonomousProxy and AttrName == "bCanSelfRescue" then
        local PlayerController = self:GetPlayerControllerSafety()
        if slua.isValid(PlayerController) then
            PlayerController:BroadcastUIMessage("UIMsg_CanSelfRescue", 0, "", "")
        end
    end
end

function BRPlayerCharacterBase:OnPawnStateChange(PawnState)
    if PawnState == EPawnState.SwitchPP then
        local PlayerController = self:GetPlayerControllerSafety()
        if slua.isValid(PlayerController) then
            PlayerController:BroadcastUIMessage("UIMsg_FPPModeChange", 0, "", "")
        end
    end
end

function BRPlayerCharacterBase:HandleFinishedState()
    if slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.SetDynamicSimpleQueryConfig then
        self.STCharacterMovement:SetDynamicSimpleQueryConfig(false)
    end
end

function BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent()
    if _G.HK_GetVal("NO_LANDING_LAG") == 1 then
        -- Hủy bỏ CheckFallingDistanceComponent ngay khi sinh ra để tránh đo đạc khoảng cách rơi trigger khuỵu gối
        return false
    end
    if CGameMode and CGameMode.GameModeType and CGameState and CGameState.GameModeID then
        local EGameModeType = import("EGameModeType")
        local MatchModeIdsConfig = require("GameLua.Mod.BaseMod.GamePlay.Config.MatchModeIdsConfig")
        local gameModeType = CGameMode.GameModeType
        local gameModeID = tonumber(CGameState.GameModeID)
        local isEligibleMode = gameModeType == EGameModeType.ETypicalGameMode or gameModeType == EGameModeType.EFourInOneGameMode or gameModeType == EGameModeType.EHeavyWeaponGameMode
        local isNotIgnoredId = not MatchModeIdsConfig[gameModeID]
        return isEligibleMode and isNotIgnoredId
    end
    return false
end

function BRPlayerCharacterBase:LuaHandleParachuteStateChanged(LastParachuteState, NewParachuteState)
    BRPlayerCharacterBase.__super.LuaHandleParachuteStateChanged(self, LastParachuteState, NewParachuteState)
    local EParachuteState = import("EParachuteState")
    if not Client then
        local PlayerController = self:GetPlayerControllerSafety()
        if slua.isValid(PlayerController) and PlayerController.CheckParachuteOpenFeature then
            if NewParachuteState == EParachuteState.PS_Opening then
                if PlayerController.CheckParachuteOpenFeature.SatrtCheckShowParachuteCloseUI then
                    PlayerController.CheckParachuteOpenFeature:SatrtCheckShowParachuteCloseUI()
                end
            elseif NewParachuteState == EParachuteState.PS_None then
                if PlayerController.CheckParachuteOpenFeature.RecoverParachuteOpenParam then
                    PlayerController.CheckParachuteOpenFeature:RecoverParachuteOpenParam()
                end
                if PlayerController.CheckParachuteOpenFeature.ClearTimerAndState then
                    PlayerController.CheckParachuteOpenFeature:ClearTimerAndState()
                end
            end
        end
    end
end

function BRPlayerCharacterBase:OnLanded()
    if _G.HK_GetVal("NO_LANDING_LAG") == 1 then
        -- Bước 2: can thiệp trực tiếp vào AnimInstance (dừng mọi montage animation khựng) và STCharacterMovement (reset trạng thái rơi)
        pcall(function()
            if slua.isValid(self.Mesh) then
                local animIns = self.Mesh:GetAnimInstance()
                if slua.isValid(animIns) then
                    animIns:Montage_Stop(0.0) -- Dừng mọi montage animation khựng tiếp đất
                end
            end
            if slua.isValid(self.STCharacterMovement) then
                local EMovementMode = import("EMovementMode")
                self.STCharacterMovement:SetMovementMode(EMovementMode.MOVE_Walking) -- Reset trạng thái rơi về đi bộ
                local velocity = self:GetVelocity()
                if velocity then
                    velocity.Z = 0 -- Triệt tiêu vận tốc rơi thẳng đứng
                end
            end
        end)
    else
        if self.HandleOnLanded then self:HandleOnLanded(-1) end
    end
    if not Client then
        local PlayerController = self:GetPlayerControllerSafety()
        if slua.isValid(PlayerController) and PlayerController.CheckParachuteOpenFeature then
            if PlayerController.CheckParachuteOpenFeature.ClearTimerAndState then
                PlayerController.CheckParachuteOpenFeature:ClearTimerAndState()
            end
            if PlayerController.CheckParachuteOpenFeature.ResetCheckShowUI then
                PlayerController.CheckParachuteOpenFeature:ResetCheckShowUI()
            end
        end
    end
end

function BRPlayerCharacterBase:IsWarGameMode()
    local gameState = GameplayData:GetGameState()
    local STExtraGameStateBase = import("STExtraGameStateBase")
    if slua.isValid(gameState) and Game:IsClassOf(gameState, STExtraGameStateBase) then
        local EGameModeType = import("EGameModeType")
        return gameState.GameModeType == EGameModeType.EWarGameMode
    else
        return false
    end
end

function BRPlayerCharacterBase:BPOnRecycled()
    if Client then self:ResetMeshRelativeLocationAndRotation() end
end

function BRPlayerCharacterBase:BPOnRespawned()
    if Client then self:ResetMeshRelativeLocationAndRotation() end
end

function BRPlayerCharacterBase:ReceiveOnRecycle()
    if Client then
        self:ResetMeshRelativeLocationAndRotation()
        GameplayData.RemoveCharacter(self.Object)
    end
end

function BRPlayerCharacterBase:ReceiveOnSpawn()
    if Client then
        self:ResetMeshRelativeLocationAndRotation()
        GameplayData.AddCharacter(self.Object)
    end
end

function BRPlayerCharacterBase:ResetMeshRelativeLocationAndRotation()
    if Game:IsValid(self.Object) and Game:IsValid(self.Mesh) then
        local defaultRot = FRotator(0, -90, 0)
        local defaultLoc = FVector(0, 0, 0)
        if self.Mesh.K2_SetRelativeRotation then
            self.Mesh:K2_SetRelativeRotation(defaultRot, false, nil, false)
        end
        self:CacheInitialMeshOffset(defaultLoc, defaultRot)
    end
end

function BRPlayerCharacterBase:BPOnMissPlayerDamageRecord() end

function BRPlayerCharacterBase:PreAttachedToVehicle()
    local KismetSystemLibrary = import("KismetSystemLibrary")
    local isDedicated = KismetSystemLibrary.IsDedicatedServer(self)
    if not isDedicated then return end
    local PlayerController = self:GetPlayerControllerSafety()
    if not slua.isValid(PlayerController) then return end
    local avatarComp = self.CharacterAvatarComp2_BP
    if not slua.isValid(avatarComp) then return end
    local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
    local mappedVehicleSkin = CommerAvatarDataUtil:ChangeVehicleSkinByClothes(PlayerController, avatarComp)
    local ESTExtraVehicleShapeType = import("ESTExtraVehicleShapeType")
    if mappedVehicleSkin then
        local AvatarUtils = import("AvatarUtils")
        if AvatarUtils.GetVehicleShapeBySkinID(mappedVehicleSkin) == ESTExtraVehicleShapeType.VST_Horse then
            local PlayerState = self:GetPlayerStateSafety()
            if slua.isValid(PlayerState) then
                PlayerState:AddGeneralCount(468, 1, false)
            end
        end
    end
end

function BRPlayerCharacterBase:ClientRPC_TriggerHighlightMoment(Type, Param)
    EventSystem:postEvent(EVENTTYPE_INGAME, EVENTID_INGAME_TRIGGER_HIGHLIGHT_MOMENT, Type, Param)
end

function BRPlayerCharacterBase:ParachuteJump()
    local PlayerController = self:GetControllerSafety()
    if slua.isValid(PlayerController) then
        if not self:GetEnsure() then
            local EStateType = import("EStateType")
            if PlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteJump and PlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteOpen then
                local ESTEPoseState = import("ESTEPoseState")
                self:SwitchPoseState(ESTEPoseState.Stand, true, true, true, false)
                PlayerController:ReInitParachuteItem()
                PlayerController:ServerChangeStatePC(EStateType.State_ParachuteJump)
            end
        else
            EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_AI_CALL_PARACHUTE_JUMP, self.Object)
        end
    end
end

function BRPlayerCharacterBase:OnMovementBaseChangedEvent(uPawn, uNewMovementBase, uOldMovementBase)
    if uPawn ~= self.Object then return end
    local newCrane = self:GetMedievalCraneFromBase(uNewMovementBase)
    if newCrane and newCrane.AddCharacter then
        newCrane:AddCharacter(self.Object)
    else
        local oldCrane = self:GetMedievalCraneFromBase(uOldMovementBase)
        if oldCrane and oldCrane.RemoveCharacter then
            oldCrane:RemoveCharacter(self.Object)
        end
    end
end

function BRPlayerCharacterBase:GetMedievalCraneFromBase(Base)
    if not slua.isValid(Base) or not Base.GetOwner then return end
    local craneOwner = Base:GetOwner()
    if not slua.isValid(craneOwner) then return end
    if not craneOwner.AddCharacter then return end
    return craneOwner
end

function BRPlayerCharacterBase:CheckForbidFlaregun()
    local PlayerState = self:GetPlayerStateSafety()
    if not slua.isValid(PlayerState) then return false end
    if PlayerState.CanUseFlaregun == false and self:IsLocallyControlled() then
        local PlayerController = self:GetPlayerControllerSafety()
        if slua.isValid(PlayerController) then
            PlayerController:DisplayGameTipWithMsgID(48532)
        end
    end
    return not PlayerState.CanUseFlaregun
end

function BRPlayerCharacterBase:ServerRPC_NearDeathGiveupRescue()
  self:HandleNearDeathGiveupRescue()
end

function BRPlayerCharacterBase:HandleNearDeathGiveupRescue()
  local uNearDeathComp = self.NearDeatchComponent
  if self:IsNearDeath() and slua.isValid(uNearDeathComp) and self.bCanNearDeathGiveup == true then
    local uPlayerState = self:GetPlayerStateSafety()
    if slua.isValid(uPlayerState) then
      uPlayerState:AddGeneralCount(1613, 1, false)
    end
    uNearDeathComp:TriggerGotoDieExplictly(self.Object)
  end
end

function BRPlayerCharacterBase:RPC_Server_GmPlayAction(actionId)
    local STExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
    if STExtraBlueprintFunctionLibrary.IsDevelopment() then
        self:MulticastRPC_GmPlayAction(actionId)
    end
end

function BRPlayerCharacterBase:MulticastRPC_GmPlayAction(actionId)
    if not Client then return end
    local PlayEmoteComponent = self:GetPlayEmoteComponent()
    if not slua.isValid(PlayEmoteComponent) then return end
    local log_filter = require("common.log_filter")
    log_filter.SetLogTreeEnable(true)
    local EmoteBPTable = CDataTable.GetTableData("EmoteBPTable", actionId)
    if not EmoteBPTable then return end
    local assetPath = EmoteBPTable.Path
    local loadedObjectData = slua.loadObject(assetPath)
    local softObjectPathArray = slua.Array(UEnums.EPropertyClass.Struct, import("/Script/CoreUObject.SoftObjectPath"))
    local emoteAssetInstance = loadedObjectData()
    PlayEmoteComponent:OnLoadEmoteAssetBegin(emoteAssetInstance, actionId, softObjectPathArray, "")
    local arrayTable = FuncUtil.LuaArrayToTable(softObjectPathArray)
    local asset_util = require("common.asset_util")
    local onLoadEndCallback = function() PlayEmoteComponent:OnLoadEmoteAssetEnd(emoteAssetInstance, actionId, 0) end
    asset_util.GetAssetsArrayAsyncParallel(arrayTable, onLoadEndCallback)
end

function BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall(bServerSyncShouldCheckPassWall)
    if slua.isValid(self.ParachuteComponent) then
        self.ParachuteComponent.bServerSyncShouldCheckPassWall = bServerSyncShouldCheckPassWall
    end
end

function BRPlayerCharacterBase:OnPlayerEnterCarryBoxState()
    self.Super:OnPlayerEnterCarryBoxState()
    if self.CarryDeadBoxFeature then self.CarryDeadBoxFeature:OnPlayerEnterCarryBoxState() end
end

function BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
    self.Super:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
    if self.CarryDeadBoxFeature then self.CarryDeadBoxFeature:OnPlayerLeaveCarryBoxState(bInIsInterrupt) end
end

function BRPlayerCharacterBase:ServerRPC_CarryDeadBox(uInDeadBox)
    if slua.isValid(uInDeadBox) and Game:IsClassOf(uInDeadBox, import("/Script/ShadowTrackerExtra.PlayerTombBox")) and self.CarryDeadBoxFeature then
        self.CarryDeadBoxFeature:CarryDeadBox(uInDeadBox)
    end
end

function BRPlayerCharacterBase:SetAreaID(AreaID)
    self:SetAttrValue("AreaID", AreaID, -1)
end

function BRPlayerCharacterBase:GetAreaID()
    return math.floor(self:GetAttrValue("AreaID") + 0.5)
end

function BRPlayerCharacterBase:CannotChangeIntoPetSpectator()
    return self.bCannotChangeIntoPetSpectator
end

function BRPlayerCharacterBase:DoModChangeToBT()
    if self:HasState(EPawnState.SpecialSuit) then
        self:TriggerEntrySkillWithID(4301101, true)
    end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteOpening()
    self.Super:SwitchCameraToParachuteOpening()
    if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
        self.ParachuteFormation:OverlayFormationCameraParams()
    end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteFalling()
    self.Super:SwitchCameraToParachuteFalling()
    if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
        self.ParachuteFormation:OverlayFormationCameraParams()
    end
end

function BRPlayerCharacterBase:SwitchCameraToNormal()
    self.Super:SwitchCameraToNormal()
    if self.ParachuteFormation and self.ParachuteFormation.OnLandingClearFormationCamera then
        self.ParachuteFormation:OnLandingClearFormationCamera()
    end
end

function BRPlayerCharacterBase:SwitchWeaponCheck(Slot, IgnoreState)
    if self:HasState(EPawnState.AttachToOther) then
        local weaponSlot = self:GetWeaponBySlot(Slot)
        if slua.isValid(weaponSlot) then
            local weaponID = weaponSlot:GetWeaponID()
            local attachConfig = GamePlayTools.GetCurrentConfig("AttachToOtherConfig")
            if attachConfig and attachConfig.CheckIsWeaponInBlackList and attachConfig.CheckIsWeaponInBlackList(weaponID) then
                local PlayerController = self:GetPlayerControllerSafety()
                if Client and slua.isValid(PlayerController) and PlayerController.Role == ENetRole.ROLE_AutonomousProxy then
                    PlayerController:DisplayGameTipWithMsgID(47306)
                end
                return false
            end
        end
    end
    return self.Super:SwitchWeaponCheck(Slot, IgnoreState)
end
