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
  else
    self:AddCommonEventWithConditions(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE, {
      [1] = "FinishedState"
    }, self.HandleFinishedState, self)
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
  if PawnState == EPawnState.SwitchPP then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:BroadcastUIMessage("UIMsg_FPPModeChange", 0, "", "")
    end
  end
end

function BRPlayerCharacterBase:HandleFinishedState()
  print(bWriteLog and "BRPlayerCharacterBase:HandleFinishedState", self.STCharacterMovement)
  if slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.SetDynamicSimpleQueryConfigDisable then
    local EDynamicSimpleQueryConfigDisableMask = import("EDynamicSimpleQueryConfigDisableMask")
    self.STCharacterMovement:SetDynamicSimpleQueryConfigDisable(EDynamicSimpleQueryConfigDisableMask.Bit0, true)
  end
end

function BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent()
  if CGameMode and CGameMode.GameModeType and CGameState and CGameState.GameModeID then
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
  BRPlayerCharacterBase.__super.ReceiveEndPlay(self, EndPlayReason)
  if Client then
    GameplayData.RemoveCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:IsWarGameMode()
  local uGameState = GameplayData:GetGameState()
  if slua.isValid(uGameState) and Game:IsClassOf(uGameState, STExtraGameStateBase) then
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

function BRPlayerCharacterBase:ParachuteJump()
  local uPlayerController = self:GetControllerSafety()
  if slua.isValid(uPlayerController) then
    if not self:GetEnsure() then
      if uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteJump and uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteOpen then
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
  
  function loadLater()
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

-- ==============================================================================
-- ================== KHỞI TẠO VÀ LOAD BYPASS ĐẦU TIÊN ==========================
-- ==============================================================================

-- ============================================================================
-- ULTIMATE MERGED BYPASS v3.0 - COMPLETE SECURITY DISABLEMENT
-- ============================================================================
local function nop() return true end
local function retFalse() return false end
local function retZero() return 0 end
local function retEmpty() return {} end
local function retNil() return nil end
local function retTrue() return true end
local function retEmptyString() return "" end

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

