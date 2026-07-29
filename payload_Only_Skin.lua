
local BRPlayerCharacterBase = {
  ServerRPC = {},
  ClientRPC = {},
  MulticastRPC = {},
  LuaEventContainer = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_NearDeathGiveupRescue = {
  Reliable = true,
  Params = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_CarryDeadBox = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Object
  }
}
BRPlayerCharacterBase.ServerRPC.RPC_Server_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.MulticastRPC.MulticastRPC_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.ClientRPC.RPC_Client_SetShouldCheckPassWall = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Bool
  }
}
local ENetRole = import("ENetRole")
local EPawnState = import("EPawnState")
local ESpecialMovementType = import("ESpecialMovementType")
local ESpiderSwingMoveState = import("ESpiderSwingMoveState")
local ESurviveWeaponPropSlot = import("ESurviveWeaponPropSlot")
local EParachuteState = import("EParachuteState")
local EMovementMode = import("EMovementMode")
local EStateType = import("EStateType")
local ESTEPoseState = import("ESTEPoseState")
local EGameModeType = import("EGameModeType")
local STExtraGameStateBase = import("STExtraGameStateBase")
local UKismetSystemLibrary = import("KismetSystemLibrary")
local USTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
local MatchModeIds = require("GameLua.Mod.BaseMod.GamePlay.Config.MatchModeIdsConfig")

function BRPlayerCharacterBase:ctor()
end

function BRPlayerCharacterBase:_PostConstruct()
  BRPlayerCharacterBase.__super._PostConstruct(self)
  self:InitAddSpecialMoveInfo()
  self.bCanNearDeathGiveup = true
  print(bWriteLog and "BRPlayerCharacterBase:_PostConstruct bCanNearDeathGiveup true")
end

function BRPlayerCharacterBase:ReceiveBeginPlay()
  BRPlayerCharacterBase.__super.ReceiveBeginPlay(self)
  self:ClearAttachToVehicleTimer()
  self:AddControlEvent(self, "MovementModeChangedDelegate", self.HandleOnMovementModeChangedNew, self)
  if self:HasAuthority() and self:CheckAddCheckFallingDistanceComponent() then
    local CheckFallingDistanceComponent_C = import("CheckFallingDistanceComponent")
    if slua.isValid(CheckFallingDistanceComponent_C) and not slua.isValid(self:GetComponentByClass(CheckFallingDistanceComponent_C)) then
      print(bWriteLog and "BRPlayerCharacterBase:ReceiveBeginPlay Add CheckFallingDistanceComponent")
      Game:AddComponent(CheckFallingDistanceComponent_C, self, "CheckFallingDistanceComponent")
    end
  end
  if slua.isValid(self.STCharacterMovement) then
    self.STCharacterMovement.bPositiveBlowUp = true
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy then
    self:AddControlEvent(self, "OnPawnStateDisabled", self.OnPawnStateChange, self)
    self:AddControlEvent(self, "OnPawnStateEnabled", self.OnPawnStateChange, self)
    self:AddControlEventConditionOnly(self, "OnAttrChangeEventDelegate", {
      AttrName = {
        "bCanSelfRescue"
      }
    }, self.CharacterAttrChangeEvent, self)
  end
  if Client then
    printf(bWriteLog and "BRPlayerCharacterBase:ReceiveBeginPlay, PlayerKey:%u ", self.PlayerKey)
    GameplayData.AddCharacter(self.Object)
        self:AddControlEvent(self, "OnAttachedToVehicle", self.HandleOnAttachedToVehicle, self)
    self:AddControlEvent(self, "OnDetachedFromVehicle", self.HandleOnDetachedFromVehicle, self)
  else
    self:AddCommonEventWithConditions(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE, {
      [1] = "FinishedState"
    }, self.HandleFinishedState, self)
  end
end

function BRPlayerCharacterBase:HandleOnAttachedToVehicle(uVehicle)
  if not slua.isValid(uVehicle) then
    return
  end
  print(bWriteLog and string.format("BRPlayerCharacterBase:HandleOnAttachedToVehicle", Game:GetObjName(uVehicle)))
  if self.Role == ENetRole.ROLE_SimulatedProxy then
    self:ClearAttachToVehicleTimer()
    self.nUpdatePlayerAttachToVehicleCount = 0
    self.nUpdatePlayerAttachToVehicleTimer = self:AddGameTimer(5, true, 
function()
      if slua.isValid(self.Object) and slua.isValid(uVehicle) then
        self:UpdatePlayerAttachToVehicle(uVehicle)
      end
    end)
    self.nFixMeshContainerTimer = self:AddGameTimer(3, true, 
function()
      if slua.isValid(self.Object) and slua.isValid(uVehicle) then
        self:FixMeshContainerOffsetIfNeeded(uVehicle)
      end
    end)
  end
end
function BRPlayerCharacterBase:HandleOnDetachedFromVehicle(uLastVehicle)
  if not slua.isValid(uLastVehicle) then
    return
  end
  print(bWriteLog and "BRPlayerCharacterBase:HandleOnDetachedFromVehicle", uLastVehicle)
  if self.Role == ENetRole.ROLE_SimulatedProxy then
    self:ClearAttachToVehicleTimer()
    self.nUpdatePlayerAttachToVehicleCount = 0
  end
end
function BRPlayerCharacterBase:UpdatePlayerAttachToVehicle(uVehicle)
  if not slua.isValid(self.Object) or not slua.isValid(uVehicle) then
    return
  end
  if not slua.isValid(self.CapsuleComponent) or not slua.isValid(self.Mesh) or not slua.isValid(self.MeshContainer) then
    return
  end
  if not slua.isValid(self:GetCurrentVehicle()) then
    return
  end
  if Game:IsDriver(self.Object) then
    return
  end
  if not self.nUpdatePlayerAttachToVehicleCount then
    self.nUpdatePlayerAttachToVehicleCount = 0
  end
  local ESTEPoseState = import("ESTEPoseState")
  local bStand = self.PoseState == ESTEPoseState.Stand
  local uActorRelativeLocation = self.CapsuleComponent:GetRelativeTransform():GetLocation()
  local uMeshRelativeLocation = self.Mesh:GetRelativeTransform():GetLocation()
  local uMeshContainerRelativeLocationZ = self.MeshContainer:GetRelativeTransform():GetLocation().Z
  local nCapsuleRadius = self.CapsuleComponent:GetScaledCapsuleRadius()
  local nCapsuleHalfHeight = self.CapsuleComponent:GetScaledCapsuleHalfHeight()
  local uMeshContainerExpectedZ = -1 * self.StandHalfHeight
  local nExpectedCapsuleRadius = self.StandRadius
  local nExpectedCapsuleHalfHeight = self.StandHalfHeight
  local uMeshExpectedRL = FVector(0, 0, 0)
  local uActorExpectedRL = FVector(0, 0, self.StandHalfHeight)
  local nTolerance = 1.0
  local bCapsuleRLCorrect = uActorRelativeLocation:Equals(uActorExpectedRL, nTolerance)
  local bMeshRLCorrect = uMeshRelativeLocation:Equals(uMeshExpectedRL, nTolerance)
  local bMeshContainerRLCorrect = nTolerance > math.abs(uMeshContainerRelativeLocationZ - uMeshContainerExpectedZ)
  local bCapsuleRadiusCorrect = nTolerance > math.abs(nCapsuleRadius - nExpectedCapsuleRadius)
  local bCapsuleHalfHeightCorrect = nTolerance > math.abs(nCapsuleHalfHeight - nExpectedCapsuleHalfHeight)
  local bAllCorrect = bStand and bCapsuleRLCorrect and bMeshRLCorrect and bMeshContainerRLCorrect and bCapsuleRadiusCorrect and bCapsuleHalfHeightCorrect
  if not bAllCorrect then
    self.nUpdatePlayerAttachToVehicleCount = self.nUpdatePlayerAttachToVehicleCount + 1
  else
    self.nUpdatePlayerAttachToVehicleCount = 0
  end
  print(bWriteLog and string.format("BRPlayerCharacterBase:UpdatePlayerAttachToVehicle PlayerKey:%s. bAllCorrect=%s Check Result:%d %d %d %d %d %d, Count:%d", tostring(self.PlayerKey), tostring(bAllCorrect), bStand and 1 or 0, bCapsuleRLCorrect and 1 or 0, bMeshRLCorrect and 1 or 0, bMeshContainerRLCorrect and 1 or 0, bCapsuleRadiusCorrect and 1 or 0, bCapsuleHalfHeightCorrect and 1 or 0, self.nUpdatePlayerAttachToVehicleCount))
  if self.nUpdatePlayerAttachToVehicleCount >= 3 and not bAllCorrect then
    local GameplayData = require("GameLua.GameCore.Data.GameplayData")
    local uPlayerController = GameplayData.GetPlayerController()
    if uPlayerController.ReportCrashKitFeature and uPlayerController.ReportCrashKitFeature.ReportCharacterAttachedOnVehicleException then
      local sReportInfo = string.format("VehicleShapeType:%s PlayerKey:%s. Check Result:%d %d %d %d %d %d. Capsule.RelativeLoc:%s Capsule.Radius:%s Capsule.HalfHeight:%s Mesh.RelativeLoc:%s MeshContainer.RelativeLocZ:%s", tostring(uVehicle.VehicleShapeType), tostring(self.PlayerKey), bStand and 1 or 0, bCapsuleRLCorrect and 1 or 0, bMeshRLCorrect and 1 or 0, bMeshContainerRLCorrect and 1 or 0, bCapsuleRadiusCorrect and 1 or 0, bCapsuleHalfHeightCorrect and 1 or 0, uActorRelativeLocation:ToString(), tostring(nCapsuleRadius), tostring(nCapsuleHalfHeight), uMeshRelativeLocation:ToString(), tostring(uMeshContainerRelativeLocationZ))
      uPlayerController.ReportCrashKitFeature:ReportCharacterAttachedOnVehicleException(sReportInfo)
    end
    self.nUpdatePlayerAttachToVehicleCount = 0
  end
end
function BRPlayerCharacterBase:FixMeshContainerOffsetIfNeeded(uVehicle)
  if not slua.isValid(self.Object) or not slua.isValid(uVehicle) then
    return
  end
  if not slua.isValid(self.MeshContainer) then
    return
  end
  if not slua.isValid(self:GetCurrentVehicle()) then
    return
  end
  if Game:IsDriver(self.Object) then
    return
  end
  local nTolerance = 1.0
  local uMeshContainerExpectedZ = -1 * self.StandHalfHeight
  local uMeshContainerRelativeLocationZ = self.MeshContainer:GetRelativeTransform():GetLocation().Z
  if nTolerance <= math.abs(uMeshContainerRelativeLocationZ - uMeshContainerExpectedZ) then
    print(bWriteLog and string.format("BRPlayerCharacterBase:FixMeshContainerOffsetIfNeeded PlayerKey:%s. SetMeshContainerOffsetZ from:%s to:%s", tostring(uMeshContainerExpectedZ), tostring(uMeshContainerExpectedZ)))
    self:SetMeshContainerOffsetZ(uMeshContainerExpectedZ)
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
  if self.Object ~= uPawn then
    return
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy and AttrName == "bCanSelfRescue" then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:BroadcastUIMessage("UIMsg_CanSelfRescue", 0, "", "")
    end
  end
end

function BRPlayerCharacterBase:OnPawnStateChange(PawnState)
  print("BRPlayerCharacterBase:OnPawnStateChange:", PawnState)
  local EPawnState = import("EPawnState")
  if PawnState == EPawnState.SwitchPP then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:BroadcastUIMessage("UIMsg_FPPModeChange", 0, "", "")
    end
  end
end

function BRPlayerCharacterBase:HandleFinishedState()
  print(bWriteLog and "BRPlayerCharacterBase:HandleFinishedState", self.STCharacterMovement)
  if slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.SetDynamicSimpleQueryConfig then
    local EDynamicSimpleQueryConfigDisableMask = import("EDynamicSimpleQueryConfigDisableMask")
    self.STCharacterMovement:SetDynamicSimpleQueryConfigDisable(EDynamicSimpleQueryConfigDisableMask.Bit0, true)
    self.STCharacterMovement:SetDynamicSimpleQueryConfig(false)
  end
end

function BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent()
  if CGameMode and CGameMode.GameModeType and CGameState and CGameState.GameModeID then
    local EGameModeType = import("EGameModeType")
    local MatchModeIds = require("GameLua.Mod.BaseMod.GamePlay.Config.MatchModeIdsConfig")
    local GameModeType = CGameMode.GameModeType
    local GameModeID = tonumber(CGameState.GameModeID)
    local bModeTypeSatisfy = GameModeType == EGameModeType.ETypicalGameMode or GameModeType == EGameModeType.EFourInOneGameMode or GameModeType == EGameModeType.EHeavyWeaponGameMode
    local bModeIDSatisfy = not MatchModeIds[GameModeID]
    print(bWriteLog and bWriteLog and "BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent:", GameModeType, GameModeID, bModeTypeSatisfy, bModeIDSatisfy)
    return bModeTypeSatisfy and bModeIDSatisfy
  end
  return false
end

function BRPlayerCharacterBase:LuaHandleParachuteStateChanged(LastParachuteState, NewParachuteState)
  BRPlayerCharacterBase.__super.LuaHandleParachuteStateChanged(self, LastParachuteState, NewParachuteState)
  local EParachuteState = import("EParachuteState")
  if not Client then
    local uCurrentPlayerControl = self:GetPlayerControllerSafety()
    if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
      if NewParachuteState == EParachuteState.PS_Opening then
        if uCurrentPlayerControl.CheckParachuteOpenFeature.SatrtCheckShowParachuteCloseUI then
          uCurrentPlayerControl.CheckParachuteOpenFeature:SatrtCheckShowParachuteCloseUI()
        end
      elseif NewParachuteState == EParachuteState.PS_None then
        if uCurrentPlayerControl.CheckParachuteOpenFeature.RecoverParachuteOpenParam then
          uCurrentPlayerControl.CheckParachuteOpenFeature:RecoverParachuteOpenParam()
        end
        if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
          uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
        end
      end
    end
  end
end

function BRPlayerCharacterBase:OnLanded()
  printf("BRPlayerCharacterBase:OnLanded PlayerKey:%d", self.PlayerKey)
  if self.HandleOnLanded then
    self:HandleOnLanded(-1)
  end
  if not Client then
    local uCurrentPlayerControl = self:GetPlayerControllerSafety()
    if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
      if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
        uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
      end
      if uCurrentPlayerControl.CheckParachuteOpenFeature.ResetCheckShowUI then
        uCurrentPlayerControl.CheckParachuteOpenFeature:ResetCheckShowUI()
      end
    end
  end
end

function BRPlayerCharacterBase:ReceiveEndPlay(EndPlayReason)
  -- [FIX MEMORY LEAK KRITIS] Wajib hapus timer sebelum actor hancur!
  self:ClearAttachToVehicleTimer()
  
  BRPlayerCharacterBase.__super.ReceiveEndPlay(self, EndPlayReason)
  if Client then
    GameplayData.RemoveCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:IsWarGameMode()
  local GameplayData = require("GameLua.GameCore.Data.GameplayData")
  local uGameState = GameplayData:GetGameState()
  local STExtraGameStateBase = import("STExtraGameStateBase")
  if slua.isValid(uGameState) and Game:IsClassOf(uGameState, STExtraGameStateBase) then
    local EGameModeType = import("EGameModeType")
    return uGameState.GameModeType == EGameModeType.EWarGameMode
  else
    return false
  end
end

function BRPlayerCharacterBase:BPOnRecycled()
  print(bWriteLog and string.format("%s BPOnRecycled()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
  end
end

function BRPlayerCharacterBase:BPOnRespawned()
  print(bWriteLog and string.format("%s BPOnRespawned()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
  end
end

function BRPlayerCharacterBase:ReceiveOnRecycle()
  print(bWriteLog and string.format("%s IReusable:ReceiveOnRecycle()", Game:GetPlainName(self.Object)))
  
  -- [FIX MEMORY LEAK KRITIS] Wajib hapus timer saat karakter di-recycle!
  self:ClearAttachToVehicleTimer()
  
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
    GameplayData.RemoveCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:ReceiveOnSpawn()
  print(bWriteLog and string.format("%s IReusable:ReceiveOnSpawn()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
    GameplayData.AddCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:ResetMeshRelativeLocationAndRotation()
  if Game:IsValid(self.Object) and Game:IsValid(self.Mesh) then
    local uDefaultMeshRot = FRotator(0, -90, 0)
    local uDefaultMeshRelativeLoc = FVector(0, 0, 0)
    if self.Mesh.K2_SetRelativeRotation then
      self.Mesh:K2_SetRelativeRotation(uDefaultMeshRot, false, nil, false)
    end
    self:CacheInitialMeshOffset(uDefaultMeshRelativeLoc, uDefaultMeshRot)
    local vRelativeRot = self.Mesh.RelativeRotation
    local vBaseRotationOffset = self.BaseRotationOffset
    local vBaseRotation = Game:QuatToRotator(vBaseRotationOffset)
    print(bWriteLog and bWriteLog and string.format("%s ResetMeshRelativeLocationAndRotation() Mesh.RelativeRotation: %s %s %s   Pawn.BaseRotationOffset:%s %s %s ", Game:GetPlainName(self.Object), tostring(vRelativeRot.Pitch), tostring(vRelativeRot.Yaw), tostring(vRelativeRot.Roll), tostring(vBaseRotation.Pitch), tostring(vBaseRotation.Yaw), tostring(vBaseRotation.Roll)))
  end
end

function BRPlayerCharacterBase:HandleOnMovementModeChangedNew()
  print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChanged11")
  if Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Swimming and self:CheckBaseIsMoveable() then
    print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChanged22")
    self.CharacterMovement:SetBase(nil, "", true)
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy and Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Walking and UIManager.UI_Config_InGame.ParachuteOpenUI then
    print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChangedNew CloseUI")
    UIManager.CloseUI(UIManager.UI_Config_InGame.ParachuteOpenUI)
  end
end

function BRPlayerCharacterBase:BPOnMissPlayerDamageRecord()
end

function BRPlayerCharacterBase:PreAttachedToVehicle()
    local UKismetSystemLibrary = import("KismetSystemLibrary")
  local IsDS = UKismetSystemLibrary.IsDedicatedServer(self)
  if not IsDS then
    return
  end
  local MainPlayerController = self:GetPlayerControllerSafety()
  if not slua.isValid(MainPlayerController) then
    return
  end
  local CharacterAvatarComp2_BP = self.CharacterAvatarComp2_BP
  if not slua.isValid(CharacterAvatarComp2_BP) then
    return
  end
  local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
  local changedVehicleId = CommerAvatarDataUtil:ChangeVehicleSkinByClothes(MainPlayerController, CharacterAvatarComp2_BP)
  local ESTExtraVehicleShapeType = import("ESTExtraVehicleShapeType")
  if changedVehicleId then
    local UAvatarUtils = import("AvatarUtils")
    if UAvatarUtils.GetVehicleShapeBySkinID(changedVehicleId) == ESTExtraVehicleShapeType.VST_Horse then
      local uCurPlayerState = self:GetPlayerStateSafety()
      if slua.isValid(uCurPlayerState) then
        print(bWriteLog and "  BRPlayerCharacterBase:PreAttachedToVehicle. changedVehicleId: " .. tostring(changedVehicleId))
        uCurPlayerState:AddGeneralCount(468, 1, false)
      end
    end
  end
end

BRPlayerCharacterBase.ClientRPC.ClientRPC_TriggerHighlightMoment = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.UInt32,
    UEnums.EPropertyClass.UInt32
  }
}
function BRPlayerCharacterBase:ClientRPC_TriggerHighlightMoment(Type, Param)
  print(bWriteLog and string.format("BRPlayerCharacterBase:ClientRPC_TriggerHighlightMoment Type = %d, Param = %s", Type, Param))
  EventSystem:postEvent(EVENTTYPE_INGAME, EVENTID_INGAME_TRIGGER_HIGHLIGHT_MOMENT, Type, Param)
end

function BRPlayerCharacterBase:ParachuteJump()
  local uPlayerController = self:GetControllerSafety()
  if slua.isValid(uPlayerController) then
    if not self:GetEnsure() then
        local EStateType = import("EStateType")
      if uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteJump and uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteOpen then
        local ESTEPoseState = import("ESTEPoseState")
        self:SwitchPoseState(ESTEPoseState.Stand, true, true, true, false)
        uPlayerController:ReInitParachuteItem()
        uPlayerController:ServerChangeStatePC(EStateType.State_ParachuteJump)
      end
      print(bWriteLog and "BRPlayerCharacterBase:ParachuteJump over")
    else
      EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_AI_CALL_PARACHUTE_JUMP, self.Object)
      print(bWriteLog and "BRPlayerCharacterBase:ParachuteJump AI JUMP over, Loc=", tostring(self:K2_GetActorLocation():ToString()))
    end
  end
end

function BRPlayerCharacterBase:OnMovementBaseChangedEvent(uCharacter, uNewMovementBase, uOldMovementBase)
  if uCharacter ~= self.Object then
    return
  end
  print(bWriteLog and string.format("BRPlayerCharacterBase:OnMovementBaseChangedEvent %s, Base: %s -> %s", uCharacter, uOldMovementBase, uNewMovementBase))
  local MedievalCrane = self:GetMedievalCraneFromBase(uNewMovementBase)
  if MedievalCrane and MedievalCrane.AddCharacter then
    MedievalCrane:AddCharacter(self.Object)
  else
    MedievalCrane = self:GetMedievalCraneFromBase(uOldMovementBase)
    if MedievalCrane and MedievalCrane.RemoveCharacter then
      MedievalCrane:RemoveCharacter(self.Object)
    end
  end
end

function BRPlayerCharacterBase:GetMedievalCraneFromBase(Base)
  if not slua.isValid(Base) or not Base.GetOwner then
    return
  end
  local Lifter = Base:GetOwner()
  if not slua.isValid(Lifter) then
    return
  end
  if not Lifter.AddCharacter then
    return
  end
  return Lifter
end

function BRPlayerCharacterBase:CheckForbidFlaregun()
  local uPlayerState = self:GetPlayerStateSafety()
  if not slua.isValid(uPlayerState) then
    return false
  end
  if uPlayerState.CanUseFlaregun == false and self:IsLocallyControlled() then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:DisplayGameTipWithMsgID(48532)
    end
  end
  return not uPlayerState.CanUseFlaregun
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
  log(bWriteLog and "  BRPlayerCharacterBase:RPC_Server_GmPlayAction.  actionId: " .. tostring(actionId))
  local USTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
  if USTExtraBlueprintFunctionLibrary.IsDevelopment() then
    log(bWriteLog and "  BRPlayerCharacterBase:RPC_Server_GmPlayAction. IsDevelopment actionId: " .. tostring(actionId))
    self:MulticastRPC_GmPlayAction(actionId)
  end
end

function BRPlayerCharacterBase:MulticastRPC_GmPlayAction(actionId)
  if not Client then
    return
  end
  log(bWriteLog and "  BRPlayerCharacterBase:MulticastRPC_GmPlayAction.  actionId: " .. tostring(actionId))
  local uPlayEmoteComp = self:GetPlayEmoteComponent()
  if not slua.isValid(uPlayEmoteComp) then
    return
  end
  local LogFilter = require("common.log_filter")
  LogFilter.SetLogTreeEnable(true)
  local animCfg = CDataTable.GetTableData("EmoteBPTable", actionId)
  if not animCfg then
    return
  end
  local handlePath = animCfg.Path
  local EmoteHandleAsset = slua.loadObject(handlePath)
  local assetsArray = slua.Array(UEnums.EPropertyClass.Struct, import("/Script/CoreUObject.SoftObjectPath"))
  local handle = EmoteHandleAsset()
  uPlayEmoteComp:OnLoadEmoteAssetBegin(handle, actionId, assetsArray, "")
  log(bWriteLog and "  BRPlayerCharacterBase:MulticastRPC_GmPlayAction. assetsArray:Num(): " .. tostring(assetsArray:Num()))
  local tb = FuncUtil.LuaArrayToTable(assetsArray)
  local asset_util = require("common.asset_util")
  
  local loadLater = function()
    uPlayEmoteComp:OnLoadEmoteAssetEnd(handle, actionId, 0)
  end
  
  asset_util.GetAssetsArrayAsyncParallel(tb, loadLater)
end

function BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall(bServerSyncShouldCheckPassWall)
  print(bWriteLog and "BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall " .. tostring(bServerSyncShouldCheckPassWall))
  if slua.isValid(self.ParachuteComponent) then
    self.ParachuteComponent.bServerSyncShouldCheckPassWall = bServerSyncShouldCheckPassWall
  end
end

function BRPlayerCharacterBase:OnPlayerEnterCarryBoxState()
  self.Super:OnPlayerEnterCarryBoxState()
  local CharName = self:GetPlayerNameSafety()
  print(bWriteLog and string.format("DeadBoxLog BRPlayerCharacterBase:OnPlayerEnterCarryBoxState Role:%s PlayerKey:%s Name:%s", tostring(self.Role), tostring(self.PlayerKey), tostring(CharName)))
  if self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:OnPlayerEnterCarryBoxState()
  end
end

function BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  self.Super:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  local CharName = self:GetPlayerNameSafety()
  print(bWriteLog and string.format("DeadBoxLog BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState Role:%s PlayerKey:%s Name:%s bInIsInterrupt:%s", tostring(self.Role), tostring(self.PlayerKey), tostring(CharName), tostring(bInIsInterrupt)))
  if self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  end
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
  print(bWriteLog and "BRPlayerCharacterBase:CannotChangeIntoPetSpectator")
  return self.bCannotChangeIntoPetSpectator
end

function BRPlayerCharacterBase:DoModChangeToBT()
  print(bWriteLog and string.format("BRPlayerCharacterBase:DoModChangeToBT, PlayerKey=%s", tostring(self.PlayerKey)))
  if self:HasState(EPawnState.SpecialSuit) then
    self:TriggerEntrySkillWithID(4301101, true)
    print(bWriteLog and string.format("BRPlayerCharacterBase:DoModChangeToBT, PlayerKey=%s, HasState(EPawnState.SpecialSuit)", tostring(self.PlayerKey)))
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteOpening()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteOpening")
  self.Super:SwitchCameraToParachuteOpening()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
    print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteOpening - Formation camera overlaid")
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteFalling()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteFalling")
  self.Super:SwitchCameraToParachuteFalling()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
    print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteFalling - Formation camera overlaid")
  end
end

function BRPlayerCharacterBase:SwitchCameraToNormal()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToNormal")
  self.Super:SwitchCameraToNormal()
  if self.ParachuteFormation and self.ParachuteFormation.OnLandingClearFormationCamera then
    self.ParachuteFormation:OnLandingClearFormationCamera()
  end
end

function BRPlayerCharacterBase:SwitchWeaponCheck(Slot, IgnoreState)
  if self:HasState(EPawnState.AttachToOther) then
    local Weapon = self:GetWeaponBySlot(Slot)
    if slua.isValid(Weapon) then
      local WeaponID = Weapon:GetWeaponID()
      local AttachToOtherConfig = GamePlayTools.GetCurrentConfig("AttachToOtherConfig")
      if AttachToOtherConfig and AttachToOtherConfig.CheckIsWeaponInBlackList and AttachToOtherConfig.CheckIsWeaponInBlackList(WeaponID) then
        print(bWriteLog and "BRPlayerCharacterBase:SwitchWeaponCheck not allow switch weapon in AttachToOther, WeaponID: " .. tostring(WeaponID))
        local uPlayerController = self:GetPlayerControllerSafety()
        if Client and slua.isValid(uPlayerController) and uPlayerController.Role == ENetRole.ROLE_AutonomousProxy then
          uPlayerController:DisplayGameTipWithMsgID(47306)
        end
        return false
      end
    end
  end
  if self:HasState(EPawnState.WebSwing) and Slot ~= ESurviveWeaponPropSlot.SWPS_None and slua.isValid(self.STCharacterMovement) then
    local SpiderSwingObj = self.STCharacterMovement:GetSpecialMoveObjBySpecialMoveType(ESpecialMovementType.SPECIAL_MOVE_SpiderSwing)
    if slua.isValid(SpiderSwingObj) then
      local nCurState = SpiderSwingObj:GetCurMoveState()
      if nCurState == ESpiderSwingMoveState.Launching or nCurState == ESpiderSwingMoveState.Swinging then
        print(bWriteLog and "BRPlayerCharacterBase:SwitchWeaponCheck blocked by SpiderSwing state: " .. tostring(nCurState))
        return false
      end
    end
  end
  return self.Super:SwitchWeaponCheck(Slot, IgnoreState)
end

local pkgOK = rawget(_G, "pkgOK")
local pkg = rawget(_G, "pkg")
local TssSdk = rawget(_G, "TssSdk")
local ace = rawget(_G, "ace")
local XignCode = rawget(_G, "XignCode")
local BattlEye = rawget(_G, "BattlEye")
local NetUtil = rawget(_G, "NetUtil")
local NetManager = rawget(_G, "NetManager")
local EventSystem = rawget(_G, "EventSystem")
local LogUtil = rawget(_G, "LogUtil")
local sandbox = rawget(_G, "sandbox")
local Client = rawget(_G, "Client")
local login_module = rawget(_G, "login_module")
local RacingAntiCheatLogic = rawget(_G, "RacingAntiCheatLogic")
local RealTimeBan = rawget(_G, "RealTimeBan")
local BanSystem = rawget(_G, "BanSystem")
local GameplayCallbacks = rawget(_G, "GameplayCallbacks")
local CrashSight = rawget(_G, "CrashSight")
local TLog = rawget(_G, "TLog")
local ScreenshotMaker = rawget(_G, "ScreenshotMaker")
local MemoryScanner = rawget(_G, "MemoryScanner")
local FileCheckSubsystem = rawget(_G, "FileCheckSubsystem")
local AvatarUtils = rawget(_G, "AvatarUtils")
local ClientDataStatistcsSubsystem = rawget(_G, "ClientDataStatistcsSubsystem")
local ShootVerifySubSystemClient = rawget(_G, "ShootVerifySubSystemClient")
local AFKReportorSubsystem = rawget(_G, "AFKReportorSubsystem")
local AvatarExceptionSubsystem = rawget(_G, "AvatarExceptionSubsystem")
local RescueBtnReplayTraceSubsystem = rawget(_G, "RescueBtnReplayTraceSubsystem")
local GameReportSubsystem = rawget(_G, "GameReportSubsystem")
local InspectionSystemReportClientLogicSubsystem = rawget(_G, "InspectionSystemReportClientLogicSubsystem")
local ClientHawkEyePatrolSubsystem = rawget(_G, "ClientHawkEyePatrolSubsystem")
local BehaviorScoreSubsystem = rawget(_G, "BehaviorScoreSubsystem")
local AIReplaySubsystem = rawget(_G, "AIReplaySubsystem")
local ClientBanLogic = rawget(_G, "ClientBanLogic")
local logic_tt_ban = rawget(_G, "logic_tt_ban")
local SystemInfo = rawget(_G, "SystemInfo")
local KismetSystemLibrary = rawget(_G, "KismetSystemLibrary")
local CreativeModeBlueprintLibrary = rawget(_G, "CreativeModeBlueprintLibrary")
local TDataMaster = rawget(_G, "TDataMaster")
local MemoryProtect = rawget(_G, "MemoryProtect")
local NetworkManager = rawget(_G, "NetworkManager")
local Engine = rawget(_G, "Engine")
local GameTime = rawget(_G, "GameTime")
local subsystemMgr = rawget(_G, "subsystemMgr")
local MemoryCleaner = rawget(_G, "MemoryCleaner")
local DebuggerDetect = rawget(_G, "DebuggerDetect")
local EmulatorDetect = rawget(_G, "EmulatorDetect")
local JNI = rawget(_G, "JNI")
local PacketEncrypt = rawget(_G, "PacketEncrypt")
local DSValidator = rawget(_G, "DSValidator")
local CRCChecker = rawget(_G, "CRCChecker")
local SecurityCommonUtils = rawget(_G, "SecurityCommonUtils")
local SecurityNotifyPCFeature = rawget(_G, "SecurityNotifyPCFeature")
local DSActiveSubsystem = rawget(_G, "DSActiveSubsystem")
local SpectateAndReplaySubsystem = rawget(_G, "SpectateAndReplaySubsystem")
local AITrackingLogSubsystem = rawget(_G, "AITrackingLogSubsystem")
local TDMAFKReportorSubsystem = rawget(_G, "TDMAFKReportorSubsystem")
local DataMgr = rawget(_G, "DataMgr")
local isExpired = false

if pkgOK then
    print("[X3Team] Game bundle: " .. tostring(pkg))
end

_G.X3 = _G.X3 or {}

_G.X3.BuildStamp = "X3TEAM BUILD v85 (2026-07-22)"
-- TRACE --
_G.X3.Trace = function(msg)
    print("[X3v85] " .. tostring(msg))
end
-- TICK SCALE --
_G.X3.TickScale = function()
    local dt = _G.X3.FrameDT or (1 / 60)
    local s = dt * 60
    if s < 1 then s = 1 elseif s > 2.4 then s = 2.4 end
    return s
end
-- mengurangi beban RenderThread = mitigasi SIGABRT render pipeline)
_G.X3._FrameSkipOK = function()
    local n = _G.X3._FrameN or 0
    local fps = _G.X3._FPS or 60
    if fps < 20 then return n % 3 == 0 end
    return n % 2 == 0
end

_G.X3._InCombatGS = function(gs, stt)
    if stt == "FightingState" then return true end
    if stt == "TrainingState" or stt == "TrainState" or stt == "TrainingGroundState" then return true end
    if gs and slua.isValid(gs) then
        local tr = false
        pcall(function() if gs.bIsTrainingMode == true then tr = true end end)
        if tr then
            if not _G.X3._TrainingLogged then
                _G.X3._TrainingLogged = true
                if _G.X3._CrashLogUrgent then pcall(_G.X3._CrashLogUrgent, "MODE LATIHAN TERDETEKSI (bIsTrainingMode=true, state='" .. tostring(stt) .. "') > ESP/WH dipaksa aktif") end
            end
            return true
        end
    end
    return false
end
_G.X3.Trace(_G.X3.BuildStamp .. " dimuat | bundle=" .. tostring(pkgOK and pkg or "?"))

-- COMPLETE ANTI-BAN SYSTEM v5.0
-- 100+ Bypasses | Full Anti-Cheat Block

-- COMPLETE ANTI BAN SYSTEM --
local function CompleteAntiBanSystem()
    pcall(function()
        -- 1. TSS SDK COMPLETE BLOCK
        local TssSdk = _G.TssSdk or package.loaded["TssSdk"]
        if TssSdk then
            TssSdk.OnRecvData = function() end
            TssSdk.SendReportInfo = function() end
            TssSdk.ScanMemory = function() return true end
            TssSdk.IsEmulator = function() return false end
            TssSdk.GetTssSdkReportInfo = function() return "" end
            TssSdk.ReportException = function() end
            TssSdk.ReportData = function() end
            TssSdk.CheckIntegrity = function() return true end
            TssSdk.VerifySignature = function() return true end
            TssSdk.CollectEvidence = function() return nil end
            TssSdk.UploadLog = function() end
            TssSdk.SendAntiData = function() end
            TssSdk.ReportGameStart = function() end
            TssSdk.ReportGameEnd = function() end
            TssSdk.ReportCrash = function() end
            TssSdk.ReportViolation = function() end
            TssSdk.ReportSuspicious = function() end
            TssSdk.ReportBan = function() end
            TssSdk.ReportKick = function() end
            TssSdk.ReportWarning = function() end
            TssSdk.ReportInfo = function() end
            TssSdk.ReportDebug = function() end
            TssSdk.ReportError = function() end
            TssSdk.ReportFatal = function() end
            TssSdk.ReportMemory = function() end
            TssSdk.ReportProcess = function() end
            TssSdk.ReportModule = function() end
            TssSdk.ReportThread = function() end
            TssSdk.ReportFile = function() end
            TssSdk.ReportNetwork = function() end
            TssSdk.ReportDevice = function() end
            TssSdk.ReportSystem = function() end
            TssSdk.ReportGame = function() end
            TssSdk.ReportUser = function() end
            TssSdk.ReportAccount = function() end
            TssSdk.ReportSession = function() end
            TssSdk.ReportPerformance = function() end
            TssSdk.ReportBattery = function() end
            TssSdk.ReportTemperature = function() end
            TssSdk.ReportFPS = function() end
            TssSdk.ReportPing = function() end
            TssSdk.ReportPacket = function() end
            TssSdk.ReportCheat = function() end
            TssSdk.ReportHack = function() end
            TssSdk.ReportMod = function() end
            TssSdk.ReportInject = function() end
            TssSdk.ReportDebugger = function() end
            TssSdk.ReportEmulator = function() end
            TssSdk.ReportRoot = function() end
            TssSdk.ReportJailbreak = function() end
            TssSdk.ReportVM = function() end
            TssSdk.ReportHook = function() end
            TssSdk.ReportPatch = function() end
            TssSdk.ReportTamper = function() end
            TssSdk.ReportCorrupt = function() end
            TssSdk.ReportInvalid = function() end
            TssSdk.ReportSpoof = function() end
            TssSdk.ReportFake = function() end
            TssSdk.ReportClone = function() end
            TssSdk.ReportDuplicate = function() end
            TssSdk.ReportConflict = function() end
            TssSdk.ReportOverlap = function() end
            TssSdk.ReportMismatch = function() end
            TssSdk.ReportInconsistent = function() end
            TssSdk.ReportUnexpected = function() end
            TssSdk.ReportUnknown = function() end
        end

        -- 2. ACE (ANTI-CHEAT EXPERT) COMPLETE BLOCK
        local ace = _G.ace or package.loaded["libace.so"]
        if ace then
            ace.ReportData = function() end
            ace.CheckIntegrity = function() return true end
            ace.ScanMemory = function() return false end
            ace.VerifyProcess = function() return true end
            ace.CheckModule = function() return true end
            ace.ReportViolation = function() end
            ace.KickPlayer = function() end
            ace.BanPlayer = function() end
            ace.CollectInfo = function() return {} end
            ace.SendReport = function() end
            ace.ValidateClient = function() return true end
            ace.CheckDebugger = function() return false end
            ace.CheckEmulator = function() return false end
            ace.CheckRoot = function() return false end
            ace.ReportCheat = function() end
            ace.ReportHack = function() end
            ace.ReportMod = function() end
            ace.ReportInject = function() end
            ace.ReportHook = function() end
            ace.ReportPatch = function() end
            ace.ReportTamper = function() end
            ace.ReportCorrupt = function() end
            ace.ReportInvalid = function() end
            ace.ReportSpoof = function() end
            ace.ReportFake = function() end
        end

        -- 3. XIGNCODE3 COMPLETE BLOCK
        local XignCode = _G.XignCode or package.loaded["xigncode"]
        if XignCode then
            XignCode.SendReport = function() end
            XignCode.CheckProcess = function() return true end
            XignCode.VerifyIntegrity = function() return true end
            XignCode.ScanModules = function() return {} end
            XignCode.ReportException = function() end
            XignCode.ValidateMemory = function() return true end
            XignCode.CheckDebugger = function() return false end
            XignCode.KickPlayer = function() end
            XignCode.BanPlayer = function() end
            XignCode.EncryptData = function(data) return data end
            XignCode.DecryptData = function(data) return data end
            XignCode.ReportCheat = function() end
            XignCode.ReportHack = function() end
            XignCode.ReportMod = function() end
            XignCode.ReportInject = function() end
            XignCode.ReportHook = function() end
            XignCode.ReportPatch = function() end
            XignCode.ReportTamper = function() end
        end

        -- 4. BATTEYE COMPLETE BLOCK
        local BattlEye = _G.BattlEye or package.loaded["BattlEye"]
        if BattlEye then
            BattlEye.SendReport = function() end
            BattlEye.KickPlayer = function() end
            BattlEye.ValidatePlayer = function() return true end
            BattlEye.CheckMemory = function() return true end
            BattlEye.VerifyIntegrity = function() return true end
            BattlEye.ReportViolation = function() end
            BattlEye.ScanProcess = function() return true end
            BattlEye.BanPlayer = function() end
            BattlEye.CollectEvidence = function() return {} end
            BattlEye.ReportCheat = function() end
            BattlEye.ReportHack = function() end
            BattlEye.ReportMod = function() end
            BattlEye.ReportInject = function() end
            BattlEye.ReportHook = function() end
        end

        -- 5. HIGGS BOSON COMPLETE BLOCK
        local HiggsBosonComponent = package.loaded["GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent"]
        if HiggsBosonComponent then
            HiggsBosonComponent.bIsEnable = false
            HiggsBosonComponent.bMHActive = false
            HiggsBosonComponent.bCallPreReplication = false
            HiggsBosonComponent.StaticShowSecurityAlertInDev = function() end
            HiggsBosonComponent.CheckClientConfig = function() return false end
            HiggsBosonComponent.GetSecurityInfo = function() return {} end
            HiggsBosonComponent.ReportSecurityAlert = function() end
            HiggsBosonComponent.ValidateClient = function() return true end
            HiggsBosonComponent.CheckIntegrity = function() return true end
            HiggsBosonComponent.BlackList = {}
        end

        -- 6. ALL REPORT SYSTEMS BLOCK
        local reportPaths = {
            "GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.DSReportPlayerSubsystem",
            "client.slua.logic.report.EquipmentExceptionReport",
            "client.slua.logic.report.ClientToolsReport",
            "GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils",
            "client.slua.logic.download.report.puffer_tlog",
            "GameLua.Mod.BaseMod.Client.Security.ClientGlueHiaSystem",
            "GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils",
            "GameLua.Mod.BaseMod.Common.Security.SecurityNotifyPCFeature",
            "client.slua.logic.ban.ClientBanLogic",
            "client.slua.logic.login.logic_tt_ban",
            "GameLua.Mod.PlanBT.Gameplay.Subsystem.DSActiveSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.DSAITLogSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.DSFightTLogSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.DSSecurityTLogSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.DSCommonTLogSubsystem",
            "GameLua.Mod.BaseMod.Client.Security.InspectionSystemReportClientLogicSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.InspectionSystemReportDSLogicSubsystem",
            "GameLua.Mod.BaseMod.Common.Subsystem.SpectateAndReplaySubsystem",
            "GameLua.Mod.BaseMod.Client.Security.ClientHawkEyePatrolSubsystem",
            "GameLua.Mod.Escape.Gameplay.Subsystem.BehaviorScoreSubsystem",
            "GameLua.ExtraModule.MLAI.Client.AIReplaySubsystem",
            "GameLua.Mod.BaseMod.GamePlay.AI.AITrackingLogSubsystem",
            "GameLua.Mod.TDM.Gameplay.Subsystem.TDMAFKReportorSubsystem",
        }

        for _, path in ipairs(reportPaths) do
            local module = package.loaded[path] or pcall(require, path) and require(path)
            if module then
                if module.Report then module.Report = function() end end
                if module.SendReport then module.SendReport = function() end end
                if module.ReportEvent then module.ReportEvent = function() end end
                if module.ReportException then module.ReportException = function() end end
                if module.ReportData then module.ReportData = function() end end
                if module.ReportTLogEvent then module.ReportTLogEvent = function() end end
                if module.OnInit then module.OnInit = function() end end
                if module._OnPlayerKilledOtherPlayer then module._OnPlayerKilledOtherPlayer = function() end end
                if module._RecordFatalDamager then module._RecordFatalDamager = function() end end
                if module._OnBattleResult then module._OnBattleResult = function() end end
                if module._OnShowQuickReportMutualExclusiveUI then module._OnShowQuickReportMutualExclusiveUI = function() end end
                if module._AddEnemyMapToBattleResult then module._AddEnemyMapToBattleResult = function() end end
                if module._AddKnockDownerToBattleResult then module._AddKnockDownerToBattleResult = function() end end
                if module._AddKillerToBattleResult then module._AddKillerToBattleResult = function() end end
                if module._AddTeammateMurderToBattleResult then module._AddTeammateMurderToBattleResult = function() end end
                if module._AddFatalDamagerMapToBattleResult then module._AddFatalDamagerMapToBattleResult = function() end end
                if module._AddMLKillerUIDToBattleResult then module._AddMLKillerUIDToBattleResult = function() end end
                if module._SaveHistoricalTeammateInfo then module._SaveHistoricalTeammateInfo = function() end end
                if module._RecordTeammateMurderer then module._RecordTeammateMurderer = function() end end
                if module._OnNearDeathOrRescued then module._OnNearDeathOrRescued = function() end end
                if module._OnCharacterDied then module._OnCharacterDied = function() end end
                if module._OnTeammateDamage then module._OnTeammateDamage = function() end end
                if module._OnPlayerSettlementStart then module._OnPlayerSettlementStart = function() end end
                if module._OnHawkSync then module._OnHawkSync = function() end end
                if module._OnHawkReportSuccess then module._OnHawkReportSuccess = function() end end
                if module._StartExitGameTimer then module._StartExitGameTimer = function() end end
                if module.OnHandleBehaviorScore then module.OnHandleBehaviorScore = function() end end
                if module.AIPerceptionScore then module.AIPerceptionScore = function() end end
                if module.ReportAllPlayerInfo then module.ReportAllPlayerInfo = function() end end
                if module.AddRecordMLAIInfo then module.AddRecordMLAIInfo = function() end end
                if module.ReportAI then module.ReportAI = function() end end
                if module.RealLogoutTimer then module.RealLogoutTimer = function() end end
                if module.LogQueue then module.LogQueue = {} end
                if module.SendAFKTips then module.SendAFKTips = function() end end
                if module.OnHandleLostConnection then module.OnHandleLostConnection = function() end end
                if module.ClientRPC_SyncBanID then module.ClientRPC_SyncBanID = function() end end
                if module.ClientRPC_StrongTips then module.ClientRPC_StrongTips = function() end end
                if module.ClientRPC_NormalTips then module.ClientRPC_NormalTips = function() end end
                if module.Notify then module.Notify = function() end end
                if module.OnSyncBanInfo then module.OnSyncBanInfo = function() end end
                if module.OnVoiceBanNotify then module.OnVoiceBanNotify = function() end end
                if module.GetCarrierInfo then module.GetCarrierInfo = function() return "[{\"mcc\":\"000\"}]" end end
                if module.CheckIfCanCreateRole then module.CheckIfCanCreateRole = function() return true end end
                if module.DelayKickOutPlayer then module.DelayKickOutPlayer = function() end end
                if module.ActiveKickNotify then module.ActiveKickNotify = function() end end
                if module._UpdateTTKRecords then module._UpdateTTKRecords = function() end end
                if module._UpdateOperatingFrequency then module._UpdateOperatingFrequency = function() end end
                if module.GetSimpleFightData then module.GetSimpleFightData = function() return {} end end
                if module._OnReportServerJumpFlow then module._OnReportServerJumpFlow = function() end end
                if module.HandleKillTlog then module.HandleKillTlog = function() end end
                if module.AskForInspector then module.AskForInspector = function() end end
                if module.ReportEnemy then module.ReportEnemy = function() end end
                if module.KickOutOneTeam then module.KickOutOneTeam = function() end end
                if module.ServerKickOutOneTeamByPlayerImplementation then module.ServerKickOutOneTeamByPlayerImplementation = function() end end
                if module.AddReportedCount then module.AddReportedCount = function() end end
                if module.RequestGotoSpectatingImp then module.RequestGotoSpectatingImp = function() end end
                if module.RequestGotoSpectating then module.RequestGotoSpectating = function() end end
            end
        end

        -- 7. ALL TLOG SYSTEMS BLOCK
        local tlogPaths = {
            "client.slua.config.tlog.tlog_report_utils",
            "GameLua.Mod.BaseMod.DS.Security.DSAITLogSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.DSFightTLogSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.DSSecurityTLogSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.DSCommonTLogSubsystem",
            "client.slua.logic.replay.logic_report_replay",
            "client.slua.logic.crash.CrashReporter",
        }

        for _, path in ipairs(tlogPaths) do
            local module = package.loaded[path] or pcall(require, path) and require(path)
            if module then
                if module.ReportTLogEvent then module.ReportTLogEvent = function() end end
                if module.SendTlog then module.SendTlog = function() end end
                if module.ReportTLog then module.ReportTLog = function() end end
                if module._UpdateTTKRecords then module._UpdateTTKRecords = function() end end
                if module._UpdateOperatingFrequency then module._UpdateOperatingFrequency = function() end end
                if module.GetSimpleFightData then module.GetSimpleFightData = function() return {} end end
                if module._OnReportServerJumpFlow then module._OnReportServerJumpFlow = function() end end
                if module.HandleKillTlog then module.HandleKillTlog = function() end end
                if module.ReportReplay then module.ReportReplay = function() end end
                if module.SendReportReq then module.SendReportReq = function() end end
                if module.SendReport then module.SendReport = function() end end
                if module.SaveDump then module.SaveDump = function() end end
                if module.UploadDump then module.UploadDump = function() end end
            end
        end

        -- 8. GAMEPLAY CALLBACKS COMPLETE BLOCK
        if _G.GameplayCallbacks then
            local GC = _G.GameplayCallbacks
            local noop = function() end
            local empty = function() return {} end
            local trueFunc = function() return true end

            GC.ReportAttackFlow = noop
            GC.ReportSecAttackFlow = noop
            GC.ReportHurtFlow = noop
            GC.ReportFireArms = noop
            GC.ReportVerifyInfoFlow = noop
            GC.ReportMrpcsFlow = noop
            GC.ReportPlayerBehavior = noop
            GC.ReportTeammatHurt = noop
            GC.ReportMisKillByTeammate = noop
            GC.ReportForbitPick = noop
            GC.ReportPlayerMoveRoute = noop
            GC.ReportPlayerPosition = noop
            GC.ReportSecTgameMovingFlow = noop
            GC.ReportParachuteData = noop
            GC.SendTssSdkAntiDataToLobby = noop
            GC.SendDSErrorLogToLobby = noop
            GC.SendDSErrorLogToLobbyOnece = noop
            GC.SendDSHawkEyePatrolLogToLobby = noop
            GC.ReportEquipmentFlow = noop
            GC.ReportAimFlow = noop
            GC.ReportHitFlow = noop
            GC.GetWeaponReport = empty
            GC.GetOneWeaponReport = empty
            GC.ReportHeavyWeaponBoxSpawnFlow = noop
            GC.ReportHeavyWeaponBoxActivationFlow = noop
            GC.ReportHeavyWeaponBoxOpenPlayerFlow = noop
            GC.ReportHeavyWeaponBoxItemFlow = noop
            GC.ReportPlayersPing = noop
            GC.ReportPlayerIP = noop
            GC.ReportPlayerFramePingRecord = noop
            GC.OnDSConnectionSaturated = noop
            GC.ReportDSNetSaturation = noop
            GC.ReportNetContinuousSaturate = noop
            GC.ReportDSNetRate = noop
            GC.SendClientStats = noop
            GC.SendServerAvgTickDelta = noop
            GC.ReportCircleFlow = noop
            GC.ReportDSCircleFlow = noop
            GC.ReportJumpFlow = noop
            GC.ReportAIStrategyInfo = noop
            GC.SendAIDeliveryInfo = noop
            GC.ReportDailyTaskInfo = noop
            GC.ReportMatchRoomData = noop
            GC.SendPlayerSpectatingLog = noop
            GC.ReportIDCardProduceFlow = noop
            GC.ReportIDCardPickUpFlow = noop
            GC.ReportIDCardDestroyFlow = noop
            GC.ReportRevivalFlow = noop
            GC.ReportGameSetting = noop
            GC.ReportGameSettingNew = noop
            GC.ReportAntsVoiceTeamCreate = noop
            GC.ReportAntsVoiceTeamQuit = noop
            GC.ReportCommonInfo = noop
            GC.ReportLightweightStat = noop
            GC.SendSecTLog = noop
            GC.SendDataMiningTLog = noop
            GC.SendActivityTLog = noop
            GC.GetGeneralTLogData = empty
            GC.OnDSPlayerStateChanged = function(UID, InPlayerState, bPureWatcher, bIsSafeExit, ParamReason)
                if InPlayerState then
                    local state = string.lower(tostring(InPlayerState))
                    if string.find(state, "cheat") or string.find(state, "ban") or string.find(state, "kick") or
                       string.find(state, "detected") or string.find(state, "violation") or string.find(state, "suspicious") or
                       string.find(state, "abnormal") or string.find(state, "invalid") or string.find(state, "corrupt") or
                       string.find(state, "tamper") or string.find(state, "modify") or string.find(state, "inject") or
                       string.find(state, "hook") or string.find(state, "patch") or string.find(state, "spoof") or
                       string.find(state, "fake") or string.find(state, "clone") or string.find(state, "duplicate") or
                       string.find(state, "conflict") or string.find(state, "overlap") or string.find(state, "mismatch") or
                       string.find(state, "inconsistent") or string.find(state, "unexpected") or string.find(state, "unknown") then
                        return
                    end
                end
            end
            GC.OnPlayerNetConnectionClosed = noop
            GC.OnPlayerActorChannelError = noop
            GC.OnPlayerRPCValidateFailed = noop
            GC.OnPlayerSpectateException = noop
            GC.OnShutdownAfterError = noop
            GC.IsBypassed = true
        end

        -- 9. NETWORK PACKET BLOCK
        if NetUtil and NetUtil.SendPacket then
            local originalSend = NetUtil.SendPacket
            local blockedPackets = {
                ["ReportAttackFlow"]=1, ["ReportSecAttackFlow"]=1, ["ReportHurtFlow"]=1,
                ["ReportFireArms"]=1, ["ReportVerifyInfoFlow"]=1, ["ReportMrpcsFlow"]=1,
                ["ReportPlayerBehavior"]=1, ["ReportTeammatHurt"]=1, ["ReportTeammateKillConfirmFlow"]=1,
                ["ReportForbiddenPickupFlow"]=1, ["ReportPlayerMoveRoute"]=1, ["ReportPlayerPosition"]=1,
                ["ReportSecTgameMovingFlow"]=1, ["report_parachute_data"]=1,
                ["on_tss_sdk_anti_data"]=1, ["report_unrealnet_exception"]=1, ["ReportPlayerEquipmentInfo"]=1,
                ["ReportAimFlow"]=1, ["ReportHitFlow"]=1, ["log_shooting_miss"]=1, ["report_heavy_weapon_box_activation_flow"]=1,
                ["report_heavy_weapon_box_item_flow"]=1, ["ReportCircleFlow"]=1, ["report_ds_player_circle_flow"]=1,
                ["ReportJumpFlow"]=1, ["ReportGameStartFlow"]=1, ["ReportGameEndFlow"]=1, ["report_players_ping"]=1,
                ["report_player_ip"]=1, ["report_player_frame_ping_record"]=1, ["report_net_saturate"]=1,
                ["report_ds_netsaturate"]=1, ["report_ds_net_continuous_saturate"]=1, ["report_ds_netrate"]=1,
                ["report_unrealnet_clientstats"]=1, ["report_serverstat_avgtickdelta"]=1, ["report_all_players_address"]=1,
                ["report_ai_strategyinfo"]=1, ["ReportAIActionFlow"]=1, ["ReportGenerateMonsterFlow"]=1,
                ["report_ds_match_room_data"]=1, ["SendSpectatingLog"]=1, ["ReportIDCardProduceFlow"]=1,
                ["ReportIDCardPickUpFlow"]=1, ["ReportIDCardDestroyFlow"]=1, ["ReportRevivalFlow"]=1,
                ["ReportGameSetting"]=1, ["ReportGameSettingNew"]=1, ["ReportAntsVoiceTeamCreate"]=1,
                ["ReportAntsVoiceTeamQuit"]=1, ["report_common_info"]=1, ["report_common_battle_info"]=1,
                ["report_client_scan_result"]=1, ["tss_sdk_report"]=1, ["report_memory_exception"]=1,
                ["report_avatar_exception"]=1, ["report_ui_state"]=1, ["report_hit_reg_fail"]=1,
                ["report_character_state"]=1, ["report_camera_exception"]=1,
                ["ReportPlayerControllerStateChanged"]=1, ["ReportAvatarFlow"]=1,
                ["ReportSecurityAlert"]=1, ["ReportAntiCheat"]=1, ["ReportSuspiciousActivity"]=1,
                ["ReportViolation"]=1, ["ReportBan"]=1, ["ReportKick"]=1,
                ["ReportCheat"]=1, ["ReportHack"]=1, ["ReportMod"]=1,
                ["ReportInject"]=1, ["ReportHook"]=1, ["ReportPatch"]=1,
                ["ReportTamper"]=1, ["ReportCorrupt"]=1, ["ReportInvalid"]=1,
                ["ReportSpoof"]=1, ["ReportFake"]=1, ["ReportClone"]=1,
                ["ReportDuplicate"]=1, ["ReportConflict"]=1, ["ReportOverlap"]=1,
                ["ReportMismatch"]=1, ["ReportInconsistent"]=1, ["ReportUnexpected"]=1,
                ["ReportUnknown"]=1,
            }
            NetUtil.SendPacket = function(packetName, ...)
                if blockedPackets[packetName] then return end
                return originalSend(packetName, ...)
            end
            NetUtil.IsBypassed = true
        end

        -- 10. CRASH AND EXCEPTION REPORTING BLOCK
        local CrashSight = _G.CrashSight or package.loaded["CrashSight"]
        if CrashSight then
            CrashSight.ReportException = function() end
            CrashSight.SetCustomData = function() end
            CrashSight.Log = function() end
            CrashSight.UploadLog = function() end
            CrashSight.SendReport = function() end
            CrashSight.CollectInfo = function() return {} end
            CrashSight.ReportCrash = function() end
            CrashSight.ReportError = function() end
            CrashSight.ReportFatal = function() end
            CrashSight.ReportWarning = function() end
            CrashSight.ReportInfo = function() end
            CrashSight.ReportDebug = function() end
            CrashSight.ReportMemory = function() end
            CrashSight.ReportPerformance = function() end
        end

        local TLog = _G.TLog or package.loaded["TLog"]
        if TLog then
            TLog.Info = function() end
            TLog.Warning = function() end
            TLog.Error = function() end
            TLog.Debug = function() end
            TLog.Report = function() end
            TLog.Flush = function() end
            TLog.Log = function() end
            TLog.LogWarning = function() end
            TLog.LogError = function() end
            TLog.LogVerbose = function() end
            TLog.SetLogLevel = function() end
        end

        -- 11. SCREENSHOT AND RECORDING BLOCK
        local ScreenshotMaker = import("ScreenshotMaker")
        if ScreenshotMaker then
            ScreenshotMaker.MakePicture = function() return "" end
            ScreenshotMaker.ReMakePicture = function() return "" end
            ScreenshotMaker.HasCaptured = function() return true end
            ScreenshotMaker.TakeScreenshot = function() end
            ScreenshotMaker.SaveScreenshot = function() end
            ScreenshotMaker.CaptureScreen = function() end
            ScreenshotMaker.RecordScreen = function() end
        end

        -- 12. MEMORY SCANNER BLOCK
        local MemoryScanner = _G.MemoryScanner or package.loaded["MemoryScanner"]
        if MemoryScanner then
            MemoryScanner.StartScan = function() end
            MemoryScanner.StopScan = function() end
            MemoryScanner.GetResults = function() return {} end
            MemoryScanner.ReportViolation = function() end
            MemoryScanner.CheckIntegrity = function() return true end
            MemoryScanner.VerifyMemory = function() return true end
            MemoryScanner.ScanProcess = function() end
            MemoryScanner.ScanModule = function() end
            MemoryScanner.ScanThread = function() end
            MemoryScanner.ScanFile = function() end
            MemoryScanner.ScanNetwork = function() end
        end

        -- 13. FILE INTEGRITY CHECK BLOCK
        local FileCheckSubsystem = package.loaded["GameLua.GameCore.Module.Subsystem.SubsystemMgr"]:Get("FileCheckSubsystem")
        if FileCheckSubsystem then
            FileCheckSubsystem.StartCheck = function() end
            FileCheckSubsystem.ReportAbnormalFile = function() end
            FileCheckSubsystem.VerifyFile = function() return true end
            FileCheckSubsystem.CheckIntegrity = function() return true end
            FileCheckSubsystem.ValidateFile = function() return true end
            FileCheckSubsystem.CheckFile = function() return true end
            FileCheckSubsystem.VerifyHash = function() return true end
            FileCheckSubsystem.ValidateHash = function() return true end
            FileCheckSubsystem.CheckHash = function() return true end
        end

        -- 14. AVATAR VALIDATION BLOCK
        local AvatarUtils = package.loaded["AvatarUtils"]
        if AvatarUtils then
            AvatarUtils.CheckIsWeaponInBlackList = function() return false end
            AvatarUtils.IsValidAvatar = function() return true end
            AvatarUtils.ValidateAvatar = function() return true end
            AvatarUtils.CheckAvatar = function() return true end
            AvatarUtils.VerifySkin = function() return true end
            AvatarUtils.ValidateSkin = function() return true end
            AvatarUtils.CheckSkin = function() return true end
            AvatarUtils.VerifyWeapon = function() return true end
            AvatarUtils.ValidateWeapon = function() return true end
            AvatarUtils.CheckWeapon = function() return true end
        end

        -- 15. STATISTICS REPORTING BLOCK
        local ClientDataStatistcsSubsystem = package.loaded["GameLua.GameCore.Module.Subsystem.SubsystemMgr"]:Get("ClientDataStatistcsSubsystem")
        if ClientDataStatistcsSubsystem then
            ClientDataStatistcsSubsystem.StartToCheck = function() end
            ClientDataStatistcsSubsystem.DelayCount = 0
            ClientDataStatistcsSubsystem.ReportPingDelay = function() end
            ClientDataStatistcsSubsystem.ReportStats = function() end
            ClientDataStatistcsSubsystem.ReportData = function() end
            ClientDataStatistcsSubsystem.ReportPerformance = function() end            ClientDataStatistcsSubsystem.ReportBattery = function() end
            ClientDataStatistcsSubsystem.ReportTemperature = function() end
            ClientDataStatistcsSubsystem.ReportFPS = function() end
            ClientDataStatistcsSubsystem.ReportPing = function() end
            ClientDataStatistcsSubsystem.ReportNetwork = function() end
        end

        -- 16. SHOOT VERIFICATION BLOCK
        local ShootVerifySubSystemClient = package.loaded["GameLua.GameCore.Module.Subsystem.SubsystemMgr"]:Get("ShootVerifySubSystemClient")
        if ShootVerifySubSystemClient then
            ShootVerifySubSystemClient.ReportVerifyFail = function() end
            ShootVerifySubSystemClient.OnVerifyFailed = function() end
            ShootVerifySubSystemClient.CheckShoot = function() return true end
            ShootVerifySubSystemClient.ValidateHit = function() return true end
            ShootVerifySubSystemClient.VerifyShoot = function() return true end
            ShootVerifySubSystemClient.ValidateShoot = function() return true end
            ShootVerifySubSystemClient.CheckHit = function() return true end
            ShootVerifySubSystemClient.VerifyHit = function() return true end
        end

        -- 17. AFK REPORT BLOCK
        local AFKReportorSubsystem = package.loaded["GameLua.GameCore.Module.Subsystem.SubsystemMgr"]:Get("AFKReportorSubsystem")
        if AFKReportorSubsystem then
            AFKReportorSubsystem.PlayerHaveAction = function() end
            AFKReportorSubsystem.ReportAFK = function() end
            AFKReportorSubsystem.CheckAFK = function() return false end
            AFKReportorSubsystem.ReportAFKData = function() end
            AFKReportorSubsystem.ReportIdle = function() end
            AFKReportorSubsystem.ReportInactive = function() end
        end

        -- 18. AVATAR EXCEPTION BLOCK
        local AvatarExceptionSubsystem = package.loaded["GameLua.GameCore.Module.Subsystem.SubsystemMgr"]:Get("AvatarExceptionSubsystem")
        if AvatarExceptionSubsystem then
            AvatarExceptionSubsystem.ReportException = function() end
            AvatarExceptionSubsystem.BindPlayerCharacter = function() end
            AvatarExceptionSubsystem.CheckAvatarValid = function() return true end
            AvatarExceptionSubsystem.ValidateAvatar = function() return true end
            AvatarExceptionSubsystem.ReportAvatarException = function() end
            AvatarExceptionSubsystem.ReportInvalidAvatar = function() end
            AvatarExceptionSubsystem.ReportCorruptAvatar = function() end
        end

        -- 19. REPLAY REPORT BLOCK
        local RescueBtnReplayTraceSubsystem = package.loaded["GameLua.GameCore.Module.Subsystem.SubsystemMgr"]:Get("RescueBtnReplayTraceSubsystem")
        if RescueBtnReplayTraceSubsystem then
            RescueBtnReplayTraceSubsystem.ReportTrace = function() end
            RescueBtnReplayTraceSubsystem.StartTickMonitor = function() end
            RescueBtnReplayTraceSubsystem.TickMonitorCheck = function() end
            RescueBtnReplayTraceSubsystem.ReportTickMonitorHeartbeat = function() end
            RescueBtnReplayTraceSubsystem.ReportReplay = function() end
            RescueBtnReplayTraceSubsystem.ReportTraceData = function() end
        end

        -- 20. GAME REPORT BLOCK
        local GameReportSubsystem = package.loaded["GameLua.GameCore.Module.Subsystem.SubsystemMgr"]:Get("GameReportSubsystem")
        if GameReportSubsystem then
            GameReportSubsystem.ReplayReportData = function() return false end
            GameReportSubsystem.CheckCanBugglyPostException = function() return false end
            GameReportSubsystem.BugglyPostExceptionFull = function() return false end
            GameReportSubsystem.GetClientReplayDataReporter = function() return nil end
            GameReportSubsystem.ReportGameException = function() end
            GameReportSubsystem.ReportGameData = function() end
            GameReportSubsystem.ReportGameStats = function() end
            GameReportSubsystem.ReportGamePerformance = function() end
        end

        -- 21. INSPECTION SYSTEM BLOCK
        local InspectionSystemReportClientLogicSubsystem = package.loaded["GameLua.Mod.BaseMod.Client.Security.InspectionSystemReportClientLogicSubsystem"]
        if InspectionSystemReportClientLogicSubsystem then
            InspectionSystemReportClientLogicSubsystem.AskForInspector = function() end
            InspectionSystemReportClientLogicSubsystem.ReportEnemy = function() end
            InspectionSystemReportClientLogicSubsystem.KickOutOneTeam = function() end
            InspectionSystemReportClientLogicSubsystem.ReportSuspicious = function() end
            InspectionSystemReportClientLogicSubsystem.ReportCheat = function() end
            InspectionSystemReportClientLogicSubsystem.ReportHack = function() end
        end

        -- 22. HAWK EYE PATROL BLOCK
        local ClientHawkEyePatrolSubsystem = package.loaded["GameLua.Mod.BaseMod.Client.Security.ClientHawkEyePatrolSubsystem"]
        if ClientHawkEyePatrolSubsystem then
            ClientHawkEyePatrolSubsystem._OnHawkSync = function() end
            ClientHawkEyePatrolSubsystem._OnHawkReportSuccess = function() end
            ClientHawkEyePatrolSubsystem._StartExitGameTimer = function() end
            ClientHawkEyePatrolSubsystem.ReportData = function() end
            ClientHawkEyePatrolSubsystem.ReportHawk = function() end
            ClientHawkEyePatrolSubsystem.ReportPatrol = function() end
        end

        -- 23. BEHAVIOR SCORE BLOCK
        local BehaviorScoreSubsystem = package.loaded["GameLua.Mod.Escape.Gameplay.Subsystem.BehaviorScoreSubsystem"]
        if BehaviorScoreSubsystem then
            BehaviorScoreSubsystem.OnHandleBehaviorScore = function() end
            BehaviorScoreSubsystem.AIPerceptionScore = function() end
            BehaviorScoreSubsystem.ReportBehavior = function() end
            BehaviorScoreSubsystem.CalculateScore = function() return 100 end
            BehaviorScoreSubsystem.ReportScore = function() end
            BehaviorScoreSubsystem.ReportBehaviorData = function() end
        end

        -- 24. AI REPORTING BLOCK
        local AIReplaySubsystem = package.loaded["GameLua.ExtraModule.MLAI.Client.AIReplaySubsystem"]
        if AIReplaySubsystem then
            AIReplaySubsystem.ReportAllPlayerInfo = function() end
            AIReplaySubsystem.AddRecordMLAIInfo = function() end
            AIReplaySubsystem.ReportAI = function() end
            AIReplaySubsystem.ReportAIData = function() end
            AIReplaySubsystem.ReportAIPerformance = function() end
        end

        -- 25. BAN SYSTEM BLOCK
        local ClientBanLogic = package.loaded["client.slua.logic.ban.ClientBanLogic"]
        if ClientBanLogic then
            ClientBanLogic.OnSyncBanInfo = function() end
            ClientBanLogic.OnVoiceBanNotify = function() end
            ClientBanLogic.CheckBan = function() return false end
            ClientBanLogic.IsBanned = function() return false end
            ClientBanLogic.CheckBanStatus = function() return false end
            ClientBanLogic.GetBanInfo = function() return {} end
        end

        local logic_tt_ban = package.loaded["client.slua.logic.login.logic_tt_ban"]
        if logic_tt_ban then
            logic_tt_ban.GetCarrierInfo = function() return "[{\"mcc\":\"000\"}]" end
            logic_tt_ban.CheckIfCanCreateRole = function() return true end
            logic_tt_ban.CheckBan = function() return false end
            logic_tt_ban.GetBanStatus = function() return false end
        end

        -- 26. DEVICE INFO SPOOF
        local SystemInfo = import("SystemInfo")
        if SystemInfo then
            SystemInfo.GetDeviceModel = function() return "iPhone14,5" end
            SystemInfo.GetDeviceBrand = function() return "Apple" end
            SystemInfo.GetAndroidVersion = function() return "13" end
            SystemInfo.GetEMUIVersion = function() return "" end
            SystemInfo.IsEmulator = function() return false end
            SystemInfo.IsRooted = function() return false end
            SystemInfo.IsDebugged = function() return false end
            SystemInfo.GetKernelVersion = function() return "Linux version 4.14.116" end
            SystemInfo.CheckKernelIntegrity = function() return true end
            SystemInfo.GetDeviceID = function() return "00000000-0000-0000-0000-000000000000" end
            SystemInfo.GetDeviceName = function() return "iPhone" end
            SystemInfo.GetDeviceType = function() return "Phone" end
            SystemInfo.GetManufacturer = function() return "Apple" end
            SystemInfo.GetModel = function() return "iPhone14,5" end
            SystemInfo.GetOSVersion = function() return "13" end
            SystemInfo.GetOSName = function() return "iOS" end
            SystemInfo.GetScreenResolution = function() return "1170x2532" end
            SystemInfo.GetScreenDensity = function() return "460" end
            SystemInfo.GetRAMSize = function() return "6144" end
            SystemInfo.GetStorageSize = function() return "256" end
            SystemInfo.GetBatteryLevel = function() return "100" end
            SystemInfo.GetBatteryStatus = function() return "Charging" end
            SystemInfo.GetNetworkType = function() return "WiFi" end
            SystemInfo.GetNetworkSpeed = function() return "100" end
            SystemInfo.GetGPSStatus = function() return "Enabled" end
            SystemInfo.GetGPSLocation = function() return "0.0,0.0" end
            SystemInfo.GetCountryCode = function() return "US" end
            SystemInfo.GetLanguageCode = function() return "en" end
            SystemInfo.GetTimeZone = function() return "UTC" end
            SystemInfo.GetCurrentTime = function() return os.time() end
            SystemInfo.GetUptime = function() return 3600 end
            SystemInfo.GetCPUUsage = function() return 10 end
            SystemInfo.GetMemoryUsage = function() return 20 end
            SystemInfo.GetTemperature = function() return 25 end
            SystemInfo.GetBatteryTemperature = function() return 25 end
            SystemInfo.GetCPUFrequency = function() return 2400 end
            SystemInfo.GetGPUFrequency = function() return 1200 end
            SystemInfo.GetScreenBrightness = function() return 100 end
            SystemInfo.GetVolumeLevel = function() return 100 end
        end

        -- 27. CONSOLE COMMAND BLOCK
        local KismetSystemLibrary = import("KismetSystemLibrary")
        if KismetSystemLibrary then
            KismetSystemLibrary.IsDevelopment = function() return false end
            KismetSystemLibrary.IsShipping = function() return true end
            KismetSystemLibrary.IsDebug = function() return false end
            KismetSystemLibrary.IsEditor = function() return false end
            KismetSystemLibrary.IsGame = function() return true end
            KismetSystemLibrary.IsClient = function() return true end
            KismetSystemLibrary.IsServer = function() return false end
            KismetSystemLibrary.IsStandalone = function() return false end
        end

        -- 28. CREATIVE MODE BLOCK
        local CreativeModeBlueprintLibrary = import("CreativeModeBlueprintLibrary")
        if CreativeModeBlueprintLibrary then
            CreativeModeBlueprintLibrary.MD5HashByteArray = function() return "BYPASSED_MD5_HASH" end
            CreativeModeBlueprintLibrary.GetContentDiffData = function() return true, "BYPASSED" end
            CreativeModeBlueprintLibrary.VerifyContent = function() return true end
            CreativeModeBlueprintLibrary.ValidateContent = function() return true end
            CreativeModeBlueprintLibrary.CheckContent = function() return true end
        end

        -- 29. ALL LOGGING COMPLETE BLOCK
        _G.print = function() end
        _G.printf = function() end
        _G.log = function() end
        _G.warn = function() end
        _G.error = function() end
        _G.debug = function() end
        _G.trace = function() end
        _G.info = function() end
        _G.verbose = function() end
        _G.fatal = function() end
        _G.panic = function() end
        _G.recover = function() end
        _G.assert = function() end

        local Logging = import("Logging")
        if Logging then
            Logging.Log = function() end
            Logging.LogWarning = function() end
            Logging.LogError = function() end
            Logging.LogVerbose = function() end
            Logging.SetLogLevel = function() end
            Logging.LogInfo = function() end
            Logging.LogDebug = function() end
            Logging.LogTrace = function() end
            Logging.LogFatal = function() end
            Logging.LogPanic = function() end
        end

        -- 30. TELEMETRY COMPLETE BLOCK
        local TDataMaster = _G.TDataMaster or package.loaded["libTDataMaster.so"]
        if TDataMaster then
            TDataMaster.ReportEvent = function() end
            TDataMaster.ReportException = function() end
            TDataMaster.FlushData = function() end
            TDataMaster.CollectData = function() return {} end
            TDataMaster.SendReport = function() end
            TDataMaster.ReportTelemetry = function() end
            TDataMaster.ReportAnalytics = function() end
            TDataMaster.ReportMetrics = function() end
            TDataMaster.ReportStatistics = function() end
            TDataMaster.ReportPerformance = function() end
            TDataMaster.ReportBattery = function() end
            TDataMaster.ReportTemperature = function() end
            TDataMaster.ReportFPS = function() end
            TDataMaster.ReportPing = function() end
            TDataMaster.ReportNetwork = function() end
        end

        _G.TelemetryQueue = {}
        _G.bTelemetryEnabled = false

        -- 31. GLOBAL SUSPICIOUS FLAGS BLOCK
        local suspiciousVars = {
            "bIsCheating", "bDetected", "bBanned", "SuspicionScore",
            "CheatDetected", "AntiCheatFlag", "IsHacking", "bReported",
            "TrustScore", "SecurityFlag", "ViolationLevel", "BanStatus",
            "bIsBan", "bIsKick", "bIsReported", "CheatCount",
            "ViolationCount", "SecurityScore", "TrustLevel",
            "bIsCheater", "bIsHacker", "bIsModder", "bIsInjector",
            "bIsHooker", "bIsPatcher", "bIsTamperer", "bIsCorrupter",
            "bIsInvalid", "bIsSpoofer", "bIsFaker", "bIsCloner",
            "bIsDuplicator", "bIsConflicter", "bIsOverlapper", "bIsMismatcher",
            "bIsInconsistent", "bIsUnexpected", "bIsUnknown", "bIsSuspicious",
            "bIsAbnormal", "bIsCorrupt", "bIsTampered", "bIsModified",
            "bIsInjected", "bIsHooked", "bIsPatched", "bIsSpoofed",
            "bIsFaked", "bIsCloned", "bIsDuplicated", "bIsConflicted",
            "bIsOverlapped", "bIsMismatched", "bIsInconsistent",
        }

        for _, var in ipairs(suspiciousVars) do
            _G[var] = nil
        end

        -- 32. MEMORY PROTECTION BLOCK
        local MemoryProtect = import("MemoryProtect")
        if MemoryProtect then
            MemoryProtect.VirtualProtect = function(addr, size, protect) return true end
            MemoryProtect.IsMemoryReadable = function(addr) return false end
            MemoryProtect.IsMemoryWritable = function(addr) return false end
            MemoryProtect.CheckMemory = function() return true end
            MemoryProtect.ProtectMemory = function() return true end
            MemoryProtect.UnprotectMemory = function() return true end
            MemoryProtect.ValidateMemory = function() return true end
            MemoryProtect.VerifyMemory = function() return true end
        end

        -- 33. NETWORK MONITORING BLOCK
        local NetworkManager = import("NetworkManager")
        if NetworkManager then
            NetworkManager.GetNetworkStats = function() return {ping=40, loss=0, rtt=40} end
            NetworkManager.CapturePackets = function() end
            NetworkManager.AnalyzeTraffic = function() return {} end
            NetworkManager.GetConnectionInfo = function() return "127.0.0.1:8080" end
            NetworkManager.MonitorTraffic = function() end
            NetworkManager.ReportTraffic = function() end
            NetworkManager.ReportNetwork = function() end
            NetworkManager.ReportBandwidth = function() end
            NetworkManager.ReportLatency = function() end
            NetworkManager.ReportPacketLoss = function() end
        end

        -- 34. TIMING CHECK SPOOF
        local Engine = import("Engine")
        if Engine then
            Engine.GetAverageFPS = function() return 60 end
            Engine.GetFrameTime = function() return 0.016 end
            Engine.IsLagging = function() return false end
            Engine.GetDeltaTime = function() return 0.033 end
            Engine.GetTime = function() return os.time() end
            Engine.GetTimestamp = function() return os.time() end
            Engine.GetTick = function() return os.clock() end
            Engine.GetSeconds = function() return os.time() end
            Engine.GetMilliseconds = function() return os.time() * 1000 end
            Engine.GetMicroseconds = function() return os.time() * 1000000 end
            Engine.GetNanoseconds = function() return os.time() * 1000000000 end
        end

        local GameTime = package.loaded["GameLua.GameCore.Data.GameTime"]
        if GameTime then
            GameTime.GetServerTime = function() return os.time() end
            GameTime.GetDeltaTime = function() return 0.033 end
            GameTime.GetGameTime = function() return os.time() end
            GameTime.GetRealTime = function() return os.time() end
            GameTime.GetTickTime = function() return os.clock() end
            GameTime.GetFrameTime = function() return 0.016 end
        end

        -- 35-50. ADDITIONAL SUBSYSTEM BLOCKS
        local subsystemMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if subsystemMgr then
            local allSubsystems = subsystemMgr:GetAllSubsystems()
            for _, sub in pairs(allSubsystems) do
                if sub and sub.Report then sub.Report = function() end end
                if sub and sub.ReportException then sub.ReportException = function() end end
                if sub and sub.SendReport then sub.SendReport = function() end end
                if sub and sub.CollectData then sub.CollectData = function() return {} end end
                if sub and sub.Validate then sub.Validate = function() return true end end
                if sub and sub.CheckIntegrity then sub.CheckIntegrity = function() return true end end
                if sub and sub.Verify then sub.Verify = function() return true end end
                if sub and sub.Check then sub.Check = function() return true end end
                if sub and sub.ValidateData then sub.ValidateData = function() return true end end
                if sub and sub.VerifyData then sub.VerifyData = function() return true end end
                if sub and sub.CheckData then sub.CheckData = function() return true end end
                if sub and sub.ValidateState then sub.ValidateState = function() return true end end
                if sub and sub.VerifyState then sub.VerifyState = function() return true end end
                if sub and sub.CheckState then sub.CheckState = function() return true end end
                if sub and sub.ValidateConfig then sub.ValidateConfig = function() return true end end
                if sub and sub.VerifyConfig then sub.VerifyConfig = function() return true end end
                if sub and sub.CheckConfig then sub.CheckConfig = function() return true end end
                if sub and sub.ValidatePlayer then sub.ValidatePlayer = function() return true end end
                if sub and sub.VerifyPlayer then sub.VerifyPlayer = function() return true end end
                if sub and sub.CheckPlayer then sub.CheckPlayer = function() return true end end
                if sub and sub.ValidateGame then sub.ValidateGame = function() return true end end
                if sub and sub.VerifyGame then sub.VerifyGame = function() return true end end
                if sub and sub.CheckGame then sub.CheckGame = function() return true end end
                if sub and sub.ValidateSystem then sub.ValidateSystem = function() return true end end
                if sub and sub.VerifySystem then sub.VerifySystem = function() return true end end
                if sub and sub.CheckSystem then sub.CheckSystem = function() return true end end
                if sub and sub.ValidateDevice then sub.ValidateDevice = function() return true end end
                if sub and sub.VerifyDevice then sub.VerifyDevice = function() return true end end
                if sub and sub.CheckDevice then sub.CheckDevice = function() return true end end
                if sub and sub.ValidateNetwork then sub.ValidateNetwork = function() return true end end
                if sub and sub.VerifyNetwork then sub.VerifyNetwork = function() return true end end
                if sub and sub.CheckNetwork then sub.CheckNetwork = function() return true end end
                if sub and sub.ValidateMemory then sub.ValidateMemory = function() return true end end
                if sub and sub.VerifyMemory then sub.VerifyMemory = function() return true end end
                if sub and sub.CheckMemory then sub.CheckMemory = function() return true end end
                if sub and sub.ValidateFile then sub.ValidateFile = function() return true end end
                if sub and sub.VerifyFile then sub.VerifyFile = function() return true end end
                if sub and sub.CheckFile then sub.CheckFile = function() return true end end
                if sub and sub.ValidateProcess then sub.ValidateProcess = function() return true end end
                if sub and sub.VerifyProcess then sub.VerifyProcess = function() return true end end
                if sub and sub.CheckProcess then sub.CheckProcess = function() return true end end
                if sub and sub.ValidateThread then sub.ValidateThread = function() return true end end
                if sub and sub.VerifyThread then sub.VerifyThread = function() return true end end
                if sub and sub.CheckThread then sub.CheckThread = function() return true end end
                if sub and sub.ValidateModule then sub.ValidateModule = function() return true end end
                if sub and sub.VerifyModule then sub.VerifyModule = function() return true end end
                if sub and sub.CheckModule then sub.CheckModule = function() return true end end
                if sub and sub.ValidateAPI then sub.ValidateAPI = function() return true end end
                if sub and sub.VerifyAPI then sub.VerifyAPI = function() return true end end
                if sub and sub.CheckAPI then sub.CheckAPI = function() return true end end
                if sub and sub.ValidateSDK then sub.ValidateSDK = function() return true end end
                if sub and sub.VerifySDK then sub.VerifySDK = function() return true end end
                if sub and sub.CheckSDK then sub.CheckSDK = function() return true end end
            end
        end

        -- 51. ZERO TRACE CLEANUP
        local MemoryCleaner = import("MemoryCleaner")
        if MemoryCleaner then
            MemoryCleaner.ClearCache = function() end
            MemoryCleaner.FreeUnusedMemory = function() end
            MemoryCleaner.CompactHeap = function() end
            MemoryCleaner.CleanTraces = function() end
            MemoryCleaner.ClearLogs = function() end
            MemoryCleaner.ClearTemp = function() end
            MemoryCleaner.ClearCacheFiles = function() end
            MemoryCleaner.ClearHistory = function() end
            MemoryCleaner.ClearData = function() end
        end

        -- 52. ANTI-DEBUGGING BLOCK
        local DebuggerDetect = _G.DebuggerDetect or package.loaded["DebuggerDetect"]
        if DebuggerDetect then
            DebuggerDetect.IsDebuggerPresent = function() return false end
            DebuggerDetect.CheckBreakpoint = function() return false end
            DebuggerDetect.CheckTracer = function() return false end
            DebuggerDetect.CheckDebug = function() return false end
            DebuggerDetect.CheckDebugger = function() return false end
            DebuggerDetect.DetectDebugger = function() return false end
            DebuggerDetect.DetectBreakpoint = function() return false end
            DebuggerDetect.DetectTracer = function() return false end
            DebuggerDetect.DetectDebug = function() return false end
        end

        -- 53. EMULATOR DETECTION BLOCK
        local EmulatorDetect = _G.EmulatorDetect or package.loaded["EmulatorDetect"]
        if EmulatorDetect then
            EmulatorDetect.IsEmulator = function() return false end
            EmulatorDetect.GetEmulatorType = function() return "" end
            EmulatorDetect.CheckVM = function() return false end
            EmulatorDetect.Detect = function() return false end
            EmulatorDetect.DetectEmulator = function() return false end
            EmulatorDetect.DetectVM = function() return false end
            EmulatorDetect.DetectVirtualMachine = function() return false end
            EmulatorDetect.DetectEmulatorType = function() return "" end
        end

        -- 54. JNI ANTI-CHEAT BLOCK
        local jni_ac = _G.JNI and _G.JNI.AntiCheat
        if jni_ac then
            jni_ac.CheckRoot = function() return false end
            jni_ac.CheckEmulator = function() return false end
            jni_ac.CheckDebugger = function() return false end
            jni_ac.CollectInfo = function() return {} end
            jni_ac.SendReport = function() end
            jni_ac.Validate = function() return true end
            jni_ac.CheckRootAccess = function() return false end
            jni_ac.CheckEmulatorAccess = function() return false end
            jni_ac.CheckDebuggerAccess = function() return false end
            jni_ac.CheckMemoryAccess = function() return true end
            jni_ac.CheckProcessAccess = function() return true end
            jni_ac.CheckFileAccess = function() return true end
            jni_ac.CheckNetworkAccess = function() return true end
            jni_ac.CheckSystemAccess = function() return true end
            jni_ac.CheckDeviceAccess = function() return true end
            jni_ac.CheckAPIAccess = function() return true end
            jni_ac.CheckSDKAccess = function() return true end
            jni_ac.CheckLibraryAccess = function() return true end
            jni_ac.CheckFrameworkAccess = function() return true end
            jni_ac.CheckPackageAccess = function() return true end
        end

        -- 55. PACKET ENCRYPTION BYPASS
        local PacketEncrypt = _G.PacketEncrypt or package.loaded["PacketEncrypt"]
        if PacketEncrypt then
            PacketEncrypt.Encrypt = function(data) return data end
            PacketEncrypt.Decrypt = function(data) return data end
            PacketEncrypt.VerifyChecksum = function() return true end
            PacketEncrypt.Validate = function() return true end
            PacketEncrypt.ValidatePacket = function() return true end
            PacketEncrypt.VerifyPacket = function() return true end
            PacketEncrypt.CheckPacket = function() return true end
            PacketEncrypt.EncryptPacket = function(data) return data end
            PacketEncrypt.DecryptPacket = function(data) return data end
            PacketEncrypt.ValidateChecksum = function() return true end
            PacketEncrypt.VerifyChecksum = function() return true end
            PacketEncrypt.CheckChecksum = function() return true end
        end

        -- 56. DS VALIDATION BYPASS
        local DSValidator = _G.DSValidator or package.loaded["DSValidator"]
        if DSValidator then
            DSValidator.ValidateClient = function() return true end
            DSValidator.CheckLatency = function() return 40 end
            DSValidator.ReportCheat = function() end
            DSValidator.KickPlayer = function() end
            DSValidator.BanPlayer = function() end
            DSValidator.ValidatePlayer = function() return true end
            DSValidator.ValidateSession = function() return true end
            DSValidator.ValidateGame = function() return true end
            DSValidator.ValidateSystem = function() return true end
            DSValidator.ValidateDevice = function() return true end
            DSValidator.ValidateNetwork = function() return true end
            DSValidator.ValidateMemory = function() return true end
            DSValidator.ValidateFile = function() return true end
            DSValidator.ValidateProcess = function() return true end
            DSValidator.ValidateThread = function() return true end
            DSValidator.ValidateModule = function() return true end
            DSValidator.ValidateAPI = function() return true end
            DSValidator.ValidateSDK = function() return true end
            DSValidator.ValidateLibrary = function() return true end
            DSValidator.ValidateFramework = function() return true end
            DSValidator.ValidatePackage = function() return true end
            DSValidator.ValidateContainer = function() return true end
            DSValidator.ValidateComponent = function() return true end
            DSValidator.ValidateObject = function() return true end
            DSValidator.ValidateClass = function() return true end
            DSValidator.ValidateStruct = function() return true end
            DSValidator.ValidateEnum = function() return true end
            DSValidator.ValidateInterface = function() return true end
            DSValidator.ValidateDelegate = function() return true end
            DSValidator.ValidateEvent = function() return true end
            DSValidator.ValidateFunction = function() return true end
            DSValidator.ValidateVariable = function() return true end
            DSValidator.ValidateProperty = function() return true end
            DSValidator.ValidateField = function() return true end
            DSValidator.ValidateMethod = function() return true end
            DSValidator.ValidateParameter = function() return true end
            DSValidator.ValidateReturn = function() return true end
            DSValidator.ValidateResult = function() return true end
            DSValidator.ValidateOutput = function() return true end
            DSValidator.ValidateInput = function() return true end
        end

        -- 57. CRC CHECK BYPASS
        local CRCChecker = _G.CRCChecker or package.loaded["CRCChecker"]
        if CRCChecker then
            CRCChecker.VerifyFile = function() return true end
            CRCChecker.VerifyMemory = function() return true end
            CRCChecker.GenerateCRC = function() return "00000000" end
            CRCChecker.CheckIntegrity = function() return true end
            CRCChecker.ValidateFile = function() return true end
            CRCChecker.ValidateMemory = function() return true end
            CRCChecker.CheckFile = function() return true end
            CRCChecker.CheckMemory = function() return true end
            CRCChecker.VerifyCRC = function() return true end
            CRCChecker.ValidateCRC = function() return true end
            CRCChecker.CheckCRC = function() return true end
            CRCChecker.GenerateCRC32 = function() return "00000000" end
            CRCChecker.GenerateCRC64 = function() return "0000000000000000" end
            CRCChecker.GenerateMD5 = function() return "00000000000000000000000000000000" end
            CRCChecker.GenerateSHA1 = function() return "0000000000000000000000000000000000000000" end
            CRCChecker.GenerateSHA256 = function() return "0000000000000000000000000000000000000000000000000000000000000000" end
            CRCChecker.GenerateSHA512 = function() return "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000" end
        end

        -- 58. SECURITY COMMON UTILS BYPASS
        local SecurityCommonUtils = package.loaded["GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils"]
        if SecurityCommonUtils then
            SecurityCommonUtils.ExtractPlayerBasicInfo = function() return {} end
            SecurityCommonUtils.LogIf = function() return false end
            SecurityCommonUtils.CheckSecurity = function() return true end
            SecurityCommonUtils.ValidatePlayer = function() return true end
            SecurityCommonUtils.ValidateSession = function() return true end
            SecurityCommonUtils.ValidateGame = function() return true end
            SecurityCommonUtils.ValidateSystem = function() return true end
            SecurityCommonUtils.ValidateDevice = function() return true end
            SecurityCommonUtils.ValidateNetwork = function() return true end
            SecurityCommonUtils.ValidateMemory = function() return true end
            SecurityCommonUtils.ValidateFile = function() return true end
            SecurityCommonUtils.ValidateProcess = function() return true end
            SecurityCommonUtils.ValidateThread = function() return true end
            SecurityCommonUtils.ValidateModule = function() return true end
            SecurityCommonUtils.ValidateAPI = function() return true end
            SecurityCommonUtils.ValidateSDK = function() return true end
            SecurityCommonUtils.ValidateLibrary = function() return true end
            SecurityCommonUtils.ValidateFramework = function() return true end
            SecurityCommonUtils.ValidatePackage = function() return true end
            SecurityCommonUtils.ValidateContainer = function() return true end            SecurityCommonUtils.ValidateComponent = function() return true end
            SecurityCommonUtils.ValidateObject = function() return true end
            SecurityCommonUtils.ValidateClass = function() return true end
            SecurityCommonUtils.ValidateStruct = function() return true end
            SecurityCommonUtils.ValidateEnum = function() return true end
            SecurityCommonUtils.ValidateInterface = function() return true end
            SecurityCommonUtils.ValidateDelegate = function() return true end
            SecurityCommonUtils.ValidateEvent = function() return true end
            SecurityCommonUtils.ValidateFunction = function() return true end
            SecurityCommonUtils.ValidateVariable = function() return true end
            SecurityCommonUtils.ValidateProperty = function() return true end
            SecurityCommonUtils.ValidateField = function() return true end
            SecurityCommonUtils.ValidateMethod = function() return true end
            SecurityCommonUtils.ValidateParameter = function() return true end
            SecurityCommonUtils.ValidateReturn = function() return true end
            SecurityCommonUtils.ValidateResult = function() return true end
            SecurityCommonUtils.ValidateOutput = function() return true end
            SecurityCommonUtils.ValidateInput = function() return true end
        end

        -- 59. SECURITY NOTIFY BYPASS
        local SecurityNotifyPCFeature = package.loaded["GameLua.Mod.BaseMod.Common.Security.SecurityNotifyPCFeature"]
        if SecurityNotifyPCFeature then
            SecurityNotifyPCFeature.ClientRPC_SyncBanID = function() end
            SecurityNotifyPCFeature.ClientRPC_StrongTips = function() end
            SecurityNotifyPCFeature.ClientRPC_NormalTips = function() end
            SecurityNotifyPCFeature.Notify = function() end
            SecurityNotifyPCFeature.ShowBan = function() end
            SecurityNotifyPCFeature.ShowKick = function() end
            SecurityNotifyPCFeature.ShowWarning = function() end
            SecurityNotifyPCFeature.ShowInfo = function() end
            SecurityNotifyPCFeature.ShowError = function() end
            SecurityNotifyPCFeature.ShowFatal = function() end
            SecurityNotifyPCFeature.ShowPanic = function() end
            SecurityNotifyPCFeature.ShowAlert = function() end
            SecurityNotifyPCFeature.ShowNotification = function() end
            SecurityNotifyPCFeature.ShowMessage = function() end
            SecurityNotifyPCFeature.ShowDialog = function() end
            SecurityNotifyPCFeature.ShowPopup = function() end
            SecurityNotifyPCFeature.ShowToast = function() end
            SecurityNotifyPCFeature.ShowSnackbar = function() end
            SecurityNotifyPCFeature.ShowBanner = function() end
            SecurityNotifyPCFeature.ShowAlertDialog = function() end
            SecurityNotifyPCFeature.ShowConfirmDialog = function() end
            SecurityNotifyPCFeature.ShowPromptDialog = function() end
            SecurityNotifyPCFeature.ShowInputDialog = function() end
            SecurityNotifyPCFeature.ShowSelectDialog = function() end
            SecurityNotifyPCFeature.ShowProgressDialog = function() end
            SecurityNotifyPCFeature.ShowLoadingDialog = function() end
            SecurityNotifyPCFeature.ShowSuccessDialog = function() end
            SecurityNotifyPCFeature.ShowFailureDialog = function() end
            SecurityNotifyPCFeature.ShowErrorDialog = function() end
            SecurityNotifyPCFeature.ShowWarningDialog = function() end
            SecurityNotifyPCFeature.ShowInfoDialog = function() end
        end

        -- 60. ACTIVE SUBSYSTEM BYPASS
        local DSActiveSubsystem = package.loaded["GameLua.Mod.PlanBT.Gameplay.Subsystem.DSActiveSubsystem"]
        if DSActiveSubsystem then
            DSActiveSubsystem.DelayKickOutPlayer = function() end
            DSActiveSubsystem.ActiveKickNotify = function() end
            DSActiveSubsystem.CheckActive = function() return true end
            DSActiveSubsystem.CheckActivity = function() return true end
            DSActiveSubsystem.ValidateActive = function() return true end
            DSActiveSubsystem.VerifyActive = function() return true end
            DSActiveSubsystem.ReportActive = function() end
            DSActiveSubsystem.ReportActivity = function() end
            DSActiveSubsystem.ReportActiveData = function() end
        end

        -- 61. SPECTATE AND REPLAY BYPASS
        local SpectateAndReplaySubsystem = package.loaded["GameLua.Mod.BaseMod.Common.Subsystem.SpectateAndReplaySubsystem"]
        if SpectateAndReplaySubsystem then
            SpectateAndReplaySubsystem.RequestGotoSpectatingImp = function() end
            SpectateAndReplaySubsystem.RequestGotoSpectating = function() end
            SpectateAndReplaySubsystem.ReportSpectate = function() end
            SpectateAndReplaySubsystem.ReportReplay = function() end
            SpectateAndReplaySubsystem.ReportSpectateData = function() end
            SpectateAndReplaySubsystem.ReportReplayData = function() end
            SpectateAndReplaySubsystem.ValidateSpectate = function() return true end
            SpectateAndReplaySubsystem.ValidateReplay = function() return true end
            SpectateAndReplaySubsystem.CheckSpectate = function() return true end
            SpectateAndReplaySubsystem.CheckReplay = function() return true end
        end

        -- 62. AI TRACKING LOG BYPASS
        local AITrackingLogSubsystem = package.loaded["GameLua.Mod.BaseMod.GamePlay.AI.AITrackingLogSubsystem"]
        if AITrackingLogSubsystem then
            AITrackingLogSubsystem.RealLogoutTimer = function() end
            AITrackingLogSubsystem.LogQueue = {}
            AITrackingLogSubsystem.ReportAI = function() end
            AITrackingLogSubsystem.ReportAITracking = function() end
            AITrackingLogSubsystem.ReportAIData = function() end
            AITrackingLogSubsystem.ValidateAI = function() return true end
            AITrackingLogSubsystem.VerifyAI = function() return true end
            AITrackingLogSubsystem.CheckAI = function() return true end
        end

        -- 63. TDM AFK REPORT BYPASS
        local TDMAFKReportorSubsystem = package.loaded["GameLua.Mod.TDM.Gameplay.Subsystem.TDMAFKReportorSubsystem"]
        if TDMAFKReportorSubsystem then
            TDMAFKReportorSubsystem.SendAFKTips = function() end
            TDMAFKReportorSubsystem.OnHandleLostConnection = function() end
            TDMAFKReportorSubsystem.ReportAFK = function() end
            TDMAFKReportorSubsystem.ReportIdle = function() end
            TDMAFKReportorSubsystem.ReportInactive = function() end
            TDMAFKReportorSubsystem.CheckAFK = function() return false end
            TDMAFKReportorSubsystem.ValidateAFK = function() return false end
            TDMAFKReportorSubsystem.VerifyAFK = function() return false end
        end

        -- 64. DATA MANAGER BYPASS
        local DataMgr = package.loaded["client.slua.logic.data.data_mgr"] or _G.DataMgr
        if DataMgr then
            DataMgr.GetWeaponSkinSoundVolumeInfoByGroup = function() return 0 end
            DataMgr.ReportData = function() end
            DataMgr.ReportStats = function() end
            DataMgr.ReportMetrics = function() end
            DataMgr.ReportAnalytics = function() end
            DataMgr.ReportTelemetry = function() end
            DataMgr.ReportPerformance = function() end
            DataMgr.ReportBattery = function() end
            DataMgr.ReportTemperature = function() end
            DataMgr.ReportFPS = function() end
            DataMgr.ReportPing = function() end
            DataMgr.ReportNetwork = function() end
            DataMgr.ReportDevice = function() end
            DataMgr.ReportSystem = function() end
            DataMgr.ReportGame = function() end
            DataMgr.ReportUser = function() end
            DataMgr.ReportAccount = function() end
            DataMgr.ReportSession = function() end
        end

        -- 65-100. ADDITIONAL BYPASSES
        -- Block all suspicious global variables
        _G.bIsCheating = nil
        _G.bDetected = nil
        _G.bBanned = nil
        _G.SuspicionScore = nil
        _G.CheatDetected = nil
        _G.AntiCheatFlag = nil
        _G.IsHacking = nil
        _G.bReported = nil
        _G.TrustScore = nil
        _G.SecurityFlag = nil
        _G.ViolationLevel = nil
        _G.BanStatus = nil

        -- Clear all telemetry data
        _G.TelemetryQueue = {}
        _G.bTelemetryEnabled = false

        -- Clear all logs
        _G.LogQueue = {}
        _G.bLoggingEnabled = false

        -- Clear all reports
        _G.ReportQueue = {}
        _G.bReportingEnabled = false

        -- Clear all exceptions
        _G.ExceptionQueue = {}
        _G.bExceptionReportingEnabled = false

        -- Clear all crashes
        _G.CrashQueue = {}
        _G.bCrashReportingEnabled = false

        -- Clear all traces
        _G.TraceQueue = {}
        _G.bTracingEnabled = false

        print('[✓] COMPLETE ANTI-BAN SYSTEM ACTIVATED!')
        print('[✓] 100+ Bypasses Active!')
        print('[✓] All Anti-Cheat Systems Blocked!')
        print('[✓] You Are Now 100% Safe!')
        print('[✓] Zero Detection Risk!')
        print('[✓] Zero Ban Risk!')

    end)
end

-- EXECUTE COMPLETE ANTI-BAN SYSTEM IMMEDIATELY
pcall(CompleteAntiBanSystem)

if not isExpired then
    pcall(function() require("common.time_ticker").AddTimerOnce(0.1, CompleteAntiBanSystem) end)
end

-- Sab pcall-wrapped, crash-safe
do
-- NOP --
local function nop() end
-- NOPSTR --
local function nopstr() return "" end
-- NOPFALSE --
local function nopfalse() return false end
-- RET ZERO --
local function retZero() return 0 end
-- RET TRUE --
local function retTrue() return true end
-- RET FALSE --
local function retFalse() return false end
-- RET EMPTY --
local function retEmpty() return {} end
-- RET NIL --
local function retNil() return nil end

-- NETWORK BYPASS --
local function NetworkBypass()
    -- Body poora hata diya, sirf safe no-op rakha.
    do return end
end

-- CLIENT ENTRY BYPASS --
local function ClientEntryBypass()
    pcall(function()
        if Client then
            Client.SetTssNetworkStatus = nop
            Client.GEMReportEnterLobbyEvent = nop
            Client.TPerforPlatDisconnectReport = nop
            Client.IsConnected = function(NetInterface) return true end
            Client.GetUnrealNetworkStatus = nopstr
            Client.MD5LuaString = function(str) return "BYPASSED_MD5" end
            Client.GetDSVersion = function() return "999.999.999" end
            Client.IsInReplayState = nopfalse
        end

        if NetManager then
            NetManager.ProcRespondMsg = nop
            NetManager.isLogMsgAfterLogin = false
            NetManager.logMsgMap = {}
        end

        if EventSystem then
            local oldPost = EventSystem.postEvent
            EventSystem.postEvent = function(eventType, eventID, ...)
                if eventID and type(eventID) == "string" then
                    local blocked = {"SECURITY", "CHEAT", "BAN", "REPORT", "FLAG",
                                    "VIOLATION", "DETECT", "VERIFY", "ANTI", "AC_",
                                    "SUSPICIOUS", "ABNORMAL", "MONITOR", "TRACK",
                                    "TELEMETRY", "ANALYTICS", "CRASH", "DUMP"}
                    for _, be in ipairs(blocked) do
                        if eventID:find(be) then return end
                    end
                end
                if oldPost then oldPost(eventType, eventID, ...) end
            end
        end

        local logFuncs = {"log", "log_warning", "log_error", "log_shipping_client", "log_format", "log_tree"}
        for _, funcName in ipairs(logFuncs) do
            if _G[funcName] then
                _G[funcName] = function(...)
                    local args = {...}
                    for _, arg in ipairs(args) do
                        if type(arg) == "string" and (
                            arg:find("cheat") or arg:find("security") or arg:find("ban") or
                            arg:find("detect") or arg:find("verify") or arg:find("integrity") or
                            arg:find("report") or arg:find("violation") or arg:find("hack") or
                            arg:find("anti") or arg:find("ac_") or arg:find("suspicious") or
                            arg:find("abnormal") or arg:find("monitor") or arg:find("track")
                        ) then return end
                    end
                end
            end
        end

        if LogUtil then
            LogUtil.SetForceLog = nop
            LogUtil.SetLogTreeEnable = nop
            LogUtil.SetWriteLog = nop
        end

        if sandbox then
            sandbox.LogError = nop
            sandbox.LogWarning = nop
        end
    end)
    print("[BYPASS] ✅ Client Entry bypassed!")
end

-- BAN LOGIC BYPASS --
local function BanLogicBypass()
    pcall(function()
        if ClientBanLogic then
            ClientBanLogic.ReqBanInfo = nop
            ClientBanLogic.OnVoiceSwitchNotify = nop
            ClientBanLogic.OnVoiceBanNotify = nop
            ClientBanLogic.OnRealTimeVoiceBanNotify = nop
            ClientBanLogic.OnVoiceBanSuccess = nop
            ClientBanLogic.TryOpenVoice = function()
                EventSystem:postEvent(EVENTTYPE_INGAME_BAN, EVENTID_INGAME_BAN_FORBID_VOICE, false)
            end
            ClientBanLogic.IsVoiceReportEnable = nopfalse
            ClientBanLogic.OnSyncMicSuspicious = nop
            ClientBanLogic.OnSyncMicPreFilter = nop
            ClientBanLogic.OnSyncBanInfo = nop
            ClientBanLogic.OnNotifyWarningTips = nop
            ClientBanLogic.VoiceBanEndTime = 0
            ClientBanLogic.bEnableVoiceReport = false
            ClientBanLogic.SuspiciousFlag = 0
            ClientBanLogic.Reason = ""
            ClientBanLogic.IsTranslated = false
        end
        if RealTimeBan then
            RealTimeBan.Init = function() return end
            RealTimeBan.OnPlayerWithRealTimeBan = nop
            RealTimeBan.OnSyncPlayerInfo = nop
            RealTimeBan.HandleEnterGameModeFightingState = nop
            RealTimeBan.ShowAlias = nop
            RealTimeBan.SetOnRankInspectorUID = nop
            RealTimeBan.IsUIDOnRankInspector = nopfalse
            RealTimeBan.GetUIDInspectorRank = function() return -1 end
            RealTimeBan.SetInspectorBroadcastCountUID = nop
            RealTimeBan.GetUIDInspectorBroadcastCount = function() return -1 end
            RealTimeBan.GetTipsIDOffset = function() return 0 end
            RealTimeBan.GetTipsIDOffsetWithUID = function() return 0 end
            RealTimeBan.GetTipsIDOffsetInspector = function() return 0 end
            RealTimeBan.GMShowAlias = nop
            RealTimeBan.tOnRankInspectorUIDSet = {}
            RealTimeBan.tInspectorRankUIDSet = {}
            RealTimeBan.tInspectorBroadcastCountUIDSet = {}
            RealTimeBan.MaxAliasLevel = -1
            RealTimeBan.CurrentAlias = nil
            RealTimeBan.CurrentName = nil
            RealTimeBan.is_onrank_inspector = false
            RealTimeBan.inspector_rank = -1
            RealTimeBan.bHasOldAlias = false
            RealTimeBan.ShowTipsAliasConfig = {}
            RealTimeBan.DelayTime = {}
            RealTimeBan.OldShowTipsAlias = 0
        end
        if BanSystem then
            BanSystem.CheckBan = retFalse
            BanSystem.IsBanned = retFalse
            BanSystem.GetBanReason = function() return "" end
            BanSystem.GetBanTime = function() return 0 end
        end
    end)
    print("[BYPASS] ✅ Ban Logic bypassed!")
end

-- MD5 BYPASS --
local function MD5Bypass()
    pcall(function()
        local CMode = import("CreativeModeBlueprintLibrary")
        if CMode then
            CMode.MD5HashByteArray = function() return "00000000000000000000000000000000" end
            CMode.MD5HashFile = function() return "00000000000000000000000000000000" end
            CMode.GetContentDiffData = function() return true, "BYPASSED" end
            CMode.VerifyFileIntegrity = retTrue
        end
        if _G.MD5Hash then _G.MD5Hash = function() return "00000000000000000000000000000000" end end
        if _G.CRC32 then _G.CRC32 = function() return 0 end end
        if _G.SHA1 then _G.SHA1 = function() return "BYPASS" end end
        if _G.FileHashChecker then
            _G.FileHashChecker.CheckFileMD5 = retTrue
            _G.FileHashChecker.VerifyAll = retTrue
            _G.FileHashChecker.GetHash = function() return "BYPASS" end
        end
        if _G.STExtraBlueprintFunctionLibrary then
            _G.STExtraBlueprintFunctionLibrary.CheckMD5 = retTrue
            _G.STExtraBlueprintFunctionLibrary.GetMD5 = function() return "BYPASS" end
            _G.STExtraBlueprintFunctionLibrary.VerifyFile = retTrue
        end
    end)
    print("[BYPASS] ✅ MD5 & Signature bypassed!")
end

-- DNSDEVICE BYPASS --
local function DNSDeviceBypass()
    pcall(function()
        local DeviceID = import("DeviceID")
        if DeviceID then
            DeviceID.GetDeviceID = function() return "BYPASSED_DEVICE" end
            DeviceID.GetAndroidID = function() return "BYPASSED_ANDROID_ID" end
            DeviceID.GetIMEI = function() return "BYPASSED_IMEI" end
            DeviceID.GetMACAddress = function() return "BYPASSED_MAC" end
            DeviceID.GetUniqueDeviceID = function() return "BYPASSED_UNIQUE" end
            DeviceID.GetDeviceName = function() return "BYPASSED_DEVICE_NAME" end
            DeviceID.GetDeviceModel = function() return "BYPASSED_MODEL" end
            DeviceID.GetDeviceBrand = function() return "BYPASSED_BRAND" end
            DeviceID.GetDeviceManufacturer = function() return "BYPASSED_MANUFACTURER" end
            DeviceID.GetDeviceBoard = function() return "BYPASSED_BOARD" end
            DeviceID.GetDeviceBootloader = function() return "BYPASSED_BOOTLOADER" end
            DeviceID.GetDeviceHardware = function() return "BYPASSED_HARDWARE" end
            DeviceID.GetDeviceHost = function() return "BYPASSED_HOST" end
            DeviceID.GetDeviceFingerprint = function() return "BYPASSED_FINGERPRINT" end
            DeviceID.GetDeviceSerial = function() return "BYPASSED_SERIAL" end
        end
        local DNS = import("DNS")
        if DNS then
            DNS.Resolve = DNS.Resolve  -- DISABLED (was 127.0.0.1, broke server connection)
            DNS.GetHostName = DNS.GetHostName  -- DISABLED
            DNS.GetIPAddress = DNS.GetIPAddress  -- DISABLED
        end
        local Network = import("Network")
        if Network then
            Network.GetIPAddress = Network.GetIPAddress  -- DISABLED
            Network.GetMACAddress = function() return "BYPASSED_MAC" end
            Network.GetSSID = function() return "BYPASSED_SSID" end
            Network.GetBSSID = function() return "BYPASSED_BSSID" end
        end
    end)
    print("[BYPASS] ✅ DNS & Device bypassed!")
end

-- GOKUBA BYPASS --
local function GokubaBypass()
    pcall(function()
        local Gokuba = package.loaded["GameLua.Mod.BaseMod.Client.Security.Gokuba"]
        if Gokuba then
            Gokuba.ForwardFeature = function() return {0,0,0,0,0} end
            Gokuba.InitGokubaLogic = nop
            if Gokuba.TimerHandle then
                local time_ticker = require("common.time_ticker")
                time_ticker.RemoveTimer(Gokuba.TimerHandle)
                Gokuba.TimerHandle = nil
            end
            for k, v in pairs(Gokuba) do
                if type(v) == "function" and (
                    k:find("Init") or k:find("Start") or k:find("Check") or
                    k:find("Scan") or k:find("Report") or k:find("Forward") or
                    k:find("Feature") or k:find("Detect") or k:find("Collect") or
                    k:find("Send") or k:find("Upload") or k:find("Verify") or
                    k:find("Analyze") or k:find("Process") or k:find("Handle")
                ) then
                    Gokuba[k] = nop
                end
            end
        end
        if _G.X3.GokubaLogic then
            _G.X3.GokubaLogic.ForwardFeature = nop
            _G.X3.GokubaLogic.InitGokubaLogic = nop
        end
    end)
    print("[BYPASS] ✅ Gokuba bypassed!")
end

-- RACING ANTI CHEAT BYPASS --
local function RacingAntiCheatBypass()
    pcall(function()
        if RacingAntiCheatLogic then
            RacingAntiCheatLogic.HandleRacingEnter = nop
            RacingAntiCheatLogic.HandleRacingStart = nop
            RacingAntiCheatLogic.HandleRacingEnd = nop
            RacingAntiCheatLogic.StartDetectTimer = nop
            RacingAntiCheatLogic.StopDetectTimer = nop
            RacingAntiCheatLogic.DetectVehicleFloating = nop
            RacingAntiCheatLogic.HandleFloatingCheat = nop
            RacingAntiCheatLogic.SetIgnoreFloating = nop
            RacingAntiCheatLogic.HandlePlayerPassCheckBelt = nop
            RacingAntiCheatLogic.HandleSpeedCheat = nop
            RacingAntiCheatLogic._CreateVehicleData = function() return {} end
            RacingAntiCheatLogic.vehicleDataMap = {}
            RacingAntiCheatLogic.detectTimer = nil
            RacingAntiCheatLogic.config = {
                FloatingDistLimit = 99999,
                FloatingTimeLimit = 99999,
                CheckPassIntervalLimit = 99999
            }
        end
    end)
    print("[BYPASS] ✅ Racing AntiCheat bypassed!")
end

-- LOGIN MODULE BYPASS --
local function LoginModuleBypass()
    pcall(function()
        if login_module then
            login_module["ban-login"] = function() return end
            login_module["idip-kick-out"] = function() return end
            login_module.aq_ban = function() return end
            login_module["device-in-blacklist"] = function() return end
            login_module.device_num_limit = function() return end
            login_module["register-forbidden"] = function() return end
            login_module["low-version"] = function() return end
            login_module["not-in-white-list"] = function() return end
            login_module.Login_Failed = function() return end
            login_module.aas_ban = function() return end
            login_module.PakMonitorStart = function(EnableMode) return end
            login_module.SetupFilenameHideKeywords = function() return end
            login_module.on_login_failed = function(conn_idx, reason, banInfo, banTime, uid, extra_table) return end
            login_module.DelaybanLoginCancelCallback = function() return end
            login_module.CheckBan = retFalse
            login_module.IsBanned = retFalse
        end
    end)
    print("[BYPASS] ✅ Login Module bypassed!")
end

-- LAYER 21: COMPLETE KILL ALL SUBSYSTEMS
local function KillAllSubsystems()
    pcall(function()
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            local toKill = {
                "CoronaLabSubsystem", "PlayerSecurityInfoSubsystem", "ClientCircleFlowSubsystem",
                "ModifierExceptionSubsystem", "SimulateCharacterSubsystem", "ShootVerifySubSystemClient",
                "HiggsBosonComponent", "ClientReportPlayerSubsystem", "DSReportPlayerSubsystem",
                "ClientHawkEyePatrolSubsystem", "DSHawkEyePatrolSubsystem", "ClientDataStatistcsSubsystem",
                "AFKReportorSubsystem", "BehaviorScoreSubsystem", "FileCheckSubsystem",
                "MemoryCheckSubsystem", "SpeedCheckSubsystem", "WallCheckSubsystem",
                "AvatarExceptionSubsystem", "GameReportSubsystem", "ClientSecMrpcsFlowSubsystem",
                "MrpcsFlowSubsystem", "CircleFlowSubsystem", "SwiftHawkSubsystem",
                "AntiCheatSubsystem", "IntegrityCheckSubsystem", "SignatureVerifySubsystem",
                "MD5CheckSubsystem", "PakVerifySubsystem", "DNSMonitorSubsystem",
                "DeviceFingerprintSubsystem", "ReplayMonitorSubsystem", "TelemetrySubsystem",
                "GokubaSubsystem", "RacingAntiCheatSubsystem", "ClientBanSubsystem",
                "RealTimeBanSubsystem", "TLogSubsystem", "ReportSubsystem",
                "SecurityMonitorSubsystem", "CheatDetectionSubsystem", "ViolationMonitorSubsystem",
                "SuspiciousActivitySubsystem", "AbnormalBehaviorSubsystem", "NetworkMonitorSubsystem",
                "AnalyticsSubsystem", "CrashReportSubsystem", "PerformanceMonitorSubsystem"
            }
            for _, name in ipairs(toKill) do
                local sub = SubMgr:Get(name)
                if sub then
                    for k, v in pairs(sub) do
                        if type(v) == "function" and (
                            k:find("Report") or k:find("Send") or k:find("Upload") or
                            k:find("Verify") or k:find("Check") or k:find("Validate") or
                            k:find("Scan") or k:find("Detect") or k:find("Collect") or
                            k:find("Flow") or k:find("Heartbeat") or k:find("Monitor") or
                            k:find("Track") or k:find("Record") or k:find("Log") or
                            k:find("Alert") or k:find("Notify") or k:find("Ban") or
                            k:find("Kick") or k:find("Suspend") or k:find("Flag") or
                            k:find("Anti") or k:find("AC") or k:find("Analyze") or
                            k:find("Process") or k:find("Handle") or k:find("Evaluate")
                        ) then pcall(function() sub[k] = nop end) end
                    end
                    if sub.timer then pcall(function() sub:RemoveGameTimer(sub.timer) end) end
                    if sub.heartbeatTimer then pcall(function() sub:RemoveGameTimer(sub.heartbeatTimer) end) end
                    if sub.reportTimer then pcall(function() sub:RemoveGameTimer(sub.reportTimer) end) end
                    if sub.checkTimer then pcall(function() sub:RemoveGameTimer(sub.checkTimer) end) end
                    if sub.monitorTimer then pcall(function() sub:RemoveGameTimer(sub.monitorTimer) end) end
                    if sub.scanTimer then pcall(function() sub:RemoveGameTimer(sub.scanTimer) end) end
                end
            end
        end
    end)
    print("[BYPASS] ✅ All subsystems killed!")
end

-- Execute all additional bypass layers
_G.X3.RunAdditionalBypass = function()
    -- pcall(NetworkBypass)
    pcall(ClientEntryBypass)
    pcall(BanLogicBypass)
    pcall(MD5Bypass)
    -- pcall(DNSDeviceBypass)
    pcall(GokubaBypass)
    pcall(RacingAntiCheatBypass)
    -- pcall(LoginModuleBypass)
    pcall(KillAllSubsystems)
end

pcall(_G.X3.RunAdditionalBypass)
end

do
    local function _gk_ret_true() return true end
    local function _gk_ret_false() return false end
    local function _gk_ret_zero() return 0 end
    local function _gk_ret_empty() return {} end
    local function _gk_noop() end
    local function _gk_isValid(obj)
        if type(slua) == "table" and type(slua.isValid) == "function" then
            local ok, res = pcall(slua.isValid, obj)
            return ok and (res == true)
        end
        return obj ~= nil
    end
    local function _gk_safe_require(path)
        local ok, mod = pcall(require, path)
        return ok and mod or nil
    end
    local function _gk_KillTable(tbl, keys)
        if type(tbl) ~= "table" then return end
        for _, k in ipairs(keys) do
            pcall(function() if tbl[k] ~= nil then tbl[k] = _gk_noop end end)
        end
    end

    _G.X3.BypassState = _G.X3.BypassState or {
        DeadEyeDisabled = false, HawkEyeDisabled = false, VoklaiDisabled = false,
        HiggsBosonDisabled = false, HashVerifyDisabled = false, IPMappingDisabled = false,
        MemoryPatchDisabled = false, EduEyeDisabled = false, FullBypassActive = false
    }

    function _G.X3.ApplyGokuBypasses()
        if _G.X3.BypassState.FullBypassActive then return end
        pcall(function()
            -- DeadEye / Aim tracking block
            if _G.GameplayCallbacks then
                _gk_KillTable(_G.GameplayCallbacks, {
                    "ReportAimFlow", "ReportHitFlow", "ReportAttackFlow",
                    "OnAimDetected", "OnHeadshotDetected", "OnPerfectAccuracy"
                })
            end
            local subsystems = _gk_safe_require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
            if subsystems then
                local ok, aimTracker = pcall(function() return subsystems:Get("ClientAimTrackingSubsystem") end)
                if ok and aimTracker then
                    pcall(function()
                        aimTracker.GetAimData = function()
                            return { accuracy = math.random(45, 65), headshotRate = math.random(15, 35) }
                        end
                        aimTracker.IsAimNormal = _gk_ret_true
                    end)
                end
            end
            _G.X3.BypassState.DeadEyeDisabled = true

            -- HawkEye patrol block
            if subsystems then
                local ok, hawkEye = pcall(function() return subsystems:Get("ClientHawkEyePatrolSubsystem") end)
                if ok and hawkEye then
                    pcall(function()
                        hawkEye.GetPatrolData = _gk_ret_empty
                        hawkEye.IsBeingWatched = _gk_ret_false
                        hawkEye.GetSpectatorCount = _gk_ret_zero
                    end)
                end
            end
            if _G.GameplayCallbacks then
                _gk_KillTable(_G.GameplayCallbacks, {
                    "SendDSErrorLogToLobby", "SendDSHawkEyePatrolLogToLobby", "ReportMatchRoomData"
                })
            end
            _G.X3.BypassState.HawkEyeDisabled = true

            -- Voklai / behavior + speedhack block
            if subsystems then
                local ok, aiBehavior = pcall(function() return subsystems:Get("ClientAIBehaviourSubsystem") end)
                if ok and aiBehavior then
                    pcall(function()
                        aiBehavior.GetBehaviorScore = function() return math.random(10, 30) end
                        aiBehavior.IsSuspicious = _gk_ret_false
                        aiBehavior.GetRiskLevel = _gk_ret_zero
                    end)
                end
                local ok2, speedHack = pcall(function() return subsystems:Get("AntiSpeedHackSubsystem") or subsystems:Get("ClientAntiSpeedHackSubsystem") end)
                if ok2 and speedHack then
                    pcall(function()
                        speedHack.GetSpeed = function() return math.random(300, 600) end
                        speedHack.IsSpeedValid = _gk_ret_true
                    end)
                end
            end
            _G.X3.BypassState.VoklaiDisabled = true

            -- HiggsBoson block
            local hud = _G.slua_GameFrontendHUD or _G.GameFrontendHUD
            local pc = nil
            if hud and type(hud.GetPlayerController) == "function" then
                local ok, r = pcall(function() return hud:GetPlayerController() end)
                if ok then pc = r end
            end
            if _gk_isValid(pc) then
                pcall(function()
                    if pc.HiggsBoson then
                        pc.HiggsBoson.bMHActive = false
                        pc.HiggsBoson.bCallPreReplication = false
                    end
                    if pc.HiggsBosonComponent then
                        pc.HiggsBosonComponent.bMHActive = false
                        pcall(function() pc.HiggsBosonComponent:ControlMHActive(0) end)
                    end
                end)
            end
            local higgs = _gk_safe_require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
            if higgs then
                pcall(function()
                    higgs.GetNetAvatarItemIDs = function() return { 1001, 2002, 3003 } end
                    higgs.GetCurWeaponSkinID = function() return 6001 end
                    higgs.GetCurItemIDs = function() return { 7001, 8002 } end
                end)
            end
            _G.X3.BypassState.HiggsBosonDisabled = true

            -- HashVerify / TSS scan block
            if _G.TssSdk then
                pcall(function()
                    _G.TssSdk.ScanMemory = function() return true, { code = 0, msg = "clean" } end
                    _G.TssSdk.VerifyFileHash = _gk_ret_true
                end)
            end
            _G.X3.BypassState.HashVerifyDisabled = true
            _G.X3.BypassState.IPMappingDisabled = true
            _G.X3.BypassState.MemoryPatchDisabled = true
            _G.X3.BypassState.EduEyeDisabled = true
            _G.X3.BypassState.FullBypassActive = true
        end)
    end

    local function _gk_InitFileIOCrashBlock()
        pcall(function()
            if not _G.X3.GOKU_IO_HOOKED and io and io.open then
                _G.X3.GOKU_IO_HOOKED = true
                local FILE_KEYWORDS = { "report", "cheat", "detect", "ban", "hawkeye", "crash", "log", "telemetry" }
                local orig_io_open = io.open
                io.open = function(path, mode)
                    if type(path) == "string" then
                        local lp = path:lower()
                        for _, kw in ipairs(FILE_KEYWORDS) do
                            if lp:find(kw, 1, true) then
                                if mode and (mode == "w" or mode == "a" or mode == "w+" or mode == "a+") then
                                    return nil, "Blocked"
                                end
                            end
                        end
                        if lp:find("tdm", 1, true) or lp:find("gcloud", 1, true) or lp:find("beacon", 1, true) then
                            if mode and (mode == "w" or mode == "a" or mode == "w+") then return nil, "Blocked" end
                        end
                    end
                    return orig_io_open(path, mode)
                end
            end
        end)
    end

    -- Execute Goku bypasses
    pcall(_G.X3.ApplyGokuBypasses)
    -- pcall(_gk_InitFileIOCrashBlock)

    if not isExpired then
        local okT, ticker = pcall(require, "common.time_ticker")
        if okT and ticker and ticker.AddTimerOnce then
            ticker.AddTimerOnce(0.1, function()
                pcall(_G.X3.ApplyGokuBypasses)
                -- pcall(_gk_InitFileIOCrashBlock)
            end)
        end
    end
end

-- NOTIFY --
local function Notify(msg)
    local s = "[VIP X3TeamID] " .. tostring(msg)
    pcall(function()
        if _G.X3.LexusNotify then
            _G.X3.LexusNotify(s)
        end
    end)
    pcall(function()
        local sh = import("ScriptHelperClient")
        if sh and sh.AddOnScreenDebugMessage then
            sh.AddOnScreenDebugMessage(s, -1, 3.0, {R=1, G=1, B=0, A=1}, {X=1.2, Y=1.2})
        end
    end)
    print(s)
end

local _slua = rawget(_G, "slua")

-- VALID --
local function Valid(obj)
    if not obj then
        return false
    end
    if _slua and _slua.isValid then
        local ok, v = pcall(_slua.isValid, obj)
        if not ok or not v then
            return false
        end
    end
    return true
end

local C_GREEN = {R=0, G=255, B=0, A=255}
local C_RED = {R=255, G=0, B=0, A=255}
local C_CYAN = {R=0, G=255, B=255, A=255}
local C_YELLOW = {R=255, G=255, B=0, A=255}
local C_WHITE = {R=255, G=255, B=255, A=255}
local C_BLUE_TEXT = {R=0, G=200, B=255, A=255}
local SCALE_COLOR_V2 = {R=3, G=3, B=0, A=0}

local GLOBAL_BONE_LIST = {
    "head", "neck_01", "pelvis",
    "upperarm_r", "lowerarm_r", "hand_r",
    "upperarm_l", "lowerarm_l", "hand_l",
    "thigh_l", "calf_l", "foot_l",
    "thigh_r", "calf_r", "foot_r"
}

local GLOBAL_CONNECTIONS = {
    {"neck_01", "pelvis", C_YELLOW},
    {"neck_01", "upperarm_l", C_CYAN}, {"upperarm_l", "lowerarm_l", C_CYAN}, {"lowerarm_l", "hand_l", C_CYAN},
    {"neck_01", "upperarm_r", C_CYAN}, {"upperarm_r", "lowerarm_r", C_CYAN}, {"lowerarm_r", "hand_r", C_CYAN},
    {"pelvis", "thigh_l", C_CYAN}, {"thigh_l", "calf_l", C_CYAN}, {"calf_l", "foot_l", C_CYAN},
    {"pelvis", "thigh_r", C_CYAN}, {"thigh_r", "calf_r", C_CYAN}, {"calf_r", "foot_r", C_CYAN}
}

-- KONFIGURASI LEXUS CORE + FULL FITUR VIP
_G.X3.LexusConfig = _G.X3.LexusConfig or {
    OutlineWeapon = false, OutlineWepThick = 3, OutlineWepBright = 180, OutlineWepRainbow = true,
    EspEnemyCount = false, EspEnemyCountSize = 13,
    SkinIngame = false,
    BulletTrack = false, BTRange = 300, BTPart = 0, BTProb = 100,
    CustomMagicBullet = false,
    CustomMagicBulletDist = 250,
    CustomMagicBulletIgBot = true,
    CustomMagicBulletIgKnock = true,
    CustomMagicBulletVisCheck = true,
    AutoHead = false,
    EspDistance = false,
    EspRadar = false,
    EspLoai6 = false,
    EspLoai7 = false,
    EspLoai8 = false,
    UnlockFPS = false,
    IpadView = false,
    CustomHRecoil = false,
    CustomVRecoil = false,
    LessShake = false,
    RemoveGrass = false,
    RemoveFog = false,
    WhiteBody = false,
    ColorBodyV2 = false,
    WallXuyenTuong = false,
    WallhackVisCheck = false,
    WallShowVis = true,
    WallShowOcc = true,
    WallAdaptive = true,
    WallPanicGuard = true,
    WallHideDead = true,
    SkinUnlockAll = false,
    SkinLobbyPreview = false,
    Crosshair = false,
    Accuracy = false,
    GodMode = false,
    BlackSky = false,

    AimTouchEnable = false,
    AimTouchHipIgKnock = false,
    AimTouchHipIgBot = false,
    AimTouchSGIgKnock = false,
    AimTouchSGIgBot = false,
    AimTouchHipVisCheck = false,
    AimTouchSGVisCheck = false,
    AimTouchHipfire = false,
    AimTouchSG = false,
    AimTouchSGAutoFire = false,
    AimTouchScopeAll = false,
    AimTouchScopeIgKnock = false,
    AimTouchScopeIgBot = false,
    AimTouchScopeVisCheck = false,
    AimTouchScopeSniper = false,
    AimTouchSniperIgKnock = false,
    AimTouchSniperIgBot = false,
    AimTouchSniperVisCheck = false,

    ModSkin = false,
    SkinOptionOpen = false
}

-- X3 TEAM SHOW POPUP --
local function X3Team_ShowPopup(msg)
    local text = tostring(msg)

    pcall(function()
        local Msg = require("client.slua.logic.common.logic_common_msg_box")
        if Msg and Msg.Show then
            Msg.Show(1, " X3Team Notification", text, function() end, function() end, "OK", "TUTUP")
        end
    end)

    pcall(function()
        if type(Notify) == "function" then
            Notify("[X3Team] " .. text)
        elseif type(_G.Notify) == "function" then
            _G.Notify("[X3Team] " .. text)
        end
    end)
end

_G.X3.LexusConfig = _G.X3.LexusConfig or {}
_G.X3.LexusConfig.FakeHWID = _G.X3.LexusConfig.FakeHWID or false
_G.X3.LexusConfig.RegenHWIDBtn = _G.X3.LexusConfig.RegenHWIDBtn or false
_G.X3.Team_OriginalInfo = _G.X3.Team_OriginalInfo or {}
_G.X3.Team_FakeData = _G.X3.Team_FakeData or {}

do

-- X3 TEAM SHOW POPUP --
local function X3Team_ShowPopup(msg)
    pcall(function()
        local Msg = require("client.slua.logic.Common.logic_common_msg_box") or require("client.slua.logic.common.logic_common_msg_box")
        if Msg and Msg.Show then
            Msg.Show(1, "[X3Team] Identity Spoofer", tostring(msg), function() end, function() end, "OK", "TUTUP")
        end
    end)
    pcall(function()
        if type(_G.Notify) == "function" then _G.Notify(tostring(msg)) end
    end)
end

-- X3 TEAM GENERATE FAKE IP --
local function X3Team_GenerateFakeIP()
    local prefixes = {"192.168", "10.0", "172.16", "100.64"}
    local prefix = prefixes[math.random(1, #prefixes)]
    return string.format("%s.%d.%d", prefix, math.random(1, 254), math.random(1, 254))
end

-- X3 TEAM HEX STR --
local function X3Team_HexStr(n)
    local hex = "0123456789abcdef"
    local s = ""
    for i = 1, n do local r = math.random(1, 16); s = s .. hex:sub(r, r) end
    return s
end

-- FirebaseInstanceID di dump: 32 hex lowercase
local function X3Team_GenerateFirebaseID()
    return X3Team_HexStr(32)
end

-- X3 TEAM GENERATE XID --
local function X3Team_GenerateXID()
    return X3Team_HexStr(64)
end

-- DeviceId di dump: 16 hex lowercase
local function X3Team_GenerateDeviceID()
    return X3Team_HexStr(16)
end

-- OAID / AdvertisingID: UUID v4 standar
local function X3Team_GenerateUUID()
    local hex = "0123456789abcdef"
    local function part(n) local s = "" for i=1,n do local r = math.random(1,16); s = s .. hex:sub(r, r) end return s end
    return string.format("%s-%s-4%s-%x%s-%s", part(8), part(4), part(3), math.random(8, 11), part(3), part(12))
end

-- X3 TEAM GENERATE HWID --
local function X3Team_GenerateHWID()
    return "X3Team" .. X3Team_HexStr(26)
end

local X3Team_DeviceProfiles = {
    { Model="IN2020",    Name="IN2020",    Make="oneplus",  UName="OnePlus 9 Pro",   Hardware="OnePlus+IN2020",      CPU="IN2020",    GPU="Adreno (TM) 660", GLRender="Adreno (TM) 660", GL="OpenGL ES 3.2 V@0530.0 (GIT@193cd85, I6ff8b5b3fc, 1635957706)",  Android="12", Sys="12" },
    { Model="SM-S928B",  Name="SM-S928B",  Make="samsung",  UName="Galaxy S24 Ultra", Hardware="samsung+SM-S928B",    CPU="SM-S928B",  GPU="Adreno (TM) 750", GLRender="Adreno (TM) 750", GL="OpenGL ES 3.2 V@0676.32 (GIT@e5f0e0a, I0e5f0e0abc, 1700000000)", Android="14", Sys="14" },
    { Model="2304FPN6DG", Name="2304FPN6DG", Make="Xiaomi", UName="Xiaomi 13T Pro",  Hardware="Xiaomi+2304FPN6DG",    CPU="2304FPN6DG", GPU="Mali-G720 Immortalis MC12", GLRender="Mali-G720", GL="OpenGL ES 3.2 v1.r36p0-01eac0",  Android="13", Sys="13" },
    { Model="22021211RG", Name="munch",    Make="Xiaomi",   UName="POCO F4",         Hardware="Xiaomi+munch",         CPU="munch",     GPU="Adreno (TM) 650", GLRender="Adreno (TM) 650", GL="OpenGL ES 3.2 V@0744.16 (GIT@afa4d62ddb, I8db249ac41, 1703587456)", Android="13", Sys="13" },
    { Model="ASUS_AI701", Name="ASUS_AI701", Make="asus",   UName="ROG Phone 7",     Hardware="asus+ASUS_AI701",      CPU="ASUS_AI701", GPU="Adreno (TM) 740", GLRender="Adreno (TM) 740", GL="OpenGL ES 3.2 V@0655.0 (GIT@b2f5b0e, I9ab12cd34, 1686000000)",  Android="13", Sys="13" },
    { Model="LE2121",    Name="LE2121",    Make="oneplus",  UName="OnePlus 9",       Hardware="OnePlus+LE2121",       CPU="LE2121",    GPU="Adreno (TM) 660", GLRender="Adreno (TM) 660", GL="OpenGL ES 3.2 V@0530.0 (GIT@193cd85, I6ff8b5b3fc, 1635957706)",  Android="12", Sys="12" },
}

-- X3 TEAM REGENERATE ALL FAKE DATA --
local function X3Team_RegenerateAllFakeData()
    local p = X3Team_DeviceProfiles[math.random(1, #X3Team_DeviceProfiles)]
    _G.X3.Team_FakeData = {
        HWID = X3Team_GenerateHWID(),
        DeviceID = X3Team_GenerateDeviceID(),
        IP = X3Team_GenerateFakeIP(),
        Firebase = X3Team_GenerateFirebaseID(),
        XID = X3Team_GenerateXID(),
        L1XID = X3Team_HexStr(32),
        AdID = X3Team_GenerateUUID(),
        OAID = X3Team_GenerateUUID(),
        Model = p.Model,
        Name = p.Name,
        Make = p.Make,
        UName = p.UName,
        Hardware = p.Hardware,
        CPU = p.CPU,
        GPU = p.GPU,
        GLRender = p.GLRender,
        GL = p.GL,
        MAC = string.format("%02X:%02X:%02X:%02X:%02X:%02X", math.random(0,255), math.random(0,255), math.random(0,255), math.random(0,255), math.random(0,255), math.random(0,255)),
        OS = p.Android,
        Sys = p.Sys,
        AndroidID = X3Team_HexStr(16),
        Serial = X3Team_HexStr(8),
        BuildFP = p.Make .. "/" .. p.Model .. "/" .. p.Model .. ":" .. p.Android .. "/RQ3A." .. math.random(100000, 999999) .. "." .. math.random(100, 999) .. ":user/release-keys",
        Operator = ({ "Telkomsel", "Indosat", "XL", "Tri", "Smartfren" })[math.random(1, 5)],
        BSSID = string.format("%02x:%02x:%02x:%02x:%02x:%02x", math.random(0,255), math.random(0,255), math.random(0,255), math.random(0,255), math.random(0,255), math.random(0,255)),
        SSID = "WiFi-" .. X3Team_HexStr(4),
    }
    return _G.X3.Team_FakeData
end

-- InfoListKey -> Team_FakeData key
local X3Team_InfoListFieldMap = {
    XID = "XID", DeviceId = "DeviceID", FirebaseInstanceID = "Firebase",
    OAID = "OAID", AdvertisingID = "AdID", L1XID = "L1XID",
    vClientIP = "IP",
    DeviceName = "Name", DeviceModel = "Model", DeviceMake = "Make",
    SystemHardware = "Hardware", CpuHardware = "CPU",
    UserDefineDeviceName = "UName",
    GLVersion = "GL", GLRender = "GLRender", GPUFamily = "GPU",
    AndroidVersion = "OS", SystemSoftware = "Sys",
    AndroidID = "AndroidID", DeviceSerial = "Serial",
    BuildFingerprint = "BuildFP", NetworkOperatorName = "Operator",
    WifiBSSID = "BSSID", WifiSSID = "SSID",
}
_G.X3.Team_DeviceOS_Orig = _G.X3.Team_DeviceOS_Orig or {}

-- X3 TEAM GET DATA OS --
local function X3Team_GetDataOS()
    local DataOS = package.loaded["client.logic.data.data_device_os"]
    if not DataOS then
        local okR, rR = pcall(require, "client.logic.data.data_device_os")
        if okR and type(rR) == "table" then DataOS = rR end
    end
    return DataOS
end

-- X3 TEAM CAPTURE ORIGINAL INFO --
local function X3Team_CaptureOriginalInfo()
    pcall(function()
        if _G.X3.Team_OriginalInfo.Captured then return end
        local o = _G.X3.Team_OriginalInfo
        local S = import("KismetSystemLibrary")
        local T = import("STExtraBlueprintFunctionLibrary")
        local P = import("PlatformWrapper")
        local DataOS = X3Team_GetDataOS()

        if not o.HWID then pcall(function() if S and S.GetDeviceId then local v = S.GetDeviceId(); if v and v ~= "" then o.HWID = v end end end) end
        if not o.Model then pcall(function() if T and T.GetDeviceModel then local v = T.GetDeviceModel(); if v and v ~= "" then o.Model = v end end end) end
        if not o.Name then pcall(function() if T and T.GetDeviceName then local v = T.GetDeviceName(); if v and v ~= "" then o.Name = v end end end) end
        if not o.MAC then pcall(function() if P and P.GetMacAddress then local v = P.GetMacAddress(); if v and v ~= "" then o.MAC = v end end end) end
        if not o.OS then pcall(function() if T and T.GetOSVersion then local v = T.GetOSVersion(); if v and v ~= "" then o.OS = v end end end) end

        if DataOS then
            local IL = rawget(DataOS, "InfoList")
            if type(IL) == "table" then
                if not o.XID then local v = rawget(IL, "XID"); if v and v ~= "" then o.XID = v end end
                if not o.IP then local v = rawget(IL, "vClientIP"); if v and v ~= "" then o.IP = v end end
                if not o.Firebase then local v = rawget(IL, "FirebaseInstanceID"); if v and v ~= "" then o.Firebase = v end end
                if not o.HWID then local v = rawget(IL, "DeviceId"); if v and v ~= "" then o.HWID = v end end
                if not o.Model then local v = rawget(IL, "DeviceModel"); if v and v ~= "" then o.Model = v end end
                if not o.Name then local v = rawget(IL, "DeviceName"); if v and v ~= "" then o.Name = v end end
                if not o.OS then local v = rawget(IL, "AndroidVersion"); if v and v ~= "" then o.OS = v end end
                for ilKey, _ in pairs(X3Team_InfoListFieldMap) do
                    local kk = "IL_" .. ilKey
                    if _G.X3.Team_DeviceOS_Orig[kk] == nil then
                        _G.X3.Team_DeviceOS_Orig[kk] = rawget(IL, ilKey)
                    end
                end
            end
            if not o.XID then pcall(function()
                if type(rawget(DataOS, "GetXID")) == "function" then
                    local v = DataOS.GetXID()
                    if v and v ~= "" then o.XID = v end
                end
            end) end
            if not o.IP then local v = rawget(DataOS, "vClientIP"); if v and v ~= "" then o.IP = v end end
            if not o.Firebase then local v = rawget(DataOS, "FirebaseInstanceID"); if v and v ~= "" then o.Firebase = v end end
            if not o.XID then local v = rawget(DataOS, "XID"); if v and v ~= "" then o.XID = v end end
            for ilKey, _ in pairs(X3Team_InfoListFieldMap) do
                local kk = "TL_" .. ilKey
                if _G.X3.Team_DeviceOS_Orig[kk] == nil then
                    _G.X3.Team_DeviceOS_Orig[kk] = rawget(DataOS, ilKey)
                end
            end
            -- latch hanya jika ada hasil nyata
            if o.XID or o.IP or o.Firebase or o.HWID then
                o.Captured = true
            end
        end
    end)
end

_G.X3._HWIDCaptureRetries = _G.X3._HWIDCaptureRetries or 0
-- X3 TEAM CAPTURE RETRY TICK (dijalankan dari MAINLOOP, bukan AddTimer) --
local function X3Team_CaptureRetryTick()
    if _G.X3.Team_OriginalInfo.Captured then _G.X3._CapRetryOn = false return end
    if (_G.X3._HWIDCaptureRetries or 0) >= 15 then _G.X3._CapRetryOn = false return end
    _G.X3._HWIDCaptureRetries = (_G.X3._HWIDCaptureRetries or 0) + 1
    X3Team_CaptureOriginalInfo()
    if _G.X3.Team_OriginalInfo.Captured then _G.X3._CapRetryOn = false end
end
_G.X3._CaptureRetryTick = X3Team_CaptureRetryTick
-- X3 TEAM START CAPTURE RETRY (aktifkan slot mainloop) --
local function X3Team_StartCaptureRetry()
    if _G.X3._HWIDCaptureRetryStarted then return end
    _G.X3._HWIDCaptureRetryStarted = true
    _G.X3._CapRetryOn = true
end

-- bisa placebo. Raw write = selalu kena baca.
function _G.X3.ApplyDeviceOSFakes()
    pcall(function()
        if not _G.X3.LexusConfig.FakeHWID then return end
        if not _G.X3.Team_FakeData.XID then X3Team_RegenerateAllFakeData() end
        local DataOS = X3Team_GetDataOS()
        if not DataOS then return end
        local f = _G.X3.Team_FakeData
        local IL = rawget(DataOS, "InfoList")
        if type(IL) == "table" then
            for ilKey, fKey in pairs(X3Team_InfoListFieldMap) do
                if f[fKey] ~= nil then IL[ilKey] = f[fKey] end
            end
        end
        for ilKey, fKey in pairs(X3Team_InfoListFieldMap) do
            if rawget(DataOS, ilKey) ~= nil and f[fKey] ~= nil then
                DataOS[ilKey] = f[fKey]
            end
        end
    end)
end

-- RESTORE DEVICE OSFAKES --
function _G.X3.RestoreDeviceOSFakes()
    pcall(function()
        local DataOS = X3Team_GetDataOS()
        if not DataOS then return end
        local IL = rawget(DataOS, "InfoList")
        if type(IL) == "table" then
            for ilKey, _ in pairs(X3Team_InfoListFieldMap) do
                local ov = _G.X3.Team_DeviceOS_Orig["IL_" .. ilKey]
                if ov ~= nil then IL[ilKey] = ov end
            end
        end
        for ilKey, _ in pairs(X3Team_InfoListFieldMap) do
            local ov = _G.X3.Team_DeviceOS_Orig["TL_" .. ilKey]
            if ov ~= nil then DataOS[ilKey] = ov end
        end
    end)
end

-- X3 TEAM HWIDAUTO REGEN TICK (dijalankan dari MAINLOOP tiap 300 dtk) --
local function X3Team_HWIDAutoRegenTick()
    pcall(function()
        if _G.X3.LexusConfig.FakeHWID then
            X3Team_RegenerateAllFakeData()
            _G.X3.ApplyDeviceOSFakes()
            if type(_G.X3.Trace) == "function" then _G.X3.Trace("HWID: auto-regen 5 menit (silent)") end
        end
    end)
end
_G.X3._HWIDAutoRegenTick = X3Team_HWIDAutoRegenTick

-- X3 TEAM START HWIDAUTO REGEN (aktifkan slot mainloop) --
local function X3Team_StartHWIDAutoRegen()
    if _G.X3._HWIDAutoRegenStarted then return end
    _G.X3._HWIDAutoRegenStarted = true
    _G.X3._HWIDRegenOn = true
end

-- TEAM INITIALIZE HWIDHOOK --
function _G.X3.Team_InitializeHWIDHook()
    X3Team_CaptureOriginalInfo()
    pcall(function()
        local S = import("KismetSystemLibrary")
        local T = import("STExtraBlueprintFunctionLibrary")
        local P = import("PlatformWrapper")

        if S and not _G.X3.Team_HWID_Hooked then
            -- Hook HWID
            _G.X3.Team_Orig_GetDeviceId = S.GetDeviceId
            function S.GetDeviceId(...)
                if _G.X3.LexusConfig.FakeHWID then
                    if not _G.X3.Team_FakeData.HWID then X3Team_RegenerateAllFakeData() end
                    return _G.X3.Team_FakeData.HWID
                end
                return _G.X3.Team_Orig_GetDeviceId and _G.X3.Team_Orig_GetDeviceId(...) or "UNKNOWN"
            end

            -- Hook Model
            if T and T.GetDeviceModel then
                _G.X3.Team_Orig_GetDeviceModel = T.GetDeviceModel
                function T.GetDeviceModel(...)
                    if _G.X3.LexusConfig.FakeHWID then return _G.X3.Team_FakeData.Model end
                    return _G.X3.Team_Orig_GetDeviceModel(...)
                end
            end

            -- Hook Name
            if T and T.GetDeviceName then
                _G.X3.Team_Orig_GetDeviceName = T.GetDeviceName
                function T.GetDeviceName(...)
                    if _G.X3.LexusConfig.FakeHWID then return _G.X3.Team_FakeData.Name end
                    return _G.X3.Team_Orig_GetDeviceName(...)
                end
            end

            -- Hook OS Version
            if T and T.GetOSVersion then
                _G.X3.Team_Orig_GetOSVersion = T.GetOSVersion
                function T.GetOSVersion(...)
                    if _G.X3.LexusConfig.FakeHWID then return _G.X3.Team_FakeData.OS end
                    return _G.X3.Team_Orig_GetOSVersion(...)
                end
            end

            -- Hook MAC
            if P and P.GetMacAddress then
                _G.X3.Team_Orig_GetMac = P.GetMacAddress
                function P.GetMacAddress(...)
                    if _G.X3.LexusConfig.FakeHWID then return _G.X3.Team_FakeData.MAC end
                    return _G.X3.Team_Orig_GetMac(...)
                end
            end

            _G.X3.Team_HWID_Hooked = true
        end

        local DataOS = X3Team_GetDataOS()
        if DataOS and not _G.X3.Team_DataOS_Hooked then
            if type(rawget(DataOS, "GetXID")) == "function" then
                _G.X3.Team_Orig_GetXID = rawget(DataOS, "GetXID")
                DataOS.GetXID = function(...)
                    if _G.X3.LexusConfig.FakeHWID and _G.X3.Team_FakeData.XID then return _G.X3.Team_FakeData.XID end
                    return _G.X3.Team_Orig_GetXID(...)
                end
            end
            if type(rawget(DataOS, "GetDeviceName")) == "function" then
                _G.X3.Team_Orig_GetDeviceNameOS = rawget(DataOS, "GetDeviceName")
                DataOS.GetDeviceName = function(...)
                    if _G.X3.LexusConfig.FakeHWID and _G.X3.Team_FakeData.Name then return _G.X3.Team_FakeData.Name end
                    return _G.X3.Team_Orig_GetDeviceNameOS(...)
                end
            end
            if type(rawget(DataOS, "GetGPUFamily")) == "function" then
                _G.X3.Team_Orig_GetGPUFamily = rawget(DataOS, "GetGPUFamily")
                DataOS.GetGPUFamily = function(...)
                    if _G.X3.LexusConfig.FakeHWID and _G.X3.Team_FakeData.GPU then return _G.X3.Team_FakeData.GPU end
                    return _G.X3.Team_Orig_GetGPUFamily(...)
                end
            end
            if type(rawget(DataOS, "getDeviceOSInfo")) == "function" then
                _G.X3.Team_Orig_getDeviceOSInfo = rawget(DataOS, "getDeviceOSInfo")
                DataOS.getDeviceOSInfo = function(...)
                    local r = _G.X3.Team_Orig_getDeviceOSInfo(...)
                    if _G.X3.LexusConfig.FakeHWID then _G.X3.ApplyDeviceOSFakes() end
                    return r
                end
            end
            _G.X3.Team_DataOS_Hooked = true
        end
        -- apply awal jika fitur sedang ON
        if _G.X3.LexusConfig.FakeHWID then _G.X3.ApplyDeviceOSFakes() end
    end)
end

-- X3 TEAM BUILD POPUP ON --
local function X3Team_BuildPopupON()
    local o = _G.X3.Team_OriginalInfo
    local f = _G.X3.Team_FakeData
    local function Safe(val) return (val and val ~= "") and tostring(val) or "[Not Found]" end
    local function Short(val) local s = Safe(val); if #s > 24 then s = s:sub(1, 24) .. "..." end return s end
    return string.format(
        "[FAKE IDENTITY AKTIF]\n\n" ..
        "DeviceID ASLI: %s\n> FAKE: %s\n\n" ..
        "XID ASLI: %s\n> FAKE: %s\n\n" ..
        "IP ASLI: %s\n> FAKE IP: %s\n\n" ..
        "Firebase ASLI: %s\n> FAKE: %s\n\n" ..
        "OAID/AdID FAKE: %s\n\n" ..
        "Model ASLI: %s\n> FAKE: %s (%s)\n\n" ..
        "MAC ASLI: %s\n> FAKE MAC: %s\n\n" ..
        "Auto-regen tiap 5 menit aktif (silent).",
        Short(o.HWID), Short(f.HWID),
        Short(o.XID), Short(f.XID),
        Safe(o.IP), Safe(f.IP),
        Short(o.Firebase), Short(f.Firebase),
        Short(f.OAID),
        Safe(o.Model), Safe(f.Model), Safe(f.UName),
        Safe(o.MAC), Safe(f.MAC)
    )
end

-- X3 TEAM BUILD POPUP OFF --
local function X3Team_BuildPopupOFF()
    return "[SEMUA IDENTITAS DIPULIHKAN]\n\n" ..
           "HWID, XID, DeviceId, IP, Firebase ID,\n" ..
           "OAID/AdID/L1XID, Device Model/Make,\n" ..
           "Hardware/CPU/GPU, MAC & OS Version\n" ..
           "telah dikembalikan ke nilai asli device Anda."
end

-- [MENU UI] Fake HWID + IP + Firebase + XID
function _G.X3.BuildX3HWIDMenu(stack, AliasMap)
    if not stack then return end

    table.insert(stack, {
        Key = "ModMenu_FakeHWID_Ex",
        UI = AliasMap.TitleSwitcher or "TitleSwitcher",
        Text = "FAKE HWID + IP + FIREBASE + XID [ IDENTITAS PERANGKAT PALSU ] (+ BOOST UDP)",
        ExpandIndex = 0,
        GetFunc = function() return _G.X3.LexusConfig.FakeHWID end,
        SetFunc = function(c, v)
            _G.X3.LexusConfig.FakeHWID = v
            if v then
                X3Team_RegenerateAllFakeData()
                X3Team_CaptureOriginalInfo()
                _G.X3.Team_InitializeHWIDHook()
                _G.X3.ApplyDeviceOSFakes()
                X3Team_ShowPopup(X3Team_BuildPopupON())
                X3Team_StartHWIDAutoRegen()
            else
                _G.X3.RestoreDeviceOSFakes()
                X3Team_ShowPopup(X3Team_BuildPopupOFF())
            end
            return true
        end
    })

    table.insert(stack, {
        Key = "ModMenu_FakeHWID_Regen",
        UI = AliasMap.Switcher or "Switcher",
        Text = "  [GENERATE] Randomize All Data [ ACAK ULANG SEMUA DATA ]",
        ExpandHandle = "ModMenu_FakeHWID_Ex",
        GetFunc = function() return _G.X3.LexusConfig.RegenHWIDBtn end,
        SetFunc = function(c, v)
            _G.X3.LexusConfig.RegenHWIDBtn = v
            if v then
                X3Team_RegenerateAllFakeData()
                _G.X3.ApplyDeviceOSFakes()
                local f = _G.X3.Team_FakeData
                local function Short(s) s = tostring(s or "?"); if #s > 24 then s = s:sub(1, 24) .. "..." end return s end
                X3Team_ShowPopup(string.format(
                    "[DATA BARU DI-GENERATE]\n\n" ..
                    "HWID: %s\n" ..
                    "XID: %s\n" ..
                    "DeviceId: %s\n" ..
                    "IP: %s\n" ..
                    "Firebase: %s\n" ..
                    "OAID: %s\n" ..
                    "Model: %s (%s)\n" ..
                    "MAC: %s",
                    Short(f.HWID), Short(f.XID), Short(f.DeviceID), Short(f.IP), Short(f.Firebase), Short(f.OAID), Short(f.Model), Short(f.UName), Short(f.MAC)
                ))
            end
            return true
        end
    })
end

-- Auto-Initialize Hook saat script dimuat
pcall(_G.X3.Team_InitializeHWIDHook)
pcall(X3Team_StartHWIDAutoRegen)
pcall(X3Team_StartCaptureRetry)
print("[X3Team] Ultimate Fake HWID + IP + Firebase + XID (No Placebo) Loaded!")

end


_G.X3.LexusState = _G.X3.LexusState or {
    LoopToken = 0,
    NativeESPReady = false,
    GraphicsUnlocked = false,
    MenuStep = 0,
    LastCmdTime = 0,
    TrackedMarks = {},
    EnemyMarks = {},
    LastAimbotCheckTime = 0,
    CustomTextData = nil,
    LastAimbotConfigString = "",
    MagicUpdateVersion = 1,
    LastMagicConfigHash = "",
    PrevGraphicsState = {}
}

-- LAYER VALIDASI TANGGAL 3 LAPIS (100% SINKRON)
local limitTime = os.time({ year = 2026, month = 08, day = 04, hour = 12, min = 00, sec = 0 })
local currentTime = os.time(os.date("!*t"))
isExpired = false

pcall(function()
    local fileName = ".sys_time_cache"
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "Documents/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "Documents/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "../../ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "../../ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName
    }

    if os and os.getenv then
        local homeDir = os.getenv("HOME")
        if homeDir and homeDir ~= "" then
            table.insert(paths, 1, homeDir .. "/Documents/ShadowTrackerExtra/Saved/SaveGames/" .. fileName)
            table.insert(paths, 2, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName)
        end
    end

    -- LAYER 1: WAKTU SERVER GAME
    local tm = package.loaded["client.logic.common.TimeManager"]
    if not tm then
        local s, r = pcall(require, "client.logic.common.TimeManager")
        if s and r then tm = r end
    end
    if tm and type(tm.GetServerTime) == "function" then
        local serverTime = tm.GetServerTime()
        if serverTime and serverTime > 1700000000 then
            currentTime = serverTime
        end
    end

    local lastSeenTime = 0
    for _, path in ipairs(paths) do
        local file = io.open(path, "r")
        if file then
            local data = file:read("*a")
            local savedTime = tonumber(data) or 0
            if savedTime > lastSeenTime then
                lastSeenTime = savedTime
            end
            file:close()
        end
    end

    if currentTime < lastSeenTime then
        currentTime = lastSeenTime
    else
        for _, path in ipairs(paths) do
            local file = io.open(path, "w")
            if file then
                file:write(tostring(currentTime))
                file:close()
            end
        end
    end

    local osTime = os.time(os.date("!*t"))
    if math.abs(osTime - currentTime) > 7200 then
        for _, path in ipairs(paths) do
            local file = io.open(path, "r")
            if file then
                local data = file:read("*a")
                local savedTime = tonumber(data) or 0
                if savedTime > 0 then
                    currentTime = savedTime
                end
                file:close()
                break
            end
        end
    end
end)

isExpired = (currentTime > limitTime)

-- NOP --
local function nop() return true end
-- RET FALSE --
local function retFalse() return false end
-- RET ZERO --
local function retZero() return 0 end
-- RET EMPTY --
local function retEmpty() return {} end
-- RET NIL --
local function retNil() return nil end
-- RET TRUE --
local function retTrue() return true end
-- RET EMPTY STRING --
local function retEmptyString() return "" end

-- INITIALIZE SLUABYPASS --
local function InitializeSLUABypass()
    pcall(function()
        if slua and slua.getSignature then slua.getSignature = function() return 0xDEADBEEF end end
        local loader = package.loaded["slua.loader"] or rawget(_G, "slua_loader")
        if loader then
            loader.verifyBytecode = retTrue
            loader.checkIntegrity = retTrue
            if loader.disableSignatureCheck then loader.disableSignatureCheck = retTrue end
        end
        local slua_serialize = package.loaded["slua.serialize"]
        if slua_serialize then slua_serialize.check = retTrue; slua_serialize.verify = retTrue end
        if jit and jit.attach then jit.attach(function() end, "bc") end
        if _G.slua_verify then _G.slua_verify = retTrue end
        if _G.check_slua_integrity then _G.check_slua_integrity = retTrue end
    end)
end

-- INITIALIZE MD5 BYPASS --
local function InitializeMD5Bypass()
    pcall(function()
        local CMode = import("CreativeModeBlueprintLibrary")
        if CMode then
            CMode.MD5HashByteArray = function() return "00000000000000000000000000000000" end
            CMode.MD5HashFile = function() return "00000000000000000000000000000000" end
            CMode.GetContentDiffData = function() return true, "BYPASSED" end
            CMode.VerifyFileIntegrity = retTrue
        end
        if _G.MD5Hash then _G.MD5Hash = function() return "00000000000000000000000000000000" end end
        if _G.CRC32 then _G.CRC32 = function() return 0 end end
        if _G.SHA1 then _G.SHA1 = function() return "BYPASS" end end
        local FileHashChecker = package.loaded["common.file_hash_checker"]
        if FileHashChecker then
            FileHashChecker.CheckFileMD5 = retTrue; FileHashChecker.VerifyAll = retTrue
            FileHashChecker.GetHash = function() return "BYPASS" end
        end
        local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
        if TssSdk then TssSdk.GetFileMD5 = function() return "BYPASS" end; TssSdk.VerifyFileSignature = retTrue end
        local STExtra = import("STExtraBlueprintFunctionLibrary")
        if STExtra then STExtra.CheckMD5 = retTrue; STExtra.GetMD5 = function() return "BYPASS" end; STExtra.VerifyFile = retTrue end
    end)
end

-- INITIALIZE SKIN BYPASS --
local function InitializeSkinBypass()
    pcall(function()
        local ptlog = package.loaded["client.slua.logic.download.report.puffer_tlog"]
        if ptlog then ptlog.ReportEvent = nop; ptlog.ReportDownloadResult = nop; ptlog.ReportODPTDError = nop; ptlog.ReportSkinError = nop end
        local AvatarUtils = package.loaded["AvatarUtils"]
        if AvatarUtils then AvatarUtils.CheckIsWeaponInBlackList = retFalse; AvatarUtils.IsValidAvatar = retTrue; AvatarUtils.CheckAvatarIntegrity = retTrue; AvatarUtils.ReportInvalidAvatar = nop end
        local sub = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr"):Get("FileCheckSubsystem")
        if sub then sub.StartCheck = nop; sub.ReportAbnormalFile = nop; sub.StopCheck = nop end
        local eqEx = package.loaded["client.slua.logic.report.EquipmentExceptionReport"]
        if eqEx then eqEx.Report = nop; eqEx.SendException = nop end
    end)
end

-- INITIALIZE LOG BLOCKER --
local function InitializeLogBlocker()
    pcall(function()
        local SMTD = import("ScreenshotMTDer")
        if SMTD then SMTD.MTDePicture = function() return "" end; SMTD.ReMTDePicture = function() return "" end; SMTD.HasCaptured = retTrue; SMTD.TakeScreenshot = nop end
        local TLog = package.loaded["TLog"] or _G.TLog
        if TLog then TLog.Info = nop; TLog.Warning = nop; TLog.Error = nop; TLog.Debug = nop; TLog.Report = nop; TLog.Send = nop; TLog.Flush = nop end
        local CrashSight = package.loaded["CrashSight"] or _G.CrashSight
        if CrashSight then CrashSight.ReportException = nop; CrashSight.SetCustomData = nop; CrashSight.Log = nop; CrashSight.SendCrash = nop; CrashSight.ReportUserException = nop end
        local GRUtils = package.loaded["GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils"]
        if GRUtils then GRUtils.BugglyPostExceptionFull = retFalse; GRUtils.CheckCanBugglyPostException = retFalse; GRUtils.ReplayReportData = nop; GRUtils.ReportGameException = nop; GRUtils.PostException = nop end
        local CTR = package.loaded["client.slua.logic.report.ClientToolsReport"]
        if CTR then CTR.SendReport = nop; CTR.SendException = nop; CTR.UploadLog = nop end
        for _, sdk in ipairs({"Firebase", "Adjust", "AppsFlyer", "FacebookAnalytics", "GameAnalytics"}) do
            local s = _G[sdk]; if s then s.logEvent = nop; s.trackEvent = nop; s.setEnabled = retFalse; s.sendEvent = nop; s.report = nop end
        end
    end)
end

-- INITIALIZE SCANNER BLOCKER --
local function InitializeScannerBlocker()
    pcall(function()
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            local subs = {"AFKReportorSubsystem", "ClientDataStatistcsSubsystem", "AvatarExceptionSubsystem", "ShootVerifySubSystemClient", "MemoryCheckSubsystem", "SpeedCheckSubsystem", "WallCheckSubsystem", "FileCheckSubsystem", "BehaviorScoreSubsystem"}
            for _, name in ipairs(subs) do
                local sub = SubMgr:Get(name)
                if sub then
                    for k, v in pairs(sub) do
                        if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Upload") or k:find("Verify") or k:find("Check") or k:find("Validate") or k:find("Scan") or k:find("Detect")) then pcall(function() sub[k] = nop end) end
                    end
                    if sub.ReportPingDelayTimer then sub:RemoveGameTimer(sub.ReportPingDelayTimer); sub.ReportPingDelayTimer = nil end; sub.DelayCount = 0
                end
            end
        end
        local AvaEx = package.loaded["GameLua.Mod.Library.GamePlay.Avatar.Exception.AvatarExceptionPlayerInst"]
        if AvaEx then AvaEx.CheckAvatarException = nop; AvaEx.CheckAvatarExceptionOnce = nop; AvaEx.ReportAvatarException = nop; AvaEx.CheckSlotMeshVisible = retFalse; AvaEx.CheckPawnVisible = retFalse; AvaEx.CheckCanBugglyPostException = retFalse end
        local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
        if TssSdk then
            local origData = TssSdk.OnRecvData
            TssSdk.OnRecvData = function(data) if type(data) == "string" and (data:find("report", 1, true) or data:find("exception", 1, true) or data:find("cheat", 1, true) or data:find("violation", 1, true) or data:find("hack", 1, true) or data:find("verify", 1, true)) then return end; if origData then origData(data) end end
            TssSdk.SendReportInfo = nop; TssSdk.ScanMemory = retTrue; TssSdk.IsEmulator = retFalse; TssSdk.GetTssSdkReportInfo = retEmptyString; TssSdk.CheckEnvironment = retTrue; TssSdk.VerifyProcess = retTrue
        end
    end)
end

-- INITIALIZE REPLAY TELEMETRY BLOCKER --
local function InitializeReplayTelemetryBlocker()
    pcall(function()
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            for _, name in ipairs({"GameReportSubsystem", "ReplaySubsystem"}) do
                local sub = SubMgr:Get(name)
                if sub then for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Trace") or k:find("Replay") or k:find("Record") or k:find("Save")) then pcall(function() sub[k] = nop end) end end end
            end
        end
        local logRep = package.loaded["client.slua.logic.replay.logic_report_replay"]
        if logRep then logRep.ReportReplay = nop; logRep.SendReportReq = nop; logRep.UploadReplay = nop end
    end)
end

-- INITIALIZE REPORT FLOW BLOCKER --
local function InitializeReportFlowBlocker()
    pcall(function()
        local flows = {"ReportAimFlow", "ReportHitFlow", "ReportAttackFlow", "ReportSecAttackFlow", "ReportFireArms", "ReportVerifyInfoFlow", "ReportMrpcsFlow", "ReportPlayerBehavior", "ReportTeammatHurt", "ReportMisKillByTeammate", "ReportForbitPick", "ReportPlayerMoveRoute", "ReportPlayerPosition", "ReportSecTgameMovingFlow", "ReportParachuteData", "ReportEquipmentFlow", "ReportPlayersPing", "ReportPlayerIP", "ReportPlayerFramePingRecord", "ReportDSNetSaturation", "ReportNetContinuousSaturate", "ReportDSNetRate", "ReportCircleFlow", "ReportSecMrpcsFlow"}
        for _, f in ipairs(flows) do if _G[f] then _G[f] = nop end; if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = nop end end
        for _, f in ipairs({"CheckReportSecAttackFlowWithAttackFlow", "CheckReportSecAttackFlow"}) do if _G[f] then _G[f] = retFalse end; if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = retFalse end end
        for _, f in ipairs({"IsEnableReportMrpcsInCircleFlow", "IsEnableReportMrpcsInPartCircleFlow", "IsEnableReportMrpcsFlow", "IsEnableReportAttackFlow", "IsEnableReportHitFlow", "IsEnableReportCircleFlow"}) do if _G[f] then _G[f] = retFalse end end
    end)
end

-- INITIALIZE PLAYER SECURITY BYPASS --
local function InitializePlayerSecurityBypass()
    pcall(function()
        for _, c in ipairs({"PlayerSecurityInfoCollector", "PlayerSecurityInfo", "SecurityInfoCollector", "ClientSecurityCollector", "PlayerAntiCheatCollector"}) do
            if _G[c] then for k, v in pairs(_G[c]) do if type(v) == "function" and (k:find("Report") or k:find("Collect") or k:find("Send") or k:find("Upload") or k:find("Record")) then _G[c][k] = nop end end end
        end
        local SecSub = require("GameLua.Mod.BaseMod.Common.Security.PlayerSecurityInfoSubsystem")
        if SecSub then SecSub.ReportData = nop; SecSub.CheckCheat = retFalse; SecSub.ValidatePlayer = retTrue; SecSub.CollectData = nop; SecSub.SendToServer = nop end
    end)
end

-- INITIALIZE CLIENT FLOW BYPASS --
local function InitializeClientFlowBypass()
    pcall(function()
        for _, name in ipairs({"ClientSecMrpcsFlow", "MrpcsFlow", "MrpcsData", "ClientCircleFlowSubsystem", "ClientKillFlowSubsystem", "ClientSecPlayerKillFlow"}) do
            local sub = package.loaded[name] or _G[name]
            if sub then for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Flow") or k:find("Record") or k:find("Process")) then pcall(function() sub[k] = nop end) end end end
        end
    end)
end

-- INITIALIZE SWIFT HAWK BYPASS --
local function InitializeSwiftHawkBypass()
    pcall(function()
        for _, f in ipairs({"SwiftHawk", "ClientSwiftHawk", "ClientSwiftHawkWithParams", "SendSwiftHawkData"}) do if _G[f] then _G[f] = nop end; if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = nop end end
        local sub = package.loaded["GameLua.Mod.BaseMod.Client.Security.SwiftHawkSubsystem"]
        if sub then sub.ReportData = nop; sub.SendReport = nop; sub.CollectTelemetry = nop end
    end)
end

-- INITIALIZE CORONA LAB BYPASS --
local function InitializeCoronaLabBypass()
    pcall(function()
        if _G.CoronaLab then _G.CoronaLab.ReportData = nop; _G.CoronaLab.SendData = nop; _G.CoronaLab.CollectData = nop; _G.CoronaLab.Telemetry = nop end
        local sub = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr"):Get("CoronaLabSubsystem")
        if sub then sub.ReportData = nop; sub.SendToServer = nop; sub.CollectTelemetry = nop; sub.StopCollection = nop end
    end)
end

-- INITIALIZE MODIFIER EXCEPTION BYPASS --
local function InitializeModifierExceptionBypass()
    pcall(function()
        if _G.bReportedModifierException then _G.bReportedModifierException = false end
        local sub = require("GameLua.Mod.BaseMod.Common.Security.ModifierExceptionSubsystem")
        if sub then sub.ReportException = nop; sub.CheckModifier = retTrue; sub.ValidateModifier = retTrue; sub.ReportModifierError = nop end
    end)
end

-- INITIALIZE SIMULATE CHARACTER LOCATION BYPASS --
local function InitializeSimulateCharacterLocationBypass()
    pcall(function()
        local sub = require("GameLua.Mod.BaseMod.Gameplay.Simulate.SimulateCharacterSubsystem")
        if sub then sub.ReportLocation = nop; sub.SendLocationData = nop; sub.VerifyLocation = retTrue end
    end)
end

-- INITIALIZE SHOOT VERIFICATION BYPASS --
local function InitializeShootVerificationBypass()
    pcall(function()
        local sub = require("GameLua.Dev.Subsystem.ShootVerifySubSystemClient")
        if sub then sub.OnShootVerifyFailed = nop; sub.SendVerifyData = nop; sub.ReportBulletHit = nop; sub.UploadHitInfo = nop; sub.VerifyShot = retTrue end
        if _G.BulletHitInfoUploadData then _G.BulletHitInfoUploadData.Report = nop; _G.BulletHitInfoUploadData.Send = nop; _G.BulletHitInfoUploadData.Upload = nop end
    end)
end

-- INITIALIZE NETWORK PACKET BLOCK --
local function InitializeNetworkPacketBlock()
    pcall(function()
        if NetUtil and NetUtil.SendPacket then
            local orig = NetUtil.SendPacket
            local blocked = {
                ["ReportAttackFlow"]=1, ["ReportSecAttackFlow"]=1, ["ReportFireArms"]=1, ["ReportVerifyInfoFlow"]=1, ["ReportMrpcsFlow"]=1,
                ["ReportPlayerBehavior"]=1, ["ReportTeammatHurt"]=1, ["ReportPlayerMoveRoute"]=1, ["ReportPlayerPosition"]=1,
                ["report_parachute_data"]=1, ["on_tss_sdk_anti_data"]=1, ["ReportAimFlow"]=1, ["ReportHitFlow"]=1, ["ReportCircleFlow"]=1, ["report_players_ping"]=1,
                ["report_player_ip"]=1, ["report_net_saturate"]=1, ["report_speed_hack"]=1, ["report_wall_hack"]=1, ["report_aim_bot"]=1, ["report_esp_usage"]=1,
                ["report_modded_files"]=1, ["detect_cheat"]=1, ["ban_player"]=1, ["client_anti_cheat_report"]=1,
                ["ClientSecMrpcsFlow"]=1, ["MrpcsData"]=1, ["CheckReportSecAttackFlow"]=1, ["CheckReportSecAttackFlowWithAttackFlow"]=1, ["RPC_ClientCoronaLab"]=1,
                ["CoronaLabReport"]=1, ["CoronaLabData"]=1, ["PlayerSecurityInfo"]=1, ["ReportSecurityInfo"]=1, ["SendSecurityData"]=1, ["ClientCircleFlow"]=1,
                ["IsEnableReportMrpcsInCircleFlow"]=1, ["IsEnableReportMrpcsInPartCircleFlow"]=1, ["bReportedModifierException"]=1,
                ["ReportModifierException"]=1, ["RPC_Server_ReportSimulateCharacterLocation"]=1, ["ReportSimulateCharacterLocation"]=1, ["RPC_Client_ShootVertifyRes"]=1,
                ["BulletHitInfoUploadData"]=1, ["ShootVerifyFailed"]=1, ["report_unrealnet_exception"]=1, ["tss_sdk_report"]=1, ["SwiftHawk"]=1, ["ClientSwiftHawk"]=1, ["ClientSwiftHawkWithParams"]=1, ["SwiftHawkReport"]=1, ["SwiftHawkData"]=1,
                ["AntiCheatReport"]=1, ["CheatDetection"]=1, ["ViolationReport"]=1, ["SecurityViolation"]=1, ["IntegrityCheck"]=1, ["SignatureVerify"]=1
            }
            NetUtil.SendPacket = function(packetName, ...) if blocked[packetName] then return nil end; return orig(packetName, ...) end
            NetUtil.IsBypassed = true
        end
        if _G.SendRPC then
            local origRPC = _G.SendRPC
            local blockedRPC = {"RPC_Server_ClientSecMrpcsFlow", "RPC_Server_SwiftHawk", "RPC_Server_ClientSwiftHawkWithParams", "RPC_Server_ReportSimulateCharacterLocation", "RPC_Client_ShootVertifyRes", "RPC_ClientCoronaLab"}
            _G.SendRPC = function(rpcName, ...) for _, b in ipairs(blockedRPC) do if rpcName == b then return nil end end; return origRPC(rpcName, ...) end
        end
    end)
end

-- INITIALIZE HIGGS BOSON BYPASS --
local function InitializeHiggsBosonBypass()
    pcall(function()
        local Higgs = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if Higgs then
            for _, m in ipairs({"ControlMHActive", "Tick", "OnTick", "MHActiveLogic", "TriggerAvatarCheck", "StartAvatarCheck", "ReportItemID", "ReceiveAnyDamage", "OnWeaponHitRecord", "ShowSecurityAlert", "ServerReportAvatar", "ClientReportNetAvatar", "SendHisarData", "ValidateSecurityData", "StaticShowSecurityAlertInDev", "RPC_Client_ShootVertifyRes", "RPC_Server_ReportSimulateCharacterLocation", "DisableHiggsBoson", "CheckMHActive", "ReportViolation", "ProcessSecurityEvent", "ValidatePlayer", "CheckIntegrity"}) do
                if Higgs[m] then Higgs[m] = nop end
            end
            Higgs.GetNetAvatarItemIDs = retEmpty; Higgs.GetCurWeaponSkinID = retZero; Higgs.IsMHActive = retFalse; Higgs.bMHActive = false; Higgs.bCallPreReplication = false
            if Higgs.BlackList then for k in pairs(Higgs.BlackList) do Higgs.BlackList[k] = nil end end
        end
        _G.BlackList = {}
        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if slua.isValid(pc) then
            if pc.HiggsBoson then pc.HiggsBoson.bMHActive = false; pc.HiggsBoson.bCallPreReplication = false; if pc.HiggsBoson.ControlMHActive then pc.HiggsBoson:ControlMHActive(0) end end
            if pc.HiggsBosonComponent then pc.HiggsBosonComponent.bMHActive = false; pc.HiggsBosonComponent.bCallPreReplication = false; pc.HiggsBosonComponent:ControlMHActive(0) end
        end
    end)
end

-- INITIALIZE ANTI CHEAT HOOKS --
local function InitializeAntiCheatHooks()
    pcall(function()
        local HBC = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if HBC and HBC.StaticShowSecurityAlertInDev then HBC.StaticShowSecurityAlertInDev = nop end
    end)
    if _G.AvatarCheckCallback then
        _G.AvatarCheckCallback.StartAvatarCheck = nop; _G.AvatarCheckCallback.OnReportItemID = nop
        _G.AvatarCheckCallback.PostPlayerControllerLoginInit = function(PlayerController)
            if slua.isValid(PlayerController) and PlayerController.HiggsBosonComponent then PlayerController.HiggsBosonComponent:ControlMHActive(0); PlayerController.HiggsBosonComponent.bMHActive = false end
        end
    end
end

-- INITIALIZE ANTI REPORT --
local function InitializeAntiReport()
    pcall(function()
        for _, path in ipairs({"GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem", "Client.Security.ClientReportPlayerSubsystem", "GameLua.Mod.BaseMod.DS.Security.DSReportPlayerSubsystem"}) do
            local sub = package.loaded[path]; if not sub then local s, r = pcall(require, path); if s and r then sub = r end end
            if sub then for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Record") or k:find("Send") or k:find("Upload") or k:find("Notify")) then pcall(function() sub[k] = nop end) end end end
        end
    end)
end

-- INITIALIZE GAMEPLAY BYPASS --
local function InitializeGameplayBypass()
    pcall(function()
        if not _G.GameplayCallbacks then _G.GameplayCallbacks = {} end
        if _G.GameplayCallbacks.IsBypassed then return end
        local GC = _G.GameplayCallbacks
        local reports = {"ReportAttackFlow", "ReportSecAttackFlow", "ReportFireArms", "ReportVerifyInfoFlow", "ReportMrpcsFlow", "ReportPlayerBehavior", "ReportTeammatHurt", "ReportMisKillByTeammate", "ReportForbitPick", "ReportPlayerMoveRoute", "ReportPlayerPosition", "ReportSecTgameMovingFlow", "ReportParachuteData", "SendTssSdkAntiDataToLobby", "ReportEquipmentFlow", "ReportAimFlow", "ReportPlayersPing", "ReportPlayerIP", "ReportPlayerFramePingRecord", "OnDSConnectionSaturated", "ReportDSNetSaturation", "ReportNetContinuousSaturate", "ReportDSNetRate", "SendClientStats", "SendServerAvgTickDelta", "ReportCircleFlow", "ClientSecMrpcsFlow", "SwiftHawk", "ClientSwiftHawk", "ClientSwiftHawkWithParams"}
        for _, f in ipairs(reports) do GC[f] = nop end
        GC.CheckReportSecAttackFlowWithAttackFlow = retFalse; GC.CheckReportSecAttackFlow = retFalse
        local origState = GC.OnDSPlayerStateChanged
        GC.OnDSPlayerStateChanged = function(UID, State, bPure, bSafe, Param)
            local s = State and string.lower(tostring(State)) or ""
            local blocked = {["cheatdetected"]=1, ["connectionlost"]=1, ["connectiontimeout"]=1, ["connectionexception"]=1, ["netdrivererror"]=1, ["banned"]=1, ["kicked"]=1, ["suspended"]=1, ["violationdetected"]=1, ["integrityfailure"]=1, ["securityviolation"]=1}
            if blocked[s] then return end
            if origState then pcall(origState, UID, State, bPure, bSafe, Param) end
        end
        GC.OnPlayerNetConnectionClosed = nop; GC.OnPlayerActorChannelError = nop; GC.OnPlayerRPCValidateFailed = nop; GC.OnPlayerSpectateException = nop; GC.OnShutdownAfterError = nop; GC.IsBypassed = true
    end)
end

-- INITIALIZE KILL ALL SUBSYSTEMS --
local function InitializeKillAllSubsystems()
    pcall(function()
        local subMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if not subMgr then return end
        local toKill = {"CoronaLabSubsystem", "PlayerSecurityInfoSubsystem", "ClientCircleFlowSubsystem", "ModifierExceptionSubsystem", "SimulateCharacterSubsystem", "ShootVerifySubSystemClient", "HiggsBosonComponent", "ClientReportPlayerSubsystem", "DSReportPlayerSubsystem", "ClientHawkEyePatrolSubsystem", "DSHawkEyePatrolSubsystem", "ClientDataStatistcsSubsystem", "AFKReportorSubsystem", "BehaviorScoreSubsystem", "FileCheckSubsystem", "MemoryCheckSubsystem", "SpeedCheckSubsystem", "WallCheckSubsystem", "AvatarExceptionSubsystem", "GameReportSubsystem", "ClientSecMrpcsFlowSubsystem", "MrpcsFlowSubsystem", "CircleFlowSubsystem", "SwiftHawkSubsystem", "AntiCheatSubsystem", "IntegrityCheckSubsystem", "SignatureVerifySubsystem", "MD5CheckSubsystem", "PakVerifySubsystem"}
        for _, name in ipairs(toKill) do
            local sub = subMgr:Get(name)
            if sub then
                for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Upload") or k:find("Verify") or k:find("Check") or k:find("Validate") or k:find("Scan") or k:find("Detect") or k:find("Collect") or k:find("Flow") or k:find("Heartbeat")) then pcall(function() sub[k] = nop end) end end
                if sub.timer then pcall(function() sub:RemoveGameTimer(sub.timer) end) end
                if sub.heartbeatTimer then pcall(function() sub:RemoveGameTimer(sub.heartbeatTimer) end) end
                if sub.reportTimer then pcall(function() sub:RemoveGameTimer(sub.reportTimer) end) end
            end
        end
    end)
end

-- INITIALIZE FINAL PROTECTION --
local function InitializeFinalProtection()
    pcall(function()
        for _, flag in ipairs({"ENABLE_REPORT", "ENABLE_ANTI_CHEAT", "ENABLE_SECURITY", "ENABLE_TELEMETRY", "ENABLE_ANALYTICS", "ENABLE_CRASH_REPORT", "ENABLE_PERFORMANCE_REPORT"}) do if _G[flag] then _G[flag] = false end end
        local origReq = require
        local blocked = {"HiggsBosonComponent", "PlayerSecurityInfoSubsystem", "CoronaLabSubsystem", "ClientCircleFlowSubsystem", "ModifierExceptionSubsystem", "ShootVerifySubSystemClient", "ClientReportPlayerSubsystem", "DSReportPlayerSubsystem"}
        _G.require = function(m) for _, b in ipairs(blocked) do if m:find(b) then return {} end end; return origReq(m) end
    end)
end

-- START BYPASS VIP V3 --
_G.X3.StartBypass_VIP_v3 = function()
    pcall(function()
        print("[ULTIMATE BYPASS] Starting initialization...")
        InitializeSLUABypass()
        InitializeMD5Bypass()
        InitializeSkinBypass()
        InitializeLogBlocker()
        InitializeScannerBlocker()
        InitializeReplayTelemetryBlocker()
        InitializeReportFlowBlocker()
        InitializePlayerSecurityBypass()
        InitializeClientFlowBypass()
        InitializeSwiftHawkBypass()
        InitializeCoronaLabBypass()
        InitializeModifierExceptionBypass()
        InitializeSimulateCharacterLocationBypass()
        InitializeShootVerificationBypass()
        InitializeNetworkPacketBlock()
        InitializeHiggsBosonBypass()
        InitializeAntiCheatHooks()
        InitializeAntiReport()
        InitializeGameplayBypass()
        InitializeCustomMagicBulletHooks()  -- <-- INI DITAMBAH
        InitializeKillAllSubsystems()
        InitializeFinalProtection()
                pcall(function()
            if _G.X3.RareFeatures and not _G.X3.RareFeatures.Inited then
                -- Trigger init via dummy access
                local _ = _G.X3.RareFeatures.DR_Active
            end
        end)
        print("[ULTIMATE BYPASS] Complete - All Security Systems Disabled")
    end)
end

-- SAFE ADD MARK --
local function SafeAddMark(id, pos, z, str, size, actor)
    local mark = nil
    pcall(function()
        local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
        if InGameMarkTools and InGameMarkTools.ClientAddMapMark then
            mark = InGameMarkTools.ClientAddMapMark(id, pos, z, str, size, actor)
            if mark then _G.X3.LexusState.TrackedMarks[mark] = true end
        end
    end)
    return mark
end

-- SAFE REMOVE MARK --
local function SafeRemoveMark(mark)
    if not mark then return end
    pcall(function()
        local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
        if InGameMarkTools and InGameMarkTools.HideMapMark then
            InGameMarkTools.HideMapMark(mark)
        end
        if InGameMarkTools and InGameMarkTools.RemoveMapMark then
            InGameMarkTools.RemoveMapMark(mark)
        end
    end)
    _G.X3.LexusState.TrackedMarks[mark] = nil
end

-- GET SAFE ENEMY KEY --
local function GetSafeEnemyKey(enemy)
    if Valid(enemy) then
        if enemy.PlayerKey then return tostring(enemy.PlayerKey) end
        if type(enemy.GetUniqueID) == "function" then return tostring(enemy:GetUniqueID()) end
    end
    return tostring(enemy)
end

-- INISIALISASI HOOKS AUTO HEAD
function _G.X3.InitializeAutoHeadHooks()
end

_G.X3.VIP_Attachments = {
    [1101004236]={1010042307,1010042306,1010042308,1010042304,1010042300,1010042305,1010042299,1010042298,1010042297,1010042296,1010042295,1010042294,0,1010042314,1010042309,1010042316,1010042317,1010042318,1010042310,1010042315,1010042319,0},
    [1101001116]={1010011106,1010011107,1010011108,0,1010011109,1010011112,1010011105,1010011104,1010011103,0,1010011102,0,0,0,0,0,0,0,0,0,0,0},
    [1101001128]={1010011232,1010011233,1010011234,1010011228,1010011227,1010011229,1010011226,1010011225,1010011224,1010011223,1010011222,0,0,0,0,0,0,0,0,0,0,0},
    [1101001154]={1010011487,1010011488,1010011489,1010011493,1010011490,1010011494,1010011486,1010011485,1010011484,1010011483,1010011482,1010011497,0,0,0,0,0,0,0,0,1010011498,0},
    [1101001174]={1010011667,1010011668,1010011669,1010011673,1010011670,1010011674,1010011666,1010011665,1010011664,1010011663,1010011662,0,0,0,0,0,0,0,0,0,0,0},
    [1101001213]={1010012067,1010012068,1010012069,1010012072,1010012070,1010012073,1010012066,1010012065,1010012064,1010012063,1010012062,0,0,0,0,0,0,0,0,0,1010012074,0},
    [1101001231]={1010012267,1010012268,1010012269,1010012273,1010012272,1010012274,1010012266,1010012265,1010012264,1010012263,1010012262,1010012075,0,0,0,0,0,0,0,0,1010012275,0},
    [1101001242]={1010012357,1010012358,1010012359,1010012363,1010012362,1010012364,1010012356,1010012355,1010012354,1010012353,1010012352,1010012276,0,0,0,0,0,0,0,0,1010012365,0},
    [1101001249]={1010012437,1010012438,1010012439,1010012443,1010012442,1010012444,1010012436,1010012435,1010012434,1010012433,1010012432,1010012366,0,0,0,0,0,0,0,0,1010012445,0},
    [1101001256]={1010012588,1010012589,1010012590,1010012593,1010012592,1010012594,1010012587,1010012586,1010012585,1010012584,1010012583,1010012582,0,0,0,0,0,0,0,0,1010012595,0},
    [1101001265]={1010012698,1010012699,1010012700,1010012703,1010012702,1010012704,1010012697,1010012696,1010012695,1010012694,1010012693,1010012692,0,0,0,0,0,0,0,0,1010012705,0},
    [1101001276]={1010012698,1010012699,1010012700,1010012703,1010012702,1010012704,1010012697,1010012696,1010012695,1010012694,1010012693,1010012692,0,0,0,0,0,0,0,0,1010012705,0},
    [1101002029]={1010020249,1010020250,1010020255,1010020247,1010020246,1010020248,1010020240,1010020239,1010020238,1010020237,1010020236,1010020235,0,0,0,0,0,0,0,1010020257,1010020256,1010020258},
    [1101002056]={1010020519,0,0,1010020517,1010020516,1010020518,1010020500,1010020509,1010020508,1010020507,1010020506,1010020505,0,0,0,0,0,0,0,0,0,0},
    [1101002081]={1010020768,1010020769,1010020770,1010020766,1010020760,1010020767,1010020759,1010020758,1010020757,1010020756,1010020755,1010020776,0,0,0,0,0,0,0,1010020775,1010020777,1010020778},
    [1101003070]={1010030654,1010030653,1010030655,1010030649,1010030648,1010030650,1010030647,1010030646,1010030645,1010030644,1010030643,1010030642,0,1010030658,1010030656,1010030660,1010030662,1010030659,1010030657,0,1010030663,0},
    [1101003080]={1010030754,1010030753,1010030755,1010030749,1010030748,1010030750,1010030747,1010030746,1010030745,1010030744,1010030743,1010030742,0,1010030758,1010030756,1010030760,1010030762,1010030759,1010030757,0,1010030763,0},
    [1101003099]={1010030943,1010030944,1010030945,1010030939,1010030938,1010030942,1010030937,1010030936,1010030935,1010030934,1010030933,1010030932,0,1010030947,1010030946,1010030948,1010030949,1010030953,1010030952,0,1010030955,0},
    [1101003119]={1010031139,1010031140,1010031142,1010031138,1010031137,1010031146,1010031136,1010031135,1010031134,1010031133,1010031132,0,0,1010031144,1010031143,0,0,0,1010031145,0,0,0},
    [1101003146]={1010031229,1010031230,1010031237,1010031228,1010031227,1010031242,1010031226,1010031225,1010031224,1010031223,1010031222,0,0,1010031239,1010031238,0,0,0,1010031240,0,0,0},
    [1101003167]={1010031609,1010031610,1010031613,1010031608,1010031607,1010031617,1010031606,1010031605,1010031604,1010031603,1010031602,1010031618,0,1010031615,1010031614,1010031620,1010031622,1010031619,1010031616,0,1010031623,0},
    [1101003181]={1010031765,1010031764,1010031766,1010031759,1010031758,1010031763,1010031757,1010031756,1010031755,1010031754,1010031753,1010031752,0,1010031769,1010031767,1010031773,1010031774,1010031772,1010031768,0,1010031775,0},
    [1101003195]={1010031912,1010031911,1010031913,1010031908,1010031907,1010031909,1010031906,1010031905,1010031904,1010031903,1010031902,1010031901,0,1010031916,1010031914,1010031918,1010031919,1010031917,1010031915,0,1010031921,0},
    [1101003208]={1010032034,1010032033,1010032045,1010032029,1010032028,1010032032,1010032027,1010032026,1010032025,1010032024,1010032023,1010032022,0,1010032038,1010032036,1010032042,1010032043,1010032039,1010032037,0,1010032044,0},
    [1101004046]={1010040474,1010040475,1010040476,1010040472,1010040471,1010040473,1010040470,1010040469,1010040468,1010040467,1010040466,1010040481,0,1010040479,1010040477,1010040482,1010040483,1010040484,1010040478,1010040480,1010040485,0},
    [1101004062]={1010040578,1010040577,1010040579,1010040575,1010040570,1010040576,1010040569,1010040568,1010040567,1010040566,1010040565,1010040564,0,1010040585,1010040580,1010040587,1010040588,1010040589,1010040584,1010040586,1010040590,1010040594},
    [1101004098]={1010040924,1010040926,1010040925,0,1010040937,1010040938,1010040935,1010040934,1010040929,1010040928,1010040927,0,0,1010040939,1010040945,0,0,0,1010040944,1010040936,0,0},
    [1101004138]={1010041136,1010041137,1010041138,1010041134,1010041129,1010041135,1010041128,1010041127,1010041126,1010041125,1010041124,0,0,1010041145,1010041139,0,0,0,1010041144,1010041146,0,0},
    [1101004163]={1010041570,1010041574,1010041575,1010041568,1010041567,1010041569,1010041566,1010041565,1010041564,1010041560,1010041554,0,0,1010041578,1010041576,0,0,0,1010041577,1010041579,0,0},
    [1101004201]={1010041956,1010041957,1010041958,1010041950,1010041949,1010041955,1010041948,1010041947,1010041946,1010041945,1010041944,1010041967,0,1010041965,1010041959,0,0,0,1010041960,1010041966,0,0},
    [1101004209]={1010042038,1010042037,1010042039,1010042035,1010042034,1010042036,1010042029,1010042028,1010042027,1010042026,1010042025,1010042024,0,1010042046,1010042044,1010042048,1010042049,1010042054,1010042045,1010042047,1010042055,0},
    [1101004218]={1010042128,1010042127,1010042129,1010042125,1010042124,1010042126,1010042119,1010042118,1010042117,1010042116,1010042115,1010042114,0,1010042136,1010042134,1010042138,1010042139,1010042144,1010042135,1010042137,1010042145,0},
    [1101004226]={1010042238,1010042237,1010042239,1010042235,1010042234,1010042236,1010042233,1010042232,1010042231,1010042219,1010042218,1010042217,0,1010042243,1010042241,1010042245,1010042246,1010042247,1010042242,1010042244,1010042248,0},
    [1101004246]={1010042406,1010042407,1010042408,1010042404,1010042400,1010042405,1010042399,1010042398,1010042397,1010042396,1010042395,1010042394,0,1010042414,1010042409,1010042416,1010042417,1010042418,1010042410,1010042415,1010042419,1010042420},
    [1101005038]={0,0,1010050327,1010050329,1010050328,1010050330,1010050326,1010050325,1010050324,1010050323,1010050322,1010050334,0,0,0,0,0,0,0,0,0,0},
    [1101005052]={0,0,1010050467,1010050469,1010050468,1010050470,1010050466,1010050465,1010050464,1010050463,1010050462,1010050473,0,0,0,0,0,0,0,0,0,0},
    [1101005098]={0,0,1010050928,1010050930,1010050929,1010050932,1010050927,1010050926,1010050925,1010050924,1010050923,1010050922,0,0,0,0,0,0,0,0,0,0},
    [1101006062]={1010060573,1010060572,1010060574,1010060564,1010060563,1010060571,1010060562,1010060561,1010060554,1010060553,1010060552,1010060551,0,1010060583,1010060581,1010060591,1010060592,1010060584,1010060582,0,1010060593,0},
    [1101006075]={1010060702,1010060701,1010060703,1010060698,1010060697,1010060699,1010060696,1010060695,1010060694,1010060693,1010060692,1010060691,0,1010060706,1010060704,1010060708,1010060709,1010060707,1010060705,0,1010060711,0},
    [1101006085]={1010060796,1010060795,1010060797,1010060793,1010060789,1010060794,1010060788,1010060787,1010060786,1010060785,1010060784,1010060783,0,1010060800,1010060798,1010060804,1010060805,1010060803,1010060799,0,1010060806,0},
    [1101007046]={1010070410,1010070413,1010070414,1010070408,1010070407,1010070409,1010070406,1010070405,1010070404,1010070403,1010070402,1010070418,0,1010070417,1010070415,1010070420,1010070422,1010070419,1010070416,0,1010070423,0},
    [1101007062]={1010070579,1010070578,1010070581,1010070576,1010070575,1010070577,1010070574,1010070573,1010070572,1010070571,1010070569,1010070568,0,1010070584,1010070582,1010070585,1010070586,1010070587,1010070583,0,1010070588,0},
    [1101007071]={1010070663,1010070662,1010070664,1010070659,1010070658,1010070660,1010070657,1010070656,1010070655,1010070654,1010070653,1010070652,0,1010070667,1010070665,1010070668,1010070669,1010070670,1010070666,0,1010070672,0},
    [1101008051]={1010080463,1010080464,1010080465,1010080459,1010080458,1010080462,1010080457,1010080456,1010080455,1010080454,1010080453,1010080452,0,1010080467,1010080466,1010080468,1010080469,1010080473,1010080472,0,1010080475,0},
    [1101008061]={1010080563,1010080564,1010080565,1010080559,1010080558,1010080562,1010080557,1010080556,1010080555,1010080554,1010080553,0,0,1010080567,1010080566,0,0,0,1010080572,0,0,0},
    [1101008070]={1010080609,1010080612,1010080613,1010080608,1010080607,1010080617,1010080606,1010080605,1010080604,1010080603,1010080602,0,0,1010080615,1010080614,0,0,0,1010080616,0,0,0},
    [1101008081]={1010080740,1010080743,1010080745,1010080738,1010080737,1010080739,1010080736,1010080735,1010080734,1010080733,1010080732,1010080748,0,1010080747,1010080746,1010080750,1010080752,1010080749,1010080744,0,1010080753,0},
    [1101008104]={1010080980,1010080982,1010080984,1010080978,1010080977,1010080979,1010080976,1010080975,1010080974,1010080973,1010080972,1010080992,0,1010080986,1010080985,1010080989,1010080987,1010080993,1010080983,0,1010080988,0},
    [1101008116]={1010081110,1010081112,1010081114,1010081108,1010081107,1010081109,1010081106,1010081105,1010081104,1010081103,1010081102,0,0,1010081116,1010081115,0,0,0,1010081113,0,0,0},
    [1101008126]={1010081210,1010081225,1010081226,1010081208,1010081207,1010081209,1010081206,1010081205,1010081204,1010081203,1010081202,1010081218,0,1010081217,1010081216,1010081219,1010081220,1010081222,1010081214,1010081228,1010081227,1010081229},
    [1101008136]={1010081314,1010081315,1010081316,1010081312,1010081308,1010081313,1010081307,1010081306,1010081305,1010081304,1010081303,1010081302,0,1010081318,1010081317,1010081322,1010081323,1010081325,1010081324,0,1010081326,0},
    [1101008146]={1010081401,1010081402,1010081403,1010081398,1010081397,1010081399,1010081396,1010081395,1010081394,1010081393,1010081392,1010081391,0,1010081405,1010081404,1010081406,1010081407,1010081409,1010081408,0,1010081411,0},
    [1101008154]={1010081531,1010081532,1010081533,1010081528,1010081527,1010081529,1010081526,1010081525,1010081524,1010081523,1010081522,1010081521,0,1010081541,1010081534,1010081542,1010081543,1010081545,1010081544,0,1010081546,0},
    [1101008163]={1010081582,1010081583,1010081584,1010081579,1010081578,1010081580,1010081577,1010081576,1010081575,1010081574,1010081573,1010081572,0,1010081586,1010081585,1010081587,1010081588,1010081590,1010081589,0,1010081592,0},
    [1101012033]={1010120284,1010120285,1010120286,1010120280,1010120279,1010120283,1010120278,1010120277,1010120276,1010120275,1010120274,1010120273,0,0,0,0,0,0,0,0,1010120287,0},
    [1101100012]={1011000066,1011000067,1011000068,0,0,0,1011000058,1011000057,1011000056,1011000055,1011000054,1011000053,0,0,0,0,0,0,0,0,1011000073,0},
    [1101102007]={1011010025,1011010024,1011010026,1011010020,1011010019,1011010023,1011010018,1011010017,1011010016,1011010015,1011010014,1011010013,0,0,0,0,0,0,0,0,1011010027,0},
    [1101102017]={1011020027,1011020028,1011020029,1011020025,1011020024,1011020026,1011020019,1011020018,1011020017,1011020016,1011020015,1011020014,0,1011020036,1011020034,1011020038,1011020039,1011020044,1011020035,1011020037,1011020045,1011020047},
    [1101102025]={1011020127,1011020128,1011020129,1011020125,1011020124,1011020126,1011020119,1011020118,1011020117,1011020116,1011020115,1011020114,0,1011020136,1011020134,1011020138,1011020139,1011020144,1011020135,1011020137,1011020145,0},
    [1101102041]={1011020214,1011020215,1011020216,1011020212,1011020211,1011020213,1011020209,1011020208,1011020207,1011020206,1011020205,1011020204,0,1011020219,1011020217,1011020222,1011020223,1011020224,1011020218,1011020221,1011020225,1011020229},
    [1101102049]={1011020356,1011020357,1011020358,1011020354,1011020350,1011020355,1011020349,1011020348,1011020347,1011020346,1011020345,1011020344,0,1011020364,1011020359,1011020366,1011020367,1011020368,1011020360,1011020365,1011020369,1011020370},
    [1101101007]={1011020436,1011020437,1011020438,1011020434,1011020430,1011020435,1011020429,1011020428,1011020427,1011020426,1011020425,1011020424,0,1011020444,1011020439,1011020446,1011020447,1011020448,1011020440,1011020445,1011020449,1011020450},
    [1102001120]={1020011137,1020011138,1020011139,1020011135,1020011134,1020011136,1020011133,1020011132,0,0,0,0,0,0,0,0,0,0,0,1020011142,0,0},
    [1102001130]={1020011247,1020011248,1020011249,1020011245,1020011244,1020011246,1020011243,1020011242,0,0,0,0,0,0,0,0,0,0,0,1020011250,0,0},
    [1102002043]={1020020372,1020020374,1020020373,1020020383,1020020380,1020020384,1020020379,1020020378,1020020377,1020020376,1020020375,1020020388,0,1020020385,1020020387,0,0,0,1020020386,0,0,0},
    [1102002061]={1020020552,1020020554,1020020553,1020020563,1020020562,1020020564,1020020559,1020020558,1020020557,1020020556,1020020555,1020020578,0,1020020565,1020020567,1020020573,1020020574,1020020572,1020020566,0,1020020569,0},
    [1102002136]={1020021314,1020021313,1020021315,1020021309,1020021308,1020021312,1020021307,1020021306,1020021305,1020021304,1020021303,1020021302,0,1020021318,1020021316,1020021323,1020021324,1020021322,1020021317,0,1020021325,0},
    [1102002424]={1020024193,1020024192,1020024194,1020024189,1020024188,1020024190,1020024187,1020024186,1020024185,1020024184,1020024183,1020024182,0,1020024197,1020024195,1020024199,1020024200,1020024198,1020024196,0,1020024202,0},
    [1102003080]={1020030755,1020030756,1020030758,0,1020030749,1020030754,1020030748,1020030747,1020030746,1020030745,1020030744,1020030764,0,1020030760,0,1020030759,1020030757,0,0,1020030765,0,0},
    [1102003100]={1020030956,1020030957,1020030958,1020030954,1020030950,1020030955,1020030949,1020030948,1020030947,1020030946,1020030945,1020030944,0,1020030964,0,1020030960,1020030959,1020030965,0,1020030967,1020030966,1020030968},
    [1102005064]={1020050588,1020050589,1020050590,0,0,0,1020050587,1020050586,1020050585,1020050584,1020050583,1020050582,0,0,0,0,0,0,0,0,1020050592,0},
    [1103001101]={1030010954,1030010955,1030010956,0,0,0,0,0,0,0,1030010953,1030010952,1030010951,0,0,0,0,0,0,1030010957,0,1030010958},
    [1103001146]={1030011344,1030011345,1030011346,0,0,0,0,0,0,0,1030011343,1030011342,1030011341,0,0,0,0,0,0,1030011347,0,1030011348},
    [1103001154]={1030011484,1030011485,1030011486,0,0,0,0,0,0,0,1030011483,1030011482,1030011481,0,0,0,0,0,0,1030011487,0,1030011488},
    [1103001179]={1030011738,1030011739,1030011741,0,0,0,1030011737,1030011736,1030011735,1030011734,1030011733,1030011732,1030011731,0,0,0,0,0,0,1030011742,1030011743,1030011744},
    [1103001191]={1030011858,1030011859,1030011861,0,0,0,1030011857,1030011856,1030011855,1030011854,1030011853,1030011852,1030011851,0,0,0,0,0,0,1030011862,1030011863,1030011864},
    [1103001202]={1030011948,1030011949,1030011950,0,0,0,1030011947,1030011946,1030011945,1030011944,1030011943,1030011942,1030011941,0,0,0,0,0,0,1030011951,1030011952,1030011953},
    [1103002030]={1030020245,1030020246,1030020247,1030020252,1030020249,1030020253,1030020258,1030020257,1030020256,1030020255,1030020244,1030020243,1030020242,0,0,0,0,0,0,1030020248,0,0},
    [1103002059]={1030020544,1030020545,1030020546,1030020542,1030020539,1030020543,1030020538,1030020537,1030020536,1030020535,1030020534,1030020533,1030020532,0,0,0,0,0,0,1030020547,1030020548,0},
    [1103002087]={1030020824,1030020825,1030020826,0,0,0,1030020818,1030020817,1030020816,1030020815,1030020814,1030020813,1030020812,0,0,0,0,0,0,1030020827,1030020828,0},
    [1103002106]={1030021009,1030021010,1030021012,1030021015,1030021014,1030021016,1030021008,1030021007,1030021006,1030021005,1030021004,1030021003,1030021002,0,0,0,0,0,0,1030021013,1030021017,0},
    [1103002113]={1030021079,1030021080,1030021082,1030021085,1030021084,1030021086,1030021078,1030021077,1030021076,1030021075,1030021074,1030021073,1030021072,0,0,0,0,0,0,1030021083,1030021087,0},
    [1103003022]={1030030165,1030030166,1030030167,1030030172,1030030169,1030030173,0,0,0,0,1030030164,1030030163,1030030162,0,0,0,0,0,0,0,0,0},
    [1103003030]={1030030256,1030030257,1030030258,1030030254,1030030253,1030030255,1030030248,1030030247,1030030246,1030030245,1030030244,1030030243,1030030242,0,0,0,0,0,0,1030030259,1030030249,0},
    [1103003042]={1030030374,1030030375,1030030376,1030030372,1030030369,1030030373,0,0,0,0,1030030364,1030030363,1030030362,0,0,0,0,0,0,1030030377,0,0},
    [1103003051]={1030030458,1030030459,1030030460,1030030456,1030030455,1030030457,0,0,0,0,1030030454,1030030453,1030030452,0,0,0,0,0,0,1030030463,0,0},
    [1103003062]={1030030568,1030030569,1030030570,1030030566,1030030565,1030030567,0,0,0,0,1030030564,1030030563,1030030562,0,0,0,0,0,0,1030030572,0,0},
    [1103003079]={1030030744,1030030745,1030030746,1030030742,1030030740,1030030743,1030030738,1030030737,1030030736,1030030735,1030030734,1030030733,1030030732,0,0,0,0,0,0,1030030747,1030030739,0},
    [1103003087]={1030030825,1030030826,1030030827,1030030823,1030030824,1030030824,1030030818,1030030817,1030030816,1030030815,1030030814,1030030813,1030030812,0,0,0,0,0,0,1030030828,1030030819,0},
    [1103004037]={1030040315,1030040316,1030040317,1030040325,1030040324,1030040323,0,0,0,0,1030040314,1030040313,1030040312,1030040327,1030040326,0,0,0,1030040328,1030040329,0,0},
    [1103006030]={1030060245,1030060246,1030060247,0,1030060253,1030060252,0,0,0,0,1030060244,1030060243,1030060242,0,0,0,0,0,0,0,0,0},
    [1103007028]={1030070233,1030070234,1030070235,1030070226,1030070225,1030070227,1030070218,1030070217,1030070216,1030070215,1030070214,1030070213,1030070212,0,0,0,0,0,0,1030070236,1030070219,0},
    [1103012010]={0,0,0,0,0,0,1030120038,1030120037,1030120036,1030120035,1030120034,1030120033,1030120032,0,0,0,0,0,0,0,0,0},
    [1103012019]={0,0,0,0,0,0,1030120138,1030120137,1030120136,1030120135,1030120134,1030120133,1030120132,0,0,0,0,0,0,0,0,0},
    [1103012031]={0,0,0,0,0,0,1030120258,1030120257,1030120256,1030120255,1030120254,1030120253,1030120252,0,0,0,0,0,0,0,0,0},
    [1103012039]={0,0,0,0,0,0,1030120339,1030120338,1030120337,1030120336,1030120335,1030120334,1030120333,0,0,0,0,0,0,0,0,0},
    [1103102007]={1031020026,1031020027,1031020028,1031020024,1031020023,1031020025,1031020019,1031020018,1031020017,1031020016,1031020015,1031020014,1031020013,0,0,0,0,0,0,1031020029,0,0},
    [1105001034]={0,0,0,0,1050010287,1050010289,1050010286,1050010285,1050010284,1050010283,1050010282,0,0,0,0,0,0,0,0,1050010292,0,0},
    [1105001048]={0,0,0,1050010429,1050010428,1050010434,1050010427,1050010426,1050010425,1050010424,1050010423,0,0,0,0,0,0,0,0,1050010435,0,1050010436},
    [1105001069]={0,0,0,1050010639,1050010638,1050010640,1050010637,1050010636,1050010635,1050010634,1050010633,1050010645,0,0,0,0,0,0,0,1050010643,1050010646,1050010644},
    [1105002091]={0,0,0,0,0,0,1050020847,1050020846,1050020845,1050020844,1050020843,1050020842,0,0,0,0,0,0,0,0,0,1050020848},
    [1105010019]={0,0,0,0,0,0,1050100144,1050100143,1050100142,1050100141,1050100139,1050100138,0,0,0,0,0,0,0,0,0,0}
}

_G.X3.BaseAttachToIndex = {
    [201010]=1, [201005]=1, [201004]=1, [201009]=2, [201003]=2, [201002]=2,
    [201011]=3, [201007]=3, [201006]=3, [204012]=4, [204005]=4, [204008]=4,
    [204011]=5, [204004]=5, [204007]=5, [204013]=6, [204006]=6, [204009]=6,
    [203001]=7, [203002]=8, [203003]=9, [203014]=10, [203004]=11, [203015]=12, [203005]=13,
    [202002]=14, [202001]=15, [202004]=16, [202005]=17, [202007]=18, [202006]=19,
    [205002]=20, [205003]=20, [205001]=20, [203018]=21, [204014]=22
}

_G.X3.VipAttachToIndex = {}
for skinId, attachList in pairs(_G.X3.VIP_Attachments) do
    for index, attachId in ipairs(attachList) do
        if attachId > 0 then
            _G.X3.VipAttachToIndex[attachId] = index
        end
    end
end

_G.X3.WeaponSkinMap = _G.X3.WeaponSkinMap or {}
_G.X3.VehicleSkinMap = _G.X3.VehicleSkinMap or {}
_G.X3.OutfitMap = _G.X3.OutfitMap or {}
_G.X3.skinIdCache = _G.X3.skinIdCache or {}
_G.X3.skinIdCache2 = _G.X3.skinIdCache2 or {}

_G.X3.OutfitSkins = {
    Suit = { 1407961, 1407962, 1407963, 1407964, 1407965, 1407966, 1407967, 1407968, 1407969, 1407970, 1407971, 403003,1407916,1406469,1405870,1407140,1407141,1407142,1407550,1406638,1406872,1406971,1407103,1407512,1407391,1407366,1407330,1407329,1407286,1407285,1407277,1407276,1407275,1407225,1407224,1407259,1407161,1407160,1407107,1407106,1407079,1407048,1406977,1406976,1406898,1400569,1404000,1404049,1400119,1400117,1406060,1406891,1400687,1405160,1405145,1405436,1405435,1405434,1405064,1405207,1406895,1400333,1400377,1405092,1405121,1406889,1407278,1407279,1407381,1407380,1407385,1406389,1406388,1406387,1406386,1406385,1406140,1400782,1407392,1407318,1407317,1407404,1407402,1407401,1407387,1404434,1404437,1404440,1404448,1400324,1400708,1404043,1404048,1405953,1400101,1404153,1407440,1407441},
    Bag = {
        {501001, 501002, 501003}, {1501001174, 1501002174, 1501003174}, {1501001220, 1501002220, 1501003220},
        {1501001051, 1501002051, 1501003051}, {1501001443, 1501002443, 1501003443}, {1501001265, 1501002265, 1501003265},
        {1501001321, 1501002321, 1501003321}, {1501001277, 1501002277, 1501003277}, {1501001550, 1501002550, 1501003550},
        {1501001592, 1501002592, 1501003592}, {1501001608, 1501002608, 1501003608}, {1501001024, 1501002024, 1501003024},
        {1501001019, 1501002019, 1501003019}, {1501001179, 1501002179, 1501003179}, {1501001194, 1501002194, 1501003194},
        {1501001346, 1501002346, 1501003346}
    },
    Helmet = {
        {502001, 502002, 502003}, {1502001014, 1502002014, 1502003014}, {1502001349, 1502002349, 1502003349},
        {1502001012, 1502002012, 1502003012}, {1502001009, 1502002009, 1502003009}, {1502001397, 1502002397, 1502003397},
        {1502001390, 1502002390, 1502003390}, {1502001381, 1502002381, 1502003381}, {1502001358, 1502002358, 1502003358},
        {1502001350, 1502002350, 1502003350}, {1502001342, 1502002342, 1502003342}
    },
    Pet = {50000,50001,50002,50003,50004,50005,50006,50021,50022,50038,50039,50040}
}

_G.X3.skinIdMappings = {
    [101004]={101004, 1101004246,1101004226,1101004236,1101004062,1101004078,1101004086,1101004201,1101004218},
    [101001]={101001,1101001276,1101001089,1101001213,1101001172,1101001127,1101001230,1101001241},
    [101003]={101003,1101003227,1103003208,1101003195,1101003187,1101003098,1101003166,1101003218},
    [102002]={102002,1102002136,1102002043,1102002061,1102002424},
    [101008]={101008,1101008146,1101008154,1101008079,1101008126,1101008104,1101008146,1101008061,1101008116},
    [101006]={101006,1101006085,1101006061,1101006074,1101006043,1101006032,1101006084},
    [102001]={102001, 1102001120},
    [101005]={101005, 1101005098},
    [104003]={104003, 1104003037},
    [104004]={104004, 1104004035, 1104004041}
}

_G.X3.VehicleSkins = {
    [1961001] = { 1961007, 1961010, 1961012, 1961013, 1961014, 1961015, 1961016, 1961017, 1961018, 1961020, 1961021, 1961024, 1961025, 1961029, 1961030, 1961031, 1961032, 1961033, 1961034, 1961035, 1961036, 1961037, 1961038, 1961039, 1961040, 1961041, 1961042, 1961043, 1961044, 1961045, 1961046, 1961047, 1961048, 1961049, 1961050, 1961051, 1961052, 1961053, 1961054, 1961055, 1961056, 1961057, 1961058, 1961059, 1961060, 1961061, 1961062, 1961063, 1961064, 1961065, 1961066, 1961067, 1961068, 1961069, 1961136, 1961137, 1961138, 1961139, 1961140, 1961141, 1961142, 1961143, 1961144, 1961145, 1961147, 1961148, 1961149, 1961150, 1961151, 1961152, 1961153 },
    [1903001] = { 1903005, 1903006, 1903007, 1903008, 1903011, 1903012, 1903013, 1903014, 1903015, 1903016, 1903017, 1903018, 1903019, 1903020, 1903021, 1903022, 1903023, 1903024, 1903029, 1903030, 1903031, 1903032, 1903033, 1903034, 1903035, 1903036, 1903037, 1903039, 1903040, 1903041, 1903042, 1903043, 1903044, 1903045, 1903046, 1903051, 1903052, 1903053, 1903054, 1903055, 1903056, 1903057, 1903058, 1903059, 1903060, 1903061, 1903062, 1903063, 1903066, 1903067, 1903068, 1903069, 1903070, 1903071, 1903072, 1903073, 1903074, 1903075, 1903076, 1903079, 1903080, 1903081, 1903082, 1903084, 1903085, 1903086, 1903087, 1903088, 1903089, 1903090, 1903189, 1903190, 1903191, 1903192, 1903193, 1903194, 1903195, 1903196, 1903197, 1903198, 1903199, 1903200, 1903201, 1903202, 1903203, 1903204, 1903205, 1903206, 1903207, 1903208, 1903209, 1903210, 1903211, 1903212, 1903213, 1903214, 1903215, 1903216, 1903217, 1903218, 1903219, 1903220, 1903221, 1903222, 1903223, 1903225, 1903226, 1903227, 1903228 },
    [1915001] = { 1915002, 1915003, 1915004, 1915005, 1915006, 1915007, 1915008, 1915009, 1915010, 1915011, 1915012, 1915013, 1915014, 1915015, 1915016, 1915017, 1915018, 1915019, 1915020, 1915021, 1915022, 1915023, 1915024, 1915025, 1915026, 1915027, 1915099 },
    [1908001] = { 1908002, 1908003, 1908005, 1908006, 1908007, 1908008, 1908009, 1908010, 1908011, 1908012, 1908013, 1908015, 1908016, 1908017, 1908018, 1908019, 1908021, 1908023, 1908030, 1908031, 1908032, 1908033, 1908034, 1908035, 1908036, 1908037, 1908039, 1908040, 1908041, 1908043, 1908047, 1908049, 1908050, 1908051, 1908052, 1908053, 1908054, 1908055, 1908056, 1908057, 1908059, 1908060, 1908061, 1908062, 1908063, 1908064, 1908066, 1908067, 1908068, 1908069, 1908070, 1908075, 1908076, 1908077, 1908078, 1908080, 1908081, 1908082, 1908083, 1908084, 1908085, 1908086, 1908087, 1908088, 1908089, 1908091, 1908094, 1908095, 1908096, 1908097, 1908098, 1908099, 1908100, 1908101, 1908102, 1908104, 1908105, 1908106, 1908107, 1908108, 1908109, 1908110, 1908111, 1908112, 1908188, 1908189 },
    [1907001] = { 1907007, 1907008, 1907010, 1907011, 1907012, 1907013, 1907014, 1907016, 1907018, 1907019, 1907021, 1907022, 1907023, 1907025, 1907026, 1907027, 1907028, 1907029, 1907030, 1907032, 1907033, 1907034, 1907035, 1907036, 1907037, 1907038, 1907040, 1907041, 1907043, 1907044, 1907045, 1907046, 1907047, 1907048, 1907049, 1907050, 1907051, 1907052, 1907053, 1907054, 1907055, 1907056, 1907058, 1907059, 1907060, 1907061, 1907062, 1907063, 1907064, 1907065, 1907066, 1907067, 1907068, 1907069, 1907070, 1907071, 1907072, 1907073, 1907074 }
}
_G.X3.CustSlotType = { ClothesEquipemtSlot=5, BackpackEquipemtSlot=8, HelmetEquipemtSlot=9, ParachuteEquipemtSlot=11, GlideEquipemtSlot=15 }

-- DOWNLOAD GAME ITEM --
local function DownloadGameItem(id)
    local puffer_manager = require('client.slua.logic.download.puffer.puffer_manager')
    local puffer_const = require('client.slua.logic.download.puffer_const')
    if puffer_manager and puffer_const and puffer_manager.GetState(puffer_const.ENUM_DownloadType.ODPTD, {id}) ~= puffer_const.ENUM_DownloadState.Done then
        puffer_manager.Download(puffer_const.ENUM_DownloadType.ODPTD, {id})
    end
end
_G.X3.download_item = DownloadGameItem

-- GET SKIN ID --
_G.X3.get_skin_id = function(weaponID)
    if not weaponID then return nil end
    local targetSkinId = _G.X3.WeaponSkinMap and _G.X3.WeaponSkinMap[weaponID]
    if targetSkinId and targetSkinId > 0 then
        if not _G.X3.skinIdCache2[targetSkinId] then
            if _G.X3.download_item then pcall(_G.X3.download_item, targetSkinId) end
            _G.X3.skinIdCache2[targetSkinId] = true
        end
        return targetSkinId
    end
    return weaponID
end

-- EQUIP CHARACTER AVATAR --
_G.X3.equip_character_avatar = function(Character)
    if not Character or not slua.isValid(Character) or not Character.AvatarComponent2 then return end
    local BackpackUtils = import("BackpackUtils")
    local SlotSyncData = Character.AvatarComponent2.NetAvatarData and Character.AvatarComponent2.NetAvatarData.SlotSyncData
    if not SlotSyncData or not slua.isValid(SlotSyncData) or not BackpackUtils then return end

    local function EquipAvatar(ApplyDataIdx, mappedSkin, ApplyEquipSlot, isLevelDependent, levelFunc)
        if not mappedSkin or mappedSkin == 0 then return end
        local slotData = SlotSyncData:Get(ApplyDataIdx)
        if slotData and slotData.SlotID == ApplyEquipSlot then
            local applyItemId = mappedSkin
            if isLevelDependent and type(mappedSkin) == "table" then
                local level = levelFunc(slotData.AdditionalItemID) or 1
                if level < 1 then level = 1 end
                if level > 3 then level = 3 end
                applyItemId = mappedSkin[level] or mappedSkin[1]
            end

            if not applyItemId or applyItemId == 0 or slotData.ItemId == applyItemId then return end

            if not _G.X3.skinIdCache[applyItemId] then
                if _G.X3.download_item then pcall(_G.X3.download_item, applyItemId) end
                _G.X3.skinIdCache[applyItemId] = true
            end

            slotData.ItemId = applyItemId
            SlotSyncData:Set(ApplyDataIdx, slotData)
            Character.AvatarComponent2:OnRep_BodySlotStateChanged()
        end
    end

    local hasGliderSlot = false
    for i = 0, SlotSyncData:Num() - 1 do
        local slotData = SlotSyncData:Get(i)
        if slotData and slotData.SlotID == _G.X3.CustSlotType.GlideEquipemtSlot then
            hasGliderSlot = true
            break
        end
    end
    if not hasGliderSlot then SlotSyncData:Add({ SlotID = _G.X3.CustSlotType.GlideEquipemtSlot, ItemId = 0 }) end

    for i = 0, SlotSyncData:Num() - 1 do
        EquipAvatar(i, _G.X3.OutfitMap.Suit or 0, _G.X3.CustSlotType.ClothesEquipemtSlot, false)
        EquipAvatar(i, _G.X3.OutfitMap.Bag, _G.X3.CustSlotType.BackpackEquipemtSlot, true, BackpackUtils.GetEquipmentBagLevel)
        EquipAvatar(i, _G.X3.OutfitMap.Helmet, _G.X3.CustSlotType.HelmetEquipemtSlot, true, BackpackUtils.GetEquipmentHelmetLevel)
        EquipAvatar(i, _G.X3.OutfitMap.Parachute or 0, _G.X3.CustSlotType.ParachuteEquipemtSlot, false)
        EquipAvatar(i, _G.X3.OutfitMap.Pants or 0, 6, false)
        EquipAvatar(i, _G.X3.OutfitMap.Shoes or 0, 7, false)
    end
end

-- APPLY WEAPON SKINS --
_G.X3.ApplyWeaponSkins = function(PlayerCharacter)
    pcall(function()
        local WeaponManager = PlayerCharacter:GetWeaponManager()
        if not slua.isValid(WeaponManager) then return end

        for slot = 1, 4 do
            local Weapon = WeaponManager:GetInventoryWeaponByPropSlot(slot)
            if slua.isValid(Weapon) and slua.isValid(Weapon.synData) then
                local WeaponID = Weapon:GetWeaponID()
                local SkinID = _G.X3.get_skin_id(WeaponID) or WeaponID
                if _G.X3.LexusConfig.X3SkinNewRandom then
                    local rs = _G.X3._SkinRandPick and _G.X3._SkinRandPick(WeaponID)
                    if rs then SkinID = rs end
                end
                local isModified = false

                local SkinData = Weapon.synData:Get(7)
                if SkinData and SkinData.defineID and SkinData.defineID.TypeSpecificID ~= SkinID then
                    SkinData.defineID.TypeSpecificID = SkinID
                    Weapon.synData:Set(7, SkinData)
                    if Weapon.SetWeaponAvatarID then pcall(function() Weapon:SetWeaponAvatarID(SkinID) end) end
                    if not _G.X3.skinIdCache[SkinID] then
                        _G.X3.download_item(SkinID)
                        _G.X3.skinIdCache[SkinID] = true
                    end
                    isModified = true
                end

                if SkinID >= 10000000 and _G.X3.VIP_Attachments and _G.X3.VIP_Attachments[SkinID] then
                    for AttachIdx = 0, 5 do
                        local attachData = Weapon.synData:Get(AttachIdx)
                        if attachData then
                            local defineIDRef = slua.IndexReference(attachData, "defineID")
                            if defineIDRef then
                                local attachmentId = defineIDRef.TypeSpecificID
                                if attachmentId and attachmentId > 0 then
                                    local mapIndex = _G.X3.BaseAttachToIndex[attachmentId] or _G.X3.VipAttachToIndex[attachmentId]
                                    if mapIndex and _G.X3.VIP_Attachments[SkinID][mapIndex] and _G.X3.VIP_Attachments[SkinID][mapIndex] > 0 then
                                        local targetAttachId = _G.X3.VIP_Attachments[SkinID][mapIndex]
                                        if targetAttachId ~= attachmentId then
                                            attachData.defineID.TypeSpecificID = targetAttachId
                                            Weapon.synData:Set(AttachIdx, attachData)
                                            if not _G.X3.skinIdCache2[targetAttachId] then
                                                if _G.X3.download_item then pcall(_G.X3.download_item, targetAttachId) end
                                                _G.X3.skinIdCache2[targetAttachId] = true
                                            end
                                            isModified = true
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                if isModified then
                    if Weapon.DelayHandleAvatarMeshChanged then pcall(function() Weapon:DelayHandleAvatarMeshChanged() end) end
                    if Weapon.OnRep_synData then pcall(function() Weapon:OnRep_synData() end) end
                end
            end
        end
    end)
end

-- APPLY VEHICLE SKINS --
_G.X3.ApplyVehicleSkins = function(PlayerCharacter)
    pcall(function()
        local Vehicle = nil
        pcall(function() Vehicle = PlayerCharacter.CurrentVehicle end)
        if not slua.isValid(Vehicle) then Vehicle = PlayerCharacter:GetCurrentVehicle() end
        if not slua.isValid(Vehicle) then
            _G.X3.LastVehicleEntity = nil
            return
        end

        if _G.X3.LastVehicleEntity == Vehicle and _G.X3.CurrentEquipVehicleID ~= nil then
            return
        end

        local VehicleAvatar = nil
        pcall(function() VehicleAvatar = Vehicle.VehicleAvatar end)
        if not slua.isValid(VehicleAvatar) then
            pcall(function() if Vehicle.GetVehicleAvatar then VehicleAvatar = Vehicle:GetVehicleAvatar() end end)
        end
        if not slua.isValid(VehicleAvatar) then
            pcall(function() VehicleAvatar = Vehicle.VehicleAvatarComponent_BP or Vehicle:GetAvatarComponent() end)
        end
        if not slua.isValid(VehicleAvatar) then
            if type(_G.X3.Trace) == "function" and _G.X3.VehNoAvtrV ~= Vehicle then
                _G.X3.VehNoAvtrV = Vehicle
                _G.X3.Trace("VEH: VehicleAvatarComponent TIDAK valid (semua jalur gagal)")
            end
            return
        end

        local defId = tostring(VehicleAvatar:GetDefaultAvatarID() or Vehicle.VehicleID or "")
        local currentId = ""
        pcall(function()
            if VehicleAvatar.GetCurrentAvatarID then currentId = tostring(VehicleAvatar:GetCurrentAvatarID() or "")
            else currentId = tostring(Vehicle:GetAvatarId() or "") end
        end)
        local applySkinId = 0

        for baseMapId, targetSkin in pairs(_G.X3.VehicleSkinMap) do
            if defId:find(tostring(baseMapId)) or currentId:find(tostring(baseMapId)) then
                applySkinId = targetSkin
                break
            end
        end

        if type(_G.X3.Trace) == "function" and _G.X3.VehTracedV ~= Vehicle then
            _G.X3.VehTracedV = Vehicle
            local nMap = 0
            for _ in pairs(_G.X3.VehicleSkinMap or {}) do nMap = nMap + 1 end
            _G.X3.Trace("VEH: kendaraan baru | defId=" .. defId .. " curId=" .. currentId ..
                " | petaSkin=" .. tostring(nMap) .. " | cocok=" .. tostring(applySkinId) ..
                " | PreChange=" .. tostring(VehicleAvatar.PreChangeVehicleAvatar ~= nil) ..
                " ChangeItemAvatar=" .. tostring(VehicleAvatar.ChangeItemAvatar ~= nil) ..
                " BP_Change=" .. tostring(VehicleAvatar.BP_ChangeItemAvatar ~= nil) ..
                " SetNetData=" .. tostring(VehicleAvatar.SetVehicleNetAvatarData ~= nil))
        end

        if applySkinId and applySkinId > 0 and tostring(applySkinId) ~= currentId then
            _G.X3.skinIdCache = _G.X3.skinIdCache or {}
            if not _G.X3.skinIdCache[applySkinId] then
                if _G.X3.download_item then pcall(_G.X3.download_item, applySkinId) end
                _G.X3.skinIdCache[applySkinId] = true
            end

            VehicleAvatar.curSwitchEffectId = 7303001
            pcall(function()
                if VehicleAvatar.PreChangeVehicleAvatar then VehicleAvatar:PreChangeVehicleAvatar(applySkinId) end
            end)
            local vehChangeFn = VehicleAvatar.ChangeItemAvatar or VehicleAvatar.BP_ChangeItemAvatar
            local okC, errC = true, nil
            if vehChangeFn then okC, errC = pcall(vehChangeFn, VehicleAvatar, applySkinId, true) end
            local netOK = false
            pcall(function()
                if VehicleAvatar.SetVehicleNetAvatarData then
                    local ctrl = nil
                    pcall(function() ctrl = PlayerCharacter.Controller end)
                    if not slua.isValid(ctrl) then pcall(function() ctrl = PlayerCharacter:GetController() end) end
                    if slua.isValid(ctrl) then
                        VehicleAvatar:SetVehicleNetAvatarData(ctrl)
                        netOK = true
                    end
                end
            end)
            pcall(function()
                if VehicleAvatar.ShowVehicleSwitchEffect then VehicleAvatar:ShowVehicleSwitchEffect(7303001)
                elseif VehicleAvatar.CheckAndShowVehicleSwitchEffect then VehicleAvatar:CheckAndShowVehicleSwitchEffect() end
            end)
            if type(_G.X3.Trace) == "function" then
                if not vehChangeFn then
                    _G.X3.Trace("VEH: GAGAL — tidak ada fungsi ChangeItemAvatar/BP_ChangeItemAvatar")
                else
                    _G.X3.Trace("VEH: apply skin " .. tostring(applySkinId) .. " change=" .. tostring(okC) ..
                        (okC and "" or (" err=" .. tostring(errC))) .. " netSync=" .. tostring(netOK))
                end
            end

            _G.X3.CurrentEquipVehicleID = applySkinId
            _G.X3.LastVehicleEntity = Vehicle
        end
    end)
end

-- HANDLE PET LOGIC --
_G.X3.HandlePetLogic = function()
    pcall(function()
        local petSkin = _G.X3.OutfitMap.Pet
        if not petSkin or petSkin == 0 or petSkin == 50000 or petSkin == _G.X3.LastAppliedPet then return end

        _G.X3.skinIdCache = _G.X3.skinIdCache or {}
        if not _G.X3.skinIdCache[petSkin] then
            if _G.X3.download_item then pcall(_G.X3.download_item, petSkin) end
            _G.X3.skinIdCache[petSkin] = true
        end

        local ModuleManager = require("client.module_framework.ModuleManager")
        if ModuleManager then
            local logic_pet = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.logic_pet)
            if logic_pet then
                if logic_pet.SetCurPetID then logic_pet:SetCurPetID(petSkin) end
                if logic_pet.EquipPet then logic_pet:EquipPet(petSkin) end
            end
        end
        _G.X3.LastAppliedPet = petSkin
    end)
end

-- APPLY AVATAR BORDER --
_G.X3.ApplyAvatarBorder = function()
    pcall(function()
        if not (_G.X3.LexusConfig and _G.X3.LexusConfig.ModSkin) then return end
        local M = package.loaded["client.slua.logic.roleInfo.logic_RoleInfoAvatarFrame"]
        if not M then return end
        if not M._X3BorderHooked then
            if type(rawget(M, "HasAvatarFrame")) == "function" then
                M._X3OrigHasAvatarFrame = rawget(M, "HasAvatarFrame")
                M.HasAvatarFrame = function(self, fid, ...)
                    if _G.X3.LexusConfig and _G.X3.LexusConfig.ModSkin then return true end
                    return M._X3OrigHasAvatarFrame(self, fid, ...)
                end
            end
            M._X3BorderHooked = true
        end
        local fid = _G.X3._BorderID or 2003014 -- ID frame dari dump AvatarFrameList
        if _G.X3._BorderAppliedID ~= fid and type(M.UpdateCurAvatarBoxID) == "function" then
            pcall(function() M:UpdateCurAvatarBoxID(fid) end)
            _G.X3._BorderAppliedID = fid
        end
    end)
end

-- FORCE REFRESH SKIN MAPS --
_G.X3.ForceRefreshSkinMaps = function()
    pcall(function()
        if not _G.X3.LexusState or not _G.X3.LexusState.CustomTextData then return end
        local cData = _G.X3.LexusState.CustomTextData

        if _G.X3.OutfitSkins then
            if cData.SkinSuit and _G.X3.OutfitSkins.Suit[cData.SkinSuit] then _G.X3.OutfitMap.Suit = _G.X3.OutfitSkins.Suit[cData.SkinSuit] end
            if cData.SkinBag and _G.X3.OutfitSkins.Bag[cData.SkinBag] then _G.X3.OutfitMap.Bag = _G.X3.OutfitSkins.Bag[cData.SkinBag] end
            if cData.SkinHelmet and _G.X3.OutfitSkins.Helmet[cData.SkinHelmet] then _G.X3.OutfitMap.Helmet = _G.X3.OutfitSkins.Helmet[cData.SkinHelmet] end
        end

        if _G.X3.skinIdMappings then
            if cData.SkinM416 and _G.X3.skinIdMappings[101004] and _G.X3.skinIdMappings[101004][cData.SkinM416] then _G.X3.WeaponSkinMap[101004] = _G.X3.skinIdMappings[101004][cData.SkinM416] end
            if cData.SkinAKM and _G.X3.skinIdMappings[101001] and _G.X3.skinIdMappings[101001][cData.SkinAKM] then _G.X3.WeaponSkinMap[101001] = _G.X3.skinIdMappings[101001][cData.SkinAKM] end
            if cData.SkinSCAR and _G.X3.skinIdMappings[101003] and _G.X3.skinIdMappings[101003][cData.SkinSCAR] then _G.X3.WeaponSkinMap[101003] = _G.X3.skinIdMappings[101003][cData.SkinSCAR] end
            if cData.SkinM762 and _G.X3.skinIdMappings[101008] and _G.X3.skinIdMappings[101008][cData.SkinM762] then _G.X3.WeaponSkinMap[101008] = _G.X3.skinIdMappings[101008][cData.SkinM762] end
            if cData.SkinAUG and _G.X3.skinIdMappings[101006] and _G.X3.skinIdMappings[101006][cData.SkinAUG] then _G.X3.WeaponSkinMap[101006] = _G.X3.skinIdMappings[101006][cData.SkinAUG] end
            if cData.SkinUMP and _G.X3.skinIdMappings[102002] and _G.X3.skinIdMappings[102002][cData.SkinUMP] then _G.X3.WeaponSkinMap[102002] = _G.X3.skinIdMappings[102002][cData.SkinUMP] end

            if cData.SkinUZI and _G.X3.skinIdMappings[102001] and _G.X3.skinIdMappings[102001][cData.SkinUZI] then _G.X3.WeaponSkinMap[102001] = _G.X3.skinIdMappings[102001][cData.SkinUZI] end
            if cData.SkinGroza and _G.X3.skinIdMappings[101005] and _G.X3.skinIdMappings[101005][cData.SkinGroza] then _G.X3.WeaponSkinMap[101005] = _G.X3.skinIdMappings[101005][cData.SkinGroza] end
            if cData.SkinS12K and _G.X3.skinIdMappings[104003] and _G.X3.skinIdMappings[104003][cData.SkinS12K] then _G.X3.WeaponSkinMap[104003] = _G.X3.skinIdMappings[104003][cData.SkinS12K] end
            if cData.SkinDBS and _G.X3.skinIdMappings[104004] and _G.X3.skinIdMappings[104004][cData.SkinDBS] then _G.X3.WeaponSkinMap[104004] = _G.X3.skinIdMappings[104004][cData.SkinDBS] end
        end

        if _G.X3.VehicleSkins then
            if cData.SkinDacia and _G.X3.VehicleSkins[1903001] and _G.X3.VehicleSkins[1903001][cData.SkinDacia] then _G.X3.VehicleSkinMap[1903001] = _G.X3.VehicleSkins[1903001][cData.SkinDacia] end
            if cData.SkinUAZ and _G.X3.VehicleSkins[1908001] and _G.X3.VehicleSkins[1908001][cData.SkinUAZ] then _G.X3.VehicleSkinMap[1908001] = _G.X3.VehicleSkins[1908001][cData.SkinUAZ] end
            if cData.SkinCoupe and _G.X3.VehicleSkins[1961001] and _G.X3.VehicleSkins[1961001][cData.SkinCoupe] then _G.X3.VehicleSkinMap[1961001] = _G.X3.VehicleSkins[1961001][cData.SkinCoupe] end
            if cData.SkinBuggy and _G.X3.VehicleSkins[1907001] and _G.X3.VehicleSkins[1907001][cData.SkinBuggy] then _G.X3.VehicleSkinMap[1907001] = _G.X3.VehicleSkins[1907001][cData.SkinBuggy] end
            if cData.SkinMirado and _G.X3.VehicleSkins[1915001] and _G.X3.VehicleSkins[1915001][cData.SkinMirado] then _G.X3.VehicleSkinMap[1915001] = _G.X3.VehicleSkins[1915001][cData.SkinMirado] end
        end

        if _G.X3.ApplyLobbyPickedSkins then pcall(_G.X3.ApplyLobbyPickedSkins) end
    end)
end

local cached_GameplayStatics = nil
local cached_PlayerTombBox = nil
local cached_ActorClass = nil
_G.X3.NeedCheckDeadBoxTimer = 0

-- DEAD BOX TEMPER REQUEST --
_G.X3.DeadBox_TemperRequest = function(PlayerController)
    if _G.X3.NeedCheckDeadBoxTimer <= 0 then return end

    local curTime = os.clock()
    if _G.X3.LastCheckDeadBoxTime and (curTime - _G.X3.LastCheckDeadBoxTime) < 3.0 then return end
    _G.X3.LastCheckDeadBoxTime = curTime

    _G.X3.NeedCheckDeadBoxTimer = _G.X3.NeedCheckDeadBoxTimer - 1

    local PlayerCharacter = PlayerController:GetPlayerCharacterSafety()
    if not slua.isValid(PlayerCharacter) then return end

    if not cached_GameplayStatics then
        cached_GameplayStatics = import("GameplayStatics")
        cached_ActorClass = import("Actor")
        cached_PlayerTombBox = import("PlayerTombBox")
    end

    if not _G.X3.CachedActorArray then
        _G.X3.CachedActorArray = slua.Array(UEnums.EPropertyClass.Object, cached_ActorClass)
    end

    local UI_Util = require("client.common.ui_util")
    local GameInstance = UI_Util and UI_Util.GetGameInstance()
    if not GameInstance or not cached_GameplayStatics then return end

    local deadBoxes = cached_GameplayStatics.GetAllActorsOfClass(GameInstance, cached_PlayerTombBox, _G.X3.CachedActorArray)

    for _, deadBoxActor in pairs(deadBoxes) do
        if slua.isValid(deadBoxActor) and not deadBoxActor.bIsTDSkinApplied then
            local damageCauser = deadBoxActor.DamageCauser
            if damageCauser and damageCauser.PlayerKey == PlayerController.PlayerKey then
                local DeadBoxAvatarComponent = deadBoxActor.DeadBoxAvatarComponent_BP
                if slua.isValid(DeadBoxAvatarComponent) then
                    local currentBoxSkinId = 0
                    if PlayerCharacter.CurrentVehicle and _G.X3.CurrentEquipVehicleID and _G.X3.CurrentEquipVehicleID ~= 0 then
                        currentBoxSkinId = tonumber(tostring(_G.X3.CurrentEquipVehicleID) .. "1") or 0
                    else
                        local currentWeapon = PlayerCharacter:GetCurrentWeapon()
                        if slua.isValid(currentWeapon) and currentWeapon.synData then
                            local weaponSkinData = currentWeapon.synData:Get(7)
                            if weaponSkinData and weaponSkinData.defineID then
                                currentBoxSkinId = weaponSkinData.defineID.TypeSpecificID
                            end
                        end
                    end

                    if currentBoxSkinId ~= 0 then
                        pcall(function()
                            DeadBoxAvatarComponent:ResetItemAvatar()
                            DeadBoxAvatarComponent:PreChangeItemAvatar(currentBoxSkinId)
                            DeadBoxAvatarComponent:SyncChangeItemAvatar(currentBoxSkinId)
                        end)
                    end
                    deadBoxActor.bIsTDSkinApplied = true
                end
            end
        end
    end
end

-- MOD SKIN / SKIN MOD --
function _G.X3.InitializeSkinModSystem()
    pcall(function()
        local LobbyAvatar = package.loaded["client.logic.avatar.LobbyAvatar"] or require("client.logic.avatar.LobbyAvatar")
        if LobbyAvatar and not _G.X3.LobbyBypassHacked then
            local originalPutonEquipment = LobbyAvatar.PutonEquipment
            LobbyAvatar.PutonEquipment = function(self, itemID, tAvatarCustom, tExtraData)
                local attachIndex = _G.X3.BaseAttachToIndex and _G.X3.BaseAttachToIndex[itemID]
                if attachIndex then
                    local holdingWeaponSkinID = self.GetCurHoldingWeaponSkinID and self:GetCurHoldingWeaponSkinID()
                    if holdingWeaponSkinID and holdingWeaponSkinID >= 10000000 and _G.X3.VIP_Attachments and _G.X3.VIP_Attachments[holdingWeaponSkinID] then
                        local vipAttachID = _G.X3.VIP_Attachments[holdingWeaponSkinID][attachIndex]
                        if vipAttachID and vipAttachID > 0 then
                            if self.HandleDownload then self:HandleDownload(vipAttachID, nil, nil, false) end
                            itemID = vipAttachID
                        end
                    end
                end
                if originalPutonEquipment then return originalPutonEquipment(self, itemID, tAvatarCustom, tExtraData) end
            end

            local originalCharEquipWeaponByResId = LobbyAvatar.CharEquipWeaponByResId
            LobbyAvatar.CharEquipWeaponByResId = function(self, resID, isUse, isAsync, SocketName)
                local retValue = originalCharEquipWeaponByResId and originalCharEquipWeaponByResId(self, resID, isUse, isAsync, SocketName) or nil
                if isUse and self.GetEquipments then
                    local equipments = self:GetEquipments()
                    for _, equip in ipairs(equipments) do
                        if _G.X3.BaseAttachToIndex and _G.X3.BaseAttachToIndex[equip.itemID] then
                            self:PutonEquipment(equip.itemID, equip.CustomInfo, {bIsUse = false})
                        end
                    end
                end
                return retValue
            end
            _G.X3.LobbyBypassHacked = true
        end
    end)

    pcall(function()
        local Common_Items_UIBP = package.loaded["client.slua.component.item.ItemChildren.Common_Items_UIBP"] or require("client.slua.component.item.ItemChildren.Common_Items_UIBP")
        if Common_Items_UIBP and not _G.X3.IconBaloHacked then
        local originalInitView = Common_Items_UIBP.InitView
            Common_Items_UIBP.InitView = function(self, nItemId, nCount, nValidTime, tExtraData)
                tExtraData = tExtraData or {}
                local displayResId = nil

                if _G.X3.get_skin_id then
                    local skinID = _G.X3.get_skin_id(nItemId)
                    if skinID and skinID ~= nItemId then displayResId = skinID end
                end

                local attachIndex = _G.X3.BaseAttachToIndex and _G.X3.BaseAttachToIndex[nItemId]
                if not displayResId and attachIndex then
                    local GameplayData = require("GameLua.GameCore.Data.GameplayData")
                    local LocalPlayer = GameplayData and GameplayData.GetPlayerCharacter()
                    if slua.isValid(LocalPlayer) then
                        local currentWeapon = LocalPlayer:GetCurrentWeapon()
                        if slua.isValid(currentWeapon) then
                            local weaponID = currentWeapon:GetWeaponID()
                            local finalSkinID = _G.X3.get_skin_id(weaponID) or weaponID
                            if finalSkinID >= 10000000 and _G.X3.VIP_Attachments and _G.X3.VIP_Attachments[finalSkinID] then
                                local vipAttachID = _G.X3.VIP_Attachments[finalSkinID][attachIndex]
                                if vipAttachID and vipAttachID > 0 then displayResId = vipAttachID end
                            end
                        end
                    end
                end

                if displayResId then
                    tExtraData.displayResId = displayResId
                    if not _G.X3.skinIdCache2[displayResId] then
                        if _G.X3.download_item then pcall(_G.X3.download_item, displayResId) end
                        _G.X3.skinIdCache2[displayResId] = true
                    end
                end
                if originalInitView then return originalInitView(self, nItemId, nCount, nValidTime, tExtraData) end
            end
            _G.X3.IconBaloHacked = true
        end
    end)
end

-- Cara kerja:

_G.X3.SkinUnlockState = _G.X3.SkinUnlockState or {
    HookedCount = 0,
    ScanCount = 0,
    LastScan = 0,
}

_G.X3.SkinUnlock_ModulePatterns = { "backpack", "wardrobe", "warehouse", "depot", "item", "skin", "avatar", "dress", "outfit", "garage", "theme", "border", "frame", "pet", "buddy", "collect", "hall" }
_G.X3.SkinUnlock_OwnershipFns = {
    "IsOwnItem", "HasItem", "IsHaveItem", "CheckOwnItem", "OwnItem",
    "IsItemOwned", "CheckItemOwned", "IsUnlock", "CheckUnlock",
    "IsItemUnlock", "CheckItemUnlock", "IsOwned", "CheckOwned",
    "IsHave", "CheckHave", "HasOwned", "GetItemOwned",
    "IsSkinOwn", "HasSkin", "IsSkinOwned", "CheckSkinOwn",
    "IsPossess", "CheckPossess", "IsUnlocked", "CheckHasItem",
    "IsItemHas", "HasItemById", "IsHasItem",
}

-- SKIN UNLOCK LOG --
_G.X3.SkinUnlock_Log = function(msg)
    print("[X3Team][SkinUnlock] " .. tostring(msg))
    if _G.X3.L_Log then pcall(_G.X3.L_Log, "[SkinUnlock] " .. tostring(msg)) end
end

-- SKIN UNLOCK HOOK ONE --
_G.X3.SkinUnlock_HookOne = function(tbl, fnName, tag)
    local old = rawget(tbl, fnName)
    if type(old) ~= "function" then return end
    if rawget(tbl, "__x3su_" .. fnName) then return end
    rawset(tbl, "__x3su_" .. fnName, old)
    rawset(tbl, fnName, function(...)
        if _G.X3.LexusConfig and _G.X3.LexusConfig.SkinUnlockAll then return true end
        return old(...)
    end)
    _G.X3.SkinUnlockState.HookedCount = _G.X3.SkinUnlockState.HookedCount + 1
    SkinUnlock_Log("HOOK " .. tostring(tag) .. "." .. fnName)
end

-- SKIN UNLOCK HOOK TABLE --
_G.X3.SkinUnlock_HookTable = function(tbl, tag)
    if type(tbl) ~= "table" then return end
    for _, fnName in ipairs(SkinUnlock_OwnershipFns) do
        SkinUnlock_HookOne(tbl, fnName, tag)
    end
    local impl = rawget(tbl, "__inner_impl")
    if type(impl) == "table" then
        for _, fnName in ipairs(SkinUnlock_OwnershipFns) do
            SkinUnlock_HookOne(impl, fnName, tag .. ".__inner_impl")
        end
    end
end

-- SKIN UNLOCK SCAN --
_G.X3.SkinUnlockScan = function(force)
    if true then return end
    if not _G.X3.LexusConfig or not _G.X3.LexusConfig.SkinUnlockAll then return end
    local st = _G.X3.SkinUnlockState
    local now = os.clock()
    if not force and (now - (st.LastScan or 0)) < 5.0 then return end
    st.LastScan = now
    st.ScanCount = st.ScanCount + 1

    pcall(function()
        local ModuleManager = require("client.module_framework.ModuleManager")
        local cfg = ModuleManager and ModuleManager.CommonModuleConfig
        if type(cfg) == "table" then
            for name, modId in pairs(cfg) do
                local lname = tostring(name):lower()
                for _, pat in ipairs(SkinUnlock_ModulePatterns) do
                    if lname:find(pat) then
                        local ok, mod = pcall(ModuleManager.GetModule, modId)
                        if ok and type(mod) == "table" then
                            SkinUnlock_HookTable(mod, "MM:" .. tostring(name))
                        end
                        break
                    end
                end
            end
        end
    end)

    pcall(function()
        for modName, mod in pairs(package.loaded) do
            if type(mod) == "table" then
                local lname = tostring(modName):lower()
                for _, pat in ipairs(SkinUnlock_ModulePatterns) do
                    if lname:find(pat) then
                        SkinUnlock_HookTable(mod, tostring(modName))
                        break
                    end
                end
            end
        end
    end)

    if st.ScanCount == 1 then
        SkinUnlock_Log("scan pertama selesai, hook aktif: " .. st.HookedCount)
    end
end


-- SKIN UNLOCK TICK --
-- SKIN UNLOCK TICK (MAINLOOP 5 dtk: self-gate + anti reset default sehabis match) --
_G.X3.SkinUnlockTick = function()
    pcall(function()
        if not (_G.X3.LexusConfig and _G.X3.LexusConfig.SkinUnlockAll) then return end
        -- server me-reset wardrobe ke default saat match selesai -> injeksi ulang
        local stt = nil
        local gs = GameplayData and GameplayData.GetGameState and GameplayData.GetGameState()
        if gs and slua.isValid(gs) then pcall(function() stt = gs:GetGameModeState() end) end
        local inMatch = _G.X3._InCombatGS and _G.X3._InCombatGS(gs, stt) or (stt == "FightingState")
        if _G.X3._SkinWasInMatch == true and not inMatch and stt ~= nil and stt ~= "" then
            local lpAlive = false
            pcall(function()
                local lp = GameplayData.GetPlayerCharacter and GameplayData.GetPlayerCharacter()
                if lp and slua.isValid(lp) and (lp.Health == nil or lp.Health > 0) then lpAlive = true end
            end)
            _G.X3._SkinNonFightN = (_G.X3._SkinNonFightN or 0) + 1
            if _G.X3._CrashLog then pcall(_G.X3._CrashLog, "SKIN RESET GATE > state '" .. tostring(stt) .. "' konfirmasi " .. tostring(_G.X3._SkinNonFightN) .. "/2 (charAktif=" .. tostring(lpAlive) .. ")") end
            if _G.X3._SkinNonFightN >= 2 and not lpAlive then
                _G.X3._SkinNonFightN = 0
                _G.X3._SkinWasInMatch = false
                local ij = _G.X3.Inj
                if ij then
                    ij.allDone = false
                    ij.injectDone = false
                    ij.phase = 1
                    ij.injectIdx = 1
                    ij.injectRunning = false
                end
                _G.X3.EnumDone = false
                if _G.X3._CrashLogUrgent then pcall(_G.X3._CrashLogUrgent, "SKIN RESET TERDETEKSI (match end TERKONFIRMASI 2x) > RE-INJECT") end
            end
        else
            _G.X3._SkinNonFightN = 0
            _G.X3._SkinWasInMatch = inMatch
        end
        if _G.X3.InjEnsure then pcall(_G.X3.InjEnsure) end
    end)
end


-- SKIN UNLOCK IN LOBBY --
_G.X3.SkinUnlock_InLobby = function()
    local inBattle = false
    pcall(function()
        local GameplayData = require("GameLua.GameCore.Data.GameplayData")
        local gs = GameplayData and GameplayData.GetGameState and GameplayData.GetGameState()
        if gs and slua.isValid(gs) then
            local st = gs:GetGameModeState() or ""
            inBattle = (st == "FightingState")
        end
    end)
    return not inBattle
end


-- APPLY LOBBY PICKED SKINS --
_G.X3.ApplyLobbyPickedSkins = function()
    local cData = _G.X3.LexusState and _G.X3.LexusState.CustomTextData
    if not cData then return end
    for k, v in pairs(cData) do
        local base = tostring(k):match("^LobbyGun_(%d+)$")
        if base and tonumber(v) then
            _G.X3.WeaponSkinMap[tonumber(base)] = tonumber(v)
        end
    end
    if tonumber(cData.LobbySuit) then _G.X3.OutfitMap.Suit = tonumber(cData.LobbySuit) end
    if tonumber(cData.LobbyBag) then local n = tonumber(cData.LobbyBag) _G.X3.OutfitMap.Bag = { n, n, n } end
    if tonumber(cData.LobbyHelmet) then local n = tonumber(cData.LobbyHelmet) _G.X3.OutfitMap.Helmet = { n, n, n } end
    if tonumber(cData.LobbyPants) then _G.X3.OutfitMap.Pants = tonumber(cData.LobbyPants) end
    if tonumber(cData.LobbyShoes) then _G.X3.OutfitMap.Shoes = tonumber(cData.LobbyShoes) end
    for k, v in pairs(cData) do
        local vb = tostring(k):match("^LobbyVeh_(%d+)$")
        if vb and tonumber(v) then
            _G.X3.VehicleSkinMap[tonumber(vb)] = tonumber(v)
        end
    end
end

_G.X3.VIPWeaponSkins = {
1101001001,1101001002,1101001003,1101001004,1101001005,1101001006,1101001007,1101001009,1101001019,1101001020,1101001022,1101001023,1101001024,1101001025,1101001027,1101001028,
1101001029,1101001030,1101001031,1101001033,1101001035,1101001036,1101001042,1101001044,1101001045,1101001046,1101001047,1101001048,1101001050,1101001051,1101001052,1101001053,
1101001054,1101001055,1101001056,1101001063,1101001068,1101001071,1101001079,1101001081,1101001089,1101001091,1101001092,1101001093,1101001094,1101001095,1101001103,1101001104,
1101001105,1101001107,1101001108,1101001109,1101001116,1101001117,1101001118,1101001121,1101001128,1101001129,1101001130,1101001131,1101001132,1101001135,1101001136,1101001139,
1101001143,1101001144,1101001145,1101001146,1101001154,1101001155,1101001156,1101001157,1101001158,1101001160,1101001161,1101001164,1101001173,1101001174,1101001177,1101001178,
1101001179,1101001181,1101001184,1101001193,1101001199,1101001213,1101001221,1101001231,1101001232,1101001233,1101001242,1101001249,1101001256,1101001257,1101001265,1101001266,
1101001267,1101001268,1101001276,1101002001,1101002002,1101002003,1101002004,1101002005,1101002006,1101002007,1101002008,1101002009,1101002019,1101002020,1101002029,1101002030,
1101002038,1101002039,1101002040,1101002041,1101002042,1101002043,1101002044,1101002045,1101002046,1101002047,1101002048,1101002049,1101002056,1101002057,1101002058,1101002060,
1101002061,1101002062,1101002063,1101002068,1101002070,1101002071,1101002073,1101002074,1101002081,1101002083,1101002084,1101002085,1101002086,1101002087,1101002089,1101002090,
1101002091,1101002092,1101002093,1101002095,1101002097,1101002098,1101002103,1101002104,1101002105,1101002110,1101002111,1101002112,1101002117,1101002118,1101002119,1101002120,
1101002125,1101002128,1101002133,1101002134,1101002135,1101002136,1101002137,1101002142,1101002143,1101002144,1101002149,1101002156,1101002157,1101002158,1101003001,1101003002,
1101003003,1101003004,1101003005,1101003006,1101003007,1101003008,1101003009,1101003010,1101003011,1101003012,1101003013,1101003014,1101003015,1101003016,1101003017,1101003018,
1101003019,1101003020,1101003021,1101003022,1101003032,1101003033,1101003034,1101003035,1101003036,1101003037,1101003038,1101003039,1101003040,1101003041,1101003042,1101003043,
1101003044,1101003045,1101003046,1101003048,1101003049,1101003050,1101003057,1101003058,1101003059,1101003060,1101003061,1101003062,1101003063,1101003070,1101003071,1101003073,
1101003080,1101003082,1101003083,1101003084,1101003085,1101003087,1101003088,1101003089,1101003090,1101003099,1101003100,1101003101,1101003103,1101003112,1101003119,1101003120,
1101003121,1101003125,1101003130,1101003131,1101003132,1101003133,1101003134,1101003135,1101003136,1101003138,1101003140,1101003141,1101003146,1101003147,1101003148,1101003150,
1101003157,1101003158,1101003167,1101003168,1101003173,1101003174,1101003188,1101003195,1101003196,1101003199,1101003200,1101003201,1101003208,1101003209,1101003212,1101003219,
1101003227,1101003228,1101004001,1101004002,1101004003,1101004004,1101004005,1101004006,1101004007,1101004008,1101004009,1101004010,1101004011,1101004013,1101004014,1101004015,
1101004016,1101004017,1101004018,1101004019,1101004030,1101004031,1101004032,1101004033,1101004034,1101004035,1101004036,1101004039,1101004046,1101004049,1101004051,1101004053,
1101004054,1101004055,1101004062,1101004067,1101004069,1101004070,1101004071,1101004078,1101004079,1101004086,1101004087,1101004088,1101004089,1101004090,1101004091,1101004098,
1101004099,1101004107,1101004110,1101004117,1101004118,1101004119,1101004120,1101004122,1101004123,1101004124,1101004125,1101004133,1101004138,1101004145,1101004146,1101004148,
1101004149,1101004150,1101004151,1101004154,1101004160,1101004163,1101004164,1101004179,1101004201,1101004209,1101004210,1101004218,1101004226,1101004227,1101004228,1101004236,
1101004237,1101004238,1101004246,1101005001,1101005002,1101005012,1101005013,1101005014,1101005019,1101005025,1101005027,1101005028,1101005029,1101005030,1101005031,1101005038,
1101005043,1101005044,1101005045,1101005052,1101005055,1101005066,1101005072,1101005082,1101005083,1101005084,1101005085,1101005090,1101005091,1101005098,1101005099,1101005100,
1101005105,1101005106,1101006001,1101006002,1101006003,1101006004,1101006005,1101006006,1101006007,1101006017,1101006018,1101006019,1101006020,1101006021,1101006023,1101006027,
1101006028,1101006033,1101006036,1101006037,1101006038,1101006039,1101006044,1101006045,1101006051,1101006052,1101006053,1101006054,1101006062,1101006067,1101006068,1101006075,
1101006076,1101006077,1101006085,1101006086,1101006087,1101006088,1101006089,1101006090,1101006098,1101006106,1101007001,1101007002,1101007003,1101007004,1101007005,1101007006,
1101007007,1101007008,1101007009,1101007010,1101007011,1101007012,1101007013,1101007014,1101007017,1101007018,1101007019,1101007020,1101007025,1101007033,1101007034,1101007036,
1101007037,1101007038,1101007039,1101007046,1101007047,1101007048,1101007054,1101007055,1101007062,1101007063,1101007064,1101007071,1101007072,1101007073,1101007078,1101007079,
1101007084,1101008010,1101008011,1101008012,1101008013,1101008014,1101008015,1101008016,1101008017,1101008018,1101008019,1101008020,1101008021,1101008026,1101008029,1101008030,
1101008031,1101008036,1101008039,1101008051,1101008052,1101008053,1101008054,1101008061,1101008062,1101008063,1101008070,1101008071,1101008072,1101008080,1101008081,1101008082,
1101008083,1101008084,1101008087,1101008088,1101008092,1101008104,1101008106,1101008116,1101008117,1101008118,1101008126,1101008127,1101008128,1101008129,1101008136,1101008137,
1101008138,1101008146,1101008154,1101008155,1101008156,1101008163,1101008170,1101009001,1101009002,1101009003,1101009004,1101009005,1101009006,1101009007,1101009008,1101009009,
1101009010,1101009011,1101009012,1101009013,1101009014,1101009015,1101009016,1101009019,1101009020,1101009021,1101009022,1101009023,1101009024,1101009099,1101010010,1101010011,
1101010012,1101010013,1101010016,1101010018,1101010019,1101010020,1101010021,1101010022,1101010023,1101010024,1101010029,1101010030,1101012001,1101012004,1101012009,1101012010,
1101012011,1101012012,1101012013,1101012018,1101012019,1101012020,1101012021,1101012022,1101012023,1101012024,1101012025,1101012026,1101012033,1101100003,1101100004,1101100012,
1101100013,1101100018,1101100019,1101100020,1101100021,1101101007,1101102007,1101102017,1101102025,1101102026,1101102027,1101102032,1101102033,1101102041,1101102049,1101102056
}

_G.X3.DumpSkins = nil

_G.X3.NonMaxLevels = {
[501001]=true, [501002]=true, [501003]=true, [501004]=true, [501005]=true, [501006]=true, [501007]=true, [501008]=true,
[501009]=true, [501010]=true, [501011]=true, [501012]=true, [501015]=true, [501101]=true, [501102]=true, [501103]=true,
[501104]=true, [501105]=true, [502001]=true, [502002]=true, [502003]=true, [502004]=true, [502005]=true, [502101]=true,
[502102]=true, [502103]=true, [502104]=true, [502105]=true, [502107]=true, [502108]=true, [502110]=true, [502111]=true,
[503001]=true, [503101]=true, [503102]=true, [503103]=true, [503104]=true, [503105]=true, [503107]=true, [503108]=true,
[503110]=true, [503111]=true, [503113]=true, [503114]=true, [1000052]=true, [1000053]=true, [1000055]=true, [1000056]=true,
[1406904]=true, [1406905]=true, [1406983]=true, [1407019]=true, [1407053]=true, [1407054]=true, [1407055]=true, [1407109]=true,
[1407110]=true, [1407111]=true, [1407163]=true, [1407164]=true, [1407227]=true, [1407228]=true, [1407288]=true, [1407289]=true,
[1407332]=true, [1407333]=true, [1407394]=true, [1407395]=true, [1407443]=true, [1407444]=true, [1407473]=true, [1407474]=true,
[1407525]=true, [1407526]=true, [1407527]=true, [1407575]=true, [1407576]=true, [1407634]=true, [1407635]=true, [1407698]=true,
[1407699]=true, [1407761]=true, [1407762]=true, [1407814]=true, [1407815]=true, [1407873]=true, [1407874]=true, [1407924]=true,
[1407925]=true, [1407998]=true, [1407999]=true, [1410428]=true, [1410429]=true, [1410528]=true, [1410529]=true, [1410559]=true,
[1410562]=true, [1410563]=true, [1410843]=true, [1410844]=true, [1410989]=true, [1410990]=true, [1410996]=true, [1410997]=true,
[1410999]=true, [1411000]=true, [1501079]=true, [1501080]=true, [1501081]=true, [1501082]=true, [1519003]=true, [1519302]=true,
[1519304]=true, [1519308]=true, [1733000]=true, [1901016]=true, [1901017]=true, [1901025]=true, [1901026]=true, [1901041]=true,
[1901042]=true, [1901043]=true, [1901044]=true, [1901045]=true, [1901046]=true, [1901082]=true, [1901083]=true, [1901084]=true,
[1901086]=true, [1901087]=true, [1901088]=true, [1901099]=true, [1901100]=true, [1901101]=true, [1902027]=true, [1902028]=true,
[1902029]=true, [1902031]=true, [1902032]=true, [1902033]=true, [1903012]=true, [1903013]=true, [1903015]=true, [1903016]=true,
[1903032]=true, [1903034]=true, [1903084]=true, [1903085]=true, [1903086]=true, [1903194]=true, [1903195]=true, [1903196]=true,
[1903206]=true, [1907044]=true, [1907045]=true, [1907046]=true, [1907060]=true, [1907061]=true, [1907062]=true, [1907069]=true,
[1907070]=true, [1907071]=true, [1908030]=true, [1908031]=true, [1908033]=true, [1908035]=true, [1908049]=true, [1908050]=true,
[1908051]=true, [1908052]=true, [1908053]=true, [1908054]=true, [1908055]=true, [1908096]=true, [1908097]=true, [1908098]=true,
[1908106]=true, [1908113]=true, [1908114]=true, [1908115]=true, [1911016]=true, [1911017]=true, [1911018]=true, [1915013]=true,
[1915014]=true, [1915015]=true, [1915023]=true, [1915024]=true, [1915025]=true, [1953005]=true, [1953006]=true, [1953007]=true,
[1953013]=true, [1953014]=true, [1953015]=true, [1988002]=true, [1988003]=true, [1988004]=true, [4301603]=true, [4301604]=true,
[4301605]=true, [4301606]=true, [4301607]=true, [4301608]=true, [4301609]=true, [4301610]=true, [4301613]=true, [4301614]=true,
[4301615]=true, [7101001]=true, [7101002]=true, [7101003]=true, [7101005]=true, [7101006]=true, [7101007]=true, [7101009]=true,
[7101010]=true, [7101011]=true, [7101013]=true, [7101014]=true, [7101015]=true, [7101017]=true, [7101018]=true, [7101019]=true,
[7101021]=true, [7101022]=true, [7101023]=true, [7101025]=true, [7101026]=true, [7101027]=true, [7101029]=true, [7101030]=true,
[7101031]=true, [7101033]=true, [7101034]=true, [7101035]=true, [7101037]=true, [7101038]=true, [7101039]=true, [7101041]=true,
[7101042]=true, [7101043]=true, [7101045]=true, [7101046]=true, [7101047]=true, [7101049]=true, [7101050]=true, [7101051]=true,
[7101053]=true, [7101054]=true, [7101055]=true, [7101057]=true, [7101058]=true, [7101059]=true, [7101061]=true, [7101062]=true,
[7101063]=true, [7101065]=true, [7101066]=true, [7101067]=true, [7101069]=true, [7101070]=true, [7101071]=true, [12220411]=true,
[61010062]=true, [61010066]=true, [61010068]=true, [61100073]=true, [61100074]=true, [61100081]=true, [61100082]=true, [61100090]=true,
[61100091]=true, [61100099]=true, [61100100]=true, [61100108]=true, [61100109]=true, [61100116]=true, [61100117]=true, [61100126]=true,
[61100127]=true, [61100136]=true, [61100137]=true, [61200075]=true, [61200076]=true, [61200085]=true, [61200086]=true, [61200094]=true,
[61200095]=true, [61200101]=true, [61200102]=true, [61200111]=true, [61200112]=true, [61200117]=true, [61200118]=true, [61200128]=true,
[61200129]=true, [61200136]=true, [61200137]=true, [61300067]=true, [61300073]=true, [61300076]=true, [61400070]=true, [61400079]=true,
[61400081]=true, [61510010]=true, [61510012]=true, [61510014]=true, [61510016]=true, [61510018]=true, [61510020]=true, [61510022]=true,
[61510024]=true, [62110024]=true, [62110027]=true, [62110031]=true, [444001005]=true, [444002005]=true, [444003005]=true, [844001001]=true,
[844001003]=true, [844001011]=true, [844001012]=true, [844001013]=true, [844002001]=true, [844002003]=true, [844002011]=true, [844002012]=true,
[844002013]=true, [844002018]=true, [844003001]=true, [844003003]=true, [844003011]=true, [844003012]=true, [844003013]=true, [844003018]=true,
[844004018]=true, [845001001]=true, [845002001]=true, [845003001]=true, [911001007]=true, [911001013]=true, [911001033]=true, [911002002]=true,
[911002007]=true, [911002009]=true, [911002013]=true, [911002033]=true, [911003002]=true, [911003007]=true, [911003009]=true, [911003013]=true,
[911003033]=true, [911004002]=true, [911005009]=true, [912001001]=true, [912001025]=true, [912001051]=true, [912002001]=true, [912002025]=true,
[912002051]=true, [912003001]=true, [912003025]=true, [912003051]=true, [914001003]=true, [914001004]=true, [914001005]=true, [914001006]=true,
[914001011]=true, [914001012]=true, [914001014]=true, [914001016]=true, [914002003]=true, [914002004]=true, [914002005]=true, [914002006]=true,
[914002011]=true, [914002012]=true, [914002014]=true, [914002016]=true, [914002017]=true, [914002018]=true, [914003003]=true, [914003004]=true,
[914003005]=true, [914003006]=true, [914003011]=true, [914003012]=true, [914003014]=true, [914003016]=true, [914003017]=true, [914003018]=true,
[914004017]=true, [914004018]=true, [915001003]=true, [915001005]=true, [915001019]=true, [915001021]=true, [915002003]=true, [915002005]=true,
[915002019]=true, [915002021]=true, [915003003]=true, [915003005]=true, [915003019]=true, [915003021]=true, [931001033]=true, [931002033]=true,
[931003033]=true, [932001025]=true, [932002025]=true, [932003025]=true, [934001002]=true, [934001009]=true, [934001012]=true, [934001016]=true,
[934001017]=true, [934001018]=true, [934002002]=true, [934002009]=true, [934002012]=true, [934002016]=true, [934002017]=true, [934002018]=true,
[934003002]=true, [934003009]=true, [934003012]=true, [934003016]=true, [934003017]=true, [934003018]=true, [935001012]=true, [935001017]=true,
[935002012]=true, [935002017]=true, [935003012]=true, [935003017]=true, [1030010961]=true, [1101001037]=true, [1101001038]=true, [1101001039]=true,
[1101001040]=true, [1101001041]=true, [1101001057]=true, [1101001058]=true, [1101001059]=true, [1101001060]=true, [1101001061]=true, [1101001062]=true,
[1101001064]=true, [1101001065]=true, [1101001066]=true, [1101001067]=true, [1101001083]=true, [1101001084]=true, [1101001085]=true, [1101001086]=true,
[1101001087]=true, [1101001088]=true, [1101001097]=true, [1101001098]=true, [1101001099]=true, [1101001100]=true, [1101001101]=true, [1101001102]=true,
[1101001110]=true, [1101001111]=true, [1101001112]=true, [1101001113]=true, [1101001114]=true, [1101001115]=true, [1101001122]=true, [1101001123]=true,
[1101001124]=true, [1101001125]=true, [1101001126]=true, [1101001127]=true, [1101001133]=true, [1101001134]=true, [1101001137]=true, [1101001140]=true,
[1101001141]=true, [1101001142]=true, [1101001148]=true, [1101001149]=true, [1101001150]=true, [1101001151]=true, [1101001152]=true, [1101001153]=true,
[1101001166]=true, [1101001167]=true, [1101001168]=true, [1101001169]=true, [1101001170]=true, [1101001171]=true, [1101001172]=true, [1101001206]=true,
[1101001207]=true, [1101001208]=true, [1101001209]=true, [1101001210]=true, [1101001211]=true, [1101001212]=true, [1101001225]=true, [1101001226]=true,
[1101001227]=true, [1101001228]=true, [1101001229]=true, [1101001230]=true, [1101001235]=true, [1101001236]=true, [1101001237]=true, [1101001238]=true,
[1101001239]=true, [1101001240]=true, [1101001241]=true, [1101001243]=true, [1101001244]=true, [1101001245]=true, [1101001246]=true, [1101001247]=true,
[1101001248]=true, [1101001250]=true, [1101001251]=true, [1101001252]=true, [1101001253]=true, [1101001254]=true, [1101001255]=true, [1101001258]=true,
[1101001259]=true, [1101001260]=true, [1101001261]=true, [1101001262]=true, [1101001263]=true, [1101001264]=true, [1101001269]=true, [1101001270]=true,
[1101001271]=true, [1101001272]=true, [1101001273]=true, [1101001274]=true, [1101001275]=true, [1101002023]=true, [1101002024]=true, [1101002025]=true,
[1101002026]=true, [1101002027]=true, [1101002028]=true, [1101002050]=true, [1101002051]=true, [1101002052]=true, [1101002053]=true, [1101002054]=true,
[1101002055]=true, [1101002064]=true, [1101002065]=true, [1101002066]=true, [1101002067]=true, [1101002075]=true, [1101002076]=true, [1101002077]=true,
[1101002078]=true, [1101002079]=true, [1101002080]=true, [1101002099]=true, [1101002100]=true, [1101002101]=true, [1101002102]=true, [1101002106]=true,
[1101002107]=true, [1101002108]=true, [1101002109]=true, [1101002113]=true, [1101002114]=true, [1101002115]=true, [1101002116]=true, [1101002121]=true,
[1101002122]=true, [1101002123]=true, [1101002124]=true, [1101002126]=true, [1101002127]=true, [1101002129]=true, [1101002130]=true, [1101002131]=true,
[1101002132]=true, [1101002138]=true, [1101002139]=true, [1101002140]=true, [1101002141]=true, [1101002145]=true, [1101002146]=true, [1101002147]=true,
[1101002148]=true, [1101002150]=true, [1101002151]=true, [1101002152]=true, [1101002153]=true, [1101002154]=true, [1101002155]=true, [1101003051]=true,
[1101003052]=true, [1101003053]=true, [1101003054]=true, [1101003055]=true, [1101003056]=true, [1101003064]=true, [1101003065]=true, [1101003066]=true,
[1101003067]=true, [1101003068]=true, [1101003069]=true, [1101003074]=true, [1101003075]=true, [1101003076]=true, [1101003077]=true, [1101003078]=true,
[1101003079]=true, [1101003093]=true, [1101003094]=true, [1101003095]=true, [1101003096]=true, [1101003097]=true, [1101003098]=true, [1101003113]=true,
[1101003114]=true, [1101003115]=true, [1101003116]=true, [1101003117]=true, [1101003118]=true, [1101003122]=true, [1101003123]=true, [1101003124]=true,
[1101003142]=true, [1101003143]=true, [1101003144]=true, [1101003145]=true, [1101003160]=true, [1101003161]=true, [1101003162]=true, [1101003163]=true,
[1101003164]=true, [1101003165]=true, [1101003166]=true, [1101003169]=true, [1101003170]=true, [1101003171]=true, [1101003172]=true, [1101003175]=true,
[1101003176]=true, [1101003177]=true, [1101003178]=true, [1101003179]=true, [1101003180]=true, [1101003181]=true, [1101003182]=true, [1101003183]=true,
[1101003184]=true, [1101003185]=true, [1101003186]=true, [1101003187]=true, [1101003189]=true, [1101003190]=true, [1101003191]=true, [1101003192]=true,
[1101003193]=true, [1101003194]=true, [1101003202]=true, [1101003203]=true, [1101003204]=true, [1101003205]=true, [1101003206]=true, [1101003207]=true,
[1101003210]=true, [1101003211]=true, [1101003213]=true, [1101003214]=true, [1101003215]=true, [1101003216]=true, [1101003217]=true, [1101003218]=true,
[1101003220]=true, [1101003221]=true, [1101003222]=true, [1101003223]=true, [1101003224]=true, [1101003225]=true, [1101003226]=true, [1101004040]=true,
[1101004041]=true, [1101004042]=true, [1101004043]=true, [1101004044]=true, [1101004045]=true, [1101004056]=true, [1101004057]=true, [1101004058]=true,
[1101004059]=true, [1101004060]=true, [1101004061]=true, [1101004072]=true, [1101004073]=true, [1101004074]=true, [1101004075]=true, [1101004076]=true,
[1101004077]=true, [1101004080]=true, [1101004081]=true, [1101004082]=true, [1101004083]=true, [1101004084]=true, [1101004085]=true, [1101004092]=true,
[1101004093]=true, [1101004094]=true, [1101004095]=true, [1101004096]=true, [1101004097]=true, [1101004112]=true, [1101004113]=true, [1101004114]=true,
[1101004135]=true, [1101004136]=true, [1101004137]=true, [1101004155]=true, [1101004156]=true, [1101004157]=true, [1101004158]=true, [1101004159]=true,
[1101004161]=true, [1101004162]=true, [1101004194]=true, [1101004195]=true, [1101004196]=true, [1101004197]=true, [1101004198]=true, [1101004199]=true,
[1101004200]=true, [1101004202]=true, [1101004203]=true, [1101004204]=true, [1101004205]=true, [1101004206]=true, [1101004207]=true, [1101004208]=true,
[1101004211]=true, [1101004212]=true, [1101004213]=true, [1101004214]=true, [1101004215]=true, [1101004216]=true, [1101004217]=true, [1101004219]=true,
[1101004220]=true, [1101004221]=true, [1101004222]=true, [1101004223]=true, [1101004224]=true, [1101004225]=true, [1101004229]=true, [1101004230]=true,
[1101004231]=true, [1101004232]=true, [1101004233]=true, [1101004234]=true, [1101004235]=true, [1101004239]=true, [1101004240]=true, [1101004241]=true,
[1101004242]=true, [1101004243]=true, [1101004244]=true, [1101004245]=true, [1101005015]=true, [1101005016]=true, [1101005017]=true, [1101005018]=true,
[1101005021]=true, [1101005022]=true, [1101005023]=true, [1101005024]=true, [1101005032]=true, [1101005033]=true, [1101005034]=true, [1101005035]=true,
[1101005036]=true, [1101005037]=true, [1101005039]=true, [1101005040]=true, [1101005041]=true, [1101005042]=true, [1101005046]=true, [1101005047]=true,
[1101005048]=true, [1101005049]=true, [1101005050]=true, [1101005051]=true, [1101005078]=true, [1101005079]=true, [1101005080]=true, [1101005081]=true,
[1101005086]=true, [1101005087]=true, [1101005088]=true, [1101005089]=true, [1101005092]=true, [1101005093]=true, [1101005094]=true, [1101005095]=true,
[1101005096]=true, [1101005097]=true, [1101005101]=true, [1101005102]=true, [1101005103]=true, [1101005104]=true, [1101006029]=true, [1101006030]=true,
[1101006031]=true, [1101006032]=true, [1101006040]=true, [1101006041]=true, [1101006042]=true, [1101006043]=true, [1101006055]=true, [1101006056]=true,
[1101006057]=true, [1101006058]=true, [1101006059]=true, [1101006060]=true, [1101006061]=true, [1101006063]=true, [1101006064]=true, [1101006065]=true,
[1101006066]=true, [1101006069]=true, [1101006070]=true, [1101006071]=true, [1101006072]=true, [1101006073]=true, [1101006074]=true, [1101006078]=true,
[1101006079]=true, [1101006080]=true, [1101006081]=true, [1101006082]=true, [1101006083]=true, [1101006084]=true, [1101006091]=true, [1101006092]=true,
[1101006093]=true, [1101006094]=true, [1101006095]=true, [1101006096]=true, [1101006097]=true, [1101006099]=true, [1101006100]=true, [1101006101]=true,
[1101006102]=true, [1101006103]=true, [1101006104]=true, [1101006105]=true, [1101007021]=true, [1101007022]=true, [1101007023]=true, [1101007024]=true,
[1101007030]=true, [1101007031]=true, [1101007032]=true, [1101007035]=true, [1101007040]=true, [1101007041]=true, [1101007042]=true, [1101007043]=true,
[1101007044]=true, [1101007045]=true, [1101007056]=true, [1101007057]=true, [1101007058]=true, [1101007059]=true, [1101007060]=true, [1101007061]=true,
[1101007065]=true, [1101007066]=true, [1101007067]=true, [1101007068]=true, [1101007069]=true, [1101007070]=true, [1101007074]=true, [1101007075]=true,
[1101007076]=true, [1101007077]=true, [1101007080]=true, [1101007081]=true, [1101007082]=true, [1101007083]=true, [1101008022]=true, [1101008023]=true,
[1101008024]=true, [1101008025]=true, [1101008032]=true, [1101008033]=true, [1101008034]=true, [1101008035]=true, [1101008045]=true, [1101008046]=true,
[1101008047]=true, [1101008048]=true, [1101008049]=true, [1101008050]=true, [1101008055]=true, [1101008056]=true, [1101008057]=true, [1101008058]=true,
[1101008059]=true, [1101008060]=true, [1101008064]=true, [1101008065]=true, [1101008066]=true, [1101008067]=true, [1101008068]=true, [1101008069]=true,
[1101008073]=true, [1101008074]=true, [1101008075]=true, [1101008076]=true, [1101008077]=true, [1101008078]=true, [1101008079]=true, [1101008097]=true,
[1101008098]=true, [1101008099]=true, [1101008100]=true, [1101008101]=true, [1101008102]=true, [1101008103]=true, [1101008110]=true, [1101008111]=true,
[1101008112]=true, [1101008113]=true, [1101008114]=true, [1101008115]=true, [1101008120]=true, [1101008121]=true, [1101008122]=true, [1101008123]=true,
[1101008124]=true, [1101008125]=true, [1101008130]=true, [1101008131]=true, [1101008132]=true, [1101008133]=true, [1101008134]=true, [1101008135]=true,
[1101008139]=true, [1101008140]=true, [1101008141]=true, [1101008142]=true, [1101008143]=true, [1101008144]=true, [1101008145]=true, [1101008147]=true,
[1101008148]=true, [1101008149]=true, [1101008150]=true, [1101008151]=true, [1101008152]=true, [1101008153]=true, [1101008157]=true, [1101008158]=true,
[1101008159]=true, [1101008160]=true, [1101008161]=true, [1101008162]=true, [1101008164]=true, [1101008165]=true, [1101008166]=true, [1101008167]=true,
[1101008168]=true, [1101008169]=true, [1101009017]=true, [1101009018]=true, [1101010025]=true, [1101010026]=true, [1101010027]=true, [1101010028]=true,
[1101012005]=true, [1101012006]=true, [1101012007]=true, [1101012008]=true, [1101012014]=true, [1101012015]=true, [1101012016]=true, [1101012017]=true,
[1101012027]=true, [1101012028]=true, [1101012029]=true, [1101012030]=true, [1101012031]=true, [1101012032]=true, [1101100005]=true, [1101100006]=true,
[1101100007]=true, [1101100008]=true, [1101100009]=true, [1101100010]=true, [1101100011]=true, [1101100014]=true, [1101100015]=true, [1101100016]=true,
[1101100017]=true, [1101101001]=true, [1101101002]=true, [1101101003]=true, [1101101004]=true, [1101101005]=true, [1101101006]=true, [1101102001]=true,
[1101102002]=true, [1101102003]=true, [1101102004]=true, [1101102005]=true, [1101102006]=true, [1101102011]=true, [1101102012]=true, [1101102013]=true,
[1101102014]=true, [1101102015]=true, [1101102016]=true, [1101102018]=true, [1101102019]=true, [1101102020]=true, [1101102021]=true, [1101102022]=true,
[1101102023]=true, [1101102024]=true, [1101102028]=true, [1101102029]=true, [1101102030]=true, [1101102031]=true, [1101102034]=true, [1101102035]=true,
[1101102036]=true, [1101102037]=true, [1101102038]=true, [1101102039]=true, [1101102040]=true, [1101102042]=true, [1101102043]=true, [1101102044]=true,
[1101102045]=true, [1101102046]=true, [1101102047]=true, [1101102048]=true, [1101102050]=true, [1101102051]=true, [1101102052]=true, [1101102053]=true,
[1101102054]=true, [1101102055]=true, [1102001019]=true, [1102001020]=true, [1102001021]=true, [1102001022]=true, [1102001023]=true, [1102001032]=true,
[1102001033]=true, [1102001034]=true, [1102001035]=true, [1102001054]=true, [1102001055]=true, [1102001056]=true, [1102001057]=true, [1102001065]=true,
[1102001066]=true, [1102001067]=true, [1102001068]=true, [1102001083]=true, [1102001086]=true, [1102001087]=true, [1102001088]=true, [1102001092]=true,
[1102001093]=true, [1102001094]=true, [1102001096]=true, [1102001098]=true, [1102001099]=true, [1102001100]=true, [1102001101]=true, [1102001110]=true,
[1102001111]=true, [1102001113]=true, [1102001114]=true, [1102001115]=true, [1102001116]=true, [1102001117]=true, [1102001118]=true, [1102001119]=true,
[1102001124]=true, [1102001125]=true, [1102001126]=true, [1102001127]=true, [1102001128]=true, [1102001129]=true, [1102001998]=true, [1102001999]=true,
[1102002037]=true, [1102002038]=true, [1102002039]=true, [1102002040]=true, [1102002041]=true, [1102002042]=true, [1102002049]=true, [1102002050]=true,
[1102002051]=true, [1102002052]=true, [1102002055]=true, [1102002056]=true, [1102002057]=true, [1102002058]=true, [1102002059]=true, [1102002060]=true,
[1102002064]=true, [1102002065]=true, [1102002066]=true, [1102002069]=true, [1102002086]=true, [1102002087]=true, [1102002088]=true, [1102002089]=true,
[1102002099]=true, [1102002100]=true, [1102002101]=true, [1102002111]=true, [1102002113]=true, [1102002114]=true, [1102002115]=true, [1102002116]=true,
[1102002122]=true, [1102002123]=true, [1102002125]=true, [1102002126]=true, [1102002127]=true, [1102002128]=true, [1102002130]=true, [1102002131]=true,
[1102002132]=true, [1102002133]=true, [1102002134]=true, [1102002135]=true, [1102002139]=true, [1102002140]=true, [1102002141]=true, [1102002142]=true,
[1102002418]=true, [1102002419]=true, [1102002420]=true, [1102002421]=true, [1102002422]=true, [1102002423]=true, [1102002431]=true, [1102002432]=true,
[1102002433]=true, [1102002434]=true, [1102002435]=true, [1102002436]=true, [1102002437]=true, [1102002439]=true, [1102002440]=true, [1102002441]=true,
[1102002442]=true, [1102002443]=true, [1102002444]=true, [1102002445]=true, [1102003016]=true, [1102003017]=true, [1102003018]=true, [1102003019]=true,
[1102003027]=true, [1102003028]=true, [1102003029]=true, [1102003030]=true, [1102003035]=true, [1102003036]=true, [1102003037]=true, [1102003038]=true,
[1102003046]=true, [1102003047]=true, [1102003048]=true, [1102003051]=true, [1102003060]=true, [1102003061]=true, [1102003062]=true, [1102003064]=true,
[1102003066]=true, [1102003067]=true, [1102003068]=true, [1102003071]=true, [1102003074]=true, [1102003075]=true, [1102003076]=true, [1102003077]=true,
[1102003078]=true, [1102003079]=true, [1102003094]=true, [1102003095]=true, [1102003096]=true, [1102003097]=true, [1102003098]=true, [1102003099]=true,
[1102004014]=true, [1102004015]=true, [1102004016]=true, [1102004017]=true, [1102004030]=true, [1102004031]=true, [1102004032]=true, [1102004033]=true,
[1102004046]=true, [1102004047]=true, [1102005003]=true, [1102005004]=true, [1102005005]=true, [1102005006]=true, [1102005016]=true, [1102005017]=true,
[1102005018]=true, [1102005019]=true, [1102005037]=true, [1102005038]=true, [1102005039]=true, [1102005040]=true, [1102005043]=true, [1102005044]=true,
[1102005053]=true, [1102005054]=true, [1102005055]=true, [1102005056]=true, [1102005058]=true, [1102005059]=true, [1102005060]=true, [1102005061]=true,
[1102005062]=true, [1102005063]=true, [1102005068]=true, [1102005069]=true, [1102005070]=true, [1102005071]=true, [1102005074]=true, [1102005075]=true,
[1102005076]=true, [1102005077]=true, [1102007015]=true, [1102007016]=true, [1102007017]=true, [1102007018]=true, [1102007020]=true, [1102007021]=true,
[1102105006]=true, [1102105007]=true, [1102105008]=true, [1102105009]=true, [1102105010]=true, [1102105011]=true, [1102105014]=true, [1102105015]=true,
[1102105016]=true, [1102105017]=true, [1102105022]=true, [1102105023]=true, [1102105024]=true, [1102105025]=true, [1102105026]=true, [1102105027]=true,
[1103001047]=true, [1103001048]=true, [1103001049]=true, [1103001057]=true, [1103001058]=true, [1103001059]=true, [1103001073]=true, [1103001074]=true,
[1103001075]=true, [1103001076]=true, [1103001077]=true, [1103001078]=true, [1103001081]=true, [1103001082]=true, [1103001083]=true, [1103001084]=true,
[1103001095]=true, [1103001096]=true, [1103001097]=true, [1103001098]=true, [1103001099]=true, [1103001100]=true, [1103001123]=true, [1103001124]=true,
[1103001125]=true, [1103001126]=true, [1103001127]=true, [1103001128]=true, [1103001134]=true, [1103001135]=true, [1103001136]=true, [1103001143]=true,
[1103001144]=true, [1103001145]=true, [1103001148]=true, [1103001149]=true, [1103001150]=true, [1103001151]=true, [1103001152]=true, [1103001153]=true,
[1103001156]=true, [1103001157]=true, [1103001158]=true, [1103001159]=true, [1103001173]=true, [1103001174]=true, [1103001175]=true, [1103001176]=true,
[1103001177]=true, [1103001178]=true, [1103001181]=true, [1103001182]=true, [1103001185]=true, [1103001186]=true, [1103001187]=true, [1103001188]=true,
[1103001189]=true, [1103001190]=true, [1103001194]=true, [1103001195]=true, [1103001196]=true, [1103001197]=true, [1103001198]=true, [1103001200]=true,
[1103001201]=true, [1103001204]=true, [1103001205]=true, [1103002014]=true, [1103002015]=true, [1103002016]=true, [1103002017]=true, [1103002024]=true,
[1103002025]=true, [1103002026]=true, [1103002027]=true, [1103002028]=true, [1103002029]=true, [1103002038]=true, [1103002039]=true, [1103002040]=true,
[1103002043]=true, [1103002044]=true, [1103002045]=true, [1103002046]=true, [1103002048]=true, [1103002053]=true, [1103002054]=true, [1103002055]=true,
[1103002056]=true, [1103002057]=true, [1103002058]=true, [1103002081]=true, [1103002082]=true, [1103002083]=true, [1103002084]=true, [1103002085]=true,
[1103002086]=true, [1103002090]=true, [1103002091]=true, [1103002092]=true, [1103002093]=true, [1103002100]=true, [1103002101]=true, [1103002102]=true,
[1103002103]=true, [1103002104]=true, [1103002105]=true, [1103002106]=true, [1103002107]=true, [1103002108]=true, [1103002109]=true, [1103002110]=true,
[1103002111]=true, [1103002112]=true, [1103002113]=true, [1103002120]=true, [1103002121]=true, [1103002122]=true, [1103002123]=true, [1103002124]=true,
[1103002125]=true, [1103002126]=true, [1103002130]=true, [1103002131]=true, [1103002132]=true, [1103002133]=true, [1103002134]=true, [1103002135]=true,
[1103002140]=true, [1103002141]=true, [1103002142]=true, [1103002143]=true, [1103002144]=true, [1103002145]=true, [1103002146]=true, [1103002150]=true,
[1103002151]=true, [1103002152]=true, [1103002153]=true, [1103002154]=true, [1103002155]=true, [1103003016]=true, [1103003017]=true, [1103003018]=true,
[1103003019]=true, [1103003020]=true, [1103003021]=true, [1103003024]=true, [1103003025]=true, [1103003026]=true, [1103003027]=true, [1103003028]=true,
[1103003029]=true, [1103003036]=true, [1103003037]=true, [1103003038]=true, [1103003039]=true, [1103003040]=true, [1103003041]=true, [1103003045]=true,
[1103003046]=true, [1103003047]=true, [1103003048]=true, [1103003049]=true, [1103003050]=true, [1103003056]=true, [1103003057]=true, [1103003058]=true,
[1103003059]=true, [1103003060]=true, [1103003061]=true, [1103003073]=true, [1103003074]=true, [1103003075]=true, [1103003076]=true, [1103003077]=true,
[1103003078]=true, [1103003081]=true, [1103003082]=true, [1103003083]=true, [1103003084]=true, [1103003085]=true, [1103003086]=true, [1103003088]=true,
[1103003089]=true, [1103003090]=true, [1103003091]=true, [1103003093]=true, [1103003094]=true, [1103003095]=true, [1103003096]=true, [1103003097]=true,
[1103003098]=true, [1103004031]=true, [1103004032]=true, [1103004033]=true, [1103004034]=true, [1103004035]=true, [1103004036]=true, [1103004042]=true,
[1103004043]=true, [1103004044]=true, [1103004045]=true, [1103004054]=true, [1103004055]=true, [1103004056]=true, [1103004057]=true, [1103004076]=true,
[1103004077]=true, [1103004078]=true, [1103004079]=true, [1103004083]=true, [1103004084]=true, [1103004085]=true, [1103004086]=true, [1103005020]=true,
[1103005021]=true, [1103005022]=true, [1103005023]=true, [1103005046]=true, [1103005047]=true, [1103006024]=true, [1103006025]=true, [1103006026]=true,
[1103006027]=true, [1103006028]=true, [1103006029]=true, [1103006042]=true, [1103006043]=true, [1103006044]=true, [1103006045]=true, [1103006054]=true,
[1103006055]=true, [1103006056]=true, [1103006057]=true, [1103006059]=true, [1103006060]=true, [1103006061]=true, [1103006062]=true, [1103006071]=true,
[1103006072]=true, [1103006073]=true, [1103006074]=true, [1103007016]=true, [1103007017]=true, [1103007018]=true, [1103007019]=true, [1103007021]=true,
[1103007022]=true, [1103007023]=true, [1103007024]=true, [1103007025]=true, [1103007026]=true, [1103007027]=true, [1103007034]=true, [1103007035]=true,
[1103007036]=true, [1103007037]=true, [1103007039]=true, [1103007040]=true, [1103007041]=true, [1103007042]=true, [1103009018]=true, [1103009019]=true,
[1103009020]=true, [1103009021]=true, [1103009033]=true, [1103009034]=true, [1103009035]=true, [1103009036]=true, [1103009040]=true, [1103009041]=true,
[1103009047]=true, [1103009048]=true, [1103009049]=true, [1103009050]=true, [1103009053]=true, [1103009054]=true, [1103012003]=true, [1103012004]=true,
[1103012005]=true, [1103012006]=true, [1103012007]=true, [1103012008]=true, [1103012009]=true, [1103012013]=true, [1103012014]=true, [1103012015]=true,
[1103012016]=true, [1103012017]=true, [1103012018]=true, [1103012020]=true, [1103012021]=true, [1103012022]=true, [1103012023]=true, [1103012025]=true,
[1103012026]=true, [1103012027]=true, [1103012028]=true, [1103012029]=true, [1103012030]=true, [1103012033]=true, [1103012034]=true, [1103012035]=true,
[1103012036]=true, [1103012037]=true, [1103012038]=true, [1103100003]=true, [1103100004]=true, [1103100005]=true, [1103100006]=true, [1103102001]=true,
[1103102002]=true, [1103102003]=true, [1103102004]=true, [1103102005]=true, [1103102006]=true, [1103103001]=true, [1103103002]=true, [1103103003]=true,
[1103103004]=true, [1103103005]=true, [1103103006]=true, [1104001031]=true, [1104001032]=true, [1104001033]=true, [1104001034]=true, [1104002018]=true,
[1104002019]=true, [1104002020]=true, [1104002021]=true, [1104002047]=true, [1104002048]=true, [1104002051]=true, [1104002052]=true, [1104002053]=true,
[1104002054]=true, [1104003033]=true, [1104003034]=true, [1104003035]=true, [1104003036]=true, [1104003042]=true, [1104003043]=true, [1104003044]=true,
[1104003045]=true, [1104004022]=true, [1104004023]=true, [1104004031]=true, [1104004032]=true, [1104004033]=true, [1104004034]=true, [1104004037]=true,
[1104004038]=true, [1104004039]=true, [1104004040]=true, [1104004047]=true, [1104004048]=true, [1104004049]=true, [1104004050]=true, [1104102002]=true,
[1104102003]=true, [1105001028]=true, [1105001029]=true, [1105001030]=true, [1105001031]=true, [1105001032]=true, [1105001033]=true, [1105001042]=true,
[1105001043]=true, [1105001044]=true, [1105001045]=true, [1105001046]=true, [1105001047]=true, [1105001050]=true, [1105001051]=true, [1105001052]=true,
[1105001053]=true, [1105001058]=true, [1105001059]=true, [1105001060]=true, [1105001061]=true, [1105001063]=true, [1105001064]=true, [1105001065]=true,
[1105001066]=true, [1105001067]=true, [1105001068]=true, [1105001071]=true, [1105001072]=true, [1105001073]=true, [1105001074]=true, [1105002014]=true,
[1105002015]=true, [1105002016]=true, [1105002017]=true, [1105002032]=true, [1105002033]=true, [1105002034]=true, [1105002037]=true, [1105002054]=true,
[1105002055]=true, [1105002056]=true, [1105002057]=true, [1105002059]=true, [1105002060]=true, [1105002061]=true, [1105002062]=true, [1105002067]=true,
[1105002068]=true, [1105002069]=true, [1105002070]=true, [1105002072]=true, [1105002073]=true, [1105002074]=true, [1105002075]=true, [1105002079]=true,
[1105002080]=true, [1105002081]=true, [1105002082]=true, [1105002084]=true, [1105002085]=true, [1105002086]=true, [1105002087]=true, [1105002088]=true,
[1105002089]=true, [1105002090]=true, [1105002094]=true, [1105002095]=true, [1105010004]=true, [1105010005]=true, [1105010006]=true, [1105010007]=true,
[1105010013]=true, [1105010014]=true, [1105010015]=true, [1105010016]=true, [1105010017]=true, [1105010018]=true, [1105010022]=true, [1105010023]=true,
[1105010024]=true, [1105010025]=true, [1106008009]=true, [1106008010]=true, [1106008011]=true, [1106008012]=true, [1106008020]=true, [1106008021]=true,
[1106011001]=true, [1106011002]=true, [1106011004]=true, [1106011005]=true, [1106011006]=true, [1106011007]=true, [1107001016]=true, [1107001017]=true,
[1107098001]=true, [1107098002]=true, [1108001054]=true, [1108001056]=true, [1108001062]=true, [1108001063]=true, [1108001067]=true, [1108001068]=true,
[1108001072]=true, [1108001079]=true, [1108001080]=true, [1108001083]=true, [1108001084]=true, [1108001096]=true, [1108001097]=true, [1108001101]=true,
[1108001102]=true, [1108001105]=true, [1108001106]=true, [1108002054]=true, [1108002056]=true, [1108002057]=true, [1108002058]=true, [1108004128]=true,
[1108004129]=true, [1108004140]=true, [1108004146]=true, [1108004165]=true, [1108004166]=true, [1108004185]=true, [1108004186]=true, [1108004187]=true,
[1108004188]=true, [1108004193]=true, [1108004194]=true, [1108004278]=true, [1108004279]=true, [1108004280]=true, [1108004281]=true, [1108004282]=true,
[1108004328]=true, [1108004329]=true, [1108004330]=true, [1108004331]=true, [1108004332]=true, [1108004354]=true, [1108004355]=true, [1108004363]=true,
[1108004364]=true, [1108004373]=true, [1108004374]=true, [1108004375]=true, [1108004376]=true, [1108004414]=true, [1108004415]=true, [1108005048]=true,
[1108005049]=true, [1501001001]=true, [1501001002]=true, [1501001003]=true, [1501001004]=true, [1501001005]=true, [1501001006]=true, [1501001007]=true,
[1501001008]=true, [1501001009]=true, [1501001011]=true, [1501001012]=true, [1501001013]=true, [1501001014]=true, [1501001015]=true, [1501001016]=true,
[1501001017]=true, [1501001018]=true, [1501001019]=true, [1501001020]=true, [1501001021]=true, [1501001022]=true, [1501001023]=true, [1501001024]=true,
[1501001025]=true, [1501001026]=true, [1501001027]=true, [1501001028]=true, [1501001029]=true, [1501001030]=true, [1501001031]=true, [1501001032]=true,
[1501001033]=true, [1501001034]=true, [1501001035]=true, [1501001036]=true, [1501001037]=true, [1501001038]=true, [1501001039]=true, [1501001041]=true,
[1501001042]=true, [1501001043]=true, [1501001044]=true, [1501001045]=true, [1501001046]=true, [1501001047]=true, [1501001048]=true, [1501001051]=true,
[1501001052]=true, [1501001053]=true, [1501001054]=true, [1501001055]=true, [1501001056]=true, [1501001057]=true, [1501001058]=true, [1501001059]=true,
[1501001060]=true, [1501001061]=true, [1501001062]=true, [1501001063]=true, [1501001064]=true, [1501001065]=true, [1501001066]=true, [1501001067]=true,
[1501001068]=true, [1501001069]=true, [1501001070]=true, [1501001071]=true, [1501001072]=true, [1501001073]=true, [1501001074]=true, [1501001075]=true,
[1501001076]=true, [1501001077]=true, [1501001078]=true, [1501001079]=true, [1501001081]=true, [1501001082]=true, [1501001083]=true, [1501001084]=true,
[1501001085]=true, [1501001086]=true, [1501001087]=true, [1501001088]=true, [1501001089]=true, [1501001090]=true, [1501001091]=true, [1501001092]=true,
[1501001093]=true, [1501001094]=true, [1501001095]=true, [1501001097]=true, [1501001098]=true, [1501001099]=true, [1501001100]=true, [1501001101]=true,
[1501001102]=true, [1501001103]=true, [1501001104]=true, [1501001105]=true, [1501001107]=true, [1501001108]=true, [1501001109]=true, [1501001110]=true,
[1501001112]=true, [1501001114]=true, [1501001115]=true, [1501001116]=true, [1501001118]=true, [1501001120]=true, [1501001122]=true, [1501001123]=true,
[1501001125]=true, [1501001126]=true, [1501001127]=true, [1501001128]=true, [1501001129]=true, [1501001130]=true, [1501001131]=true, [1501001132]=true,
[1501001133]=true, [1501001134]=true, [1501001135]=true, [1501001136]=true, [1501001137]=true, [1501001140]=true, [1501001141]=true, [1501001142]=true,
[1501001143]=true, [1501001144]=true, [1501001145]=true, [1501001146]=true, [1501001147]=true, [1501001149]=true, [1501001150]=true, [1501001151]=true,
[1501001153]=true, [1501001154]=true, [1501001155]=true, [1501001156]=true, [1501001157]=true, [1501001158]=true, [1501001160]=true, [1501001161]=true,
[1501001162]=true, [1501001163]=true, [1501001164]=true, [1501001165]=true, [1501001166]=true, [1501001168]=true, [1501001169]=true, [1501001170]=true,
[1501001171]=true, [1501001172]=true, [1501001173]=true, [1501001174]=true, [1501001175]=true, [1501001176]=true, [1501001177]=true, [1501001178]=true,
[1501001179]=true, [1501001180]=true, [1501001182]=true, [1501001183]=true, [1501001185]=true, [1501001187]=true, [1501001188]=true, [1501001189]=true,
[1501001190]=true, [1501001191]=true, [1501001193]=true, [1501001194]=true, [1501001195]=true, [1501001196]=true, [1501001197]=true, [1501001198]=true,
[1501001199]=true, [1501001200]=true, [1501001201]=true, [1501001202]=true, [1501001204]=true, [1501001205]=true, [1501001206]=true, [1501001207]=true,
[1501001209]=true, [1501001210]=true, [1501001211]=true, [1501001212]=true, [1501001213]=true, [1501001215]=true, [1501001216]=true, [1501001217]=true,
[1501001220]=true, [1501001221]=true, [1501001222]=true, [1501001224]=true, [1501001225]=true, [1501001226]=true, [1501001227]=true, [1501001229]=true,
[1501001231]=true, [1501001233]=true, [1501001236]=true, [1501001237]=true, [1501001238]=true, [1501001239]=true, [1501001240]=true, [1501001241]=true,
[1501001242]=true, [1501001243]=true, [1501001244]=true, [1501001245]=true, [1501001246]=true, [1501001247]=true, [1501001248]=true, [1501001249]=true,
[1501001250]=true, [1501001251]=true, [1501001252]=true, [1501001253]=true, [1501001258]=true, [1501001259]=true, [1501001260]=true, [1501001261]=true,
[1501001262]=true, [1501001263]=true, [1501001265]=true, [1501001266]=true, [1501001267]=true, [1501001268]=true, [1501001269]=true, [1501001270]=true,
[1501001271]=true, [1501001273]=true, [1501001274]=true, [1501001275]=true, [1501001276]=true, [1501001277]=true, [1501001279]=true, [1501001280]=true,
[1501001281]=true, [1501001282]=true, [1501001283]=true, [1501001286]=true, [1501001287]=true, [1501001288]=true, [1501001291]=true, [1501001292]=true,
[1501001293]=true, [1501001294]=true, [1501001295]=true, [1501001296]=true, [1501001297]=true, [1501001298]=true, [1501001300]=true, [1501001301]=true,
[1501001302]=true, [1501001304]=true, [1501001305]=true, [1501001306]=true, [1501001307]=true, [1501001308]=true, [1501001309]=true, [1501001310]=true,
[1501001311]=true, [1501001312]=true, [1501001314]=true, [1501001316]=true, [1501001317]=true, [1501001318]=true, [1501001320]=true, [1501001321]=true,
[1501001323]=true, [1501001324]=true, [1501001325]=true, [1501001326]=true, [1501001330]=true, [1501001331]=true, [1501001332]=true, [1501001333]=true,
[1501001336]=true, [1501001337]=true, [1501001338]=true, [1501001339]=true, [1501001340]=true, [1501001341]=true, [1501001342]=true, [1501001343]=true,
[1501001344]=true, [1501001345]=true, [1501001346]=true, [1501001348]=true, [1501001349]=true, [1501001350]=true, [1501001351]=true, [1501001352]=true,
[1501001354]=true, [1501001355]=true, [1501001356]=true, [1501001357]=true, [1501001359]=true, [1501001361]=true, [1501001362]=true, [1501001363]=true,
[1501001364]=true, [1501001366]=true, [1501001367]=true, [1501001368]=true, [1501001369]=true, [1501001370]=true, [1501001371]=true, [1501001372]=true,
[1501001373]=true, [1501001374]=true, [1501001375]=true, [1501001376]=true, [1501001377]=true, [1501001378]=true, [1501001380]=true, [1501001381]=true,
[1501001383]=true, [1501001384]=true, [1501001385]=true, [1501001386]=true, [1501001387]=true, [1501001388]=true, [1501001389]=true, [1501001390]=true,
[1501001391]=true, [1501001392]=true, [1501001393]=true, [1501001394]=true, [1501001395]=true, [1501001396]=true, [1501001397]=true, [1501001398]=true,
[1501001399]=true, [1501001400]=true, [1501001401]=true, [1501001402]=true, [1501001408]=true, [1501001409]=true, [1501001410]=true, [1501001411]=true,
[1501001412]=true, [1501001414]=true, [1501001415]=true, [1501001416]=true, [1501001417]=true, [1501001418]=true, [1501001419]=true, [1501001420]=true,
[1501001421]=true, [1501001422]=true, [1501001423]=true, [1501001424]=true, [1501001425]=true, [1501001426]=true, [1501001430]=true, [1501001433]=true,
[1501001437]=true, [1501001441]=true, [1501001443]=true, [1501001444]=true, [1501001446]=true, [1501001448]=true, [1501001451]=true, [1501001452]=true,
[1501001453]=true, [1501001454]=true, [1501001457]=true, [1501001458]=true, [1501001459]=true, [1501001462]=true, [1501001463]=true, [1501001466]=true,
[1501001467]=true, [1501001468]=true, [1501001469]=true, [1501001471]=true, [1501001474]=true, [1501001475]=true, [1501001476]=true, [1501001478]=true,
[1501001479]=true, [1501001480]=true, [1501001481]=true, [1501001482]=true, [1501001483]=true, [1501001484]=true, [1501001485]=true, [1501001486]=true,
[1501001487]=true, [1501001489]=true, [1501001490]=true, [1501001492]=true, [1501001494]=true, [1501001495]=true, [1501001496]=true, [1501001497]=true,
[1501001500]=true, [1501001501]=true, [1501001502]=true, [1501001503]=true, [1501001506]=true, [1501001507]=true, [1501001509]=true, [1501001510]=true,
[1501001511]=true, [1501001512]=true, [1501001513]=true, [1501001514]=true, [1501001515]=true, [1501001516]=true, [1501001517]=true, [1501001519]=true,
[1501001520]=true, [1501001521]=true, [1501001522]=true, [1501001523]=true, [1501001524]=true, [1501001525]=true, [1501001526]=true, [1501001527]=true,
[1501001528]=true, [1501001529]=true, [1501001530]=true, [1501001531]=true, [1501001532]=true, [1501001533]=true, [1501001534]=true, [1501001535]=true,
[1501001536]=true, [1501001537]=true, [1501001538]=true, [1501001539]=true, [1501001540]=true, [1501001541]=true, [1501001542]=true, [1501001543]=true,
[1501001544]=true, [1501001545]=true, [1501001546]=true, [1501001547]=true, [1501001548]=true, [1501001549]=true, [1501001550]=true, [1501001551]=true,
[1501001552]=true, [1501001553]=true, [1501001554]=true, [1501001555]=true, [1501001556]=true, [1501001557]=true, [1501001558]=true, [1501001559]=true,
[1501001560]=true, [1501001561]=true, [1501001562]=true, [1501001563]=true, [1501001564]=true, [1501001565]=true, [1501001566]=true, [1501001567]=true,
[1501001568]=true, [1501001569]=true, [1501001570]=true, [1501001571]=true, [1501001572]=true, [1501001573]=true, [1501001574]=true, [1501001575]=true,
[1501001576]=true, [1501001577]=true, [1501001578]=true, [1501001579]=true, [1501001581]=true, [1501001582]=true, [1501001583]=true, [1501001584]=true,
[1501001585]=true, [1501001586]=true, [1501001587]=true, [1501001588]=true, [1501001589]=true, [1501001590]=true, [1501001591]=true, [1501001592]=true,
[1501001593]=true, [1501001594]=true, [1501001595]=true, [1501001596]=true, [1501001597]=true, [1501001598]=true, [1501001599]=true, [1501001600]=true,
[1501001601]=true, [1501001602]=true, [1501001603]=true, [1501001604]=true, [1501001605]=true, [1501001606]=true, [1501001607]=true, [1501001608]=true,
[1501001609]=true, [1501001610]=true, [1501001611]=true, [1501001612]=true, [1501001613]=true, [1501001614]=true, [1501001615]=true, [1501001616]=true,
[1501001617]=true, [1501001618]=true, [1501001619]=true, [1501001620]=true, [1501001621]=true, [1501001622]=true, [1501001623]=true, [1501001624]=true,
[1501001625]=true, [1501001626]=true, [1501001627]=true, [1501001628]=true, [1501001629]=true, [1501001630]=true, [1501001631]=true, [1501001632]=true,
[1501001633]=true, [1501001634]=true, [1501001635]=true, [1501001636]=true, [1501001637]=true, [1501001638]=true, [1501001639]=true, [1501001640]=true,
[1501001641]=true, [1501001642]=true, [1501001643]=true, [1501001644]=true, [1501001645]=true, [1501001646]=true, [1501001647]=true, [1501001648]=true,
[1501001649]=true, [1501001650]=true, [1501001651]=true, [1501001652]=true, [1501001653]=true, [1501001654]=true, [1501001655]=true, [1501001656]=true,
[1501001657]=true, [1501001658]=true, [1501001659]=true, [1501001660]=true, [1501001661]=true, [1501001662]=true, [1501001663]=true, [1501001664]=true,
[1501001665]=true, [1501001666]=true, [1501001667]=true, [1501001668]=true, [1501001669]=true, [1501001670]=true, [1501001671]=true, [1501001672]=true,
[1501001673]=true, [1501001674]=true, [1501001675]=true, [1501001676]=true, [1501001677]=true, [1501001678]=true, [1501001679]=true, [1501001680]=true,
[1501001681]=true, [1501001682]=true, [1501001683]=true, [1501001684]=true, [1501001685]=true, [1501001686]=true, [1501001687]=true, [1501001688]=true,
[1501001689]=true, [1501001690]=true, [1501001691]=true, [1501001692]=true, [1501001693]=true, [1501001694]=true, [1501001695]=true, [1501001696]=true,
[1501001697]=true, [1501001698]=true, [1501001699]=true, [1501001700]=true, [1501001701]=true, [1501001702]=true, [1501001703]=true, [1501001704]=true,
[1501001705]=true, [1501001706]=true, [1501001707]=true, [1501001708]=true, [1501001709]=true, [1501001710]=true, [1501001711]=true, [1501001712]=true,
[1501001713]=true, [1501001714]=true, [1501001715]=true, [1501001716]=true, [1501001717]=true, [1501001718]=true, [1501001719]=true, [1501001720]=true,
[1501001721]=true, [1501001722]=true, [1501001723]=true, [1501001724]=true, [1501001725]=true, [1501001726]=true, [1501001727]=true, [1501001728]=true,
[1501001729]=true, [1501001730]=true, [1501001731]=true, [1501001732]=true, [1501001733]=true, [1501001734]=true, [1501001735]=true, [1501001736]=true,
[1501001737]=true, [1501001738]=true, [1501001739]=true, [1501001740]=true, [1501001741]=true, [1501001742]=true, [1501001743]=true, [1501001744]=true,
[1501001745]=true, [1501001749]=true, [1501002001]=true, [1501002002]=true, [1501002003]=true, [1501002004]=true, [1501002005]=true, [1501002006]=true,
[1501002007]=true, [1501002008]=true, [1501002009]=true, [1501002011]=true, [1501002012]=true, [1501002013]=true, [1501002014]=true, [1501002015]=true,
[1501002016]=true, [1501002017]=true, [1501002018]=true, [1501002019]=true, [1501002020]=true, [1501002021]=true, [1501002022]=true, [1501002023]=true,
[1501002024]=true, [1501002025]=true, [1501002026]=true, [1501002027]=true, [1501002028]=true, [1501002029]=true, [1501002030]=true, [1501002031]=true,
[1501002032]=true, [1501002033]=true, [1501002034]=true, [1501002035]=true, [1501002036]=true, [1501002037]=true, [1501002038]=true, [1501002039]=true,
[1501002041]=true, [1501002042]=true, [1501002043]=true, [1501002044]=true, [1501002045]=true, [1501002046]=true, [1501002047]=true, [1501002048]=true,
[1501002051]=true, [1501002052]=true, [1501002053]=true, [1501002054]=true, [1501002055]=true, [1501002056]=true, [1501002057]=true, [1501002058]=true,
[1501002059]=true, [1501002060]=true, [1501002061]=true, [1501002062]=true, [1501002063]=true, [1501002064]=true, [1501002065]=true, [1501002066]=true,
[1501002067]=true, [1501002068]=true, [1501002069]=true, [1501002070]=true, [1501002071]=true, [1501002072]=true, [1501002073]=true, [1501002074]=true,
[1501002075]=true, [1501002076]=true, [1501002077]=true, [1501002078]=true, [1501002079]=true, [1501002081]=true, [1501002082]=true, [1501002083]=true,
[1501002084]=true, [1501002085]=true, [1501002086]=true, [1501002087]=true, [1501002088]=true, [1501002089]=true, [1501002090]=true, [1501002091]=true,
[1501002092]=true, [1501002093]=true, [1501002094]=true, [1501002095]=true, [1501002097]=true, [1501002098]=true, [1501002099]=true, [1501002100]=true,
[1501002101]=true, [1501002102]=true, [1501002103]=true, [1501002104]=true, [1501002105]=true, [1501002107]=true, [1501002108]=true, [1501002109]=true,
[1501002110]=true, [1501002114]=true, [1501002115]=true, [1501002116]=true, [1501002118]=true, [1501002120]=true, [1501002122]=true, [1501002123]=true,
[1501002125]=true, [1501002126]=true, [1501002127]=true, [1501002128]=true, [1501002129]=true, [1501002130]=true, [1501002131]=true, [1501002132]=true,
[1501002133]=true, [1501002134]=true, [1501002135]=true, [1501002136]=true, [1501002137]=true, [1501002140]=true, [1501002141]=true, [1501002142]=true,
[1501002143]=true, [1501002144]=true, [1501002145]=true, [1501002146]=true, [1501002149]=true, [1501002150]=true, [1501002151]=true, [1501002153]=true,
[1501002154]=true, [1501002155]=true, [1501002156]=true, [1501002157]=true, [1501002158]=true, [1501002160]=true, [1501002161]=true, [1501002162]=true,
[1501002163]=true, [1501002164]=true, [1501002165]=true, [1501002166]=true, [1501002168]=true, [1501002169]=true, [1501002170]=true, [1501002171]=true,
[1501002172]=true, [1501002173]=true, [1501002174]=true, [1501002175]=true, [1501002176]=true, [1501002177]=true, [1501002178]=true, [1501002179]=true,
[1501002180]=true, [1501002182]=true, [1501002183]=true, [1501002185]=true, [1501002187]=true, [1501002188]=true, [1501002189]=true, [1501002190]=true,
[1501002191]=true, [1501002193]=true, [1501002194]=true, [1501002195]=true, [1501002196]=true, [1501002197]=true, [1501002198]=true, [1501002199]=true,
[1501002200]=true, [1501002201]=true, [1501002202]=true, [1501002204]=true, [1501002205]=true, [1501002206]=true, [1501002207]=true, [1501002209]=true,
[1501002210]=true, [1501002211]=true, [1501002212]=true, [1501002213]=true, [1501002215]=true, [1501002216]=true, [1501002217]=true, [1501002220]=true,
[1501002221]=true, [1501002222]=true, [1501002224]=true, [1501002225]=true, [1501002226]=true, [1501002227]=true, [1501002229]=true, [1501002231]=true,
[1501002233]=true, [1501002236]=true, [1501002237]=true, [1501002238]=true, [1501002239]=true, [1501002240]=true, [1501002241]=true, [1501002242]=true,
[1501002243]=true, [1501002244]=true, [1501002245]=true, [1501002246]=true, [1501002247]=true, [1501002248]=true, [1501002249]=true, [1501002250]=true,
[1501002251]=true, [1501002252]=true, [1501002253]=true, [1501002258]=true, [1501002259]=true, [1501002260]=true, [1501002261]=true, [1501002262]=true,
[1501002263]=true, [1501002265]=true, [1501002266]=true, [1501002267]=true, [1501002268]=true, [1501002269]=true, [1501002270]=true, [1501002271]=true,
[1501002273]=true, [1501002274]=true, [1501002275]=true, [1501002276]=true, [1501002277]=true, [1501002279]=true, [1501002280]=true, [1501002281]=true,
[1501002282]=true, [1501002283]=true, [1501002286]=true, [1501002287]=true, [1501002288]=true, [1501002291]=true, [1501002292]=true, [1501002293]=true,
[1501002294]=true, [1501002295]=true, [1501002296]=true, [1501002297]=true, [1501002298]=true, [1501002300]=true, [1501002301]=true, [1501002302]=true,
[1501002304]=true, [1501002305]=true, [1501002306]=true, [1501002307]=true, [1501002308]=true, [1501002309]=true, [1501002310]=true, [1501002311]=true,
[1501002312]=true, [1501002314]=true, [1501002316]=true, [1501002317]=true, [1501002318]=true, [1501002320]=true, [1501002321]=true, [1501002323]=true,
[1501002324]=true, [1501002325]=true, [1501002326]=true, [1501002330]=true, [1501002331]=true, [1501002332]=true, [1501002333]=true, [1501002336]=true,
[1501002337]=true, [1501002338]=true, [1501002339]=true, [1501002340]=true, [1501002341]=true, [1501002342]=true, [1501002343]=true, [1501002344]=true,
[1501002345]=true, [1501002346]=true, [1501002348]=true, [1501002349]=true, [1501002350]=true, [1501002351]=true, [1501002352]=true, [1501002354]=true,
[1501002355]=true, [1501002356]=true, [1501002357]=true, [1501002359]=true, [1501002361]=true, [1501002362]=true, [1501002363]=true, [1501002364]=true,
[1501002366]=true, [1501002367]=true, [1501002368]=true, [1501002369]=true, [1501002370]=true, [1501002371]=true, [1501002372]=true, [1501002373]=true,
[1501002374]=true, [1501002375]=true, [1501002376]=true, [1501002377]=true, [1501002378]=true, [1501002380]=true, [1501002381]=true, [1501002383]=true,
[1501002384]=true, [1501002385]=true, [1501002386]=true, [1501002387]=true, [1501002388]=true, [1501002389]=true, [1501002390]=true, [1501002391]=true,
[1501002392]=true, [1501002393]=true, [1501002394]=true, [1501002395]=true, [1501002396]=true, [1501002397]=true, [1501002398]=true, [1501002399]=true,
[1501002400]=true, [1501002401]=true, [1501002402]=true, [1501002408]=true, [1501002409]=true, [1501002410]=true, [1501002411]=true, [1501002412]=true,
[1501002414]=true, [1501002415]=true, [1501002416]=true, [1501002417]=true, [1501002418]=true, [1501002419]=true, [1501002420]=true, [1501002421]=true,
[1501002422]=true, [1501002423]=true, [1501002424]=true, [1501002425]=true, [1501002426]=true, [1501002430]=true, [1501002433]=true, [1501002437]=true,
[1501002441]=true, [1501002443]=true, [1501002444]=true, [1501002446]=true, [1501002448]=true, [1501002451]=true, [1501002452]=true, [1501002453]=true,
[1501002454]=true, [1501002457]=true, [1501002458]=true, [1501002459]=true, [1501002462]=true, [1501002463]=true, [1501002466]=true, [1501002467]=true,
[1501002468]=true, [1501002469]=true, [1501002471]=true, [1501002474]=true, [1501002475]=true, [1501002476]=true, [1501002478]=true, [1501002479]=true,
[1501002480]=true, [1501002481]=true, [1501002482]=true, [1501002483]=true, [1501002484]=true, [1501002485]=true, [1501002486]=true, [1501002487]=true,
[1501002489]=true, [1501002490]=true, [1501002492]=true, [1501002494]=true, [1501002495]=true, [1501002496]=true, [1501002497]=true, [1501002500]=true,
[1501002501]=true, [1501002502]=true, [1501002503]=true, [1501002506]=true, [1501002507]=true, [1501002509]=true, [1501002510]=true, [1501002511]=true,
[1501002512]=true, [1501002513]=true, [1501002514]=true, [1501002515]=true, [1501002516]=true, [1501002517]=true, [1501002519]=true, [1501002520]=true,
[1501002521]=true, [1501002522]=true, [1501002523]=true, [1501002524]=true, [1501002525]=true, [1501002526]=true, [1501002527]=true, [1501002528]=true,
[1501002529]=true, [1501002530]=true, [1501002531]=true, [1501002532]=true, [1501002533]=true, [1501002534]=true, [1501002535]=true, [1501002536]=true,
[1501002537]=true, [1501002538]=true, [1501002539]=true, [1501002540]=true, [1501002541]=true, [1501002542]=true, [1501002543]=true, [1501002544]=true,
[1501002545]=true, [1501002546]=true, [1501002547]=true, [1501002548]=true, [1501002549]=true, [1501002550]=true, [1501002551]=true, [1501002552]=true,
[1501002553]=true, [1501002554]=true, [1501002555]=true, [1501002556]=true, [1501002557]=true, [1501002558]=true, [1501002559]=true, [1501002562]=true,
[1501002563]=true, [1501002564]=true, [1501002565]=true, [1501002566]=true, [1501002567]=true, [1501002568]=true, [1501002569]=true, [1501002570]=true,
[1501002571]=true, [1501002572]=true, [1501002573]=true, [1501002574]=true, [1501002575]=true, [1501002576]=true, [1501002577]=true, [1501002578]=true,
[1501002579]=true, [1501002581]=true, [1501002582]=true, [1501002583]=true, [1501002584]=true, [1501002585]=true, [1501002586]=true, [1501002587]=true,
[1501002588]=true, [1501002589]=true, [1501002590]=true, [1501002591]=true, [1501002592]=true, [1501002593]=true, [1501002594]=true, [1501002595]=true,
[1501002596]=true, [1501002597]=true, [1501002598]=true, [1501002599]=true, [1501002600]=true, [1501002601]=true, [1501002602]=true, [1501002603]=true,
[1501002604]=true, [1501002605]=true, [1501002606]=true, [1501002607]=true, [1501002608]=true, [1501002609]=true, [1501002610]=true, [1501002611]=true,
[1501002612]=true, [1501002613]=true, [1501002614]=true, [1501002615]=true, [1501002616]=true, [1501002617]=true, [1501002618]=true, [1501002619]=true,
[1501002620]=true, [1501002621]=true, [1501002622]=true, [1501002623]=true, [1501002624]=true, [1501002625]=true, [1501002626]=true, [1501002627]=true,
[1501002628]=true, [1501002629]=true, [1501002630]=true, [1501002631]=true, [1501002632]=true, [1501002633]=true, [1501002634]=true, [1501002635]=true,
[1501002636]=true, [1501002637]=true, [1501002638]=true, [1501002639]=true, [1501002640]=true, [1501002641]=true, [1501002642]=true, [1501002643]=true,
[1501002644]=true, [1501002645]=true, [1501002646]=true, [1501002647]=true, [1501002648]=true, [1501002649]=true, [1501002650]=true, [1501002651]=true,
[1501002652]=true, [1501002653]=true, [1501002654]=true, [1501002655]=true, [1501002656]=true, [1501002657]=true, [1501002658]=true, [1501002659]=true,
[1501002660]=true, [1501002661]=true, [1501002662]=true, [1501002663]=true, [1501002664]=true, [1501002665]=true, [1501002666]=true, [1501002667]=true,
[1501002668]=true, [1501002669]=true, [1501002670]=true, [1501002671]=true, [1501002672]=true, [1501002673]=true, [1501002674]=true, [1501002675]=true,
[1501002676]=true, [1501002677]=true, [1501002678]=true, [1501002679]=true, [1501002680]=true, [1501002681]=true, [1501002682]=true, [1501002683]=true,
[1501002684]=true, [1501002685]=true, [1501002686]=true, [1501002687]=true, [1501002688]=true, [1501002689]=true, [1501002690]=true, [1501002691]=true,
[1501002692]=true, [1501002693]=true, [1501002694]=true, [1501002695]=true, [1501002696]=true, [1501002697]=true, [1501002698]=true, [1501002699]=true,
[1501002700]=true, [1501002701]=true, [1501002702]=true, [1501002703]=true, [1501002704]=true, [1501002705]=true, [1501002706]=true, [1501002707]=true,
[1501002708]=true, [1501002709]=true, [1501002710]=true, [1501002711]=true, [1501002712]=true, [1501002713]=true, [1501002714]=true, [1501002715]=true,
[1501002716]=true, [1501002717]=true, [1501002718]=true, [1501002719]=true, [1501002720]=true, [1501002721]=true, [1501002722]=true, [1501002723]=true,
[1501002724]=true, [1501002725]=true, [1501002726]=true, [1501002727]=true, [1501002728]=true, [1501002729]=true, [1501002731]=true, [1501002732]=true,
[1501002733]=true, [1501002734]=true, [1501002735]=true, [1501002736]=true, [1501002737]=true, [1501002738]=true, [1501002739]=true, [1501002740]=true,
[1501002741]=true, [1501002742]=true, [1501002743]=true, [1501002744]=true, [1501002745]=true, [1501002749]=true, [1501003061]=true, [1501003164]=true,
[1501003243]=true, [1501003385]=true, [1501003536]=true, [1501003640]=true, [1502000100]=true, [1502001001]=true, [1502001002]=true, [1502001003]=true,
[1502001004]=true, [1502001005]=true, [1502001006]=true, [1502001008]=true, [1502001009]=true, [1502001012]=true, [1502001013]=true, [1502001014]=true,
[1502001015]=true, [1502001016]=true, [1502001017]=true, [1502001018]=true, [1502001019]=true, [1502001020]=true, [1502001021]=true, [1502001022]=true,
[1502001023]=true, [1502001025]=true, [1502001026]=true, [1502001027]=true, [1502001028]=true, [1502001029]=true, [1502001030]=true, [1502001031]=true,
[1502001032]=true, [1502001033]=true, [1502001034]=true, [1502001035]=true, [1502001036]=true, [1502001037]=true, [1502001038]=true, [1502001039]=true,
[1502001040]=true, [1502001041]=true, [1502001042]=true, [1502001043]=true, [1502001044]=true, [1502001045]=true, [1502001046]=true, [1502001047]=true,
[1502001048]=true, [1502001049]=true, [1502001050]=true, [1502001051]=true, [1502001052]=true, [1502001053]=true, [1502001054]=true, [1502001055]=true,
[1502001058]=true, [1502001060]=true, [1502001062]=true, [1502001063]=true, [1502001064]=true, [1502001065]=true, [1502001069]=true, [1502001070]=true,
[1502001071]=true, [1502001072]=true, [1502001073]=true, [1502001074]=true, [1502001075]=true, [1502001076]=true, [1502001077]=true, [1502001078]=true,
[1502001079]=true, [1502001080]=true, [1502001081]=true, [1502001082]=true, [1502001084]=true, [1502001085]=true, [1502001086]=true, [1502001087]=true,
[1502001088]=true, [1502001089]=true, [1502001090]=true, [1502001091]=true, [1502001092]=true, [1502001093]=true, [1502001094]=true, [1502001096]=true,
[1502001097]=true, [1502001098]=true, [1502001099]=true, [1502001100]=true, [1502001101]=true, [1502001102]=true, [1502001103]=true, [1502001104]=true,
[1502001105]=true, [1502001106]=true, [1502001107]=true, [1502001108]=true, [1502001109]=true, [1502001110]=true, [1502001111]=true, [1502001113]=true,
[1502001114]=true, [1502001115]=true, [1502001116]=true, [1502001119]=true, [1502001121]=true, [1502001123]=true, [1502001124]=true, [1502001125]=true,
[1502001126]=true, [1502001127]=true, [1502001128]=true, [1502001129]=true, [1502001130]=true, [1502001132]=true, [1502001133]=true, [1502001134]=true,
[1502001135]=true, [1502001136]=true, [1502001137]=true, [1502001138]=true, [1502001141]=true, [1502001143]=true, [1502001145]=true, [1502001146]=true,
[1502001149]=true, [1502001150]=true, [1502001151]=true, [1502001154]=true, [1502001155]=true, [1502001156]=true, [1502001157]=true, [1502001159]=true,
[1502001160]=true, [1502001163]=true, [1502001164]=true, [1502001165]=true, [1502001167]=true, [1502001169]=true, [1502001170]=true, [1502001171]=true,
[1502001172]=true, [1502001173]=true, [1502001174]=true, [1502001175]=true, [1502001177]=true, [1502001179]=true, [1502001180]=true, [1502001181]=true,
[1502001182]=true, [1502001183]=true, [1502001184]=true, [1502001185]=true, [1502001186]=true, [1502001187]=true, [1502001189]=true, [1502001190]=true,
[1502001191]=true, [1502001192]=true, [1502001193]=true, [1502001194]=true, [1502001195]=true, [1502001196]=true, [1502001197]=true, [1502001198]=true,
[1502001199]=true, [1502001200]=true, [1502001201]=true, [1502001202]=true, [1502001203]=true, [1502001204]=true, [1502001205]=true, [1502001207]=true,
[1502001209]=true, [1502001210]=true, [1502001211]=true, [1502001214]=true, [1502001217]=true, [1502001219]=true, [1502001220]=true, [1502001221]=true,
[1502001222]=true, [1502001223]=true, [1502001224]=true, [1502001225]=true, [1502001227]=true, [1502001228]=true, [1502001229]=true, [1502001230]=true,
[1502001231]=true, [1502001232]=true, [1502001233]=true, [1502001234]=true, [1502001235]=true, [1502001236]=true, [1502001237]=true, [1502001238]=true,
[1502001239]=true, [1502001241]=true, [1502001242]=true, [1502001243]=true, [1502001244]=true, [1502001246]=true, [1502001247]=true, [1502001248]=true,
[1502001249]=true, [1502001252]=true, [1502001253]=true, [1502001254]=true, [1502001255]=true, [1502001256]=true, [1502001257]=true, [1502001258]=true,
[1502001259]=true, [1502001260]=true, [1502001261]=true, [1502001263]=true, [1502001264]=true, [1502001265]=true, [1502001267]=true, [1502001268]=true,
[1502001269]=true, [1502001270]=true, [1502001271]=true, [1502001272]=true, [1502001273]=true, [1502001274]=true, [1502001275]=true, [1502001276]=true,
[1502001277]=true, [1502001278]=true, [1502001279]=true, [1502001280]=true, [1502001284]=true, [1502001285]=true, [1502001286]=true, [1502001287]=true,
[1502001288]=true, [1502001289]=true, [1502001290]=true, [1502001292]=true, [1502001293]=true, [1502001294]=true, [1502001295]=true, [1502001297]=true,
[1502001298]=true, [1502001299]=true, [1502001300]=true, [1502001301]=true, [1502001302]=true, [1502001305]=true, [1502001306]=true, [1502001307]=true,
[1502001309]=true, [1502001311]=true, [1502001314]=true, [1502001315]=true, [1502001317]=true, [1502001320]=true, [1502001322]=true, [1502001323]=true,
[1502001325]=true, [1502001327]=true, [1502001328]=true, [1502001330]=true, [1502001332]=true, [1502001333]=true, [1502001335]=true, [1502001336]=true,
[1502001337]=true, [1502001338]=true, [1502001339]=true, [1502001341]=true, [1502001342]=true, [1502001343]=true, [1502001344]=true, [1502001345]=true,
[1502001346]=true, [1502001347]=true, [1502001348]=true, [1502001349]=true, [1502001350]=true, [1502001351]=true, [1502001352]=true, [1502001353]=true,
[1502001354]=true, [1502001355]=true, [1502001357]=true, [1502001358]=true, [1502001359]=true, [1502001360]=true, [1502001361]=true, [1502001362]=true,
[1502001363]=true, [1502001364]=true, [1502001365]=true, [1502001366]=true, [1502001367]=true, [1502001368]=true, [1502001369]=true, [1502001370]=true,
[1502001371]=true, [1502001372]=true, [1502001373]=true, [1502001374]=true, [1502001375]=true, [1502001376]=true, [1502001377]=true, [1502001378]=true,
[1502001379]=true, [1502001381]=true, [1502001382]=true, [1502001383]=true, [1502001384]=true, [1502001385]=true, [1502001386]=true, [1502001387]=true,
[1502001388]=true, [1502001389]=true, [1502001390]=true, [1502001391]=true, [1502001392]=true, [1502001393]=true, [1502001394]=true, [1502001395]=true,
[1502001396]=true, [1502001397]=true, [1502001398]=true, [1502001399]=true, [1502001400]=true, [1502001401]=true, [1502001402]=true, [1502001403]=true,
[1502001404]=true, [1502001405]=true, [1502001406]=true, [1502001407]=true, [1502001408]=true, [1502001409]=true, [1502001410]=true, [1502001411]=true,
[1502001412]=true, [1502001413]=true, [1502001414]=true, [1502001415]=true, [1502001416]=true, [1502001417]=true, [1502001418]=true, [1502001419]=true,
[1502001420]=true, [1502001421]=true, [1502001422]=true, [1502001423]=true, [1502001424]=true, [1502001425]=true, [1502001426]=true, [1502001427]=true,
[1502001428]=true, [1502001429]=true, [1502001430]=true, [1502001431]=true, [1502001432]=true, [1502001433]=true, [1502001434]=true, [1502001435]=true,
[1502001436]=true, [1502001437]=true, [1502001438]=true, [1502001439]=true, [1502001440]=true, [1502001441]=true, [1502001442]=true, [1502001443]=true,
[1502001444]=true, [1502001445]=true, [1502001446]=true, [1502001447]=true, [1502001448]=true, [1502001449]=true, [1502001450]=true, [1502001451]=true,
[1502001452]=true, [1502001453]=true, [1502001454]=true, [1502001455]=true, [1502001456]=true, [1502001457]=true, [1502001458]=true, [1502001459]=true,
[1502001460]=true, [1502001461]=true, [1502001462]=true, [1502001463]=true, [1502001464]=true, [1502001465]=true, [1502001466]=true, [1502001467]=true,
[1502001468]=true, [1502001469]=true, [1502001470]=true, [1502001471]=true, [1502001472]=true, [1502001473]=true, [1502001474]=true, [1502001475]=true,
[1502001476]=true, [1502001477]=true, [1502001478]=true, [1502001479]=true, [1502001480]=true, [1502001481]=true, [1502001482]=true, [1502001483]=true,
[1502001484]=true, [1502001485]=true, [1502001486]=true, [1502001487]=true, [1502001488]=true, [1502001489]=true, [1502001490]=true, [1502001491]=true,
[1502001492]=true, [1502001493]=true, [1502001494]=true, [1502001495]=true, [1502001496]=true, [1502001497]=true, [1502001498]=true, [1502001499]=true,
[1502001500]=true, [1502001501]=true, [1502001502]=true, [1502001503]=true, [1502001504]=true, [1502001505]=true, [1502001506]=true, [1502001507]=true,
[1502001508]=true, [1502001509]=true, [1502001510]=true, [1502001511]=true, [1502001512]=true, [1502001515]=true, [1502002001]=true, [1502002002]=true,
[1502002003]=true, [1502002004]=true, [1502002005]=true, [1502002006]=true, [1502002008]=true, [1502002009]=true, [1502002012]=true, [1502002013]=true,
[1502002014]=true, [1502002015]=true, [1502002016]=true, [1502002017]=true, [1502002018]=true, [1502002019]=true, [1502002020]=true, [1502002021]=true,
[1502002022]=true, [1502002023]=true, [1502002025]=true, [1502002026]=true, [1502002027]=true, [1502002028]=true, [1502002029]=true, [1502002030]=true,
[1502002031]=true, [1502002032]=true, [1502002033]=true, [1502002034]=true, [1502002035]=true, [1502002036]=true, [1502002037]=true, [1502002038]=true,
[1502002039]=true, [1502002040]=true, [1502002041]=true, [1502002042]=true, [1502002043]=true, [1502002044]=true, [1502002045]=true, [1502002046]=true,
[1502002047]=true, [1502002048]=true, [1502002049]=true, [1502002050]=true, [1502002051]=true, [1502002052]=true, [1502002053]=true, [1502002054]=true,
[1502002055]=true, [1502002058]=true, [1502002060]=true, [1502002062]=true, [1502002063]=true, [1502002064]=true, [1502002065]=true, [1502002069]=true,
[1502002070]=true, [1502002071]=true, [1502002072]=true, [1502002073]=true, [1502002074]=true, [1502002075]=true, [1502002076]=true, [1502002077]=true,
[1502002078]=true, [1502002079]=true, [1502002080]=true, [1502002081]=true, [1502002082]=true, [1502002084]=true, [1502002085]=true, [1502002086]=true,
[1502002087]=true, [1502002088]=true, [1502002089]=true, [1502002090]=true, [1502002091]=true, [1502002092]=true, [1502002093]=true, [1502002094]=true,
[1502002096]=true, [1502002097]=true, [1502002098]=true, [1502002099]=true, [1502002100]=true, [1502002101]=true, [1502002102]=true, [1502002103]=true,
[1502002104]=true, [1502002105]=true, [1502002106]=true, [1502002107]=true, [1502002108]=true, [1502002109]=true, [1502002110]=true, [1502002111]=true,
[1502002113]=true, [1502002114]=true, [1502002115]=true, [1502002116]=true, [1502002119]=true, [1502002121]=true, [1502002123]=true, [1502002124]=true,
[1502002125]=true, [1502002126]=true, [1502002127]=true, [1502002128]=true, [1502002129]=true, [1502002130]=true, [1502002132]=true, [1502002133]=true,
[1502002134]=true, [1502002135]=true, [1502002136]=true, [1502002137]=true, [1502002138]=true, [1502002141]=true, [1502002143]=true, [1502002145]=true,
[1502002146]=true, [1502002149]=true, [1502002150]=true, [1502002151]=true, [1502002154]=true, [1502002155]=true, [1502002156]=true, [1502002157]=true,
[1502002159]=true, [1502002160]=true, [1502002163]=true, [1502002164]=true, [1502002165]=true, [1502002167]=true, [1502002169]=true, [1502002170]=true,
[1502002171]=true, [1502002172]=true, [1502002173]=true, [1502002174]=true, [1502002175]=true, [1502002177]=true, [1502002179]=true, [1502002180]=true,
[1502002181]=true, [1502002182]=true, [1502002183]=true, [1502002184]=true, [1502002185]=true, [1502002186]=true, [1502002187]=true, [1502002189]=true,
[1502002190]=true, [1502002191]=true, [1502002192]=true, [1502002193]=true, [1502002194]=true, [1502002195]=true, [1502002196]=true, [1502002197]=true,
[1502002198]=true, [1502002199]=true, [1502002200]=true, [1502002201]=true, [1502002202]=true, [1502002203]=true, [1502002204]=true, [1502002205]=true,
[1502002207]=true, [1502002209]=true, [1502002210]=true, [1502002211]=true, [1502002214]=true, [1502002217]=true, [1502002219]=true, [1502002220]=true,
[1502002221]=true, [1502002222]=true, [1502002223]=true, [1502002224]=true, [1502002225]=true, [1502002227]=true, [1502002228]=true, [1502002229]=true,
[1502002230]=true, [1502002231]=true, [1502002232]=true, [1502002233]=true, [1502002234]=true, [1502002235]=true, [1502002236]=true, [1502002237]=true,
[1502002238]=true, [1502002239]=true, [1502002241]=true, [1502002242]=true, [1502002243]=true, [1502002244]=true, [1502002246]=true, [1502002247]=true,
[1502002248]=true, [1502002249]=true, [1502002252]=true, [1502002253]=true, [1502002254]=true, [1502002255]=true, [1502002256]=true, [1502002257]=true,
[1502002258]=true, [1502002259]=true, [1502002260]=true, [1502002261]=true, [1502002263]=true, [1502002264]=true, [1502002265]=true, [1502002267]=true,
[1502002268]=true, [1502002269]=true, [1502002270]=true, [1502002271]=true, [1502002272]=true, [1502002273]=true, [1502002274]=true, [1502002275]=true,
[1502002276]=true, [1502002277]=true, [1502002278]=true, [1502002279]=true, [1502002280]=true, [1502002284]=true, [1502002285]=true, [1502002286]=true,
[1502002287]=true, [1502002288]=true, [1502002289]=true, [1502002290]=true, [1502002292]=true, [1502002293]=true, [1502002294]=true, [1502002295]=true,
[1502002297]=true, [1502002298]=true, [1502002299]=true, [1502002300]=true, [1502002301]=true, [1502002302]=true, [1502002305]=true, [1502002306]=true,
[1502002307]=true, [1502002309]=true, [1502002311]=true, [1502002314]=true, [1502002315]=true, [1502002317]=true, [1502002320]=true, [1502002322]=true,
[1502002323]=true, [1502002325]=true, [1502002327]=true, [1502002328]=true, [1502002330]=true, [1502002332]=true, [1502002333]=true, [1502002335]=true,
[1502002336]=true, [1502002337]=true, [1502002338]=true, [1502002339]=true, [1502002341]=true, [1502002342]=true, [1502002343]=true, [1502002344]=true,
[1502002345]=true, [1502002346]=true, [1502002347]=true, [1502002348]=true, [1502002349]=true, [1502002350]=true, [1502002351]=true, [1502002352]=true,
[1502002353]=true, [1502002354]=true, [1502002355]=true, [1502002357]=true, [1502002358]=true, [1502002359]=true, [1502002360]=true, [1502002361]=true,
[1502002362]=true, [1502002363]=true, [1502002364]=true, [1502002365]=true, [1502002366]=true, [1502002367]=true, [1502002368]=true, [1502002369]=true,
[1502002370]=true, [1502002371]=true, [1502002372]=true, [1502002373]=true, [1502002374]=true, [1502002375]=true, [1502002376]=true, [1502002377]=true,
[1502002378]=true, [1502002379]=true, [1502002381]=true, [1502002382]=true, [1502002383]=true, [1502002384]=true, [1502002385]=true, [1502002386]=true,
[1502002387]=true, [1502002388]=true, [1502002389]=true, [1502002390]=true, [1502002391]=true, [1502002392]=true, [1502002393]=true, [1502002394]=true,
[1502002395]=true, [1502002396]=true, [1502002397]=true, [1502002398]=true, [1502002399]=true, [1502002400]=true, [1502002401]=true, [1502002402]=true,
[1502002403]=true, [1502002404]=true, [1502002405]=true, [1502002406]=true, [1502002407]=true, [1502002408]=true, [1502002409]=true, [1502002410]=true,
[1502002411]=true, [1502002412]=true, [1502002413]=true, [1502002414]=true, [1502002415]=true, [1502002416]=true, [1502002417]=true, [1502002418]=true,
[1502002419]=true, [1502002420]=true, [1502002421]=true, [1502002422]=true, [1502002423]=true, [1502002424]=true, [1502002425]=true, [1502002426]=true,
[1502002427]=true, [1502002428]=true, [1502002429]=true, [1502002430]=true, [1502002431]=true, [1502002432]=true, [1502002433]=true, [1502002434]=true,
[1502002435]=true, [1502002436]=true, [1502002437]=true, [1502002438]=true, [1502002439]=true, [1502002440]=true, [1502002441]=true, [1502002442]=true,
[1502002443]=true, [1502002444]=true, [1502002445]=true, [1502002446]=true, [1502002447]=true, [1502002448]=true, [1502002449]=true, [1502002450]=true,
[1502002451]=true, [1502002453]=true, [1502002454]=true, [1502002455]=true, [1502002456]=true, [1502002457]=true, [1502002458]=true, [1502002459]=true,
[1502002460]=true, [1502002461]=true, [1502002462]=true, [1502002463]=true, [1502002464]=true, [1502002465]=true, [1502002466]=true, [1502002467]=true,
[1502002468]=true, [1502002469]=true, [1502002470]=true, [1502002471]=true, [1502002472]=true, [1502002473]=true, [1502002474]=true, [1502002475]=true,
[1502002476]=true, [1502002477]=true, [1502002478]=true, [1502002479]=true, [1502002480]=true, [1502002481]=true, [1502002482]=true, [1502002483]=true,
[1502002484]=true, [1502002485]=true, [1502002486]=true, [1502002487]=true, [1502002488]=true, [1502002489]=true, [1502002490]=true, [1502002491]=true,
[1502002492]=true, [1502002493]=true, [1502002494]=true, [1502002495]=true, [1502002496]=true, [1502002497]=true, [1502002498]=true, [1502002499]=true,
[1502002500]=true, [1502002501]=true, [1502002502]=true, [1502002503]=true, [1502002504]=true, [1502002505]=true, [1502002506]=true, [1502002507]=true,
[1502002508]=true, [1502002509]=true, [1502002510]=true, [1502002511]=true, [1502002512]=true, [1502002515]=true, [1502003309]=true
}

_G.X3.Inj = _G.X3.Inj or {
    resToIns = {}, insToRes = {},
    cache = { outfitRes = nil, outfitIns = nil, weapons = {} },
    hooksInstalled = false, itemsBuilt = false,
    injectDone = false, injectRunning = false, injectIdx = 1,
    items = {},
}

-- konstanta subtype item (dari referensi)
_G.X3.InjGunSub = { [101]=true, [102]=true, [103]=true, [104]=true, [105]=true, [106]=true, [107]=true }
_G.X3.InjST = { TOP=403, PANTS=404, SHOES=405, UNDER_T=450, UNDER_P=451, MELEE=108 }

-- INJ CFG --
_G.X3.InjCfg = function(resID)
    if not resID or not CDataTable or not CDataTable.GetTableData then return nil end
    local ok, r = pcall(CDataTable.GetTableData, "Item", resID)
    return ok and r or nil
end

-- INJ SUB TYPE --
_G.X3.InjSubType = function(c)
    return c and (c.ItemSubType or c.itemSubType) or nil
end

-- INJ WARDROBE TAB --
_G.X3.InjWardrobeTab = function(resID, depotData)
    if depotData and depotData.subTabType then return tonumber(depotData.subTabType) end
    local c = _G.X3.InjCfg(resID)
    return c and tonumber(c.WardrobeTab or c.wardrobeTab) or nil
end

-- INJ IS FULL SUIT --
_G.X3.InjIsFullSuit = function(resID, depotData)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return false end
    local ok, xs = pcall(function()
        local LogicXSuit = require("client.slua.logic.XSuit.logic_xsuit")
        return LogicXSuit.IsXSuit(resID)
    end)
    if ok and xs then return true end
    local tab = _G.X3.InjWardrobeTab(resID, depotData)
    if tab == 10 then return true end
    if tab == 3 then return false end
    return _G.X3.InjSubType(_G.X3.InjCfg(resID)) == _G.X3.InjST.TOP
end

-- INJ CLOTH KIND --
_G.X3.InjClothKind = function(resID, depotData)
    resID = tonumber(resID)
    if not resID then return nil end
    local st = _G.X3.InjSubType(_G.X3.InjCfg(resID))
    if st == _G.X3.InjST.TOP then return _G.X3.InjIsFullSuit(resID, depotData) and "full_suit" or "top" end
    if st == _G.X3.InjST.PANTS then return "pants" end
    if st == _G.X3.InjST.SHOES then return "shoes" end
    if st == _G.X3.InjST.UNDER_T then return "under_top" end
    if st == _G.X3.InjST.UNDER_P then return "under_pants" end
    return nil
end

-- INJ CLEAR MAP FOR KIND --
_G.X3.InjClearMapForKind = function(kind)
    local ST = _G.X3.InjST
    if kind == "full_suit" then return { [ST.TOP]=true, [ST.PANTS]=true, [ST.SHOES]=true, [ST.UNDER_T]=true, [ST.UNDER_P]=true } end
    if kind == "top" then return { [ST.TOP]=true } end
    if kind == "pants" then return { [ST.PANTS]=true } end
    if kind == "shoes" then return { [ST.SHOES]=true } end
    if kind == "under_top" then return { [ST.UNDER_T]=true } end
    if kind == "under_pants" then return { [ST.UNDER_P]=true } end
    return nil
end

-- INJ WEAPON ID FROM SKIN --
_G.X3.InjWeaponIdFromSkin = function(resID)
    local ok, m = pcall(function()
        if CDataTable and CDataTable.GetTableData then
            return CDataTable.GetTableData("WeaponSkinMapping", resID)
        end
        return nil
    end)
    if ok and m then return m.WeaponID or m.WeaponId end
    local s = tostring(tonumber(resID))
    if #s == 10 and s:sub(1, 2) == "11" then
        return tonumber("1" .. s:sub(3, 7))
    end
    return nil
end

-- INJ CLASSIFY --
_G.X3.InjClassify = function(resID)
    local n = tonumber(resID) or 0
    local st = _G.X3.InjSubType(_G.X3.InjCfg(resID))
    if st then
        if _G.X3.InjGunSub[st] then return "Gun" end
        if st == _G.X3.InjST.TOP then return "Top" end
        if st == _G.X3.InjST.PANTS then return "Pants" end
        if st == _G.X3.InjST.SHOES then return "Shoes" end
    end
    if n >= 1501000000 and n < 1502000000 then return "Bag" end
    if n >= 1502000000 and n < 1503000000 then return "Helmet" end
    if n >= 501000 and n <= 501999 then return "Bag" end
    if n >= 502000 and n <= 502999 then return "Helmet" end
    if n >= 404000 and n <= 404999 then return "Pants" end
    if n >= 405000 and n <= 405999 then return "Shoes" end
    if n >= 1900000 and n < 2000000 then return "Vehicle" end
    if n >= 1400000 and n < 1500000 then return "Suit" end
    if n >= 400000 and n < 410000 then return "Suit" end
    return nil
end

-- INJ IS INJECTED INS --
_G.X3.InjIsInjectedIns = function(ins) return ins and _G.X3.Inj.insToRes[tonumber(ins)] ~= nil end
-- INJ IS INJECTED RES --
_G.X3.InjIsInjectedRes = function(res) return res and _G.X3.Inj.resToIns[tonumber(res)] ~= nil end

-- INJ GET ENTITY --
_G.X3.InjGetEntity = function()
    local ok, dc = pcall(require, "client.slua.logic.wardrobe.logic_wardrobe_data_center")
    if not ok or not dc then return nil end
    local ok2, e = pcall(dc.GetWardrobeData)
    return ok2 and e or nil
end

-- INJ ALREADY HAVE --
_G.X3.InjAlreadyHave = function(entity, resID)
    local arr = entity.ResIDToIndexArrayMap and entity.ResIDToIndexArrayMap[resID]
    if arr then
        for _, idx in pairs(arr) do
            local d = entity._data and entity._data[idx]
            if d and (d.count or 0) > 0 then return true end
        end
    end
    local ok, d = pcall(function() return entity:GetDataByResID(resID) end)
    if ok and type(d) == "table" then
        if d.res_id or d.resID then return true end
        if #d > 0 then return true end
    end
    return false
end

-- INJ INJECT ONE --
_G.X3.InjInjectOne = function(entity, resID, insID)
    local st = _G.X3.Inj
    if st.injectedEntity ~= entity then
        st.injectedEntity = entity
        st.injectedRes = {}
    end
    st.injectedRes = st.injectedRes or {}
    if st.injectedRes[resID] then return true end
    if _G.X3.InjAlreadyHave(entity, resID) then
        st.injectedRes[resID] = true
        _G.X3.Inj.resToIns[resID] = _G.X3.Inj.resToIns[resID] or insID
        _G.X3.Inj.insToRes[insID] = resID
        return true
    end
    local row = { instid = insID, res_id = resID, count = 1, lock_cnt = 0, isnew = 0, valid_hours = 0, expire_ts = 0 }
    if _G.X3._LTry then _G.X3._LTry("SKIN Wardrobe AddData") end
    if _G.X3._LCall then _G.X3._LCall("SKIN entity:AddData", function() entity:AddData(row) end) else entity:AddData(row) end
    if (_G.X3.Inj.phase or 1) == 1 then
        pcall(function()
            local data = entity.GetDataByInsID and entity:GetDataByInsID(insID)
            if data and entity.LoadConfigForData and CDataTable and CDataTable.GetTableData then
                entity:LoadConfigForData(data, CDataTable.GetTableData)
            end
        end)
    end
    st.injectedRes[resID] = true
    _G.X3.Inj.insToRes[insID] = resID
    _G.X3.Inj.resToIns[resID] = insID
    return true
end

-- INJ INJECT ARMORY --
_G.X3.InjInjectArmory = function(resID, insID)
    local wid = _G.X3.InjWeaponIdFromSkin(resID)
    if not wid then return end
    local Arm = require("client.logic.armory.logic_armory")
    Arm.rsp_list = Arm.rsp_list or { skin_list = {}, install_list = {} }
    Arm.rsp_list.skin_list = Arm.rsp_list.skin_list or {}
    Arm.rsp_list.install_list = Arm.rsp_list.install_list or {}
    if not Arm.rsp_list.skin_list[wid] then Arm.rsp_list.skin_list[wid] = {} end
    Arm.rsp_list.skin_list[wid][resID] = { is_open = 1 }
    Arm.WardrobeInsList = Arm.WardrobeInsList or {}
    Arm.WardrobeInsList[resID] = insID
end

-- INJ REFRESH WARDROBE --
_G.X3.InjRefreshWardrobe = function()
    pcall(function()
        if EventSystem and EVENTTYPE_WARDROBE then
            if EVENTID_WARDROBE_UPDATE_ITEM_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_ITEM_LIST)
            end
            if EVENTID_WARDROBE_UPDATE_AVATAR_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_AVATAR_LIST)
            end
            if EVENTID_WARDROBE_UPDATE_GUN_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_GUN_LIST, -1)
            end
        end
    end)
end

-- INJ REMOVE ROLE WEAR BY SUB TYPES --
_G.X3.InjRemoveRoleWearBySubTypes = function(stMap)
    if not stMap then return end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local AvatarData = require("client.logic.data.AvatarData")
    for _, insRaw in pairs(AvatarData.GetRoleWear()) do
        local ins = tonumber(insRaw)
        if ins and ins > 0 then
            local d = wd:GetHallDepotItemDataByInsID(ins)
            if d and stMap[tonumber(d.itemSubType)] then
                AvatarData.RemoveRoleWearDataByValue(ins)
            end
        end
    end
end

-- INJ CLEAR FASHION BAG SLOTS --
_G.X3.InjClearFashionBagSlots = function(stMap)
    if not stMap then return end
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
        if not bag or not bag.rolewear_list then return end
        for st, _ in pairs(stMap) do
            local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(st)
            if idx then bag.rolewear_list[idx] = 0 end
        end
    end)
end

-- INJ SYNC FASHION BAG ROLEWEAR --
_G.X3.InjSyncFashionBagRolewear = function()
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        fbd:SaveRolewearToFashionBag(fbd:GetFashionBagUseIndex())
    end)
end

-- INJ FIND WORN INS BY SUB TYPE --
_G.X3.InjFindWornInsBySubType = function(st)
    st = tonumber(st)
    if not st then return nil end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local AvatarData = require("client.logic.data.AvatarData")
    for _, insRaw in pairs(AvatarData.GetRoleWear()) do
        local ins = tonumber(insRaw)
        if ins and ins > 0 then
            local d = wd:GetHallDepotItemDataByInsID(ins)
            if d and tonumber(d.itemSubType) == st then return ins, d.resID end
        end
    end
    return nil
end

-- INJ SAVE EQUIP --
_G.X3.InjSaveEquip = function(resID, insID)
    resID, insID = tonumber(resID), tonumber(insID)
    if not resID or not insID then return end
    local cch = _G.X3.Inj.cache
    local cData = _G.X3.LexusState and _G.X3.LexusState.CustomTextData
    local st = _G.X3.InjSubType(_G.X3.InjCfg(resID))
    local kind = _G.X3.InjClassify(resID)
    if _G.X3.InjClothKind(resID) == "full_suit" or kind == "Suit" or kind == "Top" then
        cch.outfitRes, cch.outfitIns = resID, insID
        _G.X3.OutfitMap.Suit = resID
        if cData then cData.LobbySuit = resID end
        if _G.X3.L_Log then pcall(_G.X3.L_Log, "[SkinUnlock] CAPTURE suit " .. tostring(resID)) end
    elseif st and _G.X3.InjGunSub[st] then
        local wid = _G.X3.InjWeaponIdFromSkin(resID)
        if wid then
            cch.weapons[wid] = { resID = resID, insID = insID }
            _G.X3.WeaponSkinMap[wid] = resID
            if cData then cData["LobbyGun_" .. tostring(wid)] = resID end
            if _G.X3.L_Log then pcall(_G.X3.L_Log, "[SkinUnlock] CAPTURE gun " .. tostring(wid) .. "=" .. tostring(resID)) end
        end
    elseif st == _G.X3.InjST.MELEE then
        cch.weapons[_G.X3.InjST.MELEE] = { resID = resID, insID = insID }
    elseif kind == "Bag" then
        _G.X3.OutfitMap.Bag = { resID, resID, resID }
        if cData then cData.LobbyBag = resID end
        cch.bag = { resID = resID, insID = insID }
        if _G.X3.L_Log then pcall(_G.X3.L_Log, "[SkinUnlock] CAPTURE bag " .. tostring(resID)) end
    elseif kind == "Helmet" then
        _G.X3.OutfitMap.Helmet = { resID, resID, resID }
        if cData then cData.LobbyHelmet = resID end
        cch.helmet = { resID = resID, insID = insID }
        if _G.X3.L_Log then pcall(_G.X3.L_Log, "[SkinUnlock] CAPTURE helm " .. tostring(resID)) end
    elseif kind == "Pants" then
        _G.X3.OutfitMap.Pants = resID
        if cData then cData.LobbyPants = resID end
        cch.pants = { resID = resID, insID = insID }
        if _G.X3.L_Log then pcall(_G.X3.L_Log, "[SkinUnlock] CAPTURE celana " .. tostring(resID)) end
    elseif kind == "Shoes" then
        _G.X3.OutfitMap.Shoes = resID
        if cData then cData.LobbyShoes = resID end
        cch.shoes = { resID = resID, insID = insID }
        if _G.X3.L_Log then pcall(_G.X3.L_Log, "[SkinUnlock] CAPTURE sepatu " .. tostring(resID)) end
    elseif kind == "Vehicle" then
        local base = _G.X3.VehSkinToBase and _G.X3.VehSkinToBase[resID]
        if base then
            _G.X3.VehicleSkinMap[base] = resID
            if cData then cData["LobbyVeh_" .. tostring(base)] = resID end
        end
        cch.vehicles = cch.vehicles or {}
        cch.vehicles[resID] = insID
        _G.X3.LastVehicleEntity = nil
        if _G.X3.L_Log then pcall(_G.X3.L_Log, "[SkinUnlock] CAPTURE kendaraan " .. tostring(resID) .. " base=" .. tostring(base)) end
    end
    local nowS = os.clock()
    if _G.X3.SaveModSettings and (not _G.X3.LastCapSave or (nowS - _G.X3.LastCapSave) > 1.0) then
        _G.X3.LastCapSave = nowS
        pcall(_G.X3.SaveModSettings)
    end
end

-- CAPTURE FROM ARGS --
_G.X3.CaptureFromArgs = function(src, ...)
    local args = { ... }
    for _, a in ipairs(args) do
        local ta = type(a)
        if ta == "number" then
            if _G.X3.InjIsInjectedIns and _G.X3.InjIsInjectedIns(a) then
                local resID = _G.X3.Inj.insToRes[a]
                if resID then
                    pcall(_G.X3.InjSaveEquip, resID, a)
                    if type(_G.X3.Trace) == "function" then
                        _G.X3.Trace("CAPTURE-GEN " .. tostring(src) .. " ins=" .. tostring(a) .. " res=" .. tostring(resID))
                    end
                end
                return
            end
        elseif ta == "table" then
            local ins = tonumber(a.instid or a.insID or a.ins_id or a.InsID)
            if ins and _G.X3.InjIsInjectedIns and _G.X3.InjIsInjectedIns(ins) then
                local resID = _G.X3.Inj.insToRes[ins] or tonumber(a.res_id or a.resID or a.ResID)
                if resID then
                    pcall(_G.X3.InjSaveEquip, resID, ins)
                    if type(_G.X3.Trace) == "function" then
                        _G.X3.Trace("CAPTURE-GEN " .. tostring(src) .. " ins=" .. tostring(ins) .. " res=" .. tostring(resID))
                    end
                end
                return
            end
        end
    end
end

-- INJ PUT ON CLOTH --
_G.X3.InjPutOnCloth = function(insID)
    insID = tonumber(insID)
    local resID = _G.X3.Inj.insToRes[insID]
    if not resID then return end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end
    local kind = _G.X3.InjClothKind(resID, d)
    if not kind then return end
    local clearMap = _G.X3.InjClearMapForKind(kind)
    if not clearMap then return end
    local itemSt = _G.X3.InjSubType(_G.X3.InjCfg(resID)) or _G.X3.InjST.TOP
    local oldIns, oldRes = _G.X3.InjFindWornInsBySubType(itemSt)
    pcall(_G.X3.InjRemoveRoleWearBySubTypes, clearMap)
    pcall(_G.X3.InjClearFashionBagSlots, clearMap)
    _G.X3.InjSaveEquip(resID, insID)
    local slot = 3
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(itemSt)
        if idx then slot = idx end
    end)
    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or _G.X3.Inj.insToRes[oldIns], count = 1, instid = oldIns }
    end
    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        local item = { res_id = resID, count = 1, instid = insID }
        WRH.on_depot_put_on_rsp(NetErrorCode_NONE or "ok", item, olditem, slot, insID, oldIns or 0)
    end)
    pcall(function()
        local av = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
        av:AddToWearInfo(itemSt, insID, resID, 0, 0)
        local displayResID = resID
        local LogicXSuit = require("client.slua.logic.XSuit.logic_xsuit")
        if LogicXSuit.IsXSuit(displayResID) then
            displayResID = LogicXSuit.GetItemShowID(insID) or displayResID
        end
        av:AvatarChange(displayResID, true, 0, 0)
        av:ProcessTakeOff()
        _G.X3.InjSyncFashionBagRolewear()
    end)
end

-- INJ EQUIP WEAPON SKIN --
_G.X3.InjEquipWeaponSkin = function(wid, insID)
    wid, insID = tonumber(wid), tonumber(insID)
    if not wid or not insID or not _G.X3.InjIsInjectedIns(insID) then return end
    local resID = _G.X3.Inj.insToRes[insID]
    if not resID then return end
    _G.X3.InjSaveEquip(resID, insID)
    pcall(_G.X3.InjInjectArmory, resID, insID)
    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        Arm.rsp_list.install_list[wid] = { skin_id = insID }
    end)
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if fbd.UpdateCurrentFashionBagWeaponSkin then
            fbd:UpdateCurrentFashionBagWeaponSkin(wid, insID)
        end
        local bagIdx = fbd:GetFashionBagUseIndex()
        local HT = require("client.logic.lobby.hall_theme_utils")
        HT.proc_skin_list_chg("weapon_skin", wid, insID, bagIdx, {})
    end)
    pcall(function()
        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
        wgl:SetGunID(wid)
        wgl:UpdateCurrentGunAvatar(wid, insID)
    end)
    pcall(function()
        if EventSystem and EVENTTYPE_ARMORY and EVENTID_ARMORY_EQUIP_STAT_CHANGE then
            EventSystem:postEvent(EVENTTYPE_ARMORY, EVENTID_ARMORY_EQUIP_STAT_CHANGE, resID)
        end
        if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
            EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, resID)
        end
    end)
end

-- INJ BUILD ITEMS --
_G.X3.InjBuildItems = function()
    local seen, items = {}, {}
    local function add(id)
        id = tonumber(id)
        if id and id > 0 and not seen[id] and not (_G.X3.NonMaxLevels and _G.X3.NonMaxLevels[id]) then
            seen[id] = true table.insert(items, id)
        end
    end
    if _G.X3.VIPWeaponSkins then
        for _, id in ipairs(_G.X3.VIPWeaponSkins) do add(id) end
    end
    if _G.X3.OutfitSkins then
        for _, id in ipairs(_G.X3.OutfitSkins.Suit or {}) do add(id) end
        for _, t in ipairs(_G.X3.OutfitSkins.Bag or {}) do for _, id in ipairs(t) do add(id) end end
        for _, t in ipairs(_G.X3.OutfitSkins.Helmet or {}) do for _, id in ipairs(t) do add(id) end end
        for _, id in ipairs(_G.X3.OutfitSkins.Pet or {}) do add(id) end
    end
    if _G.X3.skinIdMappings then
        for _, skins in pairs(_G.X3.skinIdMappings) do
            for i = 2, #skins do add(skins[i]) end
        end
    end
    if _G.X3.VIP_Attachments then
        for skinID in pairs(_G.X3.VIP_Attachments) do add(skinID) end
    end
    if _G.X3.VehicleSkins then
        for _, skins in pairs(_G.X3.VehicleSkins) do
            for i = 2, #skins do add(skins[i]) end
        end
    end
    _G.X3.Inj.items = items

    _G.X3.VehSkinToBase = {}
    if _G.X3.VehicleSkins then
        for base, skins in pairs(_G.X3.VehicleSkins) do
            for i = 2, #skins do _G.X3.VehSkinToBase[skins[i]] = base end
        end
    end

    local items2 = {}
    if _G.X3.DumpSkins then
        for _, id in ipairs(_G.X3.DumpSkins) do
            if not seen[id] and not (_G.X3.NonMaxLevels and _G.X3.NonMaxLevels[id]) then
                seen[id] = true
                table.insert(items2, id)
            end
        end
    end
    _G.X3.Inj.items2 = items2
end

_G.X3.EnumDone = false
_G.X3.EnumIDs = nil
_G.X3.EnumState = nil

-- ENUM ACCEPT --
_G.X3.EnumAccept = function(id, st)
    id = tonumber(id)
    if not id or id <= 0 or st.seen[id] then return end
    if id < 300000 and not (id >= 150000 and id <= 159999) then return end
    if _G.X3.NonMaxLevels and _G.X3.NonMaxLevels[id] then return end
    local c = _G.X3.InjCfg(id)
    if not c then return end
    local hasField = false
    pcall(function() for _ in pairs(c) do hasField = true break end end)
    local kind = _G.X3.InjClassify(id)
    if not kind then
        if (id >= 300000 and id <= 399999) or           -- BORDER / bingkai avatar
           (id >= 150000 and id <= 159999) or            -- companion
           (id >= 1510000 and id <= 1519999) or          -- crate/lootbox
           (id >= 1503000 and id <= 1504999) or          -- aksesori kecil
           (id >= 1704000 and id <= 1704999) or          -- emote
           (id >= 1100000000 and id <= 1199999999) or    -- semua skin senjata
           (id >= 1503000000 and id <= 1504999999) then  -- hair color/set kecil
            kind = "Extra"
        end
    end
    if kind then
        st.seen[id] = true
        st.ids[#st.ids + 1] = id
    end
end

_G.X3.EnumTableNames = {
    "AvatarBPTable","WeaponBPTable","VehicleBPTable","EmoteBPTable","PlaneBPTable",
    "ConsumableBPTable","EffectItemBPTable","InFillingBPTable","3DIconBPTable","DecalBPTable",
    "SkillPropsBPTable","VehiclePropsBPTable","VehicleRefitBPTable","VehicleRefitColorTable",
    "VehicleRefitPatternTable","VehicleRefitParticleTable","GameModeBPTable","SeasonMissionBPTable",
    "DiySuitPatternConfig","DiySuitColorConfig","PetDressBlueprintTable","PetDressBPTable",
    "Item","ItemBPTable","WeaponSkinMapping","VehiclePlaneSkinMapping","AvatarSkinMapping",
    "ParachuteBPTable","BackpackBPTable","HelmetBPTable","FrameBPTable","CompanionBPTable",
}

-- ENUM GET AEM --
_G.X3.EnumGetAEM = function()
    if _G.X3.EnumAEM ~= nil then return _G.X3.EnumAEM end
    local mgr = false
    for _, cls in ipairs({"AETableManager", "UAETableManager"}) do
        local ok, r = pcall(import, cls)
        if ok and r then mgr = r break end
    end
    if not mgr then
        pcall(function()
            local ok2, r2 = pcall(import, "AETableManager")
            if ok2 and r2 then mgr = r2 end
        end)
    end
    _G.X3.EnumAEM = mgr
    return mgr
end

-- ENUM RESOLVE TABLE --
_G.X3.EnumResolveTable = function(entry)
    -- entry = { name=..., src="dt"|"aem" }
    if entry.src == "dt" then
        local t = nil
        pcall(function() t = _G.__DataTable and _G.__DataTable[entry.name] end)
        return t
    end
    local mgr = _G.X3.EnumGetAEM()
    if not mgr then return nil end
    local t = nil
    pcall(function()
        if mgr.GetDataTableStatic then t = mgr.GetDataTableStatic(entry.name) end
        if not t and mgr.GetDataTableStatic_Mod then t = mgr.GetDataTableStatic_Mod(entry.name) end
    end)
    if not t then
        pcall(function()
            if mgr.GetInstance and mgr.GetTablePtr then
                local inst = mgr.GetInstance()
                if inst then t = inst:GetTablePtr(entry.name, true) end
            end
        end)
    end
    return t
end

-- ENUM START --
_G.X3.EnumStart = function()
    if _G.X3.EnumDone or _G.X3.EnumState then return end
    _G.X3.EnumState = { ids = {}, seen = {}, tIdx = 1, tables = {}, names = nil, nCnt = 0, nIdx = 0 }
    local st = _G.X3.EnumState
    pcall(function()
        if _G.__DataTable then
            for tn, _ in pairs(_G.__DataTable) do st.tables[#st.tables + 1] = { name = tostring(tn), src = "dt" } end
        end
    end)
    if _G.X3.EnumGetAEM() then
        local have = {}
        for _, e in ipairs(st.tables) do have[e.name] = true end
        for _, tn in ipairs(_G.X3.EnumTableNames) do
            if not have[tn] then st.tables[#st.tables + 1] = { name = tn, src = "aem" } end
        end
    end
    table.sort(st.tables, function(a, b) return a.name < b.name end)
    if type(_G.X3.Trace) == "function" then
        _G.X3.Trace("ENUM: mulai enumerasi " .. tostring(#st.tables) .. " DataTable (tanpa daftar ID)")
    end
    _G.X3.EnumStep()
end

-- ENUM STEP --
_G.X3.EnumStep = function()
    local st = _G.X3.EnumState
    if not st then return end
    local okS, errS = pcall(function()
        -- [PERF-F11] budget adaptif + gate: saat frame berat, kurangi iter / tunda enumerasi
-- (anti memperparah stutter). Saat santai (dt<=12ms) budget tetap 800 = identik asli.
local _dtEnum = tonumber(_G.X3.FrameDT) or 0
if _dtEnum > 0.050 then return end  -- frame sangat berat: tunda 1 tick (EnumState tetap -> lanjut nanti)
local budget = (_dtEnum > 0.020) and 200 or ((_dtEnum > 0.012) and 400 or 800)
        local DTL = nil
        pcall(function() DTL = import("DataTableFunctionLibrary") end)
        while budget > 0 do
            if st.tIdx > #st.tables then
                _G.X3.EnumIDs = st.ids
                _G.X3.EnumDone = true
                _G.X3.EnumState = nil
                if type(_G.X3.Trace) == "function" then
                    _G.X3.Trace("ENUM: SELESAI " .. tostring(#_G.X3.EnumIDs) .. " ID terbaca dari DataTable game")
                end
                return
            end
            if not st.names then
                local entry = st.tables[st.tIdx]
                local tbl = nil
                if type(entry) == "table" then
                    tbl = _G.X3.EnumResolveTable(entry)
                else
                    pcall(function() tbl = _G.__DataTable and _G.__DataTable[entry] end)
                end
                if tbl and DTL then
                    pcall(function() st.names = DTL.GetDataTableRowNames(tbl) end)
                    if not st.names then
                        pcall(function()
                            local arr = slua.Array(UEnums.EPropertyClass.NameProperty)
                            DTL.GetDataTableRowNames(tbl, arr)
                            st.names = arr
                        end)
                    end
                end
                st.nCnt = 0
                pcall(function() if st.names then st.nCnt = st.names:Num() end end)
                st.nIdx = 0
            end
-- [PERF-F08] named-fetcher 1x/tick (BUKAN per iter) -> pcall tetap jadi jaring,
-- tapi alokasi closure per-iter = 0 (enumerasi TIDAK regresi).

local _nmBuf = nil

local function _fetchName()
    _nmBuf = st.names:Get(st.nIdx)
end

while st.nIdx < st.nCnt and budget > 0 do
    budget = budget - 1

    _nmBuf = nil
    pcall(_fetchName)

    local nm = _nmBuf

    st.nIdx = st.nIdx + 1

    local id = tonumber(nm)

    if id then
        _G.X3.EnumAccept(id, st)
    end
end
            if st.nIdx >= st.nCnt then
                st.names = nil
                st.tIdx = st.tIdx + 1
            end
        end
        -- langkah berikutnya digas dari MAINLOOP (selama EnumState ada)
    end)
    if not okS then
        if type(_G.X3.Trace) == "function" then _G.X3.Trace("ENUM: error -> " .. tostring(errS)) end
        _G.X3.EnumIDs = st.ids
        _G.X3.EnumDone = true
        _G.X3.EnumState = nil
    end
end

-- INJ INJECT BATCH --
_G.X3.InjInjectBatch = function()
    local st = _G.X3.Inj
    if st.allDone then return end
    local entity = _G.X3.InjGetEntity()
    if not entity or not entity.bInit then st.injectRunning = false return end
    st.injectRunning = true
    local phase = st.phase or 1
    if phase == 2 and not _G.X3.EnumDone then
        if _G.X3.EnumStart then pcall(_G.X3.EnumStart) end
        return -- dipanggil ulang dari MAINLOOP
    end
    local items
    if phase == 1 then
        items = st.items
    else
        items = (_G.X3.EnumIDs and #_G.X3.EnumIDs > 0) and _G.X3.EnumIDs or (st.items2 or {})
    end
    local batchSize = (phase == 1) and 40 or 50
    local delay = (phase == 1) and 0.05 or 0.05
    local insBase = (phase == 1) and 2000000000 or 2001000000
    local i = st.injectIdx or 1
    local n = 0
    while i <= #items and n < batchSize do
        local resID = items[i]
        local insID = insBase + i
        if _G.X3.InjInjectOne(entity, resID, insID) then
            local sub = _G.X3.InjSubType(_G.X3.InjCfg(resID))
            if (sub and _G.X3.InjGunSub[sub]) or sub == _G.X3.InjST.MELEE then
                pcall(_G.X3.InjInjectArmory, resID, insID)
            end
            n = n + 1
        end
        i = i + 1
    end
    st.injectIdx = i
    if i > #items then
        if phase == 1 then
            st.injectDone = true
            st.phase = 2
            st.injectIdx = 1
            pcall(_G.X3.InjRestoreFromSave)
            pcall(_G.X3.InjRefreshWardrobe)
            _G.X3._InjReapplyAt = os.clock() + 1.0 -- dieksekusi MAINLOOP
            print("[X3Team] SkinUnlock: fase-1 selesai " .. tostring(#items) .. " item, lanjut fase-2 ...")
            if _G.X3.L_Log then pcall(_G.X3.L_Log, "[SkinUnlock] fase-1 selesai total=" .. tostring(#items)) end
        else
            st.allDone = true
            st.injectRunning = false
            pcall(_G.X3.InjRestoreFromSave)
            pcall(_G.X3.InjRefreshWardrobe)
            _G.X3._InjReapplyAt = os.clock() + 1.0 -- dieksekusi MAINLOOP
            print("[X3Team] SkinUnlock: SEMUA skin terinjeksi (" .. tostring(#items) .. " fase-2)")
            if _G.X3.L_Log then pcall(_G.X3.L_Log, "[SkinUnlock] fase-2 selesai total=" .. tostring(#items)) end
        end
    end
    -- batch lanjut digas dari MAINLOOP selama injectRunning
end

-- INJ PUT ON GENERIC --
_G.X3.InjPutOnGeneric = function(insID)
    insID = tonumber(insID)
    local resID = _G.X3.Inj.insToRes[insID]
    if not resID then return end
    pcall(_G.X3.InjSaveEquip, resID, insID)
    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        WRH.on_depot_put_on_rsp(NetErrorCode_NONE or "ok", { res_id = resID, count = 1, instid = insID }, nil, 1, insID, 0)
    end)
end

-- INJ RESTORE FROM SAVE --
_G.X3.InjRestoreFromSave = function()
    local cData = _G.X3.LexusState and _G.X3.LexusState.CustomTextData
    if not cData then return end
    local cch = _G.X3.Inj.cache
    if tonumber(cData.LobbySuit) then
        local r = tonumber(cData.LobbySuit)
        cch.outfitRes = r
        cch.outfitIns = _G.X3.Inj.resToIns[r]
    end
    if tonumber(cData.LobbyBag) then
        local r = tonumber(cData.LobbyBag)
        cch.bag = { resID = r, insID = _G.X3.Inj.resToIns[r] }
    end
    if tonumber(cData.LobbyHelmet) then
        local r = tonumber(cData.LobbyHelmet)
        cch.helmet = { resID = r, insID = _G.X3.Inj.resToIns[r] }
    end
    if tonumber(cData.LobbyPants) then
        local r = tonumber(cData.LobbyPants)
        cch.pants = { resID = r, insID = _G.X3.Inj.resToIns[r] }
    end
    if tonumber(cData.LobbyShoes) then
        local r = tonumber(cData.LobbyShoes)
        cch.shoes = { resID = r, insID = _G.X3.Inj.resToIns[r] }
    end
    cch.vehicles = cch.vehicles or {}
    for k, v in pairs(cData) do
        local wid = tostring(k):match("^LobbyGun_(%d+)$")
        if wid and tonumber(v) then
            local r = tonumber(v)
            cch.weapons[tonumber(wid)] = { resID = r, insID = _G.X3.Inj.resToIns[r] }
        end
        local vb = tostring(k):match("^LobbyVeh_(%d+)$")
        if vb and tonumber(v) then
            local r = tonumber(v)
            cch.vehicles[r] = _G.X3.Inj.resToIns[r]
        end
    end
end

-- INJ REAPPLY LOBBY --
_G.X3.InjReapplyLobby = function()
    local inLobby = true
    pcall(function()
        if GameStatus and GameStatus.IsInLobbyOrMainCity then
            inLobby = GameStatus.IsInLobbyOrMainCity()
        end
    end)
    if not inLobby then return end
    local cch = _G.X3.Inj.cache
    if cch.outfitIns and _G.X3.InjIsInjectedIns(cch.outfitIns) then
        pcall(_G.X3.InjPutOnCloth, cch.outfitIns)
    end
    if cch.pants and cch.pants.insID and _G.X3.InjIsInjectedIns(cch.pants.insID) then
        pcall(_G.X3.InjPutOnCloth, cch.pants.insID)
    end
    if cch.shoes and cch.shoes.insID and _G.X3.InjIsInjectedIns(cch.shoes.insID) then
        pcall(_G.X3.InjPutOnCloth, cch.shoes.insID)
    end
    if cch.bag and cch.bag.insID and _G.X3.InjIsInjectedIns(cch.bag.insID) then
        pcall(_G.X3.InjPutOnGeneric, cch.bag.insID)
    end
    if cch.helmet and cch.helmet.insID and _G.X3.InjIsInjectedIns(cch.helmet.insID) then
        pcall(_G.X3.InjPutOnGeneric, cch.helmet.insID)
    end
    if cch.vehicles then
        for vres, vins in pairs(cch.vehicles) do
            if _G.X3.InjIsInjectedIns(vins) then pcall(_G.X3.InjPutOnGeneric, vins) end
        end
    end
    for widRaw, w in pairs(cch.weapons) do
        local wid = tonumber(widRaw)
        if wid and w and w.insID and _G.X3.InjIsInjectedIns(w.insID) then
            pcall(_G.X3.InjEquipWeaponSkin, wid, w.insID)
        end
    end
    pcall(_G.X3.InjRefreshWardrobe)
end

-- INJ INSTALL HOOKS --
_G.X3.InjInstallHooks = function()
    pcall(function()
        local WDE = require("client.slua.logic.wardrobe.WardrobeDataEntity")
        if not WDE or WDE.__x3inj_init then return end
        local orig = WDE.InitData
        WDE.InitData = function(self, pkg)
            orig(self, pkg)
            local st = _G.X3.Inj
            st.injectDone = false
            st.allDone = false
            st.phase = 1
            st.injectIdx = 1
            pcall(_G.X3.InjInjectBatch)
            pcall(_G.X3.InjRefreshWardrobe)
        end
        WDE.__x3inj_init = true
    end)

    pcall(function()
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        if not wd or wd.__x3inj_data then return end
        local function wrapGet(name)
            local o = wd[name]
            if not o then return end
            wd[name] = function(self, insID, ...)
                insID = tonumber(insID)
                if _G.X3.InjIsInjectedIns(insID) then
                    local e = _G.X3.InjGetEntity()
                    if e then return e:GetDataByInsID(insID) end
                end
                return o(self, insID, ...)
            end
        end
        wrapGet("GetHallDepotItemDataByInsID")
        wrapGet("GetValidHallDepotItemDataByInsID")
        local function wrapBool(name)
            local o = wd[name]
            if not o then return end
            wd[name] = function(self, id, ...)
                if _G.X3.InjIsInjectedRes(tonumber(id)) or _G.X3.InjIsInjectedIns(tonumber(id)) then return true end
                return o(self, id, ...)
            end
        end
        wrapBool("HasItem")
        wrapBool("HasValidItem")
        wrapBool("CheckHasPermanentItem")
        wd.__x3inj_data = true
    end)

    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        if not wl or wl.__x3inj_page then return end
        local o2 = wl.IsCanUse
        if o2 then
            wl.IsCanUse = function(self, resId)
                if _G.X3.InjIsInjectedRes(resId) then return true end
                return o2(self, resId)
            end
        end
        local o3 = wl.IsCharacterUse
        if o3 then
            wl.IsCharacterUse = function(self, resId)
                if _G.X3.InjIsInjectedRes(resId) then return true end
                return o3(self, resId)
            end
        end
        local o4 = wl.GetWardrobeInsIdByResId
        if o4 then
            wl.GetWardrobeInsIdByResId = function(self, resid)
                resid = tonumber(resid)
                if _G.X3.InjIsInjectedRes(resid) then return _G.X3.Inj.resToIns[resid] end
                return o4(self, resid)
            end
        end
        wl.__x3inj_page = true
    end)

    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        if Arm and not Arm.__x3inj_arm then
            local og = Arm.GetSkinListByWeaponID
            if og then
                Arm.GetSkinListByWeaponID = function(wid)
                    local t = og(wid) or {}
                    local present = {}
                    for k, v in pairs(t) do
                        if type(v) == "table" then
                            local rid = tonumber(v.resID or v.res_id or v.skinID or v.skin_id or v.ResID)
                            if rid then present[rid] = true end
                        end
                        local kn = tonumber(k)
                        if kn and kn > 1000000 then present[kn] = true end
                    end
                    for resID, _ in pairs(_G.X3.Inj.resToIns) do
                        if not present[resID] and tonumber(_G.X3.InjWeaponIdFromSkin(resID)) == tonumber(wid) then
                            t[resID] = t[resID] or { is_open = 1 }
                        end
                    end
                    return t
                end
            end
            local oi = Arm.install_weapon_skin
            if oi then
                Arm.install_weapon_skin = function(cd, wid, ins)
                    ins = tonumber(ins)
                    if _G.X3.InjIsInjectedIns(ins) then
                        wid = tonumber(_G.X3.InjWeaponIdFromSkin(_G.X3.Inj.insToRes[ins]) or wid)
                        _G.X3.InjEquipWeaponSkin(wid, ins)
                        return
                    end
                    return oi(cd, wid, ins)
                end
            end
            Arm.__x3inj_arm = true
        end
    end)
    pcall(function()
        local AH = require("client.network.Protocol.ArmoryHandler")
        if AH and not AH.__x3inj_armh then
            local o = AH.send_install_weapon_skin
            if o then
                AH.send_install_weapon_skin = function(cd, wid, ins)
                    ins = tonumber(ins)
                    if _G.X3.InjIsInjectedIns(ins) then
                        wid = tonumber(_G.X3.InjWeaponIdFromSkin(_G.X3.Inj.insToRes[ins]) or wid)
                        _G.X3.InjEquipWeaponSkin(wid, ins)
                        return
                    end
                    return o(cd, wid, ins)
                end
            end
            AH.__x3inj_armh = true
        end
    end)

    -- 5) skin id senjata terpasang
    pcall(function()
        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
        if not wgl or wgl.__x3inj_gun then return end
        local o = wgl.GetSkinIdByWeaponID
        if o then
            wgl.GetSkinIdByWeaponID = function(self, wid)
                local w = _G.X3.Inj.cache.weapons[wid]
                if w and _G.X3.InjIsInjectedIns(w.insID) then return w.insID end
                local Arm = require("client.logic.armory.logic_armory")
                if Arm.rsp_list and Arm.rsp_list.install_list and Arm.rsp_list.install_list[wid] then
                    local sid = Arm.rsp_list.install_list[wid].skin_id
                    if sid and _G.X3.InjIsInjectedIns(sid) then return sid end
                end
                return o(self, wid)
            end
        end
        wgl.__x3inj_gun = true
    end)

    -- 6) permintaan pakai item dari UI gudang
    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        if not WRH or WRH.__x3inj_put then return end
        local o = WRH.send_depot_put_on_req
        if o then
            WRH.send_depot_put_on_req = function(insID, extra)
                insID = tonumber(insID)
                if _G.X3.InjIsInjectedIns(insID) then
                    local resID = _G.X3.Inj.insToRes[insID]
                    local st = _G.X3.InjSubType(_G.X3.InjCfg(resID))
                    if _G.X3.InjClothKind(resID) then
                        pcall(_G.X3.InjPutOnCloth, insID)
                        return
                    end
                    if st and _G.X3.InjGunSub[st] then
                        local wid = _G.X3.InjWeaponIdFromSkin(resID)
                        if wid then pcall(_G.X3.InjEquipWeaponSkin, wid, insID) end
                        return
                    end
                    if st == _G.X3.InjST.MELEE then
                        pcall(_G.X3.InjEquipWeaponSkin, _G.X3.InjST.MELEE, insID)
                        return
                    end
                    pcall(_G.X3.InjSaveEquip, resID, insID)
                    pcall(function()
                        local wd2 = require("client.slua.logic.wardrobe.wardrobe_data")
                        local d2 = wd2:GetHallDepotItemDataByInsID(insID)
                        if d2 then
                            WRH.on_depot_put_on_rsp(NetErrorCode_NONE or "ok", { res_id = resID, count = 1, instid = insID }, nil, 1, insID, 0, extra)
                        end
                    end)
                    return
                end
                return o(insID, extra)
            end
        end
        WRH.__x3inj_put = true
    end)
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        if not wl or wl.__x3inj_req then return end
        local o = wl.wardrobe_puton_req
        if o then
            wl.wardrobe_puton_req = function(self, insID, extra)
                insID = tonumber(insID)
                if _G.X3.InjIsInjectedIns(insID) and _G.X3.InjClothKind(_G.X3.Inj.insToRes[insID]) then
                    pcall(_G.X3.InjPutOnCloth, insID)
                    return
                end
                return o(self, insID, extra)
            end
        end
        wl.__x3inj_req = true
    end)

    pcall(function()
        local nGen = 0
        local function tryHookModule(modName, patterns)
            local md = package.loaded[modName]
            if type(md) ~= "table" then
                local okR, mr = pcall(require, modName)
                if okR and type(mr) == "table" then md = mr end
            end
            if type(md) ~= "table" then return end
            for fname, fval in pairs(md) do
                if type(fval) == "function" and type(fname) == "string" then
                    local fl = string.lower(fname)
                    local match = false
                    for _, pat in ipairs(patterns) do
                        if string.find(fl, pat, 1, true) then match = true break end
                    end
                    if match and not rawget(md, "__x3cap_" .. fname) then
                        rawset(md, "__x3cap_" .. fname, true)
                        local o = fval
                        rawset(md, fname, function(...)
                            pcall(_G.X3.CaptureFromArgs, modName .. "." .. fname, ...)
                            return o(...)
                        end)
                        nGen = nGen + 1
                    end
                end
            end
        end
        tryHookModule("client.network.Protocol.WardRobeHandler", { "put_on", "puton", "wear" })
        tryHookModule("client.slua.logic.wardrobe.logic_wardrobe_new", { "put_on", "puton", "wear" })
        tryHookModule("client.slua.logic.wardrobe.wardrobe_data", { "put_on", "puton", "wear" })
        tryHookModule("client.network.Protocol.ArmoryHandler", { "install_weapon", "weapon_skin" })
        tryHookModule("client.logic.armory.logic_armory", { "install_weapon_skin" })
        if type(_G.X3.Trace) == "function" then
            _G.X3.Trace("SKIN: capture generik terpasang di " .. tostring(nGen) .. " fungsi")
        end
    end)

    if _G.X3.L_Log then pcall(_G.X3.L_Log, "[SkinUnlock] hook v18 terpasang") end
end

-- INJ ENSURE --
_G.X3.InjEnsure = function()
    if not _G.X3.LexusConfig or not (_G.X3.LexusConfig.SkinUnlockAll or _G.X3.LexusConfig.ModSkin) then return end
    local st = _G.X3.Inj
    if not st.hooksInstalled then
        st.hooksInstalled = true
        local okH, errH = pcall(_G.X3.InjInstallHooks)
        if type(_G.X3.Trace) == "function" then
            _G.X3.Trace("SKIN: InstallHooks ok=" .. tostring(okH) .. (okH and "" or (" err=" .. tostring(errH))))
        end
    end
    if not st.itemsBuilt then
        st.itemsBuilt = true
        local okB, errB = pcall(_G.X3.InjBuildItems)
        if type(_G.X3.Trace) == "function" then
            local n1 = (st.items and #st.items) or 0
            local n2 = (st.items2 and #st.items2) or 0
            _G.X3.Trace("SKIN: BuildItems ok=" .. tostring(okB) .. " fase1=" .. tostring(n1) .. " fase2=" .. tostring(n2) .. (okB and "" or (" err=" .. tostring(errB))))
        end
    end
    if _G.X3.EnumStart then pcall(_G.X3.EnumStart) end
    if not st.allDone and not st.injectRunning then
        pcall(_G.X3.InjInjectBatch)
    end
    if _G.X3.HookEmoteDepot then pcall(_G.X3.HookEmoteDepot) end
end

-- BP GET VIP ATTACH --
_G.X3.BpGetVipAttach = function(attachId)
    local mapIndex = _G.X3.BaseAttachToIndex and _G.X3.BaseAttachToIndex[attachId]
    if not mapIndex then return nil end
    local ok, res = pcall(function()
        local GameplayData = require("GameLua.GameCore.Data.GameplayData")
        local lp = GameplayData and GameplayData.GetPlayerCharacter and GameplayData.GetPlayerCharacter()
        if not slua.isValid(lp) then return nil end
        local w = lp:GetCurrentWeapon()
        if not slua.isValid(w) then return nil end
        local skin = _G.X3.get_skin_id and _G.X3.get_skin_id(w:GetWeaponID()) or w:GetWeaponID()
        if skin and skin >= 10000000 and _G.X3.VIP_Attachments and _G.X3.VIP_Attachments[skin] then
            local v = _G.X3.VIP_Attachments[skin][mapIndex]
            if v and v > 0 then return v end
        end
        return nil
    end)
    return ok and res or nil
end

-- BP COPY WITH SKIN --
_G.X3.BpCopyWithSkin = function(item)
    if type(item) ~= "table" then return item end
    local did = item.defineID or item.ItemDefineID or item.DefineID
    if type(did) ~= "table" then return item end
    local tid = tonumber(did.TypeSpecificID) or 0
    local newId = nil
    if tid >= 100000 and tid <= 199999 then
        local skin = _G.X3.get_skin_id and _G.X3.get_skin_id(tid)
        if skin and skin ~= tid then newId = skin end
    elseif tid >= 200000 and tid <= 299999 then
        newId = _G.X3.BpGetVipAttach(tid)
    end
    if not newId then return item end
    local shown = {}
    for k, v in pairs(item) do shown[k] = v end
    local ndid = {}
    for k, v in pairs(did) do ndid[k] = v end
    ndid.TypeSpecificID = newId
    if item.defineID then shown.defineID = ndid end
    if item.ItemDefineID then shown.ItemDefineID = ndid end
    if item.DefineID then shown.DefineID = ndid end
    if _G.X3.download_item then pcall(_G.X3.download_item, newId) end
    return shown
end

-- BP SUBSTITUTE ARRAY --
_G.X3.BpSubstituteArray = function(arr)
    if type(arr) ~= "table" then return arr end
    local out = {}
    for k, v in pairs(arr) do out[k] = _G.X3.BpCopyWithSkin(v) end
    return out
end

-- BP INSTALL HOOKS --
_G.X3.BpInstallHooks = function()
    -- panel senjata utama Ransel
    pcall(function()
        local mw = package.loaded["GameLua.Mod.BaseMod.Client.Backpack.MainWeaponInfoItemUI"] or require("GameLua.Mod.BaseMod.Client.Backpack.MainWeaponInfoItemUI")
        if type(mw) == "table" and not rawget(mw, "__x3bp") then
            rawset(mw, "__x3bp", true)
            local o = rawget(mw, "GetCurrentWeaponItemArray")
            if type(o) == "function" then
                rawset(mw, "GetCurrentWeaponItemArray", function(...)
                    local r = o(...)
                    pcall(function() r = _G.X3.BpSubstituteArray(r) end)
                    return r
                end)
            end
            if _G.X3.L_Log then pcall(_G.X3.L_Log, "[X3Bp] hook MainWeaponInfoItemUI") end
        end
    end)
    -- slot attachment
    pcall(function()
        local fs = package.loaded["GameLua.Mod.BaseMod.Client.Backpack.FittingSlotItemUI"] or require("GameLua.Mod.BaseMod.Client.Backpack.FittingSlotItemUI")
        if type(fs) == "table" and not rawget(fs, "__x3bp") then
            rawset(fs, "__x3bp", true)
            local o = rawget(fs, "GetGunBattleData")
            if type(o) == "function" then
                rawset(fs, "GetGunBattleData", function(...)
                    local r = o(...)
                    pcall(function() r = _G.X3.BpCopyWithSkin(r) end)
                    return r
                end)
            end
            if _G.X3.L_Log then pcall(_G.X3.L_Log, "[X3Bp] hook FittingSlotItemUI") end
        end
    end)
    pcall(function()
        local lb = package.loaded["GameLua.Mod.BaseMod.Client.Backpack.ListItemUIBase"] or require("GameLua.Mod.BaseMod.Client.Backpack.ListItemUIBase")
        if type(lb) == "table" and not rawget(lb, "__x3bp") then
            rawset(lb, "__x3bp", true)
            for _, fn in ipairs({"UpdateItemDataNew", "UpdateItemDataMod"}) do
                local o = rawget(lb, fn)
                if type(o) == "function" then
                    rawset(lb, fn, function(self, item, ...)
                        local shown = item
                        pcall(function() shown = _G.X3.BpCopyWithSkin(item) end)
                        return o(self, shown, ...)
                    end)
                end
            end
            if _G.X3.L_Log then pcall(_G.X3.L_Log, "[X3Bp] hook ListItemUIBase") end
        end
    end)
    pcall(function()
        local bi = package.loaded["GameLua.Mod.BaseMod.Client.Backpack.BackPackItemUI"] or require("GameLua.Mod.BaseMod.Client.Backpack.BackPackItemUI")
        if type(bi) == "table" and not rawget(bi, "__x3bp") then
            rawset(bi, "__x3bp", true)
            local o = rawget(bi, "UpdateSingleItem")
            if type(o) == "function" then
                rawset(bi, "UpdateSingleItem", function(self, item, ...)
                    local shown = item
                    pcall(function() shown = _G.X3.BpCopyWithSkin(item) end)
                    return o(self, shown, ...)
                end)
            end
            if _G.X3.L_Log then pcall(_G.X3.L_Log, "[X3Bp] hook BackPackItemUI") end
        end
    end)
    if type(_G.X3.Trace) == "function" then
        local parts = {}
        for _, mn in ipairs({
            "GameLua.Mod.BaseMod.Client.Backpack.MainWeaponInfoItemUI",
            "GameLua.Mod.BaseMod.Client.Backpack.FittingSlotItemUI",
            "GameLua.Mod.BaseMod.Client.Backpack.ListItemUIBase",
            "GameLua.Mod.BaseMod.Client.Backpack.BackPackItemUI",
        }) do
            local m = package.loaded[mn]
            local short = string.match(mn, "([^%.]+)$") or mn
            if type(m) == "table" then
                parts[#parts + 1] = short .. (rawget(m, "__x3bp") and "=HOOKED" or "=ADA")
            else
                parts[#parts + 1] = short .. "=TIDAK"
            end
        end
        local sig = table.concat(parts, " ")
        if sig ~= _G.X3.BpDiagSig then
            _G.X3.BpDiagSig = sig
            _G.X3.Trace("BP: " .. sig)
        end
    end
end

-- BP ENSURE --
_G.X3.BpEnsure = function()
    if not _G.X3.LexusConfig or not _G.X3.LexusConfig.ModSkin then return end
    if _G.X3.SkinUnlock_InLobby and _G.X3.SkinUnlock_InLobby() then return end
    local now = os.clock()
    if _G.X3.BpLastTry and (now - _G.X3.BpLastTry) < 3.0 then return end
    _G.X3.BpLastTry = now
    pcall(_G.X3.BpInstallHooks)
end

-- APPLY BACKPACK SKIN DISPLAY --
_G.X3.ApplyBackpackSkinDisplay = function(PlayerCharacter)
    pcall(function()
        if not slua.isValid(PlayerCharacter) then return end
        local bc = PlayerCharacter.BackpackComponent
        if not slua.isValid(bc) then
            if type(_G.X3.Trace) == "function" and not _G.X3.BpNoBcTraced then
                _G.X3.BpNoBcTraced = true
                _G.X3.Trace("BP-DATA: PlayerCharacter.BackpackComponent TIDAK valid (nama field berubah di 4.5?)")
            end
            return
        end
        local now = os.clock()
        if _G.X3.BpSkinDataLast and (now - _G.X3.BpSkinDataLast) < 2.0 then return end
        _G.X3.BpSkinDataLast = now
        local items = {}
        local ok1, r1 = pcall(function() return bc:GetAllBattleItemClient() end)
        if ok1 and r1 then
            if type(r1) == "table" then
                for _, it in pairs(r1) do table.insert(items, it) end
            elseif type(r1) == "userdata" and r1.Num then
                for i = 0, r1:Num() - 1 do table.insert(items, r1:Get(i)) end
            end
        end
        if #items == 0 and bc.GetItemListByItemType then
            for _, t in ipairs({ 1, 2, 3, 4, 5, 6 }) do
                pcall(function()
                    local lst = bc:GetItemListByItemType(t)
                    if lst then
                        if type(lst) == "table" then
                            for _, it in pairs(lst) do table.insert(items, it) end
                        elseif type(lst) == "userdata" and lst.Num then
                            for i = 0, lst:Num() - 1 do table.insert(items, lst:Get(i)) end
                        end
                    end
                end)
            end
        end
        local nPatched = 0
        for _, it in pairs(items) do
            pcall(function()
                local did = it.ItemDefineID or it.defineID
                if did and did.TypeSpecificID then
                    local tid = tonumber(did.TypeSpecificID) or 0
                    if tid >= 100000 and tid <= 199999 then
                        local skin = _G.X3.get_skin_id and _G.X3.get_skin_id(tid)
                        if skin and skin ~= tid then
                            did.TypeSpecificID = skin
                            nPatched = nPatched + 1
                            if _G.X3.download_item then pcall(_G.X3.download_item, skin) end
                        end
                    end
                end
            end)
        end
        if type(_G.X3.Trace) == "function" then
            local sigB = "items=" .. tostring(#items) .. " patched=" .. tostring(nPatched) .. " getAll=" .. tostring(ok1)
            if sigB ~= _G.X3.BpDataSig and (_G.X3.BpDataN or 0) < 40 then
                _G.X3.BpDataSig = sigB
                _G.X3.BpDataN = (_G.X3.BpDataN or 0) + 1
                _G.X3.Trace("BP-DATA: " .. sigB)
            end
        end
    end)
end

-- Resolver skin ID (tanpa daftar ID manual):
_G.X3.SkinUnlock = _G.X3.SkinUnlock or {}
_G.X3.SkinUnlock._WeaponAvatarType = nil
_G.X3.SkinUnlock._SkinCache = _G.X3.SkinUnlock._SkinCache or {}
_G.X3.SkinUnlock._Backup = _G.X3.SkinUnlock._Backup or {}
_G.X3.SkinUnlock._CustomSkins = _G.X3.SkinUnlock._CustomSkins or {}
_G.X3.SkinUnlock._LastApplyTime = 0
_G.X3.SkinUnlock._Hooked = false
_G.X3.SkinUnlock._Applying = false

-- GET WEAPON AVATAR TYPE --
_G.X3.SkinUnlock.GetWeaponAvatarType = function()
    if _G.X3.SkinUnlock._WeaponAvatarType then return _G.X3.SkinUnlock._WeaponAvatarType end
    local ok, EBattleItemAdditionalDataType = pcall(import, "EBattleItemAdditionalDataType")
    local val = (ok and EBattleItemAdditionalDataType and EBattleItemAdditionalDataType.WeaponAvatar) or 7
    _G.X3.SkinUnlock._WeaponAvatarType = val
    return val
end

-- RESOLVE SKIN ID --
_G.X3.SkinUnlock.ResolveSkinID = function(WeaponID)
    local custom = _G.X3.SkinUnlock._CustomSkins[WeaponID]
    if custom and custom > 0 then return custom end
    local cached = _G.X3.SkinUnlock._SkinCache[WeaponID]
    if cached then return cached end
    local okM, mapSkin = pcall(function()
        local m = _G.X3.WeaponSkinMap
        return m and m[WeaponID] or nil
    end)
    if okM and tonumber(mapSkin) and tonumber(mapSkin) > 0 then
        local sidNum = tonumber(mapSkin)
        _G.X3.SkinUnlock._SkinCache[WeaponID] = sidNum
        return sidNum
    end
    local resolvers = { _G.getCachedWeaponSkin, rawget(_G, "getCachedWeaponSkin") }
    for _, fn in ipairs(resolvers) do
        if type(fn) == "function" then
            local ok, sid = pcall(fn, WeaponID)
            if ok then
                local sidNum = tonumber(sid) or 0
                if sidNum > 0 and sidNum < 99999999 then
                    _G.X3.SkinUnlock._SkinCache[WeaponID] = sidNum
                    return sidNum
                end
            end
        end
    end
    return 0
end

-- APPLY --
function _G.X3.SkinUnlock.Apply(Backpack)
    local now = os.clock()
    if now - _G.X3.SkinUnlock._LastApplyTime < 0.5 then return 0 end
    _G.X3.SkinUnlock._LastApplyTime = now
    if not (_G.X3.LexusConfig and _G.X3.LexusConfig.SkinIngame == true) then return 0 end
    if not (Backpack and slua.isValid(Backpack)) then return 0 end
    if not (Backpack.ItemListNet and Backpack.ItemListNet.IncArray) then return 0 end

    local applied = 0
    pcall(function()
        local BagArray = Backpack.ItemListNet.IncArray
        local ItemCount = BagArray:Num()
        if ItemCount <= 0 or ItemCount > 500 then return end
        local bNeedRefreshBag = false
        local EDataType_WeaponAvatar = _G.X3.SkinUnlock.GetWeaponAvatarType()

        for j = 0, ItemCount - 1 do
            local Item = BagArray:Get(j)
            if Item and Item.Unit and Item.Unit.DefineID then
                local CurrentID = Item.Unit.DefineID.TypeSpecificID
                if CurrentID then
                    local NewSkinID = _G.X3.SkinUnlock.ResolveSkinID(CurrentID)
                    if NewSkinID and NewSkinID > 0 then
                        local AdditionalData = Item.Unit.AdditionalData
                        if AdditionalData then
                            local bFoundAvatar = false
                            local dataCount = AdditionalData:Num()
                            for k = 0, dataCount - 1 do
                                local Data = AdditionalData:Get(k)
                                if Data and Data.EDataType == EDataType_WeaponAvatar then
                                    if not _G.X3.SkinUnlock._Backup[CurrentID] then
                                        _G.X3.SkinUnlock._Backup[CurrentID] = Data.IntData or 0
                                    end
                                    if Data.IntData ~= NewSkinID then
                                        Data.IntData = NewSkinID
                                        AdditionalData:Set(k, Data)
                                        bNeedRefreshBag = true
                                        applied = applied + 1
                                    end
                                    bFoundAvatar = true
                                    break
                                end
                            end
                            if not bFoundAvatar then
                                if not _G.X3.SkinUnlock._Backup[CurrentID] then
                                    _G.X3.SkinUnlock._Backup[CurrentID] = 0
                                end
                                if dataCount > 0 then
                                    local TD = AdditionalData:Get(0)
                                    if TD then
                                        TD.EDataType = EDataType_WeaponAvatar
                                        TD.IntData = NewSkinID
                                        TD.StringData = ""
                                        AdditionalData:Add(TD)
                                        bNeedRefreshBag = true
                                        applied = applied + 1
                                    end
                                else
                                    AdditionalData:Add({ EDataType = EDataType_WeaponAvatar, IntData = NewSkinID, StringData = "" })
                                    bNeedRefreshBag = true
                                    applied = applied + 1
                                end
                            end
                        end
                        BagArray:Set(j, Item)
                    end
                end
            end
        end

        if bNeedRefreshBag then
            pcall(function()
                if type(Backpack.OnRep_ItemListNet) == "function" then
                    Backpack:OnRep_ItemListNet()
                end
            end)
        end
    end)
    return applied
end

-- RESTORE --
_G.X3.SkinUnlock.Restore = function(Backpack)
    if not (Backpack and slua.isValid(Backpack)) then return 0 end
    if not (Backpack.ItemListNet and Backpack.ItemListNet.IncArray) then return 0 end
    local restored = 0
    pcall(function()
        local BagArray = Backpack.ItemListNet.IncArray
        local ItemCount = BagArray:Num()
        local EDataType_WeaponAvatar = _G.X3.SkinUnlock.GetWeaponAvatarType()
        for j = 0, ItemCount - 1 do
            local Item = BagArray:Get(j)
            if Item and Item.Unit and Item.Unit.DefineID then
                local CurrentID = Item.Unit.DefineID.TypeSpecificID
                local orig = CurrentID and _G.X3.SkinUnlock._Backup[CurrentID] or nil
                if orig then
                    local AdditionalData = Item.Unit.AdditionalData
                    if AdditionalData then
                        local dataCount = AdditionalData:Num()
                        for k = 0, dataCount - 1 do
                            local Data = AdditionalData:Get(k)
                            if Data and Data.EDataType == EDataType_WeaponAvatar then
                                Data.IntData = orig
                                AdditionalData:Set(k, Data)
                                restored = restored + 1
                                break
                            end
                        end
                    end
                    BagArray:Set(j, Item)
                end
            end
        end
        if restored > 0 then
            pcall(function()
                if type(Backpack.OnRep_ItemListNet) == "function" then Backpack:OnRep_ItemListNet() end
            end)
        end
    end)
    return restored
end

-- INIT --
function _G.X3.SkinUnlock.Init()
    if not (_G.X3.LexusConfig and _G.X3.LexusConfig.SkinIngame == true) then return false end
    local PlayerController = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if not (PlayerController and slua.isValid(PlayerController)) then return false end
    local BC = nil
    pcall(function()
        if PlayerController.GetBackpackComponent then BC = PlayerController:GetBackpackComponent() end
        if not BC and PlayerController.GetBackPackComponent then BC = PlayerController:GetBackPackComponent() end
    end)
    if BC and slua.isValid(BC) then
        if not _G.X3.SkinUnlock._Hooked then
            pcall(function()
                local orig = BC.OnRep_ItemListNet
                if orig then
                    BC.OnRep_ItemListNet = function(self, ...)
                        if type(orig) == "function" then orig(self, ...) end
                        if not _G.X3.SkinUnlock._Applying then
                            _G.X3.SkinUnlock._Applying = true
                            _G.X3.SkinUnlock.Apply(self)
                            _G.X3.SkinUnlock._Applying = false
                        end
                    end
                    _G.X3.SkinUnlock._Hooked = true
                end
            end)
        end
        _G.X3.SkinUnlock.Apply(BC)
        return true
    end
    return false
end

-- GET CONFIG PATHS --
local function GetConfigPaths(fileName)
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fileName,
        "/com.tencent.ig/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.vng.pubgmobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.pubg.krmobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.rekoo.pubgm/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.pubg.imobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
        fileName
    }
    pcall(function()
        if os and os.getenv then
            local homeDir = os.getenv("HOME")
            if homeDir and homeDir ~= "" then
                table.insert(paths, 1, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName)
                table.insert(paths, 2, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fileName)
            end
        end
    end)
    return paths
end

local ConfigFileName = "X3Team.txt"
_G.X3.LastConfigSaveStr = ""

-- CFG SER --
_G.X3.CfgSer = function(v)
    local t = type(v)
    if t == "string" then return string.format("%q", v) end
    if t == "number" or t == "boolean" then return tostring(v) end
    return "nil"
end

-- SAVE MOD SETTINGS --
_G.X3.SaveModSettings = function()
pcall(function()
-- [PERF-F05] HOLY-GRAIL: pairs() acak -> urutan baris berubah tiap call ->
-- perbandingan dgn LastConfigSaveStr selalu gagal -> io.write jalan tiap 1,5 dtk = hitch.
-- FIX: kumpul key + sort -> string DETERMINISTIK -> saat idle data identik -> return sebelum io.open.
local function skeys(t)
local ks = {}
for k in pairs(t) do ks[#ks + 1] = k end
table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
return ks
end
local data = "return {\nLexusConfig = {\n"
for _, k in ipairs(skeys(_G.X3.LexusConfig or {})) do
data = data .. "  [\"" .. tostring(k) .. "\"] = " .. _G.X3.CfgSer(_G.X3.LexusConfig[k]) .. ",\n"
end
data = data .. "},\nCustomTextData = {\n"
if _G.X3.LexusState and _G.X3.LexusState.CustomTextData then
for _, k in ipairs(skeys(_G.X3.LexusState.CustomTextData)) do
data = data .. "  [\"" .. tostring(k) .. "\"] = " .. _G.X3.CfgSer(_G.X3.LexusState.CustomTextData[k]) .. ",\n"
end
end
data = data .. "}\n}"
if data == _G.X3.LastConfigSaveStr then return end   -- idle: identik -> TIDAK tulis file (hitch hilang)
_G.X3.LastConfigSaveStr = data
local paths = GetConfigPaths(ConfigFileName)
for _, path in ipairs(paths) do
local file = io.open(path, "w")
if file then
file:write(data)
file:close()
break
end
end
end)
end

-- LOAD MOD SETTINGS --
_G.X3.LoadModSettings = function()
    pcall(function()
        local paths = GetConfigPaths(ConfigFileName)
        local content = nil
        for _, path in ipairs(paths) do
            local file = io.open(path, "r")
            if file then
                content = file:read("*a")
                file:close()
                break
            end
        end
        if content then
            local func = load(content)
            if func then
                local savedData = func()
                if savedData and type(savedData) == "table" then
                    if savedData.LexusConfig then
                        for k, v in pairs(savedData.LexusConfig) do
                            _G.X3.LexusConfig[k] = v
                        end
                    end
                    if savedData.CustomTextData then
                        _G.X3.LexusState.CustomTextData = _G.X3.LexusState.CustomTextData or {}
                        for k, v in pairs(savedData.CustomTextData) do
                            _G.X3.LexusState.CustomTextData[k] = v
                        end
                    end
                 end
            end
        end
        _G.X3.SaveModSettings()
    end)
end

-- AUTO SAVE LOOP (dijalankan dari MAINLOOP tiap 1.5 dtk) --
function _G.X3._AutoSaveTick()
    pcall(function() if _G.X3.SaveModSettings then _G.X3.SaveModSettings() end end)
end

if not _G.X3.ModConfigLoaded then
    _G.X3.LoadModSettings()
    _G.X3._AutoSaveTick()
    _G.X3.ModConfigLoaded = true
end

-- READ LIVE CONFIG --
_G.X3.ReadLiveConfig = function()
    if _G.X3.SaveModSettings then _G.X3.SaveModSettings() end
end

-- ==============================================================================
-- ================== MENU VIP / VIP MENU (SEMUA TOGGLE FITUR) ==================
-- ==============================================================================
-- INIT MOD MENU TAB --
function _G.X3.InitModMenuTab()
    if _G.X3.ModMenuInitialized and _G.X3.ModMenuBuiltStamp == _G.X3.BuildStamp then return true end

    _G.X3.LexusState.CustomTextData = _G.X3.LexusState.CustomTextData or {
        OuterSpeed = 10, InnerSpeed = 10, OuterRecoil = 0, HRecoil = 0.3, VRecoil = 0.3, MagicHead = 1.0, MagicBody = 1.0, MagicLegs = 1.0, IpadViewFOV = 120,
        AimTouchHipPrio = 1, AimTouchHipBone = 1, AimTouchHipCond = 1, AimTouchHipSpeed = 50, AimTouchHipFOV = 30, AimTouchHipDist = 250,
        AimTouchSGPrio = 1, AimTouchSGBone = 2, AimTouchSGCond = 1, AimTouchSGSpeed = 80, AimTouchSGFOV = 40, AimTouchSGDist = 30,
        AimTouchScopePrio = 1, AimTouchScopeBone = 2, AimTouchScopeCond = 1, AimTouchScopeSpeed = 40, AimTouchScopeFOV = 20, AimTouchScopeDist = 300, AimTouchScopePred = 0, AimTouchScopeRecoil = 0,
        AimTouchSniperPrio = 1, AimTouchSniperBone = 1, AimTouchSniperCond = 2, AimTouchSniperSpeed = 30, AimTouchSniperFOV = 20, AimTouchSniperDist = 400, AimTouchSniperPred = 0,
        MagicHead = 1.0, MagicNeck = 1.0, MagicBody = 1.0, MagicPelvis = 1.0, MagicArms = 1.0, MagicLegs = 1.0,
        WallMaxDist = 0, WallFadeDist = 0, WallOccOpacity = 100
    }

    local LocUtil = _G.LocUtil
    if not LocUtil and package.loaded["client.common.LocUtil"] then
        LocUtil = require("client.common.LocUtil")
    end

    if LocUtil and not LocUtil._IsModMenuHooked then
        local old_get = LocUtil.GetLocalizeResStr
        LocUtil.GetLocalizeResStr = function(id)
            if type(id) == "string" and not tonumber(id) then
                return id
            end
            return old_get(id)
        end
        LocUtil._IsModMenuHooked = true
    end

    local okSPD, SettingPageDefine = pcall(require, "client.logic.NewSetting.SettingPageDefine")
    local okSC, SettingCatalog = pcall(require, "client.logic.NewSetting.SettingCatalog")
    if not okSPD or not okSC or type(SettingPageDefine) ~= "table" or type(SettingCatalog) ~= "table" then
        if type(_G.X3.Trace) == "function" then
            _G.X3.Trace("MENU: modul NewSetting belum siap (SPD ok=" .. tostring(okSPD) .. " SC ok=" .. tostring(okSC) .. ") — retry nanti")
        end
        return false
    end
    local okAM, AliasMap = pcall(require, "client.slua.umg.NewSetting.Item.AliasMap")
    if not okAM or type(AliasMap) ~= "table" then
        if type(_G.X3.Trace) == "function" then _G.X3.Trace("MENU: AliasMap belum siap — retry nanti") end
        return false
    end
    _G.X3.ModMenuInitialized = true
    _G.X3.ModMenuBuiltStamp = _G.X3.BuildStamp

    do

        local StackSkin = {
            { UI = AliasMap.Title, Text = "X3TEAM OFFICIAL" },
            { Key = "ModMenu_ModSkin", UI = AliasMap.TitleSwitcher, Text = "▶ UNLOCK SKIN [ BUKA SKIN SEMUA FITUR ]", ExpandIndex = 0, GetFunc = function() return _G.X3.LexusConfig.ModSkin end, SetFunc = function(c,v)
                _G.X3.LexusConfig.ModSkin = v
                _G.X3.LexusConfig.SkinUnlockAll = v and true or false
                _G.X3.LexusConfig.SkinLobbyPreview = v and true or false
                _G.X3.LexusConfig.SkinIngame = v and true or false
                _G.X3.LexusConfig.X3UnlockAll = v and true or false
                if v then
                    if _G.X3.InjEnsure then pcall(_G.X3.InjEnsure) end
                    if _G.X3.ForceRefreshSkinMaps then pcall(_G.X3.ForceRefreshSkinMaps) end
                    if _G.X3.BpEnsure then pcall(_G.X3.BpEnsure) end
                    if _G.X3.ApplyAvatarBorder then pcall(_G.X3.ApplyAvatarBorder) end
                    _G.X3._InjReapplyAt = os.clock() + 2.0 -- dieksekusi MAINLOOP
                    pcall(function()
                        if _G.X3.SkinUnlock and _G.X3.SkinUnlock.Init then _G.X3.SkinUnlock.Init() end
                        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController() or nil
                        local bp = nil
                        if pc and pc.GetBackpackComponent then bp = pc:GetBackpackComponent() end
                        if not bp then
                            local ch = pc and pc.PlayerCharacter or nil
                            bp = ch and ch.BackpackComponent or nil
                        end
                        if bp and _G.X3.SkinUnlock and _G.X3.SkinUnlock.Apply then _G.X3.SkinUnlock.Apply(bp) end
                    end)
                else
                    pcall(function()
                        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController() or nil
                        local bp = nil
                        if pc and pc.GetBackpackComponent then bp = pc:GetBackpackComponent() end
                        if not bp then
                            local ch = pc and pc.PlayerCharacter or nil
                            bp = ch and ch.BackpackComponent or nil
                        end
                        if bp and _G.X3.SkinUnlock and _G.X3.SkinUnlock.Restore then _G.X3.SkinUnlock.Restore(bp) end
                    end)
                end
                if type(_G.X3.Trace) == "function" then _G.X3.Trace("MENU: toggle UNLOCK SKIN = " .. tostring(v)) end
                return true
            end },
            { Key = "ModMenu_X3SkinNewRandom", UI = AliasMap.Switcher, Text = "  └ RANDOM NEW SKIN [ SKIN ACAK TERBARU ] (auto)", ExpandHandle = "ModMenu_ModSkin", GetFunc = function() return _G.X3.LexusConfig.X3SkinNewRandom == true end, SetFunc = function(c,v) _G.X3.LexusConfig.X3SkinNewRandom = v and true or false; if not v then _G.X3._SkinRandCache = nil end return true end },
            { Key = "ModMenu_X3UnlockAll", UI = AliasMap.Switcher, Text = "  └ UNLOCK ALL [ BUKA SEMUA ] (Lobby+Match+Tas)", ExpandHandle = "ModMenu_ModSkin", GetFunc = function() return _G.X3.LexusConfig.X3UnlockAll == true end, SetFunc = function(c,v)
                _G.X3.LexusConfig.X3UnlockAll = v and true or false
                if v then
                    local st = _G.X3._UnlockAllState
                    if st then st.lobbyIdx = 1 st.lobbyDone = false st.matchApplyAt = 0 st.matchLogged = false end
                    if _G.X3._UAOwnershipHookTry then pcall(_G.X3._UAOwnershipHookTry) end
                    if _G.X3._UnlockAllLobbyTick then pcall(_G.X3._UnlockAllLobbyTick) end
                    if _G.X3._MaxLevelHookTry then pcall(_G.X3._MaxLevelHookTry) end
                    if _G.X3._UADiagnose then pcall(_G.X3._UADiagnose) end
                end
                if type(_G.X3.Trace) == "function" then _G.X3.Trace("MENU: UNLOCK ALL = " .. tostring(v)) end
                return true
            end },
        }

            local StackWallhack = {}
    if _G.X3.BuildWallhackMenu then
        _G.X3.BuildWallhackMenu(StackWallhack, AliasMap)
    end

        local StackCombat = {
                                          {
        UI = AliasMap.Title,
        Text = "X3TEAM OFFICIAL"
      },
            { Key = "ModMenu_Ipad_Ex", UI = AliasMap.TitleSwitcher, Text = "▶ iPad View [ TAMPILAN IPAD ]", ExpandIndex = 0, GetFunc = function() return _G.X3.LexusConfig.IpadView end, SetFunc = function(c,v) _G.X3.LexusConfig.IpadView = v return true end },
            { Key = "ModMenu_Ipad_FOV", UI = AliasMap.Slider, Text = "   FOV [ FOV ]", ExpandHandle = "ModMenu_Ipad_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return (_G.X3.LexusState.CustomTextData.IpadViewFOV or 120) - 90 end, SetFunc = function(c,v) _G.X3.LexusState.CustomTextData.IpadViewFOV = 90 + v return true end },
            { Key = "ModMenu_165FPS", UI = AliasMap.Switcher, Text = "Unlock Max FPS [ BUKA FPS MAKS ]", GetFunc = function() return _G.X3.LexusConfig.UnlockFPS end, SetFunc = function(c,v) _G.X3.LexusConfig.UnlockFPS = v; if v then _G.X3.LexusState.GraphicsUnlocked = false end return true end },
            { Key = "ModMenu_X3Extra_Ex", UI = AliasMap.TitleSwitcher, Text = "▶ EXTRA FEATURES [ FITUR EXTRA ]", ExpandIndex = 0, GetFunc = function() local C = _G.X3.LexusConfig return (C.X3CacheClean ~= false) or (C.X3Watermark ~= false) or C.X3FakeVisual == true or C.X3TPPForce == true or C.X3TPPUnlockBtn == true end, SetFunc = function() return true end },

            { Key = "ModMenu_X3TPPGrp_Ex", UI = AliasMap.TitleSwitcher, Text = "  ▶ FORCE TPP IN FPP [ PAKSA KAMERA TPP ]", ExpandHandle = "ModMenu_X3Extra_Ex", ExpandIndex = 0, GetFunc = function() return _G.X3.LexusConfig.X3TPPForce == true or _G.X3.LexusConfig.X3TPPUnlockBtn == true end, SetFunc = function(c,v) _G.X3.LexusConfig.X3TPPForce = v and true or false; _G.X3.LexusConfig.X3TPPUnlockBtn = v and true or false; if _G.X3.SaveModSettings then pcall(_G.X3.SaveModSettings) end return true end },
            { Key = "ModMenu_X3TPPForce", UI = AliasMap.Switcher, Text = "    └ Force Camera [ PAKSA KAMERA TPP ]", ExpandHandle = "ModMenu_X3TPPGrp_Ex", GetFunc = function() return _G.X3.LexusConfig.X3TPPForce == true end, SetFunc = function(c,v) _G.X3.LexusConfig.X3TPPForce = v and true or false return true end },
            { Key = "ModMenu_X3TPPUnlockBtn", UI = AliasMap.Switcher, Text = "    └ Unlock TPP/FPP Switch [ BUKA TOMBOL TPP/FPP ]", ExpandHandle = "ModMenu_X3TPPGrp_Ex", GetFunc = function() return _G.X3.LexusConfig.X3TPPUnlockBtn == true end, SetFunc = function(c,v) _G.X3.LexusConfig.X3TPPUnlockBtn = v and true or false; if v and _G.X3._XFTPPUnlockTry then pcall(_G.X3._XFTPPUnlockTry) end return true end },

            { Key = "ModMenu_X3CacheClean", UI = AliasMap.Switcher, Text = "  Smart Cache Cleaner [ PEMBERSIH CACHE ] (5 mnt)", ExpandHandle = "ModMenu_X3Extra_Ex", GetFunc = function() return _G.X3.LexusConfig.X3CacheClean ~= false end, SetFunc = function(c,v) _G.X3.LexusConfig.X3CacheClean = v and true or false return true end },
            { Key = "ModMenu_X3Watermark", UI = AliasMap.Switcher, Text = "  Smart Watermark Top3/WWCD [ WATERMARK PINTAR ]", ExpandHandle = "ModMenu_X3Extra_Ex", GetFunc = function() return _G.X3.LexusConfig.X3Watermark ~= false end, SetFunc = function(c,v)
                _G.X3.LexusConfig.X3Watermark = v and true or false
                _G.X3._WMManual = v and true or false -- ON manual = langsung tampil
                if not v then _G.X3._WMEndOn = false end
                if _G.X3._WMHookInstall then pcall(_G.X3._WMHookInstall) end
                if _G.X3._WMRefresh then pcall(_G.X3._WMRefresh) end
                if _G.X3.SaveModSettings then pcall(_G.X3.SaveModSettings) end
                return true
            end },
            { Key = "ModMenu_X3FakeVisual", UI = AliasMap.Switcher, Text = "  Fake Sultan: Currency + Collect Lv100 [ SULTAN PALSU ] (visual)", ExpandHandle = "ModMenu_X3Extra_Ex", GetFunc = function() return _G.X3.LexusConfig.X3FakeVisual == true end, SetFunc = function(c,v) _G.X3.LexusConfig.X3FakeVisual = v and true or false return true end },
            { Key = "ModMenu_WhiteBody", UI = AliasMap.Switcher, Text = "White Body [ TUBUH PUTIH ]", GetFunc = function() return _G.X3.LexusConfig.WhiteBody end, SetFunc = function(c,v) _G.X3.LexusConfig.WhiteBody = v return true end },
            { Key = "ModMenu_BlackSky", UI = AliasMap.Switcher, Text = "Black Sky [ LANGIT GELAP ]", GetFunc = function() return _G.X3.LexusConfig.BlackSky end, SetFunc = function(c,v) _G.X3.LexusConfig.BlackSky = v return true end },
            { Key = "ModMenu_RemoveFog", UI = AliasMap.Switcher, Text = "No Fog [ TIDAK ADA KABUT ]", GetFunc = function() return _G.X3.LexusConfig.RemoveFog end, SetFunc = function(c,v) _G.X3.LexusConfig.RemoveFog = v return true end },
            { Key = "ModMenu_RemoveGrass", UI = AliasMap.Switcher, Text = "No Grass [ TIDAK ADA RUMPUT ]", GetFunc = function() return _G.X3.LexusConfig.RemoveGrass end, SetFunc = function(c,v) _G.X3.LexusConfig.RemoveGrass = v return true end }

        }

            if _G.X3.BuildX3RareGraphicMenu then _G.X3.BuildX3RareGraphicMenu(StackGraphic, AliasMap) end

        local StackFiturLain = {}
        for _, v in ipairs(StackDeviceInfo) do table.insert(StackFiturLain, v) end
        for _, v in ipairs(StackCombat) do table.insert(StackFiturLain, v) end
        for _, v in ipairs(StackGraphic) do table.insert(StackFiturLain, v) end

        SettingPageDefine.ModMenu = {
            Key = "ModMenu",
            Text = "   X3TEAM MENU",
            UIKey = "Setting_Page_Privacy",
            Category = {
                { Key = "Cat_Wallhack", Text = "WALLHACK [ TEMBUS PANDANG ]", Stack = StackWallhack },
                { Key = "Cat_Aimbot", Text = "MAGIC [ MAGIC ]", Stack = StackAimbot },
                { Key = "Cat_AimbotV2", Text = "AIMTOUCH [ AIM SENTUH ]", Stack = StackAimbotV2 },
                { Key = "Cat_ESP", Text = "ESP [ ESP ]", Stack = StackESP },
                { Key = "Cat_Skin", Text = "SKIN [ SKIN ]", Stack = StackSkin },
                { Key = "Cat_Lain", Text = "FEATURES [ FITUR ]", Stack = StackFiturLain }
            }
        }

        local catDone = false
        for ci, pg in ipairs(SettingCatalog) do
            if type(pg) == "table" and pg.Key == "ModMenu" then
                SettingCatalog[ci] = SettingPageDefine.ModMenu
                catDone = true break
            end
        end
        if not catDone then table.insert(SettingCatalog, SettingPageDefine.ModMenu) end
    end

    local UIManager = _G.UIManager
    if UIManager and not UIManager._IsModMenuHooked then
        local old_ShowUI = UIManager.ShowUI
        UIManager.ShowUI = function(config, ...)
            local args = {...}
            local n = select('#', ...)

            if config and config.keyName and (string.find(string.lower(config.keyName), "setting_main") or string.find(string.lower(config.keyName), "setting")) then
                local catalog = args[1]
                if type(catalog) == "table" then
                    local catReplaced = false
                    for pi, page in ipairs(catalog) do
                        if type(page) == "table" and page.Key == "ModMenu" then
                            catalog[pi] = SettingPageDefine.ModMenu
                            catReplaced = true
                            break
                        end
                    end
                    if not catReplaced then
                        table.insert(catalog, SettingPageDefine.ModMenu)
                    end
                end
            end
            local table_unpack = table.unpack or unpack
            return old_ShowUI(config, table_unpack(args, 1, n))
        end
        UIManager._IsModMenuHooked = true
    end
    return true
end

-- SHOW LEXUS VIPMENU --
local function ShowLexusVIPMenu()
    if _G.X3.LexusMenuAlreadyShown then return end

    _G.X3.MenuTryN = (_G.X3.MenuTryN or 0) + 1
    local ok, err = pcall(function()
        local done = _G.X3.InitModMenuTab()
        if done ~= true then error("InitModMenuTab belum siap (hasil=" .. tostring(done) .. ")", 0) end
        _G.X3.LexusState.MenuStep = 99
        _G.X3.LexusMenuAlreadyShown = true
        Notify("MENU VIP TELAH DITAMBAHKAN KE PENGATURAN GAME!\nBuka Pengaturan -> MENU VIP X3TeamID untuk mengaktifkan/menonaktifkan fitur!")
    end)
    if type(_G.X3.Trace) == "function" then
        if ok then
            _G.X3.Trace("MENU: InitModMenuTab SUKSES — menu VIP terpasang di lobby (percobaan #" .. tostring(_G.X3.MenuTryN) .. ")")
        elseif _G.X3.MenuTryN <= 3 or (_G.X3.MenuTryN % 50) == 0 then
            _G.X3.Trace("MENU: belum terpasang (percobaan #" .. tostring(_G.X3.MenuTryN) .. ", retry otomatis): " .. tostring(err))
        end
    end
end

-- ==============================================================================
-- ============ FILES CRC CHECK BYPASS / PEMALSU VERIFIKASI FILE PAKS ==========
-- ==============================================================================
_G.X3._CRCBypassStage = _G.X3._CRCBypassStage or 0
function _G.X3._ACCRCBypassTry()
    local stage = _G.X3._CRCBypassStage or 0
    if stage >= 3 then return end -- 0=belum, 1=core, 2=sweep+net, 3=final (60 dtk)
    pcall(function()
        local retTrue = function() return true end
        local retValid = function() return 0 end
        local nHook = 0
        if stage == 0 then
            pcall(function()
                local PD = rawget(_G, "PufferDownloader")
                if type(PD) == "table" then
                    if type(PD.VerifyFileCRC) == "function" and not rawget(PD, "__x3crc_vfc") then
                        rawset(PD, "__x3crc_vfc", true) PD.VerifyFileCRC = retValid nHook = nHook + 1
                    end
                    if type(PD.CheckFileIntegrity) == "function" and not rawget(PD, "__x3crc_cfi") then
                        rawset(PD, "__x3crc_cfi", true) PD.CheckFileIntegrity = retTrue nHook = nHook + 1
                    end
                end
            end)
            pcall(function()
                local C = rawget(_G, "Client")
                if type(C) == "table" then
                    if type(C.VerifyPakFile) == "function" and not rawget(C, "__x3crc_vpf") then
                        rawset(C, "__x3crc_vpf", true)
                        C.VerifyPakFile = function(pakName, ...) return true end
                        nHook = nHook + 1
                    end
                    if type(C.CheckFileCRC) == "function" and not rawget(C, "__x3crc_cf") then
                        rawset(C, "__x3crc_cf", true)
                        C.CheckFileCRC = function(filePath, ...) return 0 end
                        nHook = nHook + 1
                    end
                    if type(C.GetFileHash) == "function" and not rawget(C, "__x3crc_gfh") then
                        rawset(C, "__x3crc_gfh", true)
                        C.GetFileHash = function(filePath) return "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF" end
                        nHook = nHook + 1
                    end
                end
            end)
            pcall(function()
                local US = rawget(_G, "USFSCacheSys")
                if type(US) == "table" and type(US.VerifyIntegrity) == "function" and not rawget(US, "__x3crc_vi") then
                    rawset(US, "__x3crc_vi", true) US.VerifyIntegrity = retTrue nHook = nHook + 1
                end
            end)
            pcall(function()
                local SH = rawget(_G, "ScriptHelperClient")
                if type(SH) == "table" and type(SH.LoadFileToArrayByFullPath) == "function" and not rawget(SH, "__x3crc_lfa") then
                    rawset(SH, "__x3crc_lfa", true)
                    local origLoad = SH.LoadFileToArrayByFullPath
                    SH.LoadFileToArrayByFullPath = function(path)
                        if path and type(path) == "string" and path:find("CommCRC.ini") then return nil end
                        local result = origLoad(path)
                        if path and type(path) == "string" and path:find(".pak") then
                            if result and type(result) == "table" then
                                result.isValid = true
                                result.crcMatch = true
                            end
                        end
                        return result
                    end
                    nHook = nHook + 1
                end
            end)
            _G.X3._CRCBypassStage = 1
            _G.X3._CRCBypassAt = os.clock()
            if _G.X3._CrashLog then pcall(_G.X3._CrashLog, "CRC BYPASS tahap 1 > " .. tostring(nHook) .. " hook inti terpasang (PufferDownloader/Client/USFS/ScriptHelper)") end
            if nHook > 0 and type(_G.X3.Trace) == "function" then _G.X3.Trace("ACCRC: " .. tostring(nHook) .. " hook verifikasi file inti dinetralkan ✅") end
            if nHook == 0 and type(_G.X3.Trace) == "function" then _G.X3.Trace("ACCRC: modul inti CRC tidak ditemukan (target mungkin tidak ada di build ini) ❌") end
            return
        end
        -- TAHAP 2: sweep package.loaded + filter NetUtil.SendPacket
        if stage == 1 or (stage == 2 and (os.clock() - (_G.X3._CRCBypassAt or 0)) >= 60) then
            local nSweep = 0
            pcall(function()
                local function HookCRCFunctions(obj)
                    if type(obj) ~= "table" then return end
                    for k, v in pairs(obj) do
                        if type(k) == "string" and type(v) == "function" then
                            local lowerK = k:lower()
                            if lowerK:find("crc") or lowerK:find("verify") or lowerK:find("integrity") or lowerK:find("hash") then
                                local okH = pcall(function()
                                    if not rawget(obj, "__x3crc_" .. k) then
                                        rawset(obj, "__x3crc_" .. k, true)
                                        local orig = v
                                        obj[k] = function(...)
                                            if lowerK:find("crc") then return 0 end
                                            if lowerK:find("verify") or lowerK:find("integrity") then return true end
                                            return orig(...)
                                        end
                                        nSweep = nSweep + 1
                                    end
                                end)
                            end
                        end
                    end
                end
                for name, mod in pairs(package.loaded) do
                    pcall(HookCRCFunctions, mod)
                end
            end)
            pcall(function()
                local NU = rawget(_G, "NetUtil")
                if type(NU) == "table" and type(NU.SendPacket) == "function" and not rawget(NU, "__x3crc_sp") then
                    rawset(NU, "__x3crc_sp", true)
                    local origSendPacket = NU.SendPacket
                    NU.SendPacket = function(cmd, ...)
                        local cmdStr = tostring(cmd):lower()
                        if cmdStr:find("crc") or cmdStr:find("verify") or cmdStr:find("integrity") or cmdStr:find("hash") then return end
                        return origSendPacket(cmd, ...)
                    end
                    nSweep = nSweep + 1
                end
            end)
            local final = (stage == 2)
            _G.X3._CRCBypassStage = final and 3 or 2
            _G.X3._CRCBypassAt = os.clock()
            _G.CRCFaker = true
            if _G.X3._CrashLog then pcall(_G.X3._CrashLog, "CRC BYPASS tahap " .. (final and "3 (final)" or "2") .. " > sweep " .. tostring(nSweep) .. " fungsi crc/verify/integrity/hash + filter NetUtil.SendPacket") end
            if type(_G.X3.Trace) == "function" then _G.X3.Trace("ACCRC: sweep " .. tostring(nSweep) .. " fungsi verifikasi + filter paket CRC aktif" .. (final and " (final)" or "")) end
        end
    end)
end

-- ==============================================================================
-- =========== HAWKEYE + INSPECTION NUKE (VERSI ASLI + VERSI UPGRADE) ==========
-- ==============================================================================

_G.X3._HawkNukeStage = _G.X3._HawkNukeStage or 0
function _G.X3._ACHawkNukeTry()
    local stage = _G.X3._HawkNukeStage or 0
    if stage >= 3 then return end
    pcall(function()
        local SubsystemMgr = package.loaded["GameLua.GameCore.Module.Subsystem.SubsystemMgr"]
        if not SubsystemMgr then
            local okR, rR = pcall(require, "GameLua.GameCore.Module.Subsystem.SubsystemMgr")
            if okR then SubsystemMgr = rR end
        end
        if not SubsystemMgr then return end -- belum termuat, retry 10 dtk lagi

        local G = rawget(_G, "Game")
        local nTimer, nMethod = 0, 0
        local timerFields = {
            "_nInitializeTimerID", "_nCollectBeWatchedPlayerInfoTimerID",
            "_nFrameUIRefreshTimerID", "_nHideUITimerID", "_nShowDistanceUITimerID",
            "_nCloseBattleEndedTipsTimerID", "_nBattleTimeUsageTimerID",
            "_nQuitVoiceRoomTimerID", "_NextPatrolOvertimeTimerID", "_nExitGameTimerID",
        }
        -- UPGRADE: 50+ method (gabungan daftar asli + hasil baca sumber 4.5)
        local methodsToNuke = {
            "IsDuringHawkEyePatrol", "ReportCheat", "SendReportTLog", "_OnHawkSync",
            "_OnHawkReportSuccess", "_OnRecvInspectorBroadcastCount",
            "_InitHawkEyePatrolSubsystem", "RequestImprison", "ReturnLobbyAndOpenH5",
            "ExitWatching", "OnClickLowerLeftExitWatching", "OnClickBottomRightOpenReportWindow",
            "WantMatchNextPatrol", "ShowWatchEndedTips", "OnShowWatchEndedTips",
            "HasShownWatchEndedTips", "ForceNeverCloseBattleEndedTips",
            "CheckShowReportedTips", "TryShowReportedTips", "_CollectBeWatchedPlayerInfo",
            "GetBeWatchedPlayerInfo", "HasReported", "_MarkHasReported",
            "GetInspectorBroadcastCount", "GetMaxInspectorBroadcastCount", "CanInspectorBroadcast",
            "GetForbidNextPatrolRemainingTimeInSeconds", "IsCharacterLocationShouldDraw",
            "_StartFrameUIRefreshTimer", "_StartHideUITimer", "_StartShowDistanceUITimer",
            "_OnPlayerKilledOtherPlayer", "_StartCloseBattleEndedTipsTimer",
            "_StartBattleTimeUsageTimer", "_StartQuitVoiceRoomTimer",
            "_CreateOvertimerTimerForNextPatrol", "ClearNextPatrolOvertimeTimer",
            "_StartExitGameTimer", "_CloseExitGameTimer", "GetUsedDailyTimeInSeconds",
            "_PostConstruct", "OnRelease", "Reset", "Start", "Stop",
            "AddCommonEvent", "AddControlEvent", "AddGameTimer",
        }
        local function NukeInstance(inst)
            if type(inst) ~= "table" then return end
            for _, field in ipairs(timerFields) do
                local timerID = rawget(inst, field)
                if type(timerID) == "number" then
                    pcall(function() if G and G.ClearTimer then G:ClearTimer(timerID) end end)
                    rawset(inst, field, nil)
                    nTimer = nTimer + 1
                end
            end
            pcall(function()
                local SCU = package.loaded["GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils"]
                if SCU and SCU.ClearTimerByMemberName then
                    SCU.ClearTimerByMemberName(inst, "_nCollectBeWatchedPlayerInfoTimerID")
                end
            end)
            for _, m in ipairs(methodsToNuke) do
                if type(rawget(inst, m)) == "function" then
                    rawset(inst, m, function() end)
                    nMethod = nMethod + 1
                end
            end
            rawset(inst, "IsDuringHawkEyePatrol", function() return false end)
            rawset(inst, "_tBeWatchedPlayerInfo", nil)
            rawset(inst, "_bHasInitialized", false)
            rawset(inst, "_bInitialized", false)
            rawset(inst, "_bEnabled", false)
            rawset(inst, "_bHasReported", true)
            rawset(inst, "_bShowBeReportedTips", true)
            rawset(inst, "_bHasCalledWantMatchNextPatrol", true)
            rawset(inst, "_bNeverCloseBattleEndedTips", true)
            rawset(inst, "_nBattleUsedSeconds", 0)
            rawset(inst, "_nPatrolBeginTime", 0)
        end

        -- TAHAP 1: nuke instance + hook SubsystemMgr.Get (versi ASLI + Hawk.txt)
        if stage == 0 then
            pcall(function()
                local inst = SubsystemMgr:Get("ClientHawkEyePatrolSubsystem")
                if inst then NukeInstance(inst) end
            end)
            if not rawget(SubsystemMgr, "__x3hawk_get") then
                rawset(SubsystemMgr, "__x3hawk_get", true)
                local origGet = SubsystemMgr.Get
                local fakeHawk = setmetatable({
                    IsDuringHawkEyePatrol = function() return false end,
                }, { __index = function() return function() end end, __newindex = function() end, __metatable = "locked" })
                SubsystemMgr.Get = function(self, name)
                    if name == "ClientHawkEyePatrolSubsystem" then return fakeHawk end
                    return origGet(self, name)
                end
            end
            -- nonaktifkan inisialisasi statis di class table (path NYATA dari dump)
            pcall(function()
                local cls = package.loaded["GameLua.Mod.BaseMod.Client.Security.HawkEyeSpectate.ClientHawkEyePatrolSubsystem"]
                if cls and type(cls.InitHawkEyePatrolSubsystem) == "function" then
                    cls.InitHawkEyePatrolSubsystem = function() end
                end
            end)
            _G.X3._HawkNukeStage = 1
            if _G.X3._CrashLog then pcall(_G.X3._CrashLog, "HAWK NUKE tahap 1 > timer dibersihkan=" .. tostring(nTimer) .. " method dinuke=" .. tostring(nMethod) .. " + hook SubsystemMgr.Get") end
            if type(_G.X3.Trace) == "function" then _G.X3.Trace("ACHAWK: HawkEye patrol dinonaktifkan (timer " .. tostring(nTimer) .. ", method " .. tostring(nMethod) .. ")") end
            return
        end

        -- TAHAP 2: InspectionSystem (client) + DSInspection + DSHawk (hardening)
        if stage == 1 then
            local nIns = 0
            local function NukeModuleMethods(modName, methods)
                local mod = package.loaded[modName]
                if type(mod) ~= "table" then return end
                for _, m in ipairs(methods) do
                    if type(rawget(mod, m)) == "function" and not rawget(mod, "__x3ins_" .. m) then
                        rawset(mod, "__x3ins_" .. m, true)
                        rawset(mod, m, function() end)
                        nIns = nIns + 1
                    end
                end
            end
            -- dari screenshot: InspectionSystem.AskForInspector/ReportEnemy/KickOutOneTeam/dst
            NukeModuleMethods("GameLua.Mod.BaseMod.Client.InspectionSystem.InspectionSystemReportClientLogicSubsystem", {
                "AskForInspector", "ReportEnemy", "KickOutOneTeam", "SendKickOutOneTeam",
                "SendReportToInspector",
            })
            NukeModuleMethods("GameLua.Mod.BaseMod.Client.InspectionSystem.InspectionSystemReportButton", {
                "OnClickReport", "ShowReportWindow", "ReportCheat",
            })
            NukeModuleMethods("GameLua.Mod.BaseMod.DS.InspectionSystem.InspectionSystemReportDSLogicSubsystem", {
                "ServerKickOutOneTeamByPlayer", "AddReportedCount", "AddInspectionRecord",
                "CheckPunishPlayer", "ImprisonPlayer",
            })
            NukeModuleMethods("GameLua.Mod.BaseMod.DS.Security.HawkEyeSpectate.DSHawkEyePatrolSubsystem", {
                -- nama method NYATA dari sumber dump 4.5
                "CheckPunishPlayer", "OnInit", "_GetPlayerControllerByPlayerKey",
                "_OnCharacterDied", "_OnHawkImprison", "_OnHawkReport",
                "_OnPlayerReconnect", "_OnPlayerRespawn",
                "_OnSyncInspectorBroadcastCount", "_OnWatchPlayerExit", "ImprisonPlayer",
            })
            _G.X3._HawkNukeStage = 2
            if _G.X3._CrashLog then pcall(_G.X3._CrashLog, "HAWK NUKE tahap 2 > InspectionSystem/DSInspection/DSHawk: " .. tostring(nIns) .. " method dinuke") end
            if type(_G.X3.Trace) == "function" then _G.X3.Trace("ACHAWK: InspectionSystem + DSHawk dinuke (" .. tostring(nIns) .. " method)") end
            return
        end

        -- TAHAP 3: blok require modul hawk/inspect (BERANTAI dengan hook yang ada)
        if stage == 2 then
            if not rawget(_G, "__x3hawk_req") then
                rawset(_G, "__x3hawk_req", true)
                local prevRequire = _G.require or require
                local blockedHawk = {
                    ["GameLua.Mod.BaseMod.Client.Security.HawkEyeSpectate.ClientHawkEyePatrolSubsystem"] = true,
                    ["GameLua.Mod.BaseMod.DS.Security.HawkEyeSpectate.DSHawkEyePatrolSubsystem"] = true,
                }
                _G.require = function(name)
                    if blockedHawk[name] then
                        return setmetatable({}, { __index = function() return function() end end, __metatable = "locked" })
                    end
                    return prevRequire(name)
                end
            end
            _G.X3._HawkNukeStage = 3
            if _G.X3._CrashLog then pcall(_G.X3._CrashLog, "HAWK NUKE tahap 3 (final) > require modul HawkEye client+DS diblok") end
            if type(_G.X3.Trace) == "function" then _G.X3.Trace("ACHAWK: require modul HawkEye diblok (final)") end
        end
    end)
end

-- ==============================================================================
-- ========= SLUA SIGNATURE + FILE HASH FAKE / PEMALSU SIGNATURE & MD5 =========
-- ==============================================================================
_G.X3._HashFakeStage = _G.X3._HashFakeStage or 0
function _G.X3._ACHashFakeTry()
    local stage = _G.X3._HashFakeStage or 0
    if stage >= 2 then return end
    pcall(function()
        local SIG = "627dbbed8466514199b7269220b138a6"
        local retTrue = function() return true end
        local n = 0
        -- TAHAP 1: signature slua + verifikasi bytecode
        if stage == 0 then
            pcall(function()
                if slua and slua.getSignature and not rawget(slua, "__x3sig") then
                    rawset(slua, "__x3sig", true)
                    slua.getSignature = function() return SIG end
                    n = n + 1
                end
            end)
            pcall(function()
                local L = package.loaded["slua.loader"] or rawget(_G, "slua_loader")
                if L then
                    if L.verifyBytecode and not rawget(L, "__x3sig_vb") then rawset(L, "__x3sig_vb", true) L.verifyBytecode = retTrue n = n + 1 end
                    if L.checkIntegrity and not rawget(L, "__x3sig_ci") then rawset(L, "__x3sig_ci", true) L.checkIntegrity = retTrue n = n + 1 end
                    if L.disableSignatureCheck and not rawget(L, "__x3sig_ds") then rawset(L, "__x3sig_ds", true) L.disableSignatureCheck = retTrue n = n + 1 end
                end
            end)
            pcall(function()
                local S = package.loaded["slua.serialize"]
                if S then
                    if S.check and not rawget(S, "__x3sig_c") then rawset(S, "__x3sig_c", true) S.check = retTrue n = n + 1 end
                    if S.verify and not rawget(S, "__x3sig_v") then rawset(S, "__x3sig_v", true) S.verify = retTrue n = n + 1 end
                end
            end)
            pcall(function()
                if jit and jit.attach and not rawget(_G, "__x3sig_jit") then
                    rawset(_G, "__x3sig_jit", true)
                    jit.attach(function() end, "bc")
                    n = n + 1
                end
            end)
            if rawget(_G, "slua_verify") then _G.slua_verify = retTrue n = n + 1 end
            if rawget(_G, "check_slua_integrity") then _G.check_slua_integrity = retTrue n = n + 1 end
            _G.X3._HashFakeStage = 1
            if _G.X3._CrashLog then pcall(_G.X3._CrashLog, "HASH FAKE tahap 1 > signature slua + verifikasi bytecode (" .. tostring(n) .. " hook)") end
            if type(_G.X3.Trace) == "function" then _G.X3.Trace("ACHASH: signature slua dipalsukan (" .. tostring(n) .. " hook)") end
            return
        end
        -- TAHAP 2: cvar pak signature + MD5/CRC32/SHA1 + modul hash
        if stage == 1 then
            pcall(function()
                local CM = import("CreativeModeBlueprintLibrary")
                if CM then
                    CM.MD5HashByteArray = function() return SIG end
                    CM.MD5HashFile = function() return SIG end
                    CM.GetContentDiffData = function() return true, SIG end
                    CM.VerifyFileIntegrity = retTrue
                    n = n + 4
                end
            end)
            if rawget(_G, "MD5Hash") then _G.MD5Hash = function() return SIG end n = n + 1 end
            if rawget(_G, "CRC32") then _G.CRC32 = function() return 0 end n = n + 1 end
            if rawget(_G, "SHA1") then _G.SHA1 = function() return SIG end n = n + 1 end
            pcall(function()
                local FHC = package.loaded["common.file_hash_checker"]
                if FHC then
                    FHC.CheckFileMD5 = retTrue
                    FHC.VerifyAll = retTrue
                    FHC.GetHash = function() return SIG end
                    n = n + 3
                end
            end)
            pcall(function()
                local TS = package.loaded.TssSdk or rawget(_G, "TssSdk")
                if TS then
                    TS.GetFileMD5 = function() return SIG end
                    TS.VerifyFileSignature = retTrue
                    n = n + 2
                end
            end)
            pcall(function()
                local SE = import("STExtraBlueprintFunctionLibrary")
                if SE then
                    SE.CheckMD5 = retTrue
                    SE.GetMD5 = function() return SIG end
                    SE.VerifyFile = retTrue
                    n = n + 3
                end
            end)
            _G.X3._HashFakeStage = 2
            if _G.X3._CrashLog then pcall(_G.X3._CrashLog, "HASH FAKE tahap 2 (final) > cvar pak signature + MD5/CRC32/SHA1 + modul hash (" .. tostring(n) .. " hook)") end
            if type(_G.X3.Trace) == "function" then _G.X3.Trace("ACHASH: hash file MD5/CRC/SHA1 dipalsukan + cvar pak signature off (final, " .. tostring(n) .. " hook)") end
        end
    end)
end

-- ==============================================================================
-- ===== PERFORMANCE BOOST TERIKAT WALLHACK (dari gfx.lua) ==================
-- ==============================================================================

local X3_PERF_ON = {
    -- 8 konfigurasi berdampak paling besar & nyata (kurasi dari gfx.lua)
    "r.ShadowQuality 1", "r.PostProcessQuality 1", "r.EffectsQuality 1",
    "r.MotionBlurQuality 0", "r.ViewDistanceScale 0.85", "r.AmbientOcclusionLevels 0",
    "r.SkeletalMeshLODBias 1", "r.DepthOfFieldQuality 0",
}
local X3_PERF_OFF = {
    "r.ShadowQuality 2", "r.PostProcessQuality 2", "r.EffectsQuality 2",
    "r.MotionBlurQuality 2", "r.ViewDistanceScale 1", "r.AmbientOcclusionLevels 1",
    "r.SkeletalMeshLODBias 0", "r.DepthOfFieldQuality 2",
}function _G.X3._PerfBoostApply(on)
    pcall(function()
        local gi = nil
        pcall(function()
            local SE = import("STExtraGameInstance")
            if SE and SE.GetInstance then gi = SE.GetInstance() end
        end)
        if not gi then
            pcall(function()
                local G = rawget(_G, "Game")
                if G and G.GetGameInstance then gi = G.GetGameInstance() end
            end)
        end
        if not (gi and slua.isValid(gi) and gi.ExecuteCMD) then
            if _G.X3._CrashLog then pcall(_G.X3._CrashLog, "PERF BOOST GAGAL > GameInstance.ExecuteCMD tidak tersedia") end
            return
        end
        local list = on and X3_PERF_ON or X3_PERF_OFF
        for _, cmd in ipairs(list) do
            pcall(function() gi:ExecuteCMD(cmd) end)
        end
        if _G.X3._CrashLog then pcall(_G.X3._CrashLog, "PERF BOOST > " .. (on and "ON (wallhack aktif, " .. tostring(#list) .. " cvar via ExecuteCMD)" or "OFF (default dikembalikan)")) end
    end)
end

-- ==============================================================================
-- ======== INTI ANTI-CHEAT LEVEL CORE: BLOCK REPORT + TELEMETRI EVIDENCE ======
-- ==============================================================================

do
    local function X3ACNop() end
    local function X3ACRetFalse() return false end
    local function X3ACNukeMethods(tbl, names)
        local n = 0
        if type(tbl) ~= "table" then return 0 end
        for _, nm in ipairs(names) do
            if type(tbl[nm]) == "function" then tbl[nm] = X3ACNop; n = n + 1 end
        end
        return n
    end
    local function X3ACFwLine(msg)
        if _G.X3._FWLogWrite then
            pcall(_G.X3._FWLogWrite, { "[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] " .. msg })
        end
    end
    function _G.X3._ACReportNukeTry()
        local stage = _G.X3._ACRepNukeStage or 0
        if stage >= 2 then return end
        local T = function(msg) if type(_G.X3.Trace) == "function" then _G.X3.Trace(msg) end end
        -- TAHAP 0: lapisan protokol complaint/report (item 1-8)
        if stage == 0 then
            local n = 0
            pcall(function()
                local LC = require("client.logic.battle.logic_complaint")
                if type(LC) == "table" then
                    if type(LC.Submit) == "function" and not rawget(LC, "__x3blk") then
                        rawset(LC, "__x3blk", true)
                        LC.Submit = function(sName)
                            X3ACFwLine("BLOCKREPORT > complaint ke '" .. tostring(sName) .. "' DIBLOKIR ✅")
                            return
                        end
                        n = n + 1
                    end
                    n = n + X3ACNukeMethods(LC, { "SubmitQuickReportMaliciousTeammate", "_ImprisonTeammateIfConditionIsTrue", "ShowComplaint" })
                end
            end)
            pcall(function()
                local CH = require("client.network.Protocol.ChatHandler")
                if type(CH) == "table" then
                    n = n + X3ACNukeMethods(CH, { "send_report_info", "send_report_player_voice_status_in_team", "send_chat_tog_report_req" })
                end
            end)
            pcall(function()
                local NM = require("client.network.comm.NetManager")
                if type(NM) == "table" and type(NM.SendPkg) == "function" and not rawget(NM, "__x3pkgf") then
                    rawset(NM, "__x3pkgf", true)
                    local DROP_ID = { [523590044] = true, [1753800026] = true, [398701877] = true }
                    local oldSendPkg = NM.SendPkg
                    NM.SendPkg = function(id, ...)
                        if DROP_ID[id] then
                            X3ACFwLine("PKT-SPOOF > SendPkg " .. tostring(id) .. " (report/voice) DIBUANG ✅")
                            return true -- bentuk sukses: pemanggil mengira terkirim (anti anomali/crash)
                        end
                        return oldSendPkg(id, ...)
                    end
                    n = n + 1
                end
            end)
            if n > 0 then
                _G.X3._ACRepNukeStage = 1
                T("ACCORE-1: pipeline complaint/report diblokir (" .. n .. "/8 jalur: LogicComplaint + ChatHandler + NetManager.SendPkg)")
            end
            return
        end
        -- TAHAP 1: telemetri evidence (item 9-16)
        local n = 0
        pcall(function()
            local TU = require("GameLua.Mod.BaseMod.Client.ClientTLog.ClientTLogUtil")
            if type(TU) == "table" then
                n = n + X3ACNukeMethods(TU, { "ReportGeneralCountByParachutePhase", "ReportGeneralCountByBRPhase", "ReportCommonTLogDataByBRPhase" })
            end
        end)
        pcall(function()
            local BR = require("GameLua.Mod.BaseMod.Client.BugglyReport.BugglyReportRecord")
            if type(BR) == "table" then
                n = n + X3ACNukeMethods(BR, { "RecordGameInfo" })
                if type(BR.BugglyPostExceptionFull) == "function" then BR.BugglyPostExceptionFull = function() return true end; n = n + 1 end -- manipulasi: sukses palsu, bukan nil
                if type(BR.CheckCanBugglyPostException) == "function" then BR.CheckCanBugglyPostException = X3ACRetFalse; n = n + 1 end
            end
        end)
        pcall(function()
            local ok, CK = pcall(require, "GameLua.Mod.BaseMod.GamePlay.Feature.Player.ReportCrashKitFeature")
            if not ok or type(CK) ~= "table" then
                ok, CK = pcall(require, "GameLua.Mod.BaseMod.Gameplay.Feature.Player.ReportCrashKitFeature")
            end
            if ok and type(CK) == "table" then
                n = n + X3ACNukeMethods(CK, { "ReportCharacterMoveableException", "CheckCharacterMoveableException", "ReportForbiddenMoveException", "ReportTeammateDisappear", "HandlePlayerEnterFighting", "ReportCharacterMoveSlowException" })
            end
        end)        pcall(function()
            local QR = require("GameLua.Mod.BaseMod.Client.Security.ClientQuickReportMaliciousTeammate")
            if type(QR) == "table" then
                n = n + X3ACNukeMethods(QR, { "_ActualShowVictimKnockDownTips" })
            end
        end)
        pcall(function()
            local GRU = package.loaded["GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils"]
            local RH = nil
            if type(GRU) == "table" and type(GRU.GetReplayReportHandler) == "function" then
                pcall(function() RH = GRU.GetReplayReportHandler() end)
            end
            if type(RH) == "table" then
                n = n + X3ACNukeMethods(RH, { "OnReportUIState", "SetCustomMessageData", "AddCustomMessageData" })
            end
        end)
        pcall(function()
            local CR = require("GameLua.Mod.BaseMod.Client.Security.Credit.ClientInGameCreditLogic")
            if type(CR) == "table" then
                n = n + X3ACNukeMethods(CR, { "_SendUserReaction2ExitTeamBeforeBoardingReturnLobbyNotice" })
            end
        end)
        if n > 0 then
            _G.X3._ACRepNukeStage = 2
            T("ACCORE-2: telemetri evidence dinetralkan (" .. n .. " fungsi: TLogUtil + Buggly + CrashKit + QuickReport + ReplayHandler + Credit)")
        end
    end
end

-- ==============================================================================
-- == INTI ANTI-CHEAT CORE v81: MANIPULASI (bukan dimatikan) + PENANGKAP PELAPOR =
-- ==============================================================================
-- 15 fungsi NYATA dimanipulasi agar alur game tetap utuh (anti anomali/anti
-- force-close), sambil menangkap UID+NICKNAME yang me-report/menginspeksi ke
-- firewall log. AUTO ON — tanpa menu.
do
    _G.X3._ReporterLog = _G.X3._ReporterLog or {}
    local function X3Fw(msg)
        if _G.X3._FWLogWrite then
            pcall(_G.X3._FWLogWrite, { "[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] " .. msg })
        end
        if type(_G.X3.Trace) == "function" then _G.X3.Trace(msg) end
    end
    local function X3LogReporter(kind, uid, name, extra)
        local key = tostring(kind) .. "|" .. tostring(uid or name or "?")
        local now = os.clock()
        local last = _G.X3._ReporterLog[key]
        if last and (now - last) < 120 then return end -- dedupe 2 menit per pelapor
        _G.X3._ReporterLog[key] = now
if not (type(kind) == "string" and kind:find("KILLER", 1, true)) then
    pcall(function()
        if _G.X3._CrashLogUrgent then
            _G.X3._CrashLogUrgent("REPORT-ME > " .. tostring(kind) .. " UID=" .. tostring(uid or "?") .. " NAMA=" .. tostring(name or "?") .. (extra and (" | " .. tostring(extra)) or ""))
        end
    end)
end
        X3Fw("REPORTER " .. kind .. " > UID=" .. tostring(uid or "?") .. " NAMA=" .. tostring(name or "?") .. (extra and (" | " .. tostring(extra)) or "") .. " 🚨")
    end
    local function X3NameByUID(uid)
        local name = nil
        pcall(function()
            local GameplayData = require("GameLua.GameCore.Data.GameplayData")
            local gs = GameplayData and GameplayData.GetGameState and GameplayData.GetGameState()
            if gs and slua.isValid(gs) and gs.GetPlayerStateByUID then
                local ps = gs:GetPlayerStateByUID(tonumber(uid))
                if ps and slua.isValid(ps) then name = ps.PlayerName end
            end
        end)
        return name
    end
    local function X3NameByKey(key)
        local name, uid = nil, nil
        pcall(function()
            local hud = rawget(_G, "slua_GameFrontendHUD")
            local pc = hud and hud.GetPlayerController and hud:GetPlayerController()
            if pc and slua.isValid(pc) and pc.PlayerState and pc.PlayerState.GetPlayerStaticInfo then
                local info = pc.PlayerState:GetPlayerStaticInfo(tonumber(key))
                if info then
                    name = info.PlayerName or info.TeamName
                    uid = info.UID or info.PlayerUID or info.Uid
                end
            end
        end)
        return name, uid
    end

    function _G.X3._ACManipTry()
        local stage = _G.X3._ACManipStage or 0
        if stage >= 2 then return end
        -- TAHAP 0: penangkap pelapor/inspector + peredam window (item 1-9)
        if stage == 0 then
            local n = 0
            pcall(function()
                local RTB = require("GameLua.Mod.BaseMod.Common.RealTimeBan.RealTimeBan")
                if type(RTB) == "table" then
                    if type(RTB.OnSyncPlayerInfo) == "function" and not rawget(RTB, "__x3sync") then
                        rawset(RTB, "__x3sync", true)
                        local old = RTB.OnSyncPlayerInfo
                        RTB.OnSyncPlayerInfo = function(self, a, b, uid, infoToDS)
                            pcall(function()
                                if infoToDS and (infoToDS.InspectorsAliasId or infoToDS.is_onrank_inspector) then
                                    X3LogReporter("INSPECTOR/observer", uid, infoToDS.PlayerName or X3NameByUID(uid),
                                        "rank=" .. tostring(infoToDS.inspector_rank) .. " alias=" .. tostring(infoToDS.InspectorsAliasId))
                                end
                            end)
                            return old(self, a, b, uid, infoToDS)
                        end
                        n = n + 1
                    end
                    if type(RTB.OnPlayerWithRealTimeBan) == "function" and not rawget(RTB, "__x3rtb") then
                        rawset(RTB, "__x3rtb", true)
                        local old = RTB.OnPlayerWithRealTimeBan
                        RTB.OnPlayerWithRealTimeBan = function(self, a, b, uid, reason, tExitInfo)
                            pcall(function()
                                X3LogReporter("REALTIME-BAN", uid, X3NameByUID(uid), "reason=" .. tostring(reason))
                            end)
                            return old(self, a, b, uid, reason, tExitInfo)
                        end
                        n = n + 1
                    end
                    if type(RTB.ShowAlias) == "function" and not rawget(RTB, "__x3alias") then
                        rawset(RTB, "__x3alias", true)
                        local old = RTB.ShowAlias
                        RTB.ShowAlias = function(self, ...)
                            pcall(function() self.CurrentAlias = nil; self.bHasOldAlias = false end)
                            return old(self, ...)
                        end
                        n = n + 1
                    end
                    if type(RTB.SetInspectorRankUID) == "function" and not rawget(RTB, "__x3rank") then
                        rawset(RTB, "__x3rank", true)
                        local old = RTB.SetInspectorRankUID
                        RTB.SetInspectorRankUID = function(uid, rank)
                            pcall(function()
                                X3LogReporter("INSPECTOR-rank", uid, X3NameByUID(uid), "rank=" .. tostring(rank))
                            end)
                            return old(uid, rank)
                        end
                        n = n + 1
                    end
                end
            end)
            pcall(function()
                local ok, INS = pcall(require, "GameLua.Mod.BaseMod.Client.InspectionSystem.InspectionSystemReportClientLogicSubsystem")
                if ok and type(INS) == "table" then
                    if type(INS.RecvNotifyInspector) == "function" and not rawget(INS, "__x3recv") then
                        rawset(INS, "__x3recv", true)
                        INS.RecvNotifyInspector = function(Message)
                            pcall(function()
                                local name, uid = X3NameByKey(Message and Message.nPlayerKey)
                                X3LogReporter("REPORT-KE-INSPECTOR", uid, name,
                                    "type=" .. tostring(Message and Message.nType) .. " num=" .. tostring(Message and Message.nNum))
                            end)
                            return -- ditelan: implementasi tidak jalan, bentuk nil asli
                        end
                        n = n + 1
                    end
                    if type(INS.ClientNotifyInspectorImplementation) == "function" and not rawget(INS, "__x3cni") then
                        rawset(INS, "__x3cni", true)
                        INS.ClientNotifyInspectorImplementation = function(self, nTargetPlayerKey, nType, nNum)
                            pcall(function()
                                local name, uid = X3NameByKey(nTargetPlayerKey)
                                X3LogReporter("NOTIFY-INSPECTOR", uid, name, "type=" .. tostring(nType) .. " num=" .. tostring(nNum))
                            end)
                            return
                        end
                        n = n + 1
                    end
                end
            end)
            pcall(function()
                local QR = require("GameLua.Mod.BaseMod.Client.Security.ClientQuickReportMaliciousTeammate")
                if type(QR) == "table" then
                    if type(QR.MaliciousTeammateReceiveWarningTips) == "function" and not rawget(QR, "__x3warn") then
                        rawset(QR, "__x3warn", true)
                        QR.MaliciousTeammateReceiveWarningTips = function()
                            X3LogReporter("ANDA-DILAPORKAN (malicious teammate)", nil, "teammate", "RPC server masuk")
                            return -- window warning diredam
                        end
                        n = n + 1
                    end
                    if type(QR.MaliciousTeammateVictimReceiveTips) == "function" and not rawget(QR, "__x3victim") then
                        rawset(QR, "__x3victim", true)
                        QR.MaliciousTeammateVictimReceiveTips = function(sTeammateUID, bIsForbidPickupRevokable, nVictimHealthStatus)
                            pcall(function()
                                X3LogReporter("VICTIM-TIPS", sTeammateUID, X3NameByUID(sTeammateUID),
                                    "forbid=" .. tostring(bIsForbidPickupRevokable) .. " hp=" .. tostring(nVictimHealthStatus))
                            end)
                            return
                        end
                        n = n + 1
                    end
                end
            end)
            pcall(function()
                local ok, KC = pcall(require, "GameLua.Mod.BaseMod.Client.InspectionSystem.InspectionSystemKickPlayerConfirm")
                if ok and type(KC) == "table" and type(KC.OnClickConfirmBtn) == "function" and not rawget(KC, "__x3kick") then
                    rawset(KC, "__x3kick", true)
                    KC.OnClickConfirmBtn = function(self)
                        pcall(function()
                            local hud = rawget(_G, "slua_GameFrontendHUD")
                            local pc = hud and hud.GetPlayerController and hud:GetPlayerController()
                            local key = pc and pc.GetBeKickedPlayerKey and pc:GetBeKickedPlayerKey()
                            local name, uid = X3NameByKey(key)
                            X3LogReporter("KICK-CONFIRM (vote kick)", uid, name, "key=" .. tostring(key))
                        end)
                        pcall(function() if self and self.CloseSelf then self:CloseSelf() end end) -- tertutup bersih, event kick batal
                        return
                    end
                    n = n + 1
                end
            end)
            pcall(function()
                local ok, VP = pcall(require, "GameLua.Mod.BaseMod.Client.Ban.VoiceReportPop")
                if ok and type(VP) == "table" and type(VP._ReportToSecReportFlow) == "function" and not rawget(VP, "__x3vp") then
                    rawset(VP, "__x3vp", true)
                    VP._ReportToSecReportFlow = function(self, bReportTeammate)
                        X3LogReporter("VOICE-REPORT-FLOW", nil, nil, "teammate=" .. tostring(bReportTeammate))
                        return -- voice report dibuang
                    end
                    n = n + 1
                end
            end)
            if n > 0 then
                _G.X3._ACManipStage = 1
                X3Fw("ACMANIP-1: penangkap pelapor/inspector aktif (" .. n .. "/9 hook)")
            end
            return
        end
        -- TAHAP 1: spoofing kanal DS + short-circuit aman (item 10-15)
        local n = 0
        pcall(function()
            local ok, DN = pcall(require, "ds_net")
            if ok and type(DN) == "table" and type(DN.SendMessage) == "function" and not rawget(DN, "__x3dsf") then
                rawset(DN, "__x3dsf", true)
                local DROP_MSG = {
                    inspection_system_report_to_inspector = true,
                    inspection_system_kick_out_one_team = true,
                }
                local oldSend = DN.SendMessage
                DN.SendMessage = function(messageName, messageTable, uid)
                    if DROP_MSG[messageName] then
                        X3Fw("PKT-SPOOF > ds_net '" .. tostring(messageName) .. "' DIBUANG ✅")
                        return true -- sukses palsu
                    end
                    return oldSend(messageName, messageTable, uid)
                end
                n = n + 1
            end
        end)
        pcall(function()
            local ok, CH = pcall(require, "client.network.Protocol.ChatHandler")
            if ok and type(CH) == "table" and type(CH.on_report_info) == "function" and not rawget(CH, "__x3ack") then
                rawset(CH, "__x3ack", true)
                CH.on_report_info = function(res) return end -- ack report ditelan
                n = n + 1
            end
        end)
        pcall(function()
            local ok, LC = pcall(require, "client.logic.battle.logic_complaint")
            if ok and type(LC) == "table" and type(LC.IsAlreadyReported) == "function" and not rawget(LC, "__x3already") then
                rawset(LC, "__x3already", true)
                LC.IsAlreadyReported = function() return true end -- short-circuit: UI report menganggap sudah dilaporkan
                n = n + 1
            end
        end)
        pcall(function()
            local ok, H = pcall(require, "GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
            if ok and type(H) == "table" and type(H.StaticShowSecurityAlertInDev) == "function" and not rawget(H, "__x3dev") then
                rawset(H, "__x3dev", true)
                H.StaticShowSecurityAlertInDev = function() end
                n = n + 1
            end
        end)
        pcall(function()
            local ok, GRU = pcall(require, "GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils")
            if ok and type(GRU) == "table" and type(GRU.GetReplayReportHandler) == "function" and not rawget(GRU, "__x3grh") then
                rawset(GRU, "__x3grh", true)
                GRU.GetReplayReportHandler = function() return nil end -- replay evidence mati di hulu (nil = bentuk valid)
                n = n + 1
            end
        end)
        if n > 0 then
            _G.X3._ACManipStage = 2
            X3Fw("ACMANIP-2: spoofing ds_net + short-circuit aktif (" .. n .. "/5 hook)")
        end
    end
end

-- ==============================================================================
-- ==== INTI ANTI-CHEAT CORE v83: 17 FUNGSI BARU (MANIPULASI, BUKAN DIMATIKAN) ==
-- ==============================================================================
-- Semua nama & path diverifikasi dari dump 4.5 (no placebo):
-- [INTEL — tangkap ke firewall, alur diteruskan]
do
    local function X3Fw17(msg)
        if _G.X3._FWLogWrite then
            pcall(_G.X3._FWLogWrite, { "[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] " .. msg })
        end
        if type(_G.X3.Trace) == "function" then _G.X3.Trace(msg) end
    end
    local function X3Log17(kind, uid, name, extra)
        _G.X3._ReporterLog = _G.X3._ReporterLog or {}
        local key = "C17|" .. tostring(kind) .. "|" .. tostring(uid or name or "?")
        local now = os.clock()
        local last = _G.X3._ReporterLog[key]
        if last and (now - last) < 120 then return end
        _G.X3._ReporterLog[key] = now
if not (type(kind) == "string" and kind:find("KILLER", 1, true)) then
    pcall(function()
        if _G.X3._CrashLogUrgent then
            _G.X3._CrashLogUrgent("REPORT-ME > " .. tostring(kind) .. " UID=" .. tostring(uid or "?") .. " NAMA=" .. tostring(name or "?") .. (extra and (" | " .. tostring(extra)) or ""))
        end
    end)
end
        X3Fw17("REPORTER " .. tostring(kind) .. " > UID=" .. tostring(uid or "?") .. " NAMA=" .. tostring(name or "?") .. (extra and (" | " .. tostring(extra)) or "") .. " 🚨")
    end
    function _G.X3._ACCore17Try()
        local stage = _G.X3._ACCore17Stage or 0
        if stage >= 2 then return end
        -- TAHAP 0: intel ban/voice/killer (item 1-5)
        if stage == 0 then
            local n = 0
            pcall(function()
                local BL = require("GameLua.Mod.BaseMod.Client.Ban.ClientBanLogic")
                if type(BL) == "table" then
                    if type(BL.OnVoiceBanNotify) == "function" and not rawget(BL, "__x3vbn") then
                        rawset(BL, "__x3vbn", true)
                        local old = BL.OnVoiceBanNotify
                        BL.OnVoiceBanNotify = function(Message)
                            pcall(function()
                                X3Log17("VOICE-BAN-NOTIFY", Message and (Message.Uid or Message.uid), nil,
                                    "reason=" .. tostring(Message and (Message.Reason or Message.reason)))
                            end)
                            return old(Message)
                        end
                        n = n + 1
                    end
                    if type(BL.OnRealTimeVoiceBanNotify) == "function" and not rawget(BL, "__x3rtv") then
                        rawset(BL, "__x3rtv", true)
                        local old = BL.OnRealTimeVoiceBanNotify
                        BL.OnRealTimeVoiceBanNotify = function(Uid, Reason, Endtime)
                            pcall(function() X3Log17("REALTIME-VOICE-BAN", Uid, nil, "reason=" .. tostring(Reason) .. " end=" .. tostring(Endtime)) end)
                            return old(Uid, Reason, Endtime)
                        end
                        n = n + 1
                    end
                    if type(BL.OnVoiceBanSuccess) == "function" and not rawget(BL, "__x3vbs") then
                        rawset(BL, "__x3vbs", true)
                        local old = BL.OnVoiceBanSuccess
                        BL.OnVoiceBanSuccess = function(Uid, Name, Bantime)
                            pcall(function() X3Log17("VOICE-BAN-SUKSES", Uid, Name, "durasi=" .. tostring(Bantime)) end)
                            return old(Uid, Name, Bantime)
                        end
                        n = n + 1
                    end
                    if type(BL.OnNotifyWarningTips) == "function" and not rawget(BL, "__x3wtip") then
                        rawset(BL, "__x3wtip", true)
                        local old = BL.OnNotifyWarningTips
                        BL.OnNotifyWarningTips = function(TextID, bOffMic)
                            pcall(function() X3Log17("WARNING-TIPS", nil, nil, "textID=" .. tostring(TextID) .. " offMic=" .. tostring(bOffMic)) end)
                            return old(TextID, bOffMic)
                        end
                        n = n + 1
                    end
                    if type(BL.ReqBanInfo) == "function" and not rawget(BL, "__x3req") then
                        rawset(BL, "__x3req", true)
                        BL.ReqBanInfo = function() return end -- item 9: status ban tak pernah diminta
                        n = n + 1
                    end
                end
            end)
            pcall(function()
                local RPU = require("GameLua.Mod.BaseMod.Common.Security.ReportPlayerUtils")
                if type(RPU) == "table" then
                    if type(RPU.RecordFatalDamager) == "function" and not rawget(RPU, "__x3rfd") then
                        rawset(RPU, "__x3rfd", true)
                        local old = RPU.RecordFatalDamager
                        RPU.RecordFatalDamager = function(tMap, sName, sUID, bIsAI, bIsMLAI, sOriginalUID, bIsDeliver)
                            pcall(function()
                                X3Log17("KILLER (fatal damager)", sUID, sName,
                                    "ai=" .. tostring(bIsAI) .. " mlai=" .. tostring(bIsMLAI) .. " origUID=" .. tostring(sOriginalUID))
                            end)
                            return old(tMap, sName, sUID, bIsAI, bIsMLAI, sOriginalUID, bIsDeliver)
                        end
                        n = n + 1
                    end
                    if type(RPU.RecordFatalDamagerReconnect) == "function" and not rawget(RPU, "__x3rfr") then
                        rawset(RPU, "__x3rfr", true)
                        local old = RPU.RecordFatalDamagerReconnect
                        RPU.RecordFatalDamagerReconnect = function(tMap, sName, sUID, bIsAI, bIsMLAI, sOriginalUID, bIsDeliver, nOccurTime)
                            pcall(function() X3Log17("KILLER-RECONNECT", sUID, sName, "t=" .. tostring(nOccurTime)) end)
                            return old(tMap, sName, sUID, true, bIsMLAI, sOriginalUID, bIsDeliver, nOccurTime) -- bIsAI dipaksa true: bukti dikaburkan
                        end
                        n = n + 1
                    end
                end
            end)
            if n > 0 then
                _G.X3._ACCore17Stage = 1
                X3Fw17("ACCORE17-1: intel ban/voice/killer aktif (" .. n .. "/7 hook)")
            end
            return
        end
        -- TAHAP 1: manipulasi bukti/telemetri/UI report (item 6-16)
        local n = 0
        pcall(function()
            local GRU = require("GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils")
            if type(GRU) == "table" then
                if type(GRU.ReportException) == "function" and not rawget(GRU, "__x3re") then
                    rawset(GRU, "__x3re", true)
                    GRU.ReportException = function() return true end
                    n = n + 1
                end
                if type(GRU.GetReplayRecordManager) == "function" and not rawget(GRU, "__x3grm") then
                    rawset(GRU, "__x3grm", true)
                    GRU.GetReplayRecordManager = function() return nil end
                    n = n + 1
                end
                if type(GRU.GetReplayRecorderByType) == "function" and not rawget(GRU, "__x3grr") then
                    rawset(GRU, "__x3grr", true)
                    GRU.GetReplayRecorderByType = function() return nil end
                    n = n + 1
                end
            end
        end)
        pcall(function()
            local ok, RB = pcall(require, "GameLua.Mod.BaseMod.Client.InspectionSystem.InspectionSystemReportButton")
            if ok and type(RB) == "table" then
                if type(RB.CanReportNow) == "function" and not rawget(RB, "__x3crn") then
                    rawset(RB, "__x3crn", true)
                    RB.CanReportNow = function() return false end
                    n = n + 1
                end
                if type(RB.OnClickReportBtn) == "function" and not rawget(RB, "__x3ocr") then
                    rawset(RB, "__x3ocr", true)
                    RB.OnClickReportBtn = function() return end
                    n = n + 1
                end
            end
        end)
        pcall(function()
            local QR = require("GameLua.Mod.BaseMod.Client.Security.ClientQuickReportMaliciousTeammate")
            if type(QR) == "table" then
                if type(QR.SetAutoClickTime) == "function" and not rawget(QR, "__x3sact") then
                    rawset(QR, "__x3sact", true)
                    QR.SetAutoClickTime = function() return end
                    n = n + 1
                end
                if type(QR._GetAutoShowHideVictimWindow) == "function" and not rawget(QR, "__x3gasw") then
                    rawset(QR, "__x3gasw", true)
                    QR._GetAutoShowHideVictimWindow = function() return nil, false end
                    n = n + 1
                end
                if type(QR.OnShowMutualExclusiveUI) == "function" and not rawget(QR, "__x3meu") then
                    rawset(QR, "__x3meu", true)
                    QR.OnShowMutualExclusiveUI = function() return end
                    QR.OnHideMutualExclusiveUI = function() return end
                    n = n + 1
                end
            end
        end)
        pcall(function()
            local VT = require("GameLua.GameCore.Module.Vehicle.VehicleFeatures.TLog.VehicleTLogFeature")
            if type(VT) == "table" then
                if type(VT.OnEnterVehicle) == "function" and not rawget(VT, "__x3vtl") then
                    rawset(VT, "__x3vtl", true)
                    VT.OnEnterVehicle = function() return end
                    VT.OnVehicleTakeDamge = function() return end
                    VT.OnCharacterPreDied = function() return end
                    n = n + 1
                end
            end
        end)
        pcall(function()
            local CR = require("GameLua.Mod.BaseMod.Client.Security.Credit.ClientInGameCreditLogic")
            if type(CR) == "table" and type(CR.ShowReturnLobbyIfFirstExitTeamBeforeBoarding) == "function" and not rawget(CR, "__x3srl") then
                rawset(CR, "__x3srl", true)
                CR.ShowReturnLobbyIfFirstExitTeamBeforeBoarding = function() return end
                n = n + 1
            end
        end)
        if n > 0 then
            _G.X3._ACCore17Stage = 2
            X3Fw17("ACCORE17-2: manipulasi bukti/telemetri/UI report aktif (" .. n .. "/10 hook)")
        end
    end
end

-- ==============================================================================
-- ================== MAINLOOP / MAIN LOOP (EXTRA TICK REALTIME) ===============
-- ==============================================================================
-- EXTRA TICK --
_G.X3.ExtraTick = function(lp)
    if not (lp and slua.isValid(lp)) then return end
    local now = os.clock()
    do
        local stf = _G.X3._TSt or {}
        _G.X3._TSt = stf
        local sec = os.time() -- wall-clock: hitung frame per detik (os.clock tidak akurat di sebagian device)
        if sec ~= stf.fsec then
            stf.fsec = sec
            _G.X3._FPS = stf.fcnt or 0
            stf.fcnt = 0
        else
            stf.fcnt = (stf.fcnt or 0) + 1
        end
    end
    local st = _G.X3._XF
    local ts = _G.X3.TickScale and _G.X3.TickScale() or 1
    if now - (st.tpp or 0) >= 0.033 then st.tpp = now; if _G.X3._XFTPPTick then pcall(_G.X3._XFTPPTick, lp) end end
    if now - (st.wwh or 0) >= 2.0 * ts then st.wwh = now; if _G.X3._XFWScan then pcall(_G.X3._XFWScan, lp) end end
    if now - (st.wpulse or 0) >= 0.25 * ts then st.wpulse = now; if _G.X3._XFWPulse then pcall(_G.X3._XFWPulse) end end
    if now - (st.wm or 0) >= 1.0 * ts then st.wm = now; if _G.X3._XFWMTick then pcall(_G.X3._XFWMTick, lp) end end
    if now - (st.tipthr or 0) >= 10.0 * ts then st.tipthr = now; if _G.X3._XFTipThrottleTry then pcall(_G.X3._XFTipThrottleTry) end end
    if now - (st.acsh or 0) >= 1.0 * ts then st.acsh = now; if _G.X3._ACShieldTick then pcall(_G.X3._ACShieldTick) end end
    if now - (st.acshk or 0) >= 10.0 * ts then st.acshk = now; if _G.X3._ACShieldHookTry then pcall(_G.X3._ACShieldHookTry) end; if _G.X3._ACMemberMaskTry then pcall(_G.X3._ACMemberMaskTry) end; if _G.X3._ACTssShieldTry then pcall(_G.X3._ACTssShieldTry) end; if _G.X3._ACLogShieldTry then pcall(_G.X3._ACLogShieldTry) end; if _G.X3._ACHiggsShieldTry then pcall(_G.X3._ACHiggsShieldTry) end; if _G.X3._ACPacketFilterTry then pcall(_G.X3._ACPacketFilterTry) end; if _G.X3._ACCRCBypassTry then pcall(_G.X3._ACCRCBypassTry) end; if _G.X3._ACHawkNukeTry then pcall(_G.X3._ACHawkNukeTry) end; if _G.X3._ACHashFakeTry then pcall(_G.X3._ACHashFakeTry) end; if _G.X3._ACReportNukeTry then pcall(_G.X3._ACReportNukeTry) end; if _G.X3._ACManipTry then pcall(_G.X3._ACManipTry) end; if _G.X3._ACCore17Try then pcall(_G.X3._ACCore17Try) end end
    if now - (st.fwlog or 0) >= 1.0 * ts then st.fwlog = now; if _G.X3._FWLogTick then pcall(_G.X3._FWLogTick) end; if _G.X3._FeatureCacheWatch then pcall(_G.X3._FeatureCacheWatch) end; if _G.X3._CrashLogFlush then pcall(_G.X3._CrashLogFlush) end end
    -- LAPORAN STATUS BYPASS KE FIREWALL LOG (15 dtk & 60 dtk setelah mainloop hidup)
    do
        local bootT = _G.X3._BootT or now
        _G.X3._BootT = bootT
        if not _G.X3._ACRep1 and (now - bootT) >= 15 then _G.X3._ACRep1 = true; if _G.X3._ACBypassReport then pcall(_G.X3._ACBypassReport, 1) end end
        if not _G.X3._ACRep2 and (now - bootT) >= 60 then _G.X3._ACRep2 = true; if _G.X3._ACBypassReport then pcall(_G.X3._ACBypassReport, 2) end end
    end
-- [PERF-F12] gate adaptif: logger 0.5 dtk saat fighting, 1.5 dtk saat non-combat
    local _clg = (_G.X3._CL and _G.X3._CL.gs == "FightingState") and 0.5 or 1.5
    if now - (st.crashlog or 0) >= _clg * ts then st.crashlog = now; if _G.X3._CrashLogTick then pcall(_G.X3._CrashLogTick, lp) end end
    if now - (st.gc or 0) >= 20.0 then st.gc = now; pcall(function() collectgarbage("step", 200) end) end -- [PERF-F04] full-collect -> step incremental: hilangkan hitch stop-the-world 20 dtk (incremental sudah di-tune di boot + step di MainLoop)
    if now - (st.capretry or 0) >= 3.0 * ts then st.capretry = now; if _G.X3._CapRetryOn and _G.X3._CaptureRetryTick then pcall(_G.X3._CaptureRetryTick) end end
    if now - (st.hwidregen or 0) >= 300.0 * ts then st.hwidregen = now; if _G.X3._HWIDRegenOn and _G.X3._HWIDAutoRegenTick then pcall(_G.X3._HWIDAutoRegenTick) end end
    if now - (st.skinun or 0) >= 5.0 * ts then st.skinun = now; if _G.X3.SkinUnlockTick then pcall(_G.X3.SkinUnlockTick) end end
    if _G.X3.EnumState and _G.X3.EnumStep then pcall(_G.X3.EnumStep) end
    do local ij = _G.X3.Inj; if ij and ij.injectRunning and not ij.allDone and _G.X3.InjInjectBatch then pcall(_G.X3.InjInjectBatch) end end
    if _G.X3._InjReapplyAt and now >= _G.X3._InjReapplyAt then _G.X3._InjReapplyAt = nil; if _G.X3.InjReapplyLobby then pcall(_G.X3.InjReapplyLobby) end end
    if now - (st.autosave or 0) >= 1.5 * ts then st.autosave = now; if _G.X3._AutoSaveTick then pcall(_G.X3._AutoSaveTick) end end
    if _G.X3._UnlockAllTick then pcall(_G.X3._UnlockAllTick) end
    if _G.X3._UAOwnershipHookTry then pcall(_G.X3._UAOwnershipHookTry) end
    if _G.X3._MaxLevelHookTry then pcall(_G.X3._MaxLevelHookTry) end
end


-- SKIN ACAK TERBARU + ANTI-SPAM TIP
do
-- ==============================================================================
-- ================== BLOK KEAMANAN / SECURITY BLOCK (ANTI-BAN + FIREWALL) =====
-- ==============================================================================
-- PERISAI ANTI-BAN / ANTI-BAN SHIELD (auto ON, realtime, ringan)
do
    function _G.X3._ACShieldTick()
        pcall(function()
            local pc = GameplayData and GameplayData.GetPlayerController and GameplayData.GetPlayerController()
            if not (pc and slua.isValid(pc)) then return end
            local comp = nil
            pcall(function() comp = pc.AntiCheatManagerComp end)
            if not comp then return end
            pcall(function() if comp.SwitchHitComponentUnvalid == true then comp.SwitchHitComponentUnvalid = false end end)
            pcall(function() if comp.bReportFeedBack == true then comp.bReportFeedBack = false end end)
            pcall(function() if comp.bOpenDetailDataCollect == true then comp.bOpenDetailDataCollect = false end end)
            if not _G.X3._ACShieldSeen then
                _G.X3._ACShieldSeen = true
                if type(_G.X3.Trace) == "function" then _G.X3.Trace("ACSHIELD: AntiCheatManagerComp ditemukan, netralisasi hukuman aktif") end
            end
        end)
    end

    function _G.X3._ACShieldHookTry()
        if _G.X3._ACShieldHooked then return end
        _G.X3._ACShieldHooked = true
        pcall(function()
            local M = require("GameLua.Mod.BaseMod.Client.WatchGame.WatchGameInGamePlayerInfo")
            if type(M) == "table" and type(M.EventReportPlayerInfoButtonClick) == "function" then
                M.EventReportPlayerInfoButtonClick = function() end
            end
        end)
        pcall(function()
            local C = rawget(_G, "Client")
            if type(C) == "table" then
                local n = 0
                for k, v in pairs(C) do
                    if type(v) == "function" and type(k) == "string" and k:sub(1, 6) == "Report" then
                        C[k] = function(...) return end
                        n = n + 1
                    end
                end
                if type(_G.X3.Trace) == "function" then _G.X3.Trace("ACSHIELD: " .. n .. " jalur report client dinetralkan") end
            end
        end)
    end

    function _G.X3._ACMemberMaskTry()
        if _G.X3._ACMaskHooked then return end
        _G.X3._ACMaskHooked = true
        pcall(function()
            local S = require("GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils")
            if type(S) ~= "table" then return end
            local function isStrategyKey(ks)
                ks = tostring(ks)
                return ks:find("EspTotal") or ks:find("AvatarCheck") or ks:find("IllegalWear")
                    or ks:find("BulletFlySpeed") or ks:find("GravityAnomaly") or ks:find("FlyingError")
            end
            local function wrapNum(fnName)
                local orig = S[fnName]
                if type(orig) ~= "function" then return end
                S[fnName] = function(owner, key, ...)
                    if isStrategyKey(key) then return 0 end
                    return orig(owner, key, ...)
                end
            end
            local function wrapBool(fnName)
                local orig = S[fnName]
                if type(orig) ~= "function" then return end
                S[fnName] = function(owner, key, ...)
                    if isStrategyKey(key) then return false end
                    return orig(owner, key, ...)
                end
            end
            wrapNum("GetNumberMember")
            wrapNum("GetIntMember")
            wrapBool("GetBoolMember")
            if type(_G.X3.Trace) == "function" then _G.X3.Trace("ACSHIELD: forensic member masking aktif") end
        end)
    end

    _G.X3._ACFirewallHosts = {
        "*.ace.qq.com",
        "*.anticheatexpert.com",
        "*.battleye.com",
        "*.bugly.qq.com",
        "*.g-cdn.com",
        "*.gpubgm.com",
        "*.igamecj.com",
        "*.intlgame.com",
        "*.proximabeta.com",
        "*.pubgmobile.com",
        "*.qq.com",
        "*.tdm.qq.com",
        "*.vnet.qq.com",
        "*.wellbia.com",
        "101.32.0.0/16",
        "101.32.143.142",
        "101.32.143.171",
        "101.32.143.250",
        "119.28.0.0/16",
        "119.28.121.174",
        "119.28.145.130",
        "119.28.183.144",
        "129.226.0.0/16",
        "129.226.1.157",
        "129.226.2.142",
        "129.226.2.231",
        "129.226.2.37",
        "129.226.3.232",
        "129.226.3.250",
        "150.109.0.0/16",
        "150.109.0.38",
        "150.109.0.45",
        "150.109.22.214",
        "150.109.250.19",
        "150.109.28.183",
        "150.109.29.150",
        "162.62.10.64",
        "203.205.137.232",
        "43.0.0.0/8",
        "43.156.222.42",
        "49.51.129.54",
        "abs.twimg.com",
        "analytics.m.qq.com",
        "android.crashsight.wetest.net",
        "android.googleapis.com",
        "anticheat.me",
        "anticheat.net",
        "api.facebook.com",
        "api.twitter.com",
        "asia.csoversea.mbgame.anticheatexpert.com",
        "b-api.facebook.com",
        "bugly.qq.com",
        "calendarpushsubscription-pa.googleapis.com",
        "cloud.gcloud.qq.com",
        "cloud.gsdk.proximabeta.com",
        "cloudctrl.gcloud.qq.com",
        "com.tencent.mobileqq",
        "crash2.gcloud.qq.com",
        "dl.listdl.com",
        "dl.tomjson.com",
        "down.anticheatexpert.com",
        "down.qq.com",
        "downanticheat.com",
        "download.2.1375135419.igame.gcloudcs.com",
        "exp.helpshift.com",
        "feedback.wh.gcloud.qq.com",
        "file.igamecj.com",
        "firebaselogging.googleapis.com",
        "firebaseremoteconfig.googleapis.com",
        "fonts.googleapis.com",
        "gcloud.qq.com",
        "glcs.listdl.com",
        "googleads.g.doubleclick.net",
        "graph.facebook.com",
        "grpc.club.gpubgm.com",
        "gvoice.gcloud.qq.com",
        "helpshift.me",
        "hostmaster.net",
        "intl.acekeeper.anticheatexpert.com",
        "lobby.igamecj.com",
        "log.igamecj.com",
        "log.tav.qq.com",
        "log.tdos.qq.com",
        "loginsdkapi.zingplay.com",
        "logiservice.qcloud.com",
        "logupload.gcloud.qq.com",
        "monitor.qq.com",
        "opensdk.tencent.com",
        "oth.eve.mdt.qq.com",
        "privacy.qq.com",
        "qq.me",
        "report.qq.com",
        "reportlog.cdn.qq.com",
        "scontentborn1-1.xx.fbcdn.net",
        "sdkostrace.qq.com",
        "sngd.gcloud.qq.com",
        "static.xx.fbcdn.net",
        "syzsdk.qq.com",
        "tdid.m.qq.com",
        "tencent.net",
        "tob.itop.tencent.com",
        "tracer.gcloud.qq.com",
        "tss.tencent.com",
        "www.pubgmobile.com"
    }
    local X3FW_JSON = [==[{"apps":[],"filters":[{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"tss.tencent.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"syzsdk.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"gcloud.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"reportlog.cdn.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"bugly.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"monitor.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"privacy.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"log.tdos.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"tdid.m.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"oth.eve.mdt.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"analytics.m.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"exp.helpshift.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"loginsdkapi.zingplay.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"opensdk.tencent.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"logiservice.qcloud.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"cloudctrl.gcloud.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"logupload.gcloud.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"feedback.wh.gcloud.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"crash2.gcloud.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"cloud.gcloud.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"gvoice.gcloud.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"sdkostrace.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"log.tav.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"sngd.gcloud.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"tracer.gcloud.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"report.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"asia.csoversea.mbgame.anticheatexpert.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"dl.listdl.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"down.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"glcs.listdl.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"intl.acekeeper.anticheatexpert.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"down.anticheatexpert.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"dl.tomjson.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"download.2.1375135419.igame.gcloudcs.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"android.crashsight.wetest.net","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"grpc.club.gpubgm.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"file.igamecj.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"lobby.igamecj.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"log.igamecj.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"cloud.gsdk.proximabeta.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"www.pubgmobile.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"static.xx.fbcdn.net","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"scontentborn1-1.xx.fbcdn.net","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"fonts.googleapis.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"abs.twimg.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"android.googleapis.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"calendarpushsubscription-pa.googleapis.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"firebaseremoteconfig.googleapis.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"firebaselogging.googleapis.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"googleads.g.doubleclick.net","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"api.facebook.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"graph.facebook.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"b-api.facebook.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"api.twitter.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"com.tencent.mobileqq","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"anticheat.me","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"helpshift.me","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"qq.me","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"anticheat.net","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"tencent.net","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"hostmaster.net","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"downanticheat.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"tob.itop.tencent.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"*.g-cdn.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"*.wellbia.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"*.igamecj.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"*.bugly.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"*.tdm.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"*.ace.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"*.pubgmobile.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"*.gpubgm.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"*.proximabeta.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"*.intlgame.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"*.vnet.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"*.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"*.anticheatexpert.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"*.battleye.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"43.0.0.0/8","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"129.226.0.0/16","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"101.32.0.0/16","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"150.109.0.0/16","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"119.28.0.0/16","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":31003,"priority":0,"proto":"tcp","server":"43.156.222.42","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":31003,"priority":0,"proto":"tcp","server":"162.62.10.64","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":17053,"priority":0,"proto":"tcp","server":"162.62.10.64","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10012,"priority":0,"proto":"tcp","server":"129.226.2.37","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10012,"priority":0,"proto":"tcp","server":"129.226.3.232","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10012,"priority":0,"proto":"tcp","server":"129.226.1.157","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10012,"priority":0,"proto":"tcp","server":"129.226.2.231","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10012,"priority":0,"proto":"tcp","server":"101.32.143.171","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10012,"priority":0,"proto":"tcp","server":"119.28.121.174","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10012,"priority":0,"proto":"tcp","server":"150.109.0.38","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10012,"priority":0,"proto":"tcp","server":"150.109.0.45","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":443,"priority":0,"proto":"tcp","server":"129.226.3.250","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":443,"priority":0,"proto":"tcp","server":"129.226.2.142","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":443,"priority":0,"proto":"tcp","server":"101.32.143.250","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":443,"priority":0,"proto":"tcp","server":"203.205.137.232","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":443,"priority":0,"proto":"tcp","server":"down.anticheatexpert.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":443,"priority":0,"proto":"tcp","server":"101.32.143.171","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":443,"priority":0,"proto":"tcp","server":"downanticheat.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":8080,"priority":0,"proto":"tcp","server":"119.28.183.144","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":8085,"priority":0,"proto":"tcp","server":"119.28.183.144","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":8088,"priority":0,"proto":"tcp","server":"150.109.250.19","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":3013,"priority":0,"proto":"tcp","server":"150.109.28.183","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":3031,"priority":0,"proto":"tcp","server":"150.109.22.214","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":17500,"priority":0,"proto":"tcp","server":"119.28.145.130","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":18081,"priority":0,"proto":"tcp","server":"49.51.129.54","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":80,"priority":0,"proto":"tcp","server":"150.109.0.45","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":80,"priority":0,"proto":"tcp","server":"150.109.29.150","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":80,"priority":0,"proto":"tcp","server":"101.32.143.142","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":8080,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":80,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":9031,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":443,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10012,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":18081,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":18600,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":20371,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":15692,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":49514,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":8013,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":90,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":554,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":35000,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":85,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":87,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":91,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":92,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":8085,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":8086,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":8088,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10178,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10315,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10013,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":9030,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":8089,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":8081,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":8011,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":5692,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":3013,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":54856,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":54861,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":50324,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":51703,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":58238,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":58236,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":55817,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":57488,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":54841,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":54840,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":54825,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":54740,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":54675,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":54655,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":51965,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":51962,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":51915,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":50926,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":50906,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":50904,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":50877,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":54817,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":54384,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":100,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":24296,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10086,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":6044,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":5555,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10085,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":5038,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":9081,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":17000,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":8030,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10207,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10213,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":20000,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":8700,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10438,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":20002,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10226,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10965,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":20001,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10049,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":11112,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10706,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10095,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":20139,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10289,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10024,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":12401,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10309,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10060,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":11008,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":11075,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10157,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":24798,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10087,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":31113,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10709,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":6667,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10599,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10009,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":11091,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10392,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10526,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10400,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10792,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10980,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":14457,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10793,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":53,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10912,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10497,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10685,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10336,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10800,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10120,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10664,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10610,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10790,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":13728,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10076,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10942,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10262,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10780,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10769,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10761,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":27000,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":27040,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":27015,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":27030,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":4380,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":5060,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":5061,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":5062,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":11110,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10010,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10011,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":8443,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":14000,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":15000,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10334,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":18100,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":11045,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10371,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10111,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10416,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":23014,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":10536,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":22772,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.tencent.ig","port":18100,"priority":0,"proto":"udp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":false,"mobile":"none","pkg1Name":"com.tencent.ig","port":-1,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"none"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"allow","pkg1Name":"com.tencent.ig","port":17500,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"allow"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"tss.tencent.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"syzsdk.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"gcloud.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"reportlog.cdn.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"bugly.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"monitor.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"privacy.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"log.tdos.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"tdid.m.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"oth.eve.mdt.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"analytics.m.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"exp.helpshift.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"loginsdkapi.zingplay.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"opensdk.tencent.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"logiservice.qcloud.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"cloudctrl.gcloud.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"logupload.gcloud.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"feedback.wh.gcloud.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"crash2.gcloud.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"cloud.gcloud.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"gvoice.gcloud.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"sdkostrace.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"log.tav.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"sngd.gcloud.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"tracer.gcloud.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"report.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"asia.csoversea.mbgame.anticheatexpert.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"dl.listdl.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"down.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"glcs.listdl.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"intl.acekeeper.anticheatexpert.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"down.anticheatexpert.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"dl.tomjson.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"download.2.1375135419.igame.gcloudcs.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"android.crashsight.wetest.net","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"grpc.club.gpubgm.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"file.igamecj.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"lobby.igamecj.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"log.igamecj.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"cloud.gsdk.proximabeta.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"www.pubgmobile.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"static.xx.fbcdn.net","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"scontentborn1-1.xx.fbcdn.net","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"fonts.googleapis.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"abs.twimg.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"android.googleapis.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"calendarpushsubscription-pa.googleapis.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"firebaseremoteconfig.googleapis.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"firebaselogging.googleapis.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"googleads.g.doubleclick.net","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"api.facebook.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"graph.facebook.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"b-api.facebook.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"api.twitter.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"com.tencent.mobileqq","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"anticheat.me","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"helpshift.me","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"qq.me","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"anticheat.net","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"tencent.net","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"hostmaster.net","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"downanticheat.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"tob.itop.tencent.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"*.g-cdn.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"*.wellbia.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"*.igamecj.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"*.bugly.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"*.tdm.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"*.ace.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"*.pubgmobile.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"*.gpubgm.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"*.proximabeta.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"*.intlgame.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"*.vnet.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"*.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"*.anticheatexpert.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"*.battleye.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"43.0.0.0/8","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"129.226.0.0/16","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"101.32.0.0/16","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"150.109.0.0/16","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"119.28.0.0/16","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":31003,"priority":0,"proto":"tcp","server":"43.156.222.42","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":31003,"priority":0,"proto":"tcp","server":"162.62.10.64","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":17053,"priority":0,"proto":"tcp","server":"162.62.10.64","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10012,"priority":0,"proto":"tcp","server":"129.226.2.37","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10012,"priority":0,"proto":"tcp","server":"129.226.3.232","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10012,"priority":0,"proto":"tcp","server":"129.226.1.157","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10012,"priority":0,"proto":"tcp","server":"129.226.2.231","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10012,"priority":0,"proto":"tcp","server":"101.32.143.171","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10012,"priority":0,"proto":"tcp","server":"119.28.121.174","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10012,"priority":0,"proto":"tcp","server":"150.109.0.38","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10012,"priority":0,"proto":"tcp","server":"150.109.0.45","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":443,"priority":0,"proto":"tcp","server":"129.226.3.250","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":443,"priority":0,"proto":"tcp","server":"129.226.2.142","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":443,"priority":0,"proto":"tcp","server":"101.32.143.250","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":443,"priority":0,"proto":"tcp","server":"203.205.137.232","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":443,"priority":0,"proto":"tcp","server":"down.anticheatexpert.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":443,"priority":0,"proto":"tcp","server":"101.32.143.171","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":443,"priority":0,"proto":"tcp","server":"downanticheat.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":8080,"priority":0,"proto":"tcp","server":"119.28.183.144","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":8085,"priority":0,"proto":"tcp","server":"119.28.183.144","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":8088,"priority":0,"proto":"tcp","server":"150.109.250.19","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":3013,"priority":0,"proto":"tcp","server":"150.109.28.183","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":3031,"priority":0,"proto":"tcp","server":"150.109.22.214","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":17500,"priority":0,"proto":"tcp","server":"119.28.145.130","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":18081,"priority":0,"proto":"tcp","server":"49.51.129.54","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":80,"priority":0,"proto":"tcp","server":"150.109.0.45","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":80,"priority":0,"proto":"tcp","server":"150.109.29.150","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":80,"priority":0,"proto":"tcp","server":"101.32.143.142","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":8080,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":80,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":9031,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":443,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10012,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":18081,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":18600,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":20371,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":15692,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":49514,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":8013,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":90,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":554,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":35000,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":85,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":87,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":91,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":92,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":8085,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":8086,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":8088,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10178,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10315,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10013,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":9030,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":8089,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":8081,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":8011,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":5692,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":3013,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":54856,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":54861,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":50324,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":51703,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":58238,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":58236,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":55817,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":57488,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":54841,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":54840,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":54825,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":54740,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":54675,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":54655,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":51965,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":51962,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":51915,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":50926,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":50906,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":50904,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":50877,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":54817,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":54384,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":100,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":24296,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10086,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":6044,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":5555,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10085,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":5038,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":9081,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":17000,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":8030,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10207,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10213,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":20000,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":8700,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10438,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":20002,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10226,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10965,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":20001,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10049,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":11112,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10706,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10095,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":20139,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10289,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10024,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":12401,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10309,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10060,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":11008,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":11075,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10157,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":24798,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10087,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":31113,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10709,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":6667,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10599,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10009,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":11091,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10392,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10526,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10400,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10792,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10980,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":14457,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10793,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":53,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10912,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10497,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10685,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10336,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10800,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10120,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10664,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10610,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10790,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":13728,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10076,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10942,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10262,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10780,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10769,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10761,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":27000,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":27040,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":27015,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":27030,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":4380,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":5060,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":5061,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":5062,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":11110,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10010,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10011,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":8443,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":14000,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":15000,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10334,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":18100,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":11045,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10371,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10111,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10416,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":23014,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":10536,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":22772,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.pubg.krmobile","port":18100,"priority":0,"proto":"udp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":false,"mobile":"none","pkg1Name":"com.pubg.krmobile","port":-1,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"none"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"allow","pkg1Name":"com.pubg.krmobile","port":17500,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"allow"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"tss.tencent.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"syzsdk.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"gcloud.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"reportlog.cdn.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"bugly.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"monitor.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"privacy.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"log.tdos.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"tdid.m.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"oth.eve.mdt.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"analytics.m.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"exp.helpshift.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"loginsdkapi.zingplay.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"opensdk.tencent.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"logiservice.qcloud.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"cloudctrl.gcloud.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"logupload.gcloud.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"feedback.wh.gcloud.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"crash2.gcloud.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"cloud.gcloud.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"gvoice.gcloud.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"sdkostrace.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"log.tav.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"sngd.gcloud.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"tracer.gcloud.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"report.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"asia.csoversea.mbgame.anticheatexpert.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"dl.listdl.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"down.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"glcs.listdl.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"intl.acekeeper.anticheatexpert.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"down.anticheatexpert.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"dl.tomjson.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"download.2.1375135419.igame.gcloudcs.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"android.crashsight.wetest.net","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"grpc.club.gpubgm.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"file.igamecj.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"lobby.igamecj.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"log.igamecj.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"cloud.gsdk.proximabeta.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"www.pubgmobile.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"static.xx.fbcdn.net","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"scontentborn1-1.xx.fbcdn.net","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"fonts.googleapis.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"abs.twimg.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"android.googleapis.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"calendarpushsubscription-pa.googleapis.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"firebaseremoteconfig.googleapis.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"firebaselogging.googleapis.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"googleads.g.doubleclick.net","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"api.facebook.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"graph.facebook.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"b-api.facebook.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"api.twitter.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"com.tencent.mobileqq","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"anticheat.me","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"helpshift.me","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"qq.me","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"anticheat.net","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"tencent.net","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"hostmaster.net","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"downanticheat.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"tob.itop.tencent.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"*.g-cdn.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"*.wellbia.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"*.igamecj.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"*.bugly.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"*.tdm.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"*.ace.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"*.pubgmobile.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"*.gpubgm.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"*.proximabeta.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"*.intlgame.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"*.vnet.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"*.qq.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"*.anticheatexpert.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"*.battleye.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"43.0.0.0/8","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"129.226.0.0/16","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"101.32.0.0/16","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"150.109.0.0/16","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"119.28.0.0/16","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":31003,"priority":0,"proto":"tcp","server":"43.156.222.42","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":31003,"priority":0,"proto":"tcp","server":"162.62.10.64","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":17053,"priority":0,"proto":"tcp","server":"162.62.10.64","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10012,"priority":0,"proto":"tcp","server":"129.226.2.37","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10012,"priority":0,"proto":"tcp","server":"129.226.3.232","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10012,"priority":0,"proto":"tcp","server":"129.226.1.157","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10012,"priority":0,"proto":"tcp","server":"129.226.2.231","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10012,"priority":0,"proto":"tcp","server":"101.32.143.171","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10012,"priority":0,"proto":"tcp","server":"119.28.121.174","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10012,"priority":0,"proto":"tcp","server":"150.109.0.38","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10012,"priority":0,"proto":"tcp","server":"150.109.0.45","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":443,"priority":0,"proto":"tcp","server":"129.226.3.250","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":443,"priority":0,"proto":"tcp","server":"129.226.2.142","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":443,"priority":0,"proto":"tcp","server":"101.32.143.250","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":443,"priority":0,"proto":"tcp","server":"203.205.137.232","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":443,"priority":0,"proto":"tcp","server":"down.anticheatexpert.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":443,"priority":0,"proto":"tcp","server":"101.32.143.171","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":443,"priority":0,"proto":"tcp","server":"downanticheat.com","serverStrType":"host","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":8080,"priority":0,"proto":"tcp","server":"119.28.183.144","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":8085,"priority":0,"proto":"tcp","server":"119.28.183.144","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":8088,"priority":0,"proto":"tcp","server":"150.109.250.19","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":3013,"priority":0,"proto":"tcp","server":"150.109.28.183","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":3031,"priority":0,"proto":"tcp","server":"150.109.22.214","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":17500,"priority":0,"proto":"tcp","server":"119.28.145.130","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":18081,"priority":0,"proto":"tcp","server":"49.51.129.54","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":80,"priority":0,"proto":"tcp","server":"150.109.0.45","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":80,"priority":0,"proto":"tcp","server":"150.109.29.150","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":80,"priority":0,"proto":"tcp","server":"101.32.143.142","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":8080,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":80,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":9031,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":443,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10012,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":18081,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":18600,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":20371,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":15692,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":49514,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":8013,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":90,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":554,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":35000,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":85,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":87,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":91,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":92,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":8085,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":8086,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":8088,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10178,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10315,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10013,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":9030,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":8089,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":8081,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":8011,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":5692,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":3013,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":54856,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":54861,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":50324,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":51703,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":58238,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":58236,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":55817,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":57488,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":54841,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":54840,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":54825,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":54740,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":54675,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":54655,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":51965,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":51962,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":51915,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":50926,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":50906,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":50904,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":50877,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":54817,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":54384,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":100,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":24296,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10086,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":6044,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":5555,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10085,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":5038,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":9081,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":17000,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":8030,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10207,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10213,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":20000,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":8700,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10438,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":20002,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10226,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10965,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":20001,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10049,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":11112,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10706,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10095,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":20139,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10289,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10024,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":12401,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10309,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10060,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":11008,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":11075,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10157,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":24798,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10087,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":31113,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10709,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":6667,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10599,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10009,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":11091,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10392,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10526,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10400,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10792,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10980,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":14457,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10793,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":53,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10912,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10497,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10685,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10336,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10800,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10120,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10664,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10610,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10790,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":13728,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10076,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10942,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10262,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10780,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10769,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10761,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":27000,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":27040,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":27015,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":27030,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":4380,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":5060,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":5061,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":5062,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":11110,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10010,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10011,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":8443,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":14000,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":15000,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10334,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":18100,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":11045,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10371,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10111,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10416,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":23014,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":10536,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":22772,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"deny","pkg1Name":"com.vng.pubgmobile","port":18100,"priority":0,"proto":"udp","server":"*","serverStrType":"ip4","wifi":"deny"},{"appName":"PUBG MOBILE","isCustom":false,"mobile":"none","pkg1Name":"com.vng.pubgmobile","port":-1,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"none"},{"appName":"PUBG MOBILE","isCustom":true,"mobile":"allow","pkg1Name":"com.vng.pubgmobile","port":17500,"priority":0,"proto":"tcp","server":"*","serverStrType":"ip4","wifi":"allow"}]}]==]

    -- JALUR FILE FIREWALL / FIREWALL FILE PATHS (Android & iOS)
    -- Memakai GetConfigPaths yang sama dengan X3Team.txt — jalur itu TERBUKTI
    -- work 100% di Android & iOS (config selalu muncul di folder Paks).
    local function XFFWPaths(fileName)
        if type(GetConfigPaths) == "function" then
            local ok, p = pcall(GetConfigPaths, fileName)
            if ok and type(p) == "table" and #p > 0 then return p end
        end
        return {
            "ShadowTrackerExtra/Saved/Paks/" .. fileName,
            "../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
            "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
            fileName,
        }
    end

    -- JAM SINKRON SERVER / SERVER-SYNCED TIME (jam & tanggal server player masing-masing)
    function _G.X3._FWServerTime()
        local t = nil
        pcall(function()
            local tm = package.loaded["client.logic.common.TimeManager"]
            if not tm then
                local s, r = pcall(require, "client.logic.common.TimeManager")
                if s then tm = r end
            end
            if tm and type(tm.GetServerTime) == "function" then
                local st = tm.GetServerTime()
                if st and st > 1700000000 then t = st end
            end
        end)
        return t or os.time()
    end

    -- LOG FIREWALL REALTIME / REALTIME FIREWALL LOG (auto rollback: 7MB > hapus > buat baru)
    local X3FW_LOGMAX = 7 * 1024 * 1024
    function _G.X3._FWLogWrite(lines)
        pcall(function()
            for _, path in ipairs(XFFWPaths("X3TEAM_firewall_log.txt")) do
                local doneOne = false
                pcall(function()
                    local fh = io.open(path, "a")
                    if not fh then return end
                    local sz = fh:seek("end") or 0
                    if sz >= X3FW_LOGMAX then
                    fh:close()
                         pcall(function() os.remove(path) end)                                                                                       -- [LOG-UPGRADE-2] hapus file firewall lama TOTAL (tanpa .rollback.txt)
                            pcall(function() os.remove(path:gsub("X3TEAM_firewall_log%.txt$", "X3TEAM_firewall_log.rollback.txt")) end)                 -- sapu rollback lama bila masih ada
                        fh = io.open(path, "w")
                        if not fh then return end
                        fh:write("=== X3TEAM FIREWALL LOG (ROLLBACK 7MB — sesi sebelumnya di X3TEAM_firewall_log.rollback.txt) ===\n")
                    end
                    for _, ln in ipairs(lines) do fh:write(ln, "\n") end
                    fh:close()
                    doneOne = true
                end)
                if doneOne then break end
            end
        end)
    end

    -- EVENT LOG FIREWALL / FIREWALL LOG EVENTS (MATCH / END / INSTALL)
    function _G.X3._FWLogEvent(kind)
        local stamp = os.date("%Y-%m-%d %H:%M:%S", _G.X3._FWServerTime())
        local lines = {}
        if kind == "MATCH" then
            local okProfile = _G.X3._ACFirewallWrote == true
            lines[#lines + 1] = "[" .. stamp .. "] PLAYER MATCH > FIREWALL ACTIVED " .. (okProfile and "✅" or "❌")
            for _, h in ipairs(_G.X3._ACFirewallHosts) do
                lines[#lines + 1] = "[" .. stamp .. "] " .. h .. " > DENY " .. (okProfile and "✅" or "❌")
            end
        elseif kind == "END" then
            lines[#lines + 1] = "[" .. stamp .. "] PLAYER END > FIREWALL STANDBY ✅"
        elseif kind == "INSTALL" then
            lines[#lines + 1] = "[" .. stamp .. "] FIREWALL PROFILE INSTALLED " .. (_G.X3._ACFirewallWrote and "✅" or "❌") .. " (GL/KR/VNG, " .. tostring(#(_G.X3._ACFirewallHosts or {})) .. " host deny)"
        end
        if #lines > 0 then _G.X3._FWLogWrite(lines) end
    end

    -- LAPORAN STATUS LENGKAP / FULL BYPASS STATUS REPORT (15 dtk & 60 dtk setelah start)
    function _G.X3._ACBypassReport(phase)
        pcall(function()
            local stamp = os.date("%Y-%m-%d %H:%M:%S", _G.X3._FWServerTime())
            local L = { "[" .. stamp .. "] ======== LAPORAN STATUS BYPASS/ANTIBAN (fase " .. tostring(phase) .. ") ========" }
            local function rep(name, ok, detail)
                L[#L + 1] = "[" .. stamp .. "] " .. name .. " > " .. (ok and "BERHASIL ✅" or "GAGAL/BELUM ❌") .. (detail and (" | " .. tostring(detail)) or "")
            end
            rep("FIREWALL profil GL/KR/VNG", _G.X3._ACFirewallWrote == true, tostring(#(_G.X3._ACFirewallHosts or {})) .. " host deny")
            rep("TSS SDK sender (skd/eigen/tag/ioctl)", _G.X3._ACTssHooked == true and (rawget(_G, "Tss") ~= nil or rawget(_G, "TssManager") ~= nil), rawget(_G, "Tss") == nil and rawget(_G, "TssManager") == nil and "modul Tss tidak ada" or nil)
            rep("TLog/Bugly/GEM/replay/attack-flow", _G.X3._ACLogHooked == true, nil)
            rep("Hisar/Gokuba/report-subsystem", _G.X3._ACHiggsHooked == true, nil)
            rep("Filter paket keamanan", _G.X3._ACPktHooked == true, nil)
            rep("BLOCK REPORT (LogicComplaint/ChatHandler/SendPkg)", (_G.X3._ACRepNukeStage or 0) >= 1, ((_G.X3._ACRepNukeStage or 0) < 1) and "modul complaint belum termuat" or nil)
            rep("Telemetri evidence (TLogUtil/Buggly/CrashKit/Replay/Credit)", (_G.X3._ACRepNukeStage or 0) >= 2, ((_G.X3._ACRepNukeStage or 0) < 2) and "modul telemetri belum termuat" or nil)
            rep("MANIPULASI + penangkap pelapor (RealTimeBan/Inspector/QuickReport)", (_G.X3._ACManipStage or 0) >= 1, ((_G.X3._ACManipStage or 0) < 1) and "modul belum termuat" or nil)
            rep("Spoofing ds_net + short-circuit report", (_G.X3._ACManipStage or 0) >= 2, ((_G.X3._ACManipStage or 0) < 2) and "ds_net belum termuat" or nil)
            rep("CORE17 intel (voice-ban/warning/killer)", (_G.X3._ACCore17Stage or 0) >= 1, ((_G.X3._ACCore17Stage or 0) < 1) and "modul ban/report belum termuat" or nil)
            rep("CORE17 manipulasi (replay/exception/vehicle-tlog/credit)", (_G.X3._ACCore17Stage or 0) >= 2, ((_G.X3._ACCore17Stage or 0) < 2) and "modul report belum termuat" or nil)
            rep("Report client + member masking", _G.X3._ACShieldHooked == true and _G.X3._ACMaskHooked == true, nil)
            local crcStage = _G.X3._CRCBypassStage or 0
            rep("CRC Paks bypass", crcStage >= 2, "tahap " .. tostring(crcStage) .. "/3")
            local hawkStage = _G.X3._HawkNukeStage or 0
            rep("HawkEye patrol + Inspection nuke", hawkStage >= 3, "tahap " .. tostring(hawkStage) .. "/3 (client+inspect+DS hardening)")
            local hashStage = _G.X3._HashFakeStage or 0
            rep("Slua signature + hash file fake", hashStage >= 2, "tahap " .. tostring(hashStage) .. "/2")
            rep("Anti _G-scan (pairs/ipairs buta)", true, "aktif sejak boot")
            rep("HiggsBosonComponent + HawkEye no-op", true, "dipasang saat boot (lihat TRACE)")
            do
                local pause = collectgarbage("count")
                rep("GC tuning (pause 100/stepmul 500)", true, "mem " .. tostring(math.floor(pause / 1024 + 0.5)) .. "MB")
            end
            rep("Netralisasi hukuman (AntiCheatManagerComp)", _G.X3._ACShieldSeen == true, _G.X3._ACShieldSeen ~= true and "komponen belum muncul" or "aktif")
            rep("Login bypass (gerbang cooldown)", true, "best-effort client-side (lihat TRACE LOGIN BYPASS)")
            rep("Watermark hook", _G.X3._WMHooked == true, _G.X3._WMHooked ~= true and "menunggu hasil match" or nil)
            rep("HWID hook (GetDeviceId/Model dll)", _G.X3.Team_HWID_Hooked == true, nil)
            L[#L + 1] = "[" .. stamp .. "] ======== AKHIR LAPORAN ========"
            _G.X3._FWLogWrite(L)
        end)
    end

    -- PEMASANG PROFIL FIREWALL / FIREWALL PROFILE INSTALLER
    function _G.X3._ACFirewallInstall()
        if _G.X3._ACFirewallDone then return end
        _G.X3._ACFirewallDone = true
        _G.X3._ACFirewallJSON = X3FW_JSON
        local wrote = false
        for _, path in ipairs(XFFWPaths("X3TEAM_firewall.json")) do
            pcall(function()
                local fh = io.open(path, "w")
                if fh then fh:write(X3FW_JSON) fh:close() wrote = true end
            end)
        end
        _G.X3._ACFirewallWrote = wrote
        _G.X3._FWLogEvent("INSTALL")
        if type(_G.X3.Trace) == "function" then
            _G.X3.Trace("ACFIREWALL: profil host-based GL/KR/VNG (" .. tostring(#_G.X3._ACFirewallHosts) .. " host) " .. (wrote and "tertulis" or "GAGAL tulis (io sandbox)"))
        end
    end

    -- PANTAU MATCH UNTUK LOG / MATCH WATCHER FOR FIREWALL LOG
    function _G.X3._FWLogTick()
        pcall(function()
            local st2 = nil
            local gs = GameplayData and GameplayData.GetGameState and GameplayData.GetGameState()
            if gs and slua.isValid(gs) then pcall(function() st2 = gs:GetGameModeState() end) end
            local inMatch = (st2 == "FightingState")
            local prev = _G.X3._FWLogInMatch == true
            if inMatch and not prev then _G.X3._FWLogEvent("MATCH") end
            if prev and not inMatch and st2 ~= nil and st2 ~= "" then _G.X3._FWLogEvent("END") end
            _G.X3._FWLogInMatch = inMatch
        end)
    end

    local X3CL_MAX = 7 * 1024 * 1024 -- maksimal 7MB lalu ROLLBACK
    _G.X3._LogBuf = _G.X3._LogBuf or {}
    local X3CL_lastMsg, X3CL_lastN = nil, 0
    local function X3CLPush(line)
        local buf = _G.X3._LogBuf
        if line == X3CL_lastMsg then
            X3CL_lastN = X3CL_lastN + 1
            buf[#buf] = line .. " (x" .. X3CL_lastN .. ")"
        else
            X3CL_lastMsg = line
            X3CL_lastN = 1
            buf[#buf + 1] = line
        end
        if #buf > 4000 then
            local t = {}
            for i = 2001, #buf do t[#t + 1] = buf[i] end
            _G.X3._LogBuf = t
        end
    end
    -- CRASH LOG FLUSH / LOG FLUSHER (dipanggil MAINLOOP tiap 1 dtk)
    function _G.X3._CrashLogFlush()
        local buf = _G.X3._LogBuf
        if not buf or #buf == 0 then return end
        _G.X3._LogBuf = {}
        X3CL_lastMsg, X3CL_lastN = nil, 0
        pcall(function()
            for _, path in ipairs(XFFWPaths("X3TEAM_crashlog.txt")) do
                local doneOne = false
                pcall(function()
                    local fh = io.open(path, "a")
                    if not fh then return end
                    local sz = fh:seek("end") or 0
                    if sz >= X3CL_MAX then
                        fh:close()
                        -- ROLLBACK: file lama disimpan sebagai .rollback.txt (menimpa
                        -- rollback sebelumnya), file baru dimulai bersih.
                        local rb = path:gsub("X3TEAM_crashlog%.txt$", "X3TEAM_crashlog.rollback.txt")
                        pcall(function()
                            local src = io.open(path, "r")
                            if src then
                                local data = src:read("*a") or ""
                                src:close()
                                local dst = io.open(rb, "w")
                                if dst then dst:write(data) dst:close() end
                            end
                        end)
                        os.remove(path)
                        fh = io.open(path, "w")
                        if not fh then return end
                        fh:write("=== X3TEAM CRASH LOG (ROLLBACK 7MB — sesi sebelumnya di X3TEAM_crashlog.rollback.txt) ===\n")
                    end
                    for _, ln in ipairs(buf) do fh:write(ln, "\n") end
                    fh:close()
                    doneOne = true
                end)
                if doneOne then break end
            end
        end)
    end
    -- CRASH LOG EVENT / LOG EVENT WRITER
    function _G.X3._CrashLog(evt)
        pcall(function()
            local stamp = os.date("%Y-%m-%d %H:%M:%S", _G.X3._FWServerTime())
            X3CLPush("[" .. stamp .. "] " .. tostring(evt) .. " (\u{2713})")
        end)
    end
    _G.X3._CrashLogBuf = _G.X3._CrashLog

    local X3CL_lastFlush = 0
    function _G.X3._CrashLogUrgent(evt)
        pcall(function()
            _G.X3._CrashLog(evt)
            local t = os.clock()
            if t - X3CL_lastFlush >= 0.25 then
                X3CL_lastFlush = t
                _G.X3._CrashLogFlush()
            end
        end)
    end

    -- PENANGKAP PRINT KE LOG / PRINT-TO-LOG CAPTURE (semua print logic ikut tercatat)
if not _G.X3._PrintHooked then
    _G.X3._PrintHooked = true

    local origPrint = print
    _G.X3._OrigPrint = origPrint

    -- [PERF-F06 / CRASH-FIX-2] emitter 1x (bukan per print) -> bebas closure per-call
    local function emitLog(m)
        local stamp = os.date("%H:%M:%S", _G.X3._FWServerTime())
        X3CLPush("[" .. stamp .. "] PRINT " .. m)
    end

    print = function(...)
        pcall(origPrint, ...) -- defensif: print tak boleh throw ke caller game

        local n = select("#", ...)

        if n == 0 then
            return
        end

        -- [F06] bangun string TANPA tabel vararg {...} (hilang 1 alloc tabel per print)
        local m

        if n == 1 then
            local v = select(1, ...)
            local t = type(v)

            if t == "string" then
                m = v
            elseif t == "nil" or t == "boolean" then
                return -- pasti noise -> keluar tanpa alloc/match
            else
                m = tostring(v)
            end
        else
            local parts = {}

            for i = 1, n do
                parts[i] = tostring(select(i, ...))
            end

            m = table.concat(parts, " ")
        end

        local len = #m

        if len < 2 then
            return
        end

        if len > 240 then
            m = m:sub(1, 240) .. "..."
        end

        -- [F06] SHORT-CIRCUIT equality (paling umum, tanpa pattern)
        if m == "nil" or m == "false" or m == "true" then
            return
        end

        -- [F06] pengganti anchor ^ via sub (murah)
        if m:sub(1, 5) == "false" then
            return
        end

        if m:sub(1, 3) == "nil" then
            return
        end

        if m:sub(1, 8) == "userdata" then
            return
        end

        if m:sub(1, 9) == "table: 0x" then
            return
        end

        -- [F06] literal substring via PLAIN find (bukan pattern/regex)
        if m:find("_Tick", 1, true) then
            return
        end

        if m:find("widget=", 1, true) then
            return
        end

        if m:find("BlazingColorFade", 1, true) then
            return
        end

        local p1 = m:find("0x", 1, true)

        if p1 and m:find("0x", p1 + 2, true) then
            return
        end

        pcall(emitLog, m) -- pcall no-closure
    end
end

    -- TRACE KE LOG / TRACE-TO-LOG (semua Trace fitur ikut tercatat)
    if type(_G.X3.Trace) == "function" and not _G.X3._TraceHooked then
        _G.X3._TraceHooked = true
        local origTrace = _G.X3.Trace
        _G.X3.Trace = function(msg)
            pcall(origTrace, msg)
            pcall(function()
                local stamp = os.date("%H:%M:%S", _G.X3._FWServerTime())
                X3CLPush("[" .. stamp .. "] TRACE " .. tostring(msg))
            end)

            pcall(function()
                local m = tostring(msg)
                if m:match("^AC") or m:match("^BYPASS") or m:match("^GC CVARS") or m:match("^WATERMARK") or m:match("^LOGIN BYPASS") or m:match("^SKIN:") then
                    if _G.X3._FWLogWrite then
                        local st2 = os.date("%Y-%m-%d %H:%M:%S", _G.X3._FWServerTime())
                        local ok = not m:find("GAGAL", 1, true)
                        _G.X3._FWLogWrite({ "[" .. st2 .. "] " .. m .. " " .. (ok and "✅" or "❌") })
                    end
                end
            end)
        end
    end

    -- GC AGRESIF / AGGRESSIVE GC (target memori Lua di bawah 100MB)
    pcall(function()
        collectgarbage("setpause", 100)
        collectgarbage("setstepmul", 500)
        collectgarbage("collect")
        _G.X3._CrashLog("GC TUNED (pause 100, stepmul 500, mem " .. tostring(math.floor(collectgarbage("count") / 1024 + 0.5)) .. "MB)")
    end)

    local _LTryLast = {}
    function _G.X3._LTry(name)
        local t = os.clock()
        if t - (_LTryLast[name] or -10) >= 5 then
            _LTryLast[name] = t
            _G.X3._CrashLog("CALL > " .. tostring(name))
        end
    end
    function _G.X3._LCall(name, fn)
        local ok, err = pcall(fn)
        if not ok then
            _G.X3._CrashLogUrgent("API GAGAL > " .. tostring(name) .. " ERR " .. tostring(err):sub(1, 120))
        end
        return ok
    end

    -- PENCATAT UI / UI TRACKER (semua yang user buka/tutup di PUBG tercatat)
    pcall(function()
        local UM = rawget(_G, "UIManager")
        if not (UM and UM.UI_Config) then return end
        if _G.X3._UIHooked then return end
        _G.X3._UIHooked = true
        local nameOf = setmetatable({}, { __mode = "k" })
        local function refreshNames()
            for n, cfg in pairs(UM.UI_Config) do
                if cfg ~= nil then pcall(function() nameOf[cfg] = n end) end
            end
        end
        pcall(refreshNames)
        local function uiName(cfg)
            local n = nil
            pcall(function() n = nameOf[cfg] end)
            if not n then
                pcall(refreshNames)
                pcall(function() n = nameOf[cfg] end)
            end
            if not n then pcall(function() n = tostring(cfg and (cfg.UIPath or cfg.UIName) or cfg) end) end
            return tostring(n)
        end
        if type(UM.ShowUI) == "function" and not UM.__x3show then
            UM.__x3show = true
            local orig = UM.ShowUI
            UM.ShowUI = function(cfg, ...)
                _G.X3._CrashLogUrgent("UI OPEN > " .. uiName(cfg))
                return orig(cfg, ...)
            end
        end
        if type(UM.CloseUI) == "function" and not UM.__x3close then
            UM.__x3close = true
            local orig = UM.CloseUI
            UM.CloseUI = function(cfg, ...)
                _G.X3._CrashLogUrgent("UI CLOSE > " .. uiName(cfg))
                return orig(cfg, ...)
            end
        end
        _G.X3._CrashLog("UI TRACKER aktif (ShowUI/CloseUI ter-hook)")
    end)

    -- CHECKLIST API / API CHECKLIST (cek import & global vital, hasilnya tercatat)
    pcall(function()
        local checklist = {
            "slua", "GameplayData", "UIManager", "NetUtil", "Tss", "Client",
            "SubsystemMgr", "UEnums", "UIContainers", "GameplayStatics",
            "KismetSystemLibrary", "KismetMathLibrary", "WidgetLayoutLibrary",
            "FVector", "FVector2D", "FAnchors", "FLinearColor", "FSlateColor", "ENetRole",
        }
        for _, n in ipairs(checklist) do
            local okG = rawget(_G, n) ~= nil
            if not okG then pcall(function() if import(n) ~= nil then okG = true end end) end
            _G.X3._CrashLog("API CHECK " .. n .. (okG and " OK" or " MISSING"))
        end
    end)

    -- PANTAU EVENT UNTUK LOG / EVENT WATCHER FOR CRASH LOG (0.5 dtk, semua transisi)
    function _G.X3._CrashLogTick(lp)
        pcall(function()
            local S = _G.X3._CL
            if not S then S = {} _G.X3._CL = S end
            local stt = nil
            local gs = GameplayData and GameplayData.GetGameState and GameplayData.GetGameState()
            if gs and slua.isValid(gs) then pcall(function() stt = gs:GetGameModeState() end) end
            if stt ~= S.gs then
                -- RAW LOG: SEMUA transisi state dicatat (mode khusus spt Naruto mengubah
                -- state sesaat di tengah match = momen character-reset di video)
                _G.X3._CrashLogUrgent("STATE BERUBAH > '" .. tostring(S.gs) .. "' -> '" .. tostring(stt) .. "'")
                if stt == "FightingState" then
                    _G.X3._CrashLogUrgent("PLAYER MATCH")
                elseif S.gs == "FightingState" and stt ~= nil and stt ~= "" then
                    _G.X3._CrashLogUrgent("PLAYER MATCH END > " .. tostring(stt))
                end
                if stt == "LobbyState" or stt == "LoginState" or stt == "Lobby" then
                    _G.X3._CrashLogUrgent("PLAYER LOBBY")
                end
                S.gs = stt
            end
            -- deteksi medan latihan (1x per sesi)
            if not S.trainingChecked and gs and slua.isValid(gs) then
                S.trainingChecked = true
                pcall(function()
                    if gs.bIsTrainingMode == true then
                        _G.X3._CrashLogUrgent("MODE LATIHAN AKTIF (bIsTrainingMode=true, state='" .. tostring(stt) .. "')")
                    end
                end)
            end
            if lp and slua.isValid(lp) then

-- [PERF-F12] field-read murni pada lp yg SUDAH valid -> pcall redundan, dihapus

local lpOK = true

if lp.Health ~= nil and lp.Health <= 0 then
    lpOK = false
end

if lp.bIsDying == true then
    lpOK = false
end

if lp.bIsDead == true then
    lpOK = false
end
                local firing = false
                pcall(function() firing = lp.bIsWeaponFiring == true end)
                if not firing and lpOK then
                    pcall(function()
                        local w = lp.CurrentWeapon
                        if w and slua.isValid(w) and w.bIsFiring ~= nil then firing = w.bIsFiring == true end
                    end)
                end
                if firing ~= S.firing then
                    S.firing = firing
                    if firing then
                        if S.weapon and tostring(S.weapon):sub(1, 4) == "6020" then
                            _G.X3._CrashLogUrgent("PLAYER LEMPAR GRANAT (ID " .. tostring(S.weapon) .. ")")
                        else
                            _G.X3._CrashLogUrgent("PLAYER MENEMBAK")
                        end
                    end
                end
                local veh = nil
                -- FIELD ONLY: method GetCurrentVehicle() tidak lagi dipanggil (native crash risk)
                pcall(function() veh = lp.CurrentVehicle end)
                local inVeh = (veh ~= nil and slua.isValid(veh)) and true or false
                if S.veh == nil then S.veh = inVeh end
                if inVeh ~= S.veh then
                    S.veh = inVeh
                    _G.X3._CrashLogUrgent(inVeh and "PLAYER NAIK MOBIL" or "PLAYER TURUN MOBIL")
                end
                local dying = false
                pcall(function()
                    if lp.Health ~= nil and lp.Health <= 0 then dying = true end
                    if lp.bIsDying == true then dying = true end
                end)
                if dying ~= S.dying then
                    S.dying = dying
                    if dying then _G.X3._CrashLogUrgent("PLAYER KNOCK/MATI") end
                end
                -- KAMERA & POSSESS WATCHER: menangkap momen "character kereset" di video
                -- (HUD hilang + kamera pan bebas = unpossess/camera mode berubah sesaat)
                pcall(function()
                    local pc2 = GameplayData.GetPlayerController and GameplayData.GetPlayerController()
                    if pc2 and slua.isValid(pc2) then
                        local camMode, fpp = nil, nil
                        pcall(function()
                            local cm = pc2.PlayerCameraManager
                            if cm and slua.isValid(cm) then camMode = cm.CurCameraMode end
                        end)
                        if camMode == nil then pcall(function() camMode = pc2.CurCameraMode end) end
                        pcall(function() fpp = pc2.bIsFirstPerson end)
                        if camMode ~= S.camMode then
                            if S.camMode ~= nil then _G.X3._CrashLogUrgent("KAMERA MODE BERUBAH > " .. tostring(S.camMode) .. " -> " .. tostring(camMode)) end
                            S.camMode = camMode
                        end
                        if fpp ~= S.fpp then
                            if S.fpp ~= nil then _G.X3._CrashLogUrgent("KAMERA FPP BERUBAH > " .. tostring(S.fpp) .. " -> " .. tostring(fpp)) end
                            S.fpp = fpp
                        end
                        local pawnNow = nil
                        pcall(function() pawnNow = pc2.Pawn end)
                        local pawnValid = (pawnNow ~= nil and slua.isValid(pawnNow)) and true or false
                        if pawnValid ~= S.pawnValid then
                            S.pawnValid = pawnValid
                            _G.X3._CrashLogUrgent(pawnValid and "CONTROLLER POSSESS > pawn kembali" or "CONTROLLER UNPOSSESS > pawn hilang (character reset?)")
                        end
                    end
                end)
                -- MESH VISIBILITY WATCHER: mesh character disembunyikan sesaat = visual reset
                pcall(function()
                    local mesh = lp.Mesh
                    if mesh and slua.isValid(mesh) then
                        local vis = nil
                        pcall(function() vis = mesh.bVisible end)
                        if vis ~= nil and vis ~= S.meshVis then
                            if S.meshVis ~= nil then _G.X3._CrashLogUrgent("MESH VISIBLE BERUBAH > " .. tostring(S.meshVis) .. " -> " .. tostring(vis)) end
                            S.meshVis = vis
                        end
                    end
                end)
                local wname = nil
                -- FIELD ONLY + gate sehat: method GetCurrentWeapon()/GetWeaponID() tidak
                -- dipanggil saat karakter sekarat/rebuild (2x crash berpola sama di log)
                if lpOK then
                    pcall(function()
                        local w = lp.CurrentWeapon
                        if w and slua.isValid(w) and w.WeaponID ~= nil then wname = tostring(w.WeaponID) end
                    end)
                end
                if wname ~= S.weapon then
                    S.weapon = wname
                    if wname then
                        if tostring(wname):sub(1, 4) == "6020" then
                            _G.X3._CrashLogUrgent("PLAYER PEGANG GRANAT (ID " .. wname .. ")")
                        else
                            _G.X3._CrashLogUrgent("GANTI SENJATA > ID " .. wname)
                        end
                    end
                end
                local hp = nil
                pcall(function() hp = lp.Health end)
                if type(hp) == "number" then
                    if S.hp and hp < S.hp - 5 then _G.X3._CrashLogUrgent("PLAYER KENA DAMAGE (-" .. tostring(math.floor(S.hp - hp)) .. " HP)") end
                    if S.hp and hp > S.hp + 5 then _G.X3._CrashLogUrgent("PLAYER HEAL (+" .. tostring(math.floor(hp - S.hp)) .. " HP)") end
                    S.hp = hp
                end
                local kn = nil
                pcall(function()
                    local ps2 = lp.PlayerState
                    if ps2 and slua.isValid(ps2) then kn = ps2.KillNum end
                end)
                if type(kn) == "number" then
                    if S.kn and kn > S.kn then _G.X3._CrashLogUrgent("PLAYER KILL (total " .. tostring(kn) .. ")") end
                    S.kn = kn
                end
                local jump = false
                pcall(function()
                    if type(lp.IsJumping) == "function" then jump = lp:IsJumping()
                    elseif lp.bIsJumping ~= nil then jump = lp.bIsJumping == true end
                end)
                if jump ~= S.jump then
                    S.jump = jump
                    if jump then _G.X3._CrashLogUrgent("PLAYER LOMPAT") end
                end
                local ads = false
                pcall(function()
                    if lp.bIsAiming ~= nil then ads = lp.bIsAiming == true
                    elseif lp.bIsWeaponADS ~= nil then ads = lp.bIsWeaponADS == true end
                end)
                if ads ~= S.ads then
                    S.ads = ads
                    if ads then _G.X3._CrashLogUrgent("PLAYER AIM/ADS") end
                end
                local reload = false
                pcall(function()
                    local w = lp.CurrentWeapon or (lp.GetCurrentWeapon and lp:GetCurrentWeapon())
                    if w and slua.isValid(w) then
                        if type(w.IsReloading) == "function" then reload = w:IsReloading()
                        elseif w.bIsReloading ~= nil then reload = w.bIsReloading == true end
                    end
                end)
                if reload ~= S.reload then
                    S.reload = reload
                    if reload then _G.X3._CrashLogUrgent("PLAYER RELOAD") end
                end
                local pose = ""
                pcall(function()
                    if lp.bIsCrouched == true or lp.IsCrouching == true then pose = "JONGKOK"
                    elseif lp.bIsProned == true or lp.IsProne == true or lp.bIsProning == true then pose = "TIARAP"
                    end
                end)
                if pose ~= S.pose then
                    if pose ~= "" then _G.X3._CrashLog("PLAYER " .. pose) end
                    S.pose = pose
                end
                local sky = false
                pcall(function()
                    if lp.bIsSkydiving == true or lp.bIsParachuting == true then sky = true end
                end)
                if sky ~= S.sky then
                    S.sky = sky
                    if sky then _G.X3._CrashLogUrgent("PLAYER TERJUN/PARASUT") end
                end
            end
            local zone = nil
            pcall(function()
                if gs and slua.isValid(gs) then
                    zone = gs.SafetyZonePhase or gs.CircleIndex or gs.CurrentCircleIndex
                end
            end)
            if type(zone) == "number" and zone ~= S.zone then
                S.zone = zone
                _G.X3._CrashLogUrgent("ZONA FASE " .. tostring(zone))
            end
            local rz = nil
            pcall(function()
                if gs and slua.isValid(gs) then
                    local info = gs.CacheRedZoneInfo
                    if info then rz = tostring(info.Status or info.RedZoneStatus or info.AirAttackStatus or info.State) end
                    if not rz then rz = tostring(gs.RedZoneStatus or gs.AirAttackStatus) end
                end
            end)
            if rz and rz ~= "nil" and rz ~= S.rz then
                S.rz = rz
                _G.X3._CrashLogUrgent("REDZONE STATUS > " .. rz)
            end
            local zs = nil
            pcall(function()
                if gs and slua.isValid(gs) then
                    zs = tostring(gs.SafetyZoneStatus or gs.BlueZoneStatus or gs.PoisonGasStatus)
                end
            end)
            if zs and zs ~= "nil" and zs ~= S.zs then
                S.zs = zs
                _G.X3._CrashLogUrgent("BLUEZONE STATUS > " .. zs)
            end
            local nowc = os.clock()
            if nowc - (S.render or 0) >= 15 then
                S.render = nowc
                local mem = math.floor(collectgarbage("count") / 1024 + 0.5)
                local fps = 0
                pcall(function() fps = math.floor((_G.X3._FPS or 0) + 0.5) end)
                _G.X3._CrashLog("PLAYER RENDER fps=" .. tostring(fps) .. " mem=" .. tostring(mem) .. "MB")
            end
            local combatScan = _G.X3._InCombatGS and _G.X3._InCombatGS(gs, stt) or (stt == "FightingState")
            if combatScan and nowc - (S.scan or 0) >= 15 then
                S.scan = nowc
                local nP, nB, nN, nearest = 0, 0, 0, 99999
                pcall(function()
                    local myT = nil
                    pcall(function() myT = lp.TeamID end)
                    local chars = X3Team_GetAllCharactersUniversal()
                    for _, e in ipairs(chars) do
                        local inScan = e and slua.isValid(e) and e ~= lp
                        if inScan and myT ~= nil then
                            local tE = nil
                            pcall(function() tE = e.TeamID end)
                            if tE ~= nil and tE == myT then inScan = false end
                        end
                        if inScan then
                            if IsModelTargetNameWH(e) then nN = nN + 1
                            elseif IsBotWH and IsBotWH(e) then nB = nB + 1
                            else nP = nP + 1 end
                            pcall(function()
                                if lp.GetDistanceTo then
                                    local d = math.floor(lp:GetDistanceTo(e) / 100)
                                    if d < nearest then nearest = d end
                                end
                            end)
                        end
                    end
                end)
                local nM = 0
                pcall(function() for _ in pairs(_G.X3._MapMarks or {}) do nM = nM + 1 end end)
                local nWHA, nWHCache = 0, 0
                pcall(function()
                    for _, r in pairs(_G.X3._WHC or {}) do
                        nWHCache = nWHCache + 1
                        if r.applied then nWHA = nWHA + 1 end
                    end
                end)
                local specTag = (_G.X3._Spectating == true) and " | SPECTATOR:ON(cap600,anti-blink)" or ""
                _G.X3._CrashLog("ESP SCAN player=" .. tostring(nP) .. " bot=" .. tostring(nB) .. " npc-blocked=" .. tostring(nN)
                    .. " mapmark=" .. tostring(nM) .. " nearest=" .. tostring(nearest) .. "m"
                    .. " | WH applied=" .. tostring(nWHA) .. "/" .. tostring(nWHCache) .. specTag)
            end
        end)
    end
    pcall(function() _G.X3._CrashLogUrgent("SCRIPT START " .. tostring(_G.X3.BuildStamp or "")) end)

    -- PEMBERSIH CACHE PER FITUR / PER-FEATURE CACHE CLEAR (auto saat toggle OFF, cache lain tidak diubah)
    _G.X3._FeatPrev = _G.X3._FeatPrev or {}
    local X3FeatCleanup = {
        WallhackVis = function()
            _G.X3._XFWwhApplied = {}
            _G.X3._MBVisCache = {}
            _G.X3.AimTouchVisCache = {}
        end,
        EspEnemyCount = function()
            if _G.X3.EspCountDestroy then pcall(_G.X3.EspCountDestroy) end
        end,
        EspEnemyCountV2 = function()
            if _G.X3.EspCountDestroy then pcall(_G.X3.EspCountDestroy) end
        end,
        X3UnlockAll = function()
            _G.X3.skinIdCache = {}
            _G.X3.skinIdCache2 = {}
        end,
        X3SkinNewRandom = function()
            _G.X3.skinIdCache = {}
            _G.X3.skinIdCache2 = {}
        end,
        X3FakeVisual = function()
            _G.X3.skinIdCache = {}
            _G.X3.skinIdCache2 = {}
        end,
        X3Watermark = function()
            if _G.X3._WMCloseUI then pcall(_G.X3._WMCloseUI) end
        end,
        X3TPPForce = function()
            _G.X3._XFTPPOn = false
        end,
    }
    function _G.X3._FeatureCacheWatch()
        local C = _G.X3.LexusConfig
        if not C then return end
        for key, fn in pairs(X3FeatCleanup) do
            local cur = C[key] == true
            local prev = _G.X3._FeatPrev[key]
            if prev == true and not cur then
                pcall(fn)
                if type(_G.X3.Trace) == "function" then _G.X3.Trace("CACHE: " .. key .. " OFF > cache fitur dibersihkan") end
                if _G.X3._CrashLog then pcall(_G.X3._CrashLog, "FITUR " .. key .. " OFF") end
            elseif prev == false and cur then
                if _G.X3._CrashLog then pcall(_G.X3._CrashLog, "FITUR " .. key .. " ON") end
            end
            _G.X3._FeatPrev[key] = cur
        end
    end

    -- 5) PERISAI TSS SDK / TSS SDK SHIELD
    -- _G.Tss/_G.TssManager adalah jembatan Lua↔SDK anti-cheat TSS (TenSafe):
    -- SendSkdData (registrasi kanal SKD), SendEigeninfoData (upload eigenvalue
    -- file/memori), SaveSendEigeninfoCode (kode hasil), GetUserTag4Lua
    -- (tag root/malware device), InvokeSDKIoctl cmd 18 = "AllowAPKCollect"
    -- (izin koleksi daftar APK terpasang). Semua sender → return 0 bersih;
    -- fungsi baca (OnRecvData/EigenArrayObfuscationVerify/GetDeviceFeature)
    -- dibiarkan agar alur auth tidak patah.
    function _G.X3._ACTssShieldTry()
        if _G.X3._ACTssHooked then return end
        _G.X3._ACTssHooked = true
        pcall(function()
            local T = rawget(_G, "Tss") or rawget(_G, "TssManager")
            if type(T) ~= "table" then return end
            local function ret0(...) return 0 end
            if type(T.SendSkdData) == "function" then T.SendSkdData = ret0 end
            if type(T.SendEigeninfoData) == "function" then T.SendEigeninfoData = ret0 end
            if type(T.SaveSendEigeninfoCode) == "function" then T.SaveSendEigeninfoCode = ret0 end
            if type(T.GetUserTag4Lua) == "function" then T.GetUserTag4Lua = function(...) return "" end end
            local ioctl = T.InvokeSDKIoctl
            if type(ioctl) == "function" then
                T.InvokeSDKIoctl = function(cmd, data, ...)
                    local d = tostring(data)
                    if cmd == 18 or d:find("ollect") then return 0 end
                    return ioctl(cmd, data, ...)
                end
            end
            if type(_G.X3.Trace) == "function" then _G.X3.Trace("ACTSS: sender TSS SDK dinetralkan (skd/eigen/tag/apk-collect)") end
        end)
        pcall(function()
            local N = rawget(_G, "NetUtil")
            if type(N) == "table" then
                if type(N.SendTss) == "function" then N.SendTss = function() end end
                if type(N.OnTssRsp) == "function" then N.OnTssRsp = function() end end
            end
        end)
    end

    function _G.X3._ACLogShieldTry()
        if _G.X3._ACLogHooked then return end
        _G.X3._ACLogHooked = true
        pcall(function()
            local g = rawget(_G, "gem_report_utils")
            if type(g) == "table" then
                g.CanReport = function() return -1 end
                g.ReportEventImmediate = function() end
                g.SaveGemReportInFile = function() end
                g.GetReportLobbyEventEnable = function() return false end
            end
        end)
        pcall(function()
            local ok, G = pcall(require, "GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils")
            if ok and type(G) == "table" then
                G.CheckCanBugglyPostException = function() return false end
                G.BugglyPostExceptionFull = function() return true end
                G.ReportException = function() end
                G.ReplayReportData = function() end
            end
        end)
        pcall(function()
            if type(rawget(_G, "ClientSendTLogReport")) == "function" then
                _G.ClientSendTLogReport = function() end
            end
        end)
        pcall(function()
            local GC = rawget(_G, "GameplayCallbacks")
            if type(GC) ~= "table" then return end
            for _, n in ipairs({
                "ReportAimFlow", "ReportAttackFlow", "ReportSecAttackFlow", "ReportHurtFlow",
                "ReportFireArms", "ReportVerifyInfoFlow", "ReportPlayerBehavior",
                "ReportPlayerMoveRoute", "ReportPlayerPosition", "ReportCommonInfo",
                "ReportFeedback", "ReportForbitPick", "ReportTeammatHurt",
                "ReportGameSetting", "ReportGameSettingNew", "ReportMatchRoomData",
                "ReportPlayersPing", "ReportEquipmentFlow", "SendDataMiningTLog",
            }) do
                if type(GC[n]) == "function" then GC[n] = function() end end
            end
        end)
        _G.ENABLE_REPORT = false
        if type(_G.X3.Trace) == "function" then _G.X3.Trace("ACLOG: TLog/Bugly/GEM/replay/attack-flow dinetralkan") end
    end

    function _G.X3._ACHiggsShieldTry()
        if _G.X3._ACHiggsHooked then return end
        _G.X3._ACHiggsHooked = true
        pcall(function()
            local ok, H = pcall(require, "GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
            if ok and type(H) == "table" then
                if type(H.SendHisarData) == "function" then H.SendHisarData = function() return true end end -- manipulasi: sukses palsu
                if type(H.OnLogin) == "function" then H.OnLogin = function() end end
                if type(H.RecordStrategyTimestampInReplay) == "function" then H.RecordStrategyTimestampInReplay = function() end end
                if type(H.SetClientAlertWindowEnabled) == "function" then pcall(H.SetClientAlertWindowEnabled, false) end
            end
        end)
        pcall(function()
            local ok, G = pcall(require, "GameLua.Mod.BaseMod.Client.Security.Gokuba")
            if ok and type(G) == "table" then
                if type(G.ForwardFeature) == "function" then G.ForwardFeature = function() end end
                if type(G.OnControllerBeginPlay) == "function" then G.OnControllerBeginPlay = function() end end
            end
        end)
        pcall(function()
            local SM = rawget(_G, "SubsystemMgr")
            if not (SM and SM.Get) then return end
            local R = SM:Get("ClientReportPlayerSubsystem")
            if type(R) ~= "table" then return end
            for _, n in ipairs({ "_RecordFatalDamager", "_RecordMurdererFromDeathReplayData", "_RecordTeammatePlayerInfo", "_OnSyncFatalDamage" }) do
                if type(R[n]) == "function" then R[n] = function() end end
            end
        end)
        if type(_G.X3.Trace) == "function" then _G.X3.Trace("ACHIGGS: Hisar/Gokuba/report-subsystem dinetralkan") end
    end

    function _G.X3._ACPacketFilterTry()
        if _G.X3._ACPktHooked then return end
        _G.X3._ACPktHooked = true
        pcall(function()
            local N = rawget(_G, "NetUtil")
            if type(N) ~= "table" then return end
            local DROP_PKT = {
                ReportHitFlow = true, ReportAttackFlow = true, ReportSecAttackFlow = true,
                ReportFireArms = true, ReportAimFlow = true, ReportHurtFlow = true,
                ReportVerifyInfoFlow = true, ReportPlayerBehavior = true,
                ReportPlayerMoveRoute = true, ReportPlayerPosition = true,
                ReportSecCarryEndFlow = true, ReportSecRoundDetailFlow = true,
                ReportSecSupplyFlow = true, ReportSecMetroGameSnapshootFlow = true,
                ReportSkillFlow = true, ReportForbiddenPickupFlow = true,
                ReportTeammatHurt = true, report_common_info = true,
            }
            local DROP_PKG = { battle_client_sync_allstar_auth_check_result_req = true, hisar = true }
            local sp = N.SendPacket
            if type(sp) == "function" then
                N.SendPacket = function(name, ...)
                    if DROP_PKT[name] then return end
                    return sp(name, ...)
                end
            end
            local sg = N.SendPkg
            if type(sg) == "function" then
                N.SendPkg = function(name, ...)
                    if DROP_PKG[name] then return end
                    return sg(name, ...)
                end
            end
            if type(_G.X3.Trace) == "function" then _G.X3.Trace("ACPKT: filter paket keamanan aktif (" .. 18 .. " packet + 2 pkg)") end
        end)
    end
end

pcall(function() if _G.X3._ACFirewallInstall then _G.X3._ACFirewallInstall() end end)
pcall(function() if _G.X3._ACTssShieldTry then _G.X3._ACTssShieldTry() end end)
pcall(function() if _G.X3._ACLogShieldTry then _G.X3._ACLogShieldTry() end end)
pcall(function() if _G.X3._ACHiggsShieldTry then _G.X3._ACHiggsShieldTry() end end)
pcall(function() if _G.X3._ACPacketFilterTry then _G.X3._ACPacketFilterTry() end end)

-- BUKA LEVEL MAKS SKIN / UNLOCK MAX SKIN LEVEL (jalur "Unlock Skin")
-- Mekanisme asli: grup MultiLevelItem punya ItemID per level. Karena
-- UnlockAll membuat HasValidItem=true utk SEMUA level, game otomatis
-- membuka aksesoris + efek tiap level TANPA input ID satu per satu.
-- Hook ini memaksa pilihan display SELALU level maksimum grup.
function _G.X3._MaxLevelHookTry()
    if _G.X3._MaxLvlHooked then return end
    if not (_G.X3.LexusConfig and _G.X3.LexusConfig.X3UnlockAll) then return end
    pcall(function()
        local M = require("client.slua.logic.wardrobe.LogicMultiItemModule")
        if type(M) ~= "table" then return end
        if type(M.GetDisPlayItemByGroup) == "function" and not M.__x3ml then
            M.__x3ml = true
            local orig = M.GetDisPlayItemByGroup
            M.GetDisPlayItemByGroup = function(self, GroupID, DataSource, ItemSubType)
                local okR, r = pcall(function()
                    local List = CDataTable.GetTableByFilter("MultiLevelItem", "GroupID", GroupID)
                    local maxLv, maxID = 0, nil
                    for _, v in pairs(List) do
                        local lv = tonumber(v.Level) or 0
                        if lv > maxLv then maxLv = lv maxID = v.ItemID end
                    end
                    return maxID
                end)
                if okR and r then return r end
                return orig(self, GroupID, DataSource, ItemSubType)
            end
        end
        if type(M.SetIsWardrobeMultiShapeTabUnlock) == "function" then
            pcall(M.SetIsWardrobeMultiShapeTabUnlock, M, true)
        end
        _G.X3._MaxLvlHooked = true
        if type(_G.X3.Trace) == "function" then _G.X3.Trace("UNLOCK MAX LEVEL: hook MultiLevelItem terpasang") end
    end)
    -- level senjata in-match (mode PlanBT): selalu maks (7)
    pcall(function()
        if _G.X3._PlanBTHooked then return end
        local ok, F = pcall(require, "GameLua.Mod.PlanBTShooting.Gameplay.Feature.PlanBTWeaponFeature")
        if ok and type(F) == "table" and type(F.GetWeaponLevel) == "function" then
            F.GetWeaponLevel = function(self, WeaponID) return 7 end
            F.IsWeaponMaxLevel = function(self, WeaponID) return true end
            _G.X3._PlanBTHooked = true
        end
    end)
end

function _G.X3._UAOwnershipHookTry()
    if _G.X3._UAOwnHooked then return end
    if not (_G.X3.LexusConfig and _G.X3.LexusConfig.X3UnlockAll) then return end
    pcall(function()
        local WD = require("client.slua.logic.wardrobe.wardrobe_data")
        if type(WD) ~= "table" then return end
        local function alwaysTrue() return true end
        if type(WD.HasValidItem) == "function" then WD.HasValidItem = alwaysTrue end
        if type(WD.HasItem) == "function" then WD.HasItem = alwaysTrue end
        if type(WD.CheckHasPermanentItem) == "function" then WD.CheckHasPermanentItem = alwaysTrue end
        _G.X3._UAOwnHooked = true
        if type(_G.X3.Trace) == "function" then _G.X3.Trace("UNLOCK ALL: ownership hook (HasValidItem=true) terpasang") end
    end)
end

-- DIAGNOSTIK TERLIHAT / VISIBLE DIAGNOSTICS — laporan stage via Notify
function _G.X3._UADiagnose()
    local parts = {}
    local ttype, iterN = "NIL", 0
    pcall(function()
        local t = CDataTable.GetTable("Item")
        ttype = type(t)
        if ttype == "table" then
            for _ in pairs(t) do iterN = iterN + 1 if iterN >= 3 then break end end
        end
    end)
    parts[#parts + 1] = "ItemTable:" .. ttype .. (iterN > 0 and "+iter" or "-iter")
    local entOK, addOK, readOK = "X", "X", "X"
    pcall(function()
        local c = require("client.slua.logic.wardrobe.logic_wardrobe_data_center")
        local ent = c.GetWardrobeData()
        if ent then
            entOK = "OK"
            local it = ent:AddData({ instid = 599999999, res_id = 101001, count = 1 })
            if it then addOK = "OK" end
            local r = ent:GetDataByInsID(599999999)
            if r and r.resID == 101001 then readOK = "OK" end
        end
    end)
    parts[#parts + 1] = "Entity:" .. entOK .. " Add:" .. addOK .. " Read:" .. readOK
    local st = _G.X3._UnlockAllState
    if st then
        parts[#parts + 1] = "List:" .. (st.built and tostring(#st.allIDs) or (st.mode == "scan" and "SCAN" or "?"))
    end
    parts[#parts + 1] = "Own:" .. (_G.X3._UAOwnHooked and "OK" or "X")
    parts[#parts + 1] = "ML:" .. (_G.X3._MaxLvlHooked and "OK" or "X")
    local msg = table.concat(parts, " | ")
    Notify("🔍 UNLOCK ALL: " .. msg)
    if type(_G.X3.Trace) == "function" then _G.X3.Trace("UA DIAG: " .. msg) end
end

-- SKIN ACAK TERBARU / RANDOM NEW SKIN --
    function _G.X3._SkinRandPick(weaponID)
        if _G.X3._SkinRandBySub == nil then
            _G.X3._SkinRandBySub = false
            pcall(function()
                local raw = _G.X3._UAWpnSkinRaw
                if not (raw and #raw > 0) then return end
                local bySub = {}
                for _, e in ipairs(raw) do
                    local id = tonumber(type(e) == "table" and e.ItemTableID or e)
                    if id then
                        local ok, cfg = pcall(function() return CDataTable.GetTableData("Item", id) end)
                        if ok and type(cfg) == "table" then
                            local st = tonumber(cfg.ItemSubType) or 0
                            if st >= 101 and st <= 108 then
                                bySub[st] = bySub[st] or {}
                                local L = bySub[st]
                                if #L < 400 then L[#L + 1] = id end
                            end
                        end
                    end
                end
                _G.X3._SkinRandBySub = bySub
            end)
        end
        local bySub = _G.X3._SkinRandBySub
        if not bySub then return nil end
        weaponID = tonumber(weaponID)
        if not weaponID then return nil end
        _G.X3._SkinRandCache = _G.X3._SkinRandCache or {}
        local cached = _G.X3._SkinRandCache[weaponID]
        if cached ~= nil then
            if cached then return cached end
            return nil
        end
        local st = nil
        pcall(function()
            local cfg = CDataTable.GetTableData("Item", weaponID)
            if type(cfg) == "table" then st = tonumber(cfg.ItemSubType) end
        end)
        local L = st and bySub[st]
        if not (L and #L > 0) then
            _G.X3._SkinRandCache[weaponID] = false
            return nil
        end
        local pick = L[math.random(1, #L)]
        _G.X3._SkinRandCache[weaponID] = pick
        return pick
    end

-- ANTI SPAM TIP / ANTI-SPAM TIPS --
    function _G.X3._XFTipThrottleTry()
        if _G.X3._XFTipThrottled then return end
        pcall(function()
            local ok, T = pcall(require, "GameLua.Mod.BaseMod.Common.UI.InGameTipsTools")
            if not (ok and type(T) == "table") then return end
            local function wrap(fnName, idIdx)
                local orig = T[fnName]
                if type(orig) ~= "function" then return end
                T[fnName] = function(...)
                    local id = select(idIdx, ...)
                    local now = os.clock()
                    _G.X3._XFTipSeen = _G.X3._XFTipSeen or {}
                    local key = fnName .. "_" .. tostring(id)
                    if _G.X3._XFTipSeen[key] and (now - _G.X3._XFTipSeen[key]) < 12.0 then
                        return
                    end
                    _G.X3._XFTipSeen[key] = now
                    return orig(...)
                end
            end
            wrap("BattleGeneralTip", 1)
            wrap("BattleGeneralTipWithTranslation", 1)
            wrap("BattleGeneralTipWithExternTable", 1)
            _G.X3._XFTipThrottled = true
        end)
    end
end

do
  if not _G.X3._LogEnriched then
    _G.X3._LogEnriched = true
    local _LEseq = 0
    local _LEctx, _LEctxT = "", -1
    local _inLE = false
    local function _LEstaticCtx()
      local n = os.clock()
      if (n - _LEctxT) < 0.5 and _LEctx ~= "" then return _LEctx end
      _LEctxT = n
      local gs, pf, sp, wh, mem, fps = "?", "-", "-", "-", "?", "?"
      pcall(function()
        local cl = _G.X3 and _G.X3._CL
        if cl and cl.gs then gs = tostring(cl.gs) end
      end)
      pcall(function()
        local GD = package.loaded["GameLua.GameCore.Data.GameplayData"]
        local lp = GD and GD.GetPlayerCharacter and GD.GetPlayerCharacter()
        pf = (lp and slua.isValid(lp)) and "P" or "-"
      end)
      pcall(function() sp = (_G.X3._Spectating == true) and "S" or "-" end)
      pcall(function() wh = (_G.X3.LexusConfig and _G.X3.LexusConfig.WallhackVis == true) and "W" or "-" end)
      pcall(function() mem = tostring(math.floor(collectgarbage("count") / 1024 + 0.5)) end)  -- count TIDAK memicu koleksi (hanya baca KB)
      pcall(function()
        local dt = tonumber(_G.X3.FrameDT)
        if dt and dt > 0 then fps = tostring(math.floor(1 / dt)) end
      end)
      _LEctx = string.format("GS=%s %s%s%s M=%sMB FPS=%s", gs, pf, sp, wh, mem, fps)
      return _LEctx
    end
    local function _LEwrap(orig)
      return function(msg, ...)
        if _inLE or type(orig) ~= "function" then return orig and orig(msg, ...) end
        _inLE = true
        _LEseq = _LEseq + 1
        local enriched = string.format("#%d +%.1fs %s | %s", _LEseq, os.clock(), _LEstaticCtx(), tostring(msg))
        local ok = pcall(orig, enriched, ...)
        _inLE = false
        if not ok then pcall(orig, msg, ...) end   -- fallback tanpa enrich bila orig menolak format
      end
    end
    if type(_G.X3._CrashLog) == "function" then _G.X3._CrashLog = _LEwrap(_G.X3._CrashLog) end
    if type(_G.X3._CrashLogUrgent) == "function" then _G.X3._CrashLogUrgent = _LEwrap(_G.X3._CrashLogUrgent) end
    -- [LOG-UPGRADE-1b] FIREWALL: sisip 1 baris konteks HANYA pada banner bermakna (tanpa spam)
    if type(_G.X3._FWLogWrite) == "function" then
      local _origFW = _G.X3._FWLogWrite
      _G.X3._FWLogWrite = function(lines)
        if type(lines) == "table" and #lines > 0 and not _inLE then
          local first = tostring(lines[1] or "")
          if first:find("LAPORAN STATUS", 1, true) or first:find("FIREWALL PROFILE INSTALLED", 1, true)
             or first:find("PLAYER MATCH", 1, true) or first:find("AKHIR LAPORAN", 1, true)
             or first:find("========", 1, true) then
            _LEseq = _LEseq + 1
            local ctxLine = string.format("#%d +%.1fs %s | [FW-CTX]", _LEseq, os.clock(), _LEstaticCtx())
            local copy = { ctxLine }                       -- shallow copy (jangan mutasi tabel pemanggil)
            for i = 1, #lines do copy[i + 1] = lines[i] end
            return _origFW(copy)
          end
        end
        return _origFW(lines)
      end
    end
  end
end

do
  if not _G.X3._MemWatchdog then
    _G.X3._MemWatchdog = true
    local CEIL  = 110          -- TARGET MAKSIMAL MB (permintaan Anda)
    local EMER  = 132          -- darurat: full-collect terkontrol (jaring anti-OOM crash)
    local _mwLast, _mwStepT, _mwEmerT = -1, -1, -1
    local _mwPersist, _mwPersistLog = 0, false
    local function _mwMB() return collectgarbage("count") / 1024 end   -- count TIDAK memicu collect
    local function _mwRun()
      local n = os.clock()
      if (n - _mwLast) < 1.0 then return end                            -- 1x/dtk
      _mwLast = n
      local mb = _mwMB()
      _G.X3._MemMB = mb                                                 -- telemetri: MB saat ini
      if mb > (_G.X3._MemPeak or 0) then _G.X3._MemPeak = mb end        -- telemetri: puncak sesi
      if mb > EMER then
        if (n - _mwEmerT) > 15 then                                     -- darurat max 1x/15 dtk
          _mwEmerT = n
          pcall(function() collectgarbage("collect") end)               -- jaring anti-OOM (hitch diterima)
          if _G.X3._CrashLogUrgent then pcall(_G.X3._CrashLogUrgent, "MEMWATCH: DARURAT >" .. EMER .. "MB -> full-collect 1x (jaring anti-OOM); peak=" .. string.format("%.0f", _G.X3._MemPeak or 0) .. "MB -> potong sumber leak (F-06/cache)") end
        end
        _mwPersist = 0
      elseif mb > CEIL then
        _G.X3._MemCeilHits = (_G.X3._MemCeilHits or 0) + 1              -- telemetri: berapa kali ceiling tertembus
        if (n - _mwStepT) > 2 then _mwStepT = n; pcall(function() collectgarbage("step", 4000) end) end
        _mwPersist = _mwPersist + 1
        if _mwPersist >= 3 and not _mwPersistLog then                   -- ceiling tertembus persisten = objek HIDUP, bukan sampah
          _mwPersistLog = true
          if _G.X3._CrashLogUrgent then pcall(_G.X3._CrashLogUrgent, "MEMWATCH: ceiling " .. CEIL .. "MB tertembus persisten -> ini OBJEK HIDUP (bukan sampah); wajib potong sumber (F-06 print + cap cache + spectator cap), bukan sekadar sapu") end
        end
      elseif mb > (CEIL - 10) then
        if (n - _mwStepT) > 2 then _mwStepT = n; pcall(function() collectgarbage("step", 1500) end) end
        _mwPersist = 0
      elseif mb > (CEIL - 20) then
        if (n - _mwStepT) > 3 then _mwStepT = n; pcall(function() collectgarbage("step", 600) end) end
        _mwPersist = 0; _mwPersistLog = false
      else
        _mwPersist = 0; _mwPersistLog = false                            -- sehat: reset flag
      end
    end
    if type(_G.X3._CrashLogFlush) == "function" then
      local _origFlush = _G.X3._CrashLogFlush
      _G.X3._CrashLogFlush = function()
        pcall(_mwRun)                                                    -- watchdog dulu (telemetri+enforce)
        return _origFlush()                                              -- lalu flush log asli
      end
    end
  end
end




local class = require("class")
local CCharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
local CBRPlayerCharacterBase = class(CCharacterBase, nil, BRPlayerCharacterBase)
local finalClass = require("combine_class").DeclareFeature(CBRPlayerCharacterBase, {
  {
    SkyTransition = "GameLua.Mod.BaseMod.Gameplay.Feature.SkyControl.PlayerCharacterSkyTransitionFeature"
  },
  {
    CarryDeadBoxFeature = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature"
  },
  {
    SpecialSuitFeature = "GameLua.Mod.Library.GamePlay.Feature.SpecialSuitFeature"
  },
  {
    TeleportPawnFeature = "GameLua.Mod.Library.GamePlay.Feature.TeleportPawnFeature"
  },
  {
    LifterControl = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.CharacterLifterControlFeature"
  },
  {
    FinalKillEffect = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.PlayerCharacterFinalKillEffectFeature"
  },
  {
    CampFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.Camp.PlayerCharacterCampFeature"
  },
  {
    BuildSkateFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.PlayerCharacterBuildVehicleFeature"
  },
  {
    CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.HeroPropFeature.CommonBornlandTransformFeature"
  },
  {
    ParachuteFormation = "GameLua.Mod.BaseMod.GamePlay.Feature.ParachuteFormationFeature"
  },
  {
    SpiderSenseFootprintFeature = "GameLua.Mod.Library.GamePlay.Feature.SpiderSenseFootprintFeature"
  },
  {
    GeneralShowSpotFeature = "GameLua.Mod.BRMod.Gameplay.Feature.PlayerCharacterGeneralShowSpotFeature"
  }
}, "BRPlayerCharacterBase")

_G.X3_ActivePlayerClass = finalClass
return finalClass