local function InitializeMD5Bypass()
    pcall(function()
        local console = import("KismetSystemLibrary")
        if console then
            console.ExecuteConsoleCommand(nil, "pak.DisablePakSignatureCheck 1")
            console.ExecuteConsoleCommand(nil, "pakchunk.EnableSignatureCheck 0")
            console.ExecuteConsoleCommand(nil, "s.VerifyPak 0")
            console.ExecuteConsoleCommand(nil, "sig.Check 0")
            console.ExecuteConsoleCommand(nil, "security.DisableChecks 1")
        end
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

local function InitializeReportFlowBlocker()
    pcall(function()
        local flows = {"ReportAimFlow","ReportHitFlow","ReportAttackFlow","ReportSecAttackFlow","ReportFireArms","ReportVerifyInfoFlow","ReportMrpcsFlow","ReportPlayerBehavior","ReportTeammatHurt","ReportMisKillByTeammate","ReportForbitPick","ReportPlayerMoveRoute","ReportPlayerPosition","ReportVehicleMoveFlow","ReportSecTgameMovingFlow","ReportParachuteData","ReportEquipmentFlow","ReportPlayersPing","ReportPlayerIP","ReportPlayerFramePingRecord","ReportDSNetSaturation","ReportNetContinuousSaturate","ReportDSNetRate","ReportCircleFlow","ReportSecMrpcsFlow"}
        for _, f in ipairs(flows) do if _G[f] then _G[f] = nop end; if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = nop end end
        for _, f in ipairs({"CheckReportSecAttackFlowWithAttackFlow","CheckReportSecAttackFlow"}) do if _G[f] then _G[f] = retFalse end; if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = retFalse end end
        for _, f in ipairs({"IsEnableReportMrpcsInCircleFlow","IsEnableReportMrpcsInPartCircleFlow","IsEnableReportMrpcsFlow","IsEnableReportAttackFlow","IsEnableReportHitFlow","IsEnableReportCircleFlow"}) do if _G[f] then _G[f] = retFalse end end
    end)
end

local function InitializePlayerSecurityBypass()
    pcall(function()
        for _, c in ipairs({"PlayerSecurityInfoCollector","PlayerSecurityInfo","SecurityInfoCollector","ClientSecurityCollector","PlayerAntiCheatCollector"}) do
            if _G[c] then for k, v in pairs(_G[c]) do if type(v) == "function" and (k:find("Report") or k:find("Collect") or k:find("Send") or k:find("Upload") or k:find("Record")) then _G[c][k] = nop end end end
        end
        local SecSub = require("GameLua.Mod.BaseMod.Common.Security.PlayerSecurityInfoSubsystem")
        if SecSub then SecSub.ReportData = nop; SecSub.CheckCheat = retFalse; SecSub.ValidatePlayer = retTrue; SecSub.CollectData = nop; SecSub.SendToServer = nop end
    end)
end

local function InitializeClientFlowBypass()
    pcall(function()
        for _, name in ipairs({"ClientSecMrpcsFlow","MrpcsFlow","MrpcsData","ClientCircleFlowSubsystem","ClientKillFlowSubsystem","ClientSecPlayerKillFlow"}) do
            local sub = package.loaded[name] or _G[name]
            if sub then for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Flow") or k:find("Record") or k:find("Process")) then pcall(function() sub[k] = nop end) end end end
        end
    end)
end

local function InitializeSwiftHawkBypass()
    pcall(function()
        for _, f in ipairs({"SwiftHawk","ClientSwiftHawk","ClientSwiftHawkWithParams","SendSwiftHawkData"}) do if _G[f] then _G[f] = nop end; if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = nop end end
        local sub = package.loaded["GameLua.Mod.BaseMod.Client.Security.SwiftHawkSubsystem"]
        if sub then sub.ReportData = nop; sub.SendReport = nop; sub.CollectTelemetry = nop end
    end)
end

local function InitializeCoronaLabBypass()
    pcall(function()
        if _G.CoronaLab then _G.CoronaLab.ReportData = nop; _G.CoronaLab.SendData = nop; _G.CoronaLab.CollectData = nop; _G.CoronaLab.Telemetry = nop end
        local sub = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr"):Get("CoronaLabSubsystem")
        if sub then sub.ReportData = nop; sub.SendToServer = nop; sub.CollectTelemetry = nop; sub.StopCollection = nop end
    end)
end

local function InitializeModifierExceptionBypass()
    pcall(function()
        if _G.bReportedModifierException then _G.bReportedModifierException = false end
        local sub = require("GameLua.Mod.BaseMod.Common.Security.ModifierExceptionSubsystem")
        if sub then sub.ReportException = nop; sub.CheckModifier = retTrue; sub.ValidateModifier = retTrue; sub.ReportModifierError = nop end
    end)
end

local function InitializeSimulateCharacterLocationBypass()
    pcall(function()
        local sub = require("GameLua.Mod.BaseMod.Gameplay.Simulate.SimulateCharacterSubsystem")
        if sub then sub.ReportLocation = nop; sub.SendLocationData = nop; sub.VerifyLocation = retTrue end
    end)
end

local function InitializeShootVerificationBypass()
    pcall(function()
        local sub = require("GameLua.Dev.Subsystem.ShootVerifySubSystemClient")
        if sub then sub.OnShootVerifyFailed = nop; sub.SendVerifyData = nop; sub.ReportBulletHit = nop; sub.UploadHitInfo = nop; sub.VerifyShot = retTrue end
        if _G.BulletHitInfoUploadData then _G.BulletHitInfoUploadData.Report = nop; _G.BulletHitInfoUploadData.Send = nop; _G.BulletHitInfoUploadData.Upload = nop end
    end)
end

local function InitializeNetworkPacketBlock()
    pcall(function()
        if NetUtil and NetUtil.SendPacket then
            local orig = NetUtil.SendPacket
            local blocked = {
                ["ReportAttackFlow"]=1,["ReportSecAttackFlow"]=1,["ReportFireArms"]=1,["ReportVerifyInfoFlow"]=1,["ReportMrpcsFlow"]=1,
                ["ReportPlayerBehavior"]=1,["ReportTeammatHurt"]=1,["ReportPlayerMoveRoute"]=1,["ReportPlayerPosition"]=1,["ReportSecVehicleMoveFlow"]=1,
                ["report_parachute_data"]=1,["on_tss_sdk_anti_data"]=1,["ReportAimFlow"]=1,["ReportHitFlow"]=1,["ReportCircleFlow"]=1,["report_players_ping"]=1,
                ["report_player_ip"]=1,["report_net_saturate"]=1,["report_speed_hack"]=1,["report_wall_hack"]=1,["report_aim_bot"]=1,["report_esp_usage"]=1,
                ["report_modded_files"]=1,["detect_cheat"]=1,["ban_player"]=1,["client_anti_cheat_report"]=1,
                ["ClientSecMrpcsFlow"]=1,["MrpcsData"]=1,["CheckReportSecAttackFlow"]=1,["CheckReportSecAttackFlowWithAttackFlow"]=1,["RPC_ClientCoronaLab"]=1,
                ["CoronaLabReport"]=1,["CoronaLabData"]=1,["PlayerSecurityInfo"]=1,["ReportSecurityInfo"]=1,["SendSecurityData"]=1,["ClientCircleFlow"]=1,
                ["IsEnableReportMrpcsInCircleFlow"]=1,["IsEnableReportMrpcsInPartCircleFlow"]=1,["bReportedModifierException"]=1,
                ["ReportModifierException"]=1,["RPC_Server_ReportSimulateCharacterLocation"]=1,["ReportSimulateCharacterLocation"]=1,["RPC_Client_ShootVertifyRes"]=1,
                ["BulletHitInfoUploadData"]=1,["ShootVerifyFailed"]=1,["report_unrealnet_exception"]=1,["tss_sdk_report"]=1,["SwiftHawk"]=1,["ClientSwiftHawk"]=1,["ClientSwiftHawkWithParams"]=1,["SwiftHawkReport"]=1,["SwiftHawkData"]=1,
                ["AntiCheatReport"]=1,["CheatDetection"]=1,["ViolationReport"]=1,["SecurityViolation"]=1,["IntegrityCheck"]=1,["SignatureVerify"]=1
            }
            NetUtil.SendPacket = function(packetName, ...) if blocked[packetName] then return nil end; return orig(packetName, ...) end
            NetUtil.IsBypassed = true
        end
        if _G.SendRPC then
            local origRPC = _G.SendRPC
            local blockedRPC = {"RPC_Server_ClientSecMrpcsFlow","RPC_Server_SwiftHawk","RPC_Server_ClientSwiftHawkWithParams","RPC_Server_ReportSimulateCharacterLocation","RPC_Client_ShootVertifyRes","RPC_ClientCoronaLab"}
            _G.SendRPC = function(rpcName, ...) for _, b in ipairs(blockedRPC) do if rpcName == b then return nil end end; return origRPC(rpcName, ...) end
        end
    end)
end

local function InitializeHiggsBosonBypass()
    pcall(function()
        local Higgs = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if Higgs then
            for _, m in ipairs({"ControlMHActive","Tick","OnTick","MHActiveLogic","TriggerAvatarCheck","StartAvatarCheck","ReportItemID","ReceiveAnyDamage","OnWeaponHitRecord","ShowSecurityAlert","ServerReportAvatar","ClientReportNetAvatar","SendHisarData","ValidateSecurityData","StaticShowSecurityAlertInDev","RPC_Client_ShootVertifyRes","RPC_Server_ReportSimulateCharacterLocation","DisableHiggsBoson","CheckMHActive","ReportViolation","ProcessSecurityEvent","ValidatePlayer","CheckIntegrity"}) do
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

local function InitializeAntiReport()
    pcall(function()
        for _, path in ipairs({"GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem","Client.Security.ClientReportPlayerSubsystem","GameLua.Mod.BaseMod.DS.Security.DSReportPlayerSubsystem"}) do
            local sub = package.loaded[path]; if not sub then local s, r = pcall(require, path); if s and r then sub = r end end
            if sub then for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Record") or k:find("Send") or k:find("Upload") or k:find("Notify")) then pcall(function() sub[k] = nop end) end end end
        end
    end)
end

local function InitializeGameplayBypass()
    pcall(function()
        if not _G.GameplayCallbacks then _G.GameplayCallbacks = {} end
        if _G.GameplayCallbacks.IsBypassed then return end
        local GC = _G.GameplayCallbacks
        local reports = {"ReportAttackFlow","ReportSecAttackFlow","ReportFireArms","ReportVerifyInfoFlow","ReportMrpcsFlow","ReportPlayerBehavior","ReportTeammatHurt","ReportMisKillByTeammate","ReportForbitPick","ReportPlayerMoveRoute","ReportPlayerPosition","ReportVehicleMoveFlow","ReportSecTgameMovingFlow","ReportParachuteData","SendTssSdkAntiDataToLobby","ReportEquipmentFlow","ReportAimFlow","ReportPlayersPing","ReportPlayerIP","ReportPlayerFramePingRecord","OnDSConnectionSaturated","ReportDSNetSaturation","ReportNetContinuousSaturate","ReportDSNetRate","SendClientStats","SendServerAvgTickDelta","ReportCircleFlow","ClientSecMrpcsFlow","SwiftHawk","ClientSwiftHawk","ClientSwiftHawkWithParams"}
        for _, f in ipairs(reports) do GC[f] = nop end
        GC.CheckReportSecAttackFlowWithAttackFlow = retFalse; GC.CheckReportSecAttackFlow = retFalse
        local origState = GC.OnDSPlayerStateChanged
        GC.OnDSPlayerStateChanged = function(UID, State, bPure, bSafe, Param)
            local s = State and string.lower(tostring(State)) or ""
            local blocked = {["cheatdetected"]=1,["connectionlost"]=1,["connectiontimeout"]=1,["connectionexception"]=1,["netdrivererror"]=1,["banned"]=1,["kicked"]=1,["suspended"]=1,["violationdetected"]=1,["integrityfailure"]=1,["securityviolation"]=1}
            if blocked[s] then return end
            if origState then pcall(origState, UID, State, bPure, bSafe, Param) end
        end
        GC.OnPlayerNetConnectionClosed = nop; GC.OnPlayerActorChannelError = nop; GC.OnPlayerRPCValidateFailed = nop; GC.OnPlayerSpectateException = nop; GC.OnShutdownAfterError = nop; GC.IsBypassed = true
    end)
end

local function InitializeKillAllSubsystems()
    pcall(function()
        local subMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if not subMgr then return end
        local toKill = {"CoronaLabSubsystem","PlayerSecurityInfoSubsystem","ClientCircleFlowSubsystem","ModifierExceptionSubsystem","SimulateCharacterSubsystem","ShootVerifySubSystemClient","HiggsBosonComponent","ClientReportPlayerSubsystem","DSReportPlayerSubsystem","ClientHawkEyePatrolSubsystem","DSHawkEyePatrolSubsystem","ClientDataStatistcsSubsystem","AFKReportorSubsystem","BehaviorScoreSubsystem","FileCheckSubsystem","MemoryCheckSubsystem","SpeedCheckSubsystem","WallCheckSubsystem","AvatarExceptionSubsystem","GameReportSubsystem","ClientSecMrpcsFlowSubsystem","MrpcsFlowSubsystem","CircleFlowSubsystem","SwiftHawkSubsystem","AntiCheatSubsystem","IntegrityCheckSubsystem","SignatureVerifySubsystem","MD5CheckSubsystem","PakVerifySubsystem"}
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

local function InitializeFinalProtection()
    pcall(function()
        for _, flag in ipairs({"ENABLE_REPORT","ENABLE_ANTI_CHEAT","ENABLE_SECURITY","ENABLE_TELEMETRY","ENABLE_ANALYTICS","ENABLE_CRASH_REPORT","ENABLE_PERFORMANCE_REPORT"}) do if _G[flag] then _G[flag] = false end end
        local origReq = require
        local blocked = {"HiggsBosonComponent","PlayerSecurityInfoSubsystem","CoronaLabSubsystem","ClientCircleFlowSubsystem","ModifierExceptionSubsystem","ShootVerifySubSystemClient","ClientReportPlayerSubsystem","DSReportPlayerSubsystem"}
        _G.require = function(m) for _, b in ipairs(blocked) do if m:find(b) then return {} end end; return origReq(m) end
    end)
end

_G.StartBypass_VIP_v3 = function()
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
        InitializeKillAllSubsystems()
        InitializeFinalProtection()
        print("[ULTIMATE BYPASS] Complete - All Security Systems Disabled")
    end)
end

-- ==============================================================================
-- ========================= ENGLISH AURA / WALLHACK MOD =========================
-- ==============================================================================

local ConfigFileName = "Menu_Settings.txt"
_G.HK_Settings = _G.HK_Settings or {
    WALLHACK = 1,
    WALL_VISIBLE_COLOR = 3,       -- Default: Yellow
    WALL_OCCLUDED_COLOR = 2,      -- Default: Red
    WALL_OCCLUDED_AI_COLOR = 7,   -- Default: Purple
}

_G.SaveModSettings = function()
    pcall(function()
        local data = "return {\n"
        for k, v in pairs(_G.HK_Settings) do
            data = data .. "  [\"" .. tostring(k) .. "\"] = " .. tostring(v) .. ",\n"
        end
        data = data .. "}"
        local paths = {
            "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. ConfigFileName,
            "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. ConfigFileName,
            "/Documents/ShadowTrackerExtra/Saved/Paks/" .. ConfigFileName,
            ConfigFileName
        }
        for _, path in ipairs(paths) do
            local file = io.open(path, "w")
            if file then file:write(data); file:close(); break end
        end
    end)
end

_G.LoadModSettings = function()
    pcall(function()
        local paths = {
            "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. ConfigFileName,
            "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. ConfigFileName,
            "/Documents/ShadowTrackerExtra/Saved/Paks/" .. ConfigFileName,
            ConfigFileName
        }
        local content = nil
        for _, path in ipairs(paths) do
            local file = io.open(path, "r")
            if file then content = file:read("*a"); file:close(); break end
        end
        if content then
            local func = load(content)
            if func then
                local savedData = func()
                if savedData and type(savedData) == "table" then
                    for k, v in pairs(savedData) do _G.HK_Settings[k] = v end
                end
            end
        end
    end)
end

if not _G.ModConfigLoaded then
    _G.LoadModSettings()
    _G.ModConfigLoaded = true
end

function _G.InitModMenuTab()
    local LocUtil = _G.LocUtil
    if not LocUtil and package.loaded["client.common.LocUtil"] then LocUtil = require("client.common.LocUtil") end
    if LocUtil and not LocUtil._IsModMenuHooked then
        local old_get = LocUtil.GetLocalizeResStr
        LocUtil.GetLocalizeResStr = function(id)
            if type(id) == "string" and not tonumber(id) then return id end
            return old_get(id)
        end
        LocUtil._IsModMenuHooked = true
    end
    local SettingPageDefine = require("client.logic.NewSetting.SettingPageDefine")
    local SettingCatalog = require("client.logic.NewSetting.SettingCatalog")
    if not SettingPageDefine.ModMenu then
        local AliasMap = require("client.slua.umg.NewSetting.Item.AliasMap")
        local StackESP = { { UI = AliasMap.Title, Text = "AURA" } }
        table.insert(StackESP, {
            Key = "ModMenu_Wall_Ex", UI = AliasMap.TitleSwitcher,
            Text = "▶ AURA / WALLHACK (1 White | 2 Red | 3 Yellow | 4 Green | 5 Cyan | 6 Blue | 7 Purple | 8 Pink | 9 Black)",
            ExpandIndex = 0,
            GetFunc = function() return _G.HK_Settings.WALLHACK == 1 end,
            SetFunc = function(_, value)
                _G.HK_Settings.WALLHACK = value and 1 or 0
                _G.EnvRequiresUpdate = true; _G.SaveModSettings(); return true
            end
        })
        local function ResetWallColorCache()
            pcall(function()
                local ac = GameplayData.GetAllPlayerCharacters and GameplayData.GetAllPlayerCharacters() or {}
                for _, ch in pairs(ac) do if ch then ch.WallhackApplied = false; ch.LastAuraHash = nil; ch.LastAuraMeshes = nil end end
            end)
            _G.EnvRequiresUpdate = true
        end
        table.insert(StackESP, {
            Key = "ModMenu_Wall_VisColor", UI = AliasMap.Slider or "Slider",
            Text = "   Visible Color (1-9)", ExpandHandle = "ModMenu_Wall_Ex",
            MinValue = 1, MaxValue = 9, Min = 1, Max = 9,
            GetFunc = function() return _G.HK_Settings.WALL_VISIBLE_COLOR or 3 end,
            SetFunc = function(_, value)
                _G.HK_Settings.WALL_VISIBLE_COLOR = math.max(1, math.min(9, math.floor(tonumber(value) or 3)))
                ResetWallColorCache(); _G.SaveModSettings(); return true
            end
        })
        table.insert(StackESP, {
            Key = "ModMenu_Wall_OccColor", UI = AliasMap.Slider or "Slider",
            Text = "   Occluded Color - Player (1-9)", ExpandHandle = "ModMenu_Wall_Ex",
            MinValue = 1, MaxValue = 9, Min = 1, Max = 9,
            GetFunc = function() return _G.HK_Settings.WALL_OCCLUDED_COLOR or 2 end,
            SetFunc = function(_, value)
                _G.HK_Settings.WALL_OCCLUDED_COLOR = math.max(1, math.min(9, math.floor(tonumber(value) or 2)))
                ResetWallColorCache(); _G.SaveModSettings(); return true
            end
        })
        table.insert(StackESP, {
            Key = "ModMenu_Wall_AIColor", UI = AliasMap.Slider or "Slider",
            Text = "   Occluded Color - Bot/AI (1-9)", ExpandHandle = "ModMenu_Wall_Ex",
            MinValue = 1, MaxValue = 9, Min = 1, Max = 9,
            GetFunc = function() return _G.HK_Settings.WALL_OCCLUDED_AI_COLOR or 7 end,
            SetFunc = function(_, value)
                _G.HK_Settings.WALL_OCCLUDED_AI_COLOR = math.max(1, math.min(9, math.floor(tonumber(value) or 7)))
                ResetWallColorCache(); _G.SaveModSettings(); return true
            end
        })
        SettingPageDefine.ModMenu = {
            Key = "ModMenu", loc = "AURA-MOD", text = "AURA-MOD", Text = "AURA-MOD",
            title = "AURA-MOD", Title = "AURA-MOD", UIKey = "Setting_Page_Privacy",
            Category = {
                { Key = "ModMenu_Cat1", loc = "AURA", text = "AURA", Text = "AURA", title = "AURA", Title = "AURA", Stack = StackESP }
            }
        }
        table.insert(SettingCatalog, 1, SettingPageDefine.ModMenu)
    end
    local UIManager = _G.UIManager
    if UIManager and not UIManager._IsModMenuHooked then
        local old_ShowUI = UIManager.ShowUI
        UIManager.ShowUI = function(config, ...)
            local args = {...}; local n = select('#', ...)
            if config and config.keyName and string.find(string.lower(config.keyName), "setting_main") then
                local catalog = args[1]
                if type(catalog) == "table" then
                    local hasModMenu = false; local newCatalog = {}
                    for _, page in ipairs(catalog) do
                        table.insert(newCatalog, page)
                        if type(page) == "table" and page.Key == "ModMenu" then hasModMenu = true end
                    end
                    if not hasModMenu then table.insert(newCatalog, 1, SettingPageDefine.ModMenu); args[1] = newCatalog end
                end
            end
            return old_ShowUI(config, (table.unpack or unpack)(args, 1, n))
        end
        UIManager._IsModMenuHooked = true
    end
end

local slua_isValid = slua and slua.isValid
local os_clock = os.clock
local math_random = math.random
local math_sqrt = math.sqrt

local function AuraColor(r, g, b)
    if FLinearColor then return FLinearColor(r, g, b, 1.0) end
    return {R=r, G=g, B=b, A=1.0, r=r, g=g, b=b, a=1.0}
end

local WALL_COLOR_PRESETS = {
    [1] = {3.5, 3.5, 3.5},      -- White
    [2] = {3.5, 0.0, 0.0},      -- Red
    [3] = {3.5, 3.15, 0.0},     -- Yellow
    [4] = {0.0, 3.5, 0.0},      -- Green
    [5] = {0.0, 3.5, 3.15},     -- Cyan
    [6] = {0.0, 0.0, 3.5},      -- Blue
    [7] = {0.829, 0.229, 3.829},-- Purple
    [8] = {3.5, 0.0, 2.1},      -- Pink
    [9] = {0.0, 0.0, 0.0},      -- Black
}
local function GetWallColorByIndex(idx)
    local p = WALL_COLOR_PRESETS[idx] or WALL_COLOR_PRESETS[3]
    return AuraColor(p[1], p[2], p[3])
end
local function GetCurrentWallVisibleColor()
    return GetWallColorByIndex((_G.HK_Settings and _G.HK_Settings.WALL_VISIBLE_COLOR) or 3)
end
local function GetCurrentWallOccludedColor(isAI)
    if isAI then return GetWallColorByIndex((_G.HK_Settings and _G.HK_Settings.WALL_OCCLUDED_AI_COLOR) or 7)
    else return GetWallColorByIndex((_G.HK_Settings and _G.HK_Settings.WALL_OCCLUDED_COLOR) or 2) end
end

local function AuraValid(obj)
    if not obj then return false end
    if slua_isValid then return slua_isValid(obj) end
    return true
end

local function IsParachuteComponent(comp)
    if not comp then return false end
    local ok, res = pcall(function()
        local name = comp.GetName and string.lower(tostring(comp:GetName())) or ""
        if string.find(name, "parachute") then return true end
        local path = comp.GetPathName and string.lower(tostring(comp:GetPathName())) or ""
        if string.find(path, "parachute") then return true end
        return false
    end)
    return ok and res or false
end

local function ApplyAuraToMeshComponent(mesh, visibleColor, occludedColor)
    if not AuraValid(mesh) then return end
    pcall(function()
        mesh:SetDrawDyeing(true); mesh:SetDrawDyeingMode(1)
        mesh:SetVisibleDyeingColor(visibleColor); mesh:SetOccludedDyeingColor(occludedColor)
        mesh:SetDyeingColorFadeDistance(99999.0); mesh:SetDyeingColorMinMaxDistance(0.0, 99999.0)
        mesh:SetDrawHighlight(true); mesh:SetRenderCustomDepth(true); mesh:SetCustomDepthStencilValue(255)
    end)
end

local function ResetMeshAuraComponent(mesh)
    if not AuraValid(mesh) then return end
    pcall(function()
        mesh:SetDrawDyeing(false); mesh:SetDrawHighlight(false)
        mesh:SetRenderCustomDepth(false); mesh:SetCustomDepthStencilValue(0)
    end)
end

local function CheckIsAI(pawn)
    if not AuraValid(pawn) then return false end
    if pawn.HK_IsAICached ~= nil then return pawn.HK_IsAICached end
    local isAI = false; local hasChecked = false
    pcall(function()
        if pawn.bIsAI or pawn.IsAI then isAI = true; hasChecked = true end
        if type(pawn.IsBot) == "function" and pawn:IsBot() then isAI = true; hasChecked = true end
        if pawn.IsBot == true then isAI = true; hasChecked = true end
        local pState = pawn.PlayerState or (type(pawn.GetPlayerState)=="function" and pawn:GetPlayerState())
        if AuraValid(pState) then
            hasChecked = true
            if pState.bIsABot or pState.bIsBot then isAI = true end
            if type(pState.IsBot)=="function" and pState:IsBot() then isAI = true end
        end
        if not isAI then
            local name = pawn.PlayerName or (type(pawn.GetPlayerName)=="function" and pawn:GetPlayerName()) or ""
            if name ~= "" and (name:find("Cobra") or name:find("Target") or name:find("bot_") or name:find("PlayerBot")) then
                isAI = true; hasChecked = true
            end
        end
    end)
    if hasChecked then pawn.HK_IsAICached = isAI end
    return isAI
end

function BRPlayerCharacterBase:StartAdvancedSystems()
    if not Client then return end
    if self.bAdvancedSystemsStarted then return end
    self.bAdvancedSystemsStarted = true
    local GlobalSkelClass = import("SkeletalMeshComponent")
    local systemTimerHandle
    systemTimerHandle = self:AddGameTimer(0.25, true, function()
        if not AuraValid(self.Object) then
            if systemTimerHandle then self:RemoveGameTimer(systemTimerHandle) end; return
        end
        local pc = GameplayData.GetPlayerController()
        local isSpectating = false
        pcall(function()
            if pc and ((pc.IsSpectator and pc:IsSpectator()) or (pc.IsDemoPlaySpectator and pc:IsDemoPlaySpectator())) then
                isSpectating = true
            end
        end)
        local LocalPlayer = isSpectating and (pc:GetViewTarget() or pc:GetCurPawn()) or GameplayData.GetPlayerCharacter()
        if not AuraValid(LocalPlayer) then return end
        if self.Object ~= LocalPlayer and not isSpectating then
            if systemTimerHandle then self:RemoveGameTimer(systemTimerHandle) end; return
        end
        local isWallhackOn = (_G.HK_Settings and _G.HK_Settings.WALLHACK) == 1
        if not _G.TDModTickCount then _G.TDModTickCount = 0 end
        if _G.EnvRequiresUpdate == nil then _G.EnvRequiresUpdate = true end
        _G.TDModTickCount = _G.TDModTickCount + 1
        if _G.EnvRequiresUpdate then
            _G.EnvRequiresUpdate = false
            pcall(function()
                local KSL = import("KismetSystemLibrary"); local pc2 = GameplayData.GetPlayerController()
                local function ExecCmd(k, v)
                    if AuraValid(KSL) and AuraValid(pc2) then KSL.ExecuteConsoleCommand(pc2, k.." "..v) end
                end
                if isWallhackOn then
                    ExecCmd("r.EnableDrawDyeingColor","1"); ExecCmd("r.SupportDyeingColorDistanceFade","1")
                    ExecCmd("r.SupportDyeingColorMeshProxy","1"); ExecCmd("r.EnablePrimitiveHighlight","1")
                    ExecCmd("r.CustomDepth","3"); ExecCmd("r.Highlight.Enable","1")
                end
            end)
        end
        if _G.TDModTickCount % 2 == 0 then
            local allPlayers = GameplayData.GetAllPlayerCharacters and GameplayData.GetAllPlayerCharacters() or {}
            local localLoc = type(LocalPlayer.K2_GetActorLocation)=="function" and LocalPlayer:K2_GetActorLocation()
            local myTeamID = LocalPlayer.TeamID
            local tick = os_clock()
            local gVC, gPC, gAC, gHash
            if isWallhackOn then
                gVC = GetCurrentWallVisibleColor(); gPC = GetCurrentWallOccludedColor(false); gAC = GetCurrentWallOccludedColor(true)
                gHash = tostring((_G.HK_Settings.WALL_VISIBLE_COLOR or 3)).."_"..tostring((_G.HK_Settings.WALL_OCCLUDED_COLOR or 2)).."_"..tostring((_G.HK_Settings.WALL_OCCLUDED_AI_COLOR or 7))
            end
            for _, enemy in pairs(allPlayers) do
                if AuraValid(enemy) and enemy ~= LocalPlayer and enemy.TeamID ~= myTeamID then
                    local isDead = (type(enemy.IsDead)=="function" and enemy:IsDead()) or enemy.bIsDead or false
                    local isKnocked = false
                    if type(enemy.IsNearDeath) == "function" then
                        isKnocked = enemy:IsNearDeath()
                    else
                        isKnocked = enemy.bIsNearDeath or false
                    end
                    local eMesh = enemy.Mesh
                    if not isSpectating and (enemy.bHidden or (AuraValid(eMesh) and eMesh.bHidden)) then isDead = true end
                    if not isDead and not isKnocked then
                        local hp = 100
                        if type(enemy.GetHealth) == "function" then
                            hp = enemy:GetHealth() or 100
                        else
                            hp = enemy.Health or 100
                        end
                        if hp <= 0 then isDead = true end
                    end
                    if not isDead then
                        if enemy.HK_IsAICached == nil then enemy.HK_IsAICached = CheckIsAI(enemy) end
                        local distM = 0
                        if type(LocalPlayer.GetDistanceTo)=="function" then
                            distM = LocalPlayer:GetDistanceTo(enemy) / 100
                        elseif localLoc then
                            local eLoc = type(enemy.K2_GetActorLocation)=="function" and enemy:K2_GetActorLocation()
                            if eLoc then distM = math_sqrt((localLoc.X-eLoc.X)^2+(localLoc.Y-eLoc.Y)^2+(localLoc.Z-eLoc.Z)^2)/100 end
                        end
                        if distM > 500 then
                            if enemy.WallhackApplied then
                                pcall(function()
                                    for _, c in ipairs(enemy.LastAuraMeshes or {}) do if AuraValid(c) then ResetMeshAuraComponent(c) end end
                                end)
                                enemy.WallhackApplied = false; enemy.LastAuraHash = nil; enemy.LastAuraMeshes = nil
                            end
                            goto continue
                        end
                        if not enemy.HK_NextMeshUpdateTime or tick > enemy.HK_NextMeshUpdateTime then
                            enemy.HK_NextMeshUpdateTime = tick + 1.5 + math_random() * 1.0
                            local meshes = enemy.HK_CachedMeshes or {}; local existing = {}
                            for _, m in ipairs(meshes) do existing[m] = true end
                            if AuraValid(enemy.Mesh) and not existing[enemy.Mesh] then
                                if not IsParachuteComponent(enemy.Mesh) then
                                    table.insert(meshes, enemy.Mesh)
                                    existing[enemy.Mesh] = true
                                end
                            end
                            if GlobalSkelClass then
                                pcall(function()
                                    local childs = enemy:GetComponentsByClass(GlobalSkelClass)
                                    if childs then
                                        local count = type(childs.Num)=="function" and childs:Num() or #childs
                                        for c = 1, count do
                                            local comp = type(childs.Get)=="function" and childs:Get(c-1) or childs[c]
                                            if AuraValid(comp) and not existing[comp] then
                                                if not IsParachuteComponent(comp) then
                                                    table.insert(meshes, comp)
                                                    existing[comp] = true
                                                end
                                            end
                                        end
                                    end
                                end)
                            end
                            enemy.HK_CachedMeshes = meshes
                        end
                        local meshes = enemy.HK_CachedMeshes or {}
                        local isMeshChanged = enemy.LastAuraMeshes and #enemy.LastAuraMeshes ~= #meshes
                        if isWallhackOn then
                            local oColor = enemy.HK_IsAICached and gAC or gPC
                            local aHash = (enemy.HK_IsAICached and "ai_" or "p_") .. gHash
                            if isMeshChanged or enemy.LastAuraHash ~= aHash or not enemy.WallhackApplied then
                                pcall(function()
                                    if enemy.LastAuraMeshes then for _, m in ipairs(enemy.LastAuraMeshes) do if AuraValid(m) then ResetMeshAuraComponent(m) end end end
                                    for _, m in ipairs(meshes) do if AuraValid(m) then ApplyAuraToMeshComponent(m, gVC, oColor) end end
                                    if enemy.DelayCustomDepth then pcall(function() enemy:DelayCustomDepth(true) end) end
                                end)
                                enemy.WallhackApplied = true; enemy.LastAuraHash = aHash
                                enemy.LastAuraMeshes = {(table.unpack or unpack)(meshes)}
                            end
                        else
                            if enemy.WallhackApplied then
                                pcall(function() for _, m in ipairs(enemy.LastAuraMeshes or meshes) do if AuraValid(m) then ResetMeshAuraComponent(m) end end end)
                                enemy.WallhackApplied = false; enemy.LastAuraHash = nil; enemy.LastAuraMeshes = nil
                            end
                        end
                    else
                        if enemy.WallhackApplied then
                            pcall(function() for _, c in ipairs(enemy.LastAuraMeshes or {}) do if AuraValid(c) then ResetMeshAuraComponent(c) end end end)
                            enemy.WallhackApplied = false; enemy.LastAuraHash = nil; enemy.LastAuraMeshes = nil
                        end
                    end
                    ::continue::
                end
            end
        end
    end)
end

local orig_ReceiveBeginPlay = BRPlayerCharacterBase.ReceiveBeginPlay
function BRPlayerCharacterBase:ReceiveBeginPlay()
    if orig_ReceiveBeginPlay then orig_ReceiveBeginPlay(self)
    elseif BRPlayerCharacterBase.__super then BRPlayerCharacterBase.__super.ReceiveBeginPlay(self) end
    if Client then
        pcall(function()
            local isLocal = (self.Role == ENetRole.ROLE_AutonomousProxy) or (self.IsLocallyControlled and self:IsLocallyControlled())
            if isLocal then
                self:AddGameTimer(1.0, false, function() self:StartAdvancedSystems() end)
            end
        end)
    end
end

local function InitAllModSystems()
    pcall(function()
        if _G.StartBypass_VIP_v3 then _G.StartBypass_VIP_v3() end
        _G.InitModMenuTab()
    end)
    pcall(function()
        local GD = package.loaded["GameLua.GameCore.Data.GameplayData"] or require("GameLua.GameCore.Data.GameplayData")
        if not GD then return end
        local LocalPlayer = GD.GetPlayerCharacter and GD.GetPlayerCharacter()
        if slua.isValid(LocalPlayer) then
            local isLocal = (LocalPlayer.Role == ENetRole.ROLE_AutonomousProxy) or (LocalPlayer.IsLocallyControlled and LocalPlayer:IsLocallyControlled())
            if isLocal and not LocalPlayer.bAdvancedSystemsStarted then
                pcall(function() LocalPlayer:StartAdvancedSystems() end)
            end
        end
    end)
end

pcall(function() require("common.time_ticker").AddTimerOnce(0.5, InitAllModSystems) end)

local class = require("class")
local CCharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
local CBRPlayerCharacterBase = class(CCharacterBase, nil, BRPlayerCharacterBase)
return require("combine_class").DeclareFeature(CBRPlayerCharacterBase, {
  { SkyTransition = "GameLua.Mod.BaseMod.Gameplay.Feature.SkyControl.PlayerCharacterSkyTransitionFeature" },
  { CarryDeadBoxFeature = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature" },
  { SpecialSuitFeature = "GameLua.Mod.Library.GamePlay.Feature.SpecialSuitFeature" },
  { TeleportPawnFeature = "GameLua.Mod.Library.GamePlay.Feature.TeleportPawnFeature" },
  { LifterControl = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.CharacterLifterControlFeature" },
  { FinalKillEffect = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.PlayerCharacterFinalKillEffectFeature" },
  { CampFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.Camp.PlayerCharacterCampFeature" },
  { BuildSkateFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.PlayerCharacterBuildVehicleFeature" },
  { CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.HeroPropFeature.CommonBornlandTransformFeature" },
  { ParachuteFormation = "GameLua.Mod.BaseMod.GamePlay.Feature.ParachuteFormationFeature" },
  { SpiderSenseFootprintFeature = "GameLua.Mod.Library.GamePlay.Feature.SpiderSenseFootprintFeature" },
  { GeneralShowSpotFeature = "GameLua.Mod.BRMod.Gameplay.Feature.PlayerCharacterGeneralShowSpotFeature" }
}, "BRPlayerCharacterBase")
