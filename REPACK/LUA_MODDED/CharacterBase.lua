local CharacterBase = {
  ServerRPC = {},
  ClientRPC = {},
  MulticastRPC = {},
  LuaEventContainer = {
    "DefaultLuaEventPlaceholder",
    "OnCharacterAnimInstanceInit",
    "OnCharacterAnimInstanceInitFrameDelay",
    "OnProjectileEffect",
    "OnUnmannedVehicleStateChange",
    "OnDSEnterSelfieMode",
    "OnDSExitSelfieMode",
    "EVENTID_CHARACTER_POSSESSED",
    "EVENTID_PAWN_PICK_UP_ITEM",
    "EVENTID_PLAYEREVENT_REVIVAL",
    "EVENTID_INGAME_BUILD_SUCCESS",
    "EVENTID_PLAYEREVENT_SCOPECHANGE",
    "EVENTID_CHARACTER_DIED_PRE",
    "EVENTID_LOCAL_HERO_ID_CHANGED",
    "EVENTID_HERO_ID_CHANGED",
    "EVENTID_INGAME_ON_PAWN_CAMP_CHANGED",
    "EVENTID_TAKE_DAMAGE",
    "EVENTID_PLAYEREVENT_CONSUMEITEM",
    "EVENTID_PLAYEREVENT_DROPITEM"
  }
}
local IngameTipsTools = require("GameLua.Mod.BaseMod.Common.UI.InGameTipsTools")
local EAvatarSlotType = import("EAvatarSlotType")
local EPawnState = import("EPawnState")
local ECharacterPoseState = import("ECharacterPoseType")
local GameLuaAPI = import("/Script/ShadowTrackerExtra.GameLuaAPI")
local ASTExtraPlayerController = import("/Script/ShadowTrackerExtra.STExtraPlayerController")
local ANewFakePlayerAIController = import("NewFakePlayerAIController")
local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local GameComponentData = require("GameLua.GameCore.Data.GameComponentData")
local GameplayActorData = require("GameLua.GameCore.Data.GameplayActorData")
local EMovementMode = import("EMovementMode")
local ESTEPoseState = import("ESTEPoseState")
local USTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
local ECharacterHealthStatus = import("ECharacterHealthStatus")
local FHealthPredictShowData = import("HealthPredictShowData")
local ELifetimeCondition = import("ELifetimeCondition")
CharacterBase.ServerRPC.ServerRPC_FailPreJoinDance = {
  Reliable = true,
  Params = {
    import("/Script/Engine.Actor")
  }
}
CharacterBase.ClientRPC.ClientRPC_FailedToJoinDance = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
CharacterBase.ClientRPC.ClientRPC_TryJoinDance = {
  Reliable = true,
  Params = {
    import("/Script/Engine.Actor"),
    UEnums.EPropertyClass.Int
  }
}
CharacterBase.ClientRPC.ClientRPC_ShowEffectAfterFruitBingo = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Str,
    UEnums.EPropertyClass.Str,
    UEnums.EPropertyClass.Int
  }
}
CharacterBase.ClientRPC.ClientRPC_PlayMontageCamera = {
  Reliable = true,
  Params = {
    import("/Script/CoreUObject.Vector"),
    UEnums.EPropertyClass.Float,
    UEnums.EPropertyClass.Float,
    UEnums.EPropertyClass.Str
  }
}
CharacterBase.MulticastRPC.ShowEffectAfterSelfRescueSucceed = {
  Reliable = true,
  Params = {}
}
CharacterBase.MulticastRPC.ServerShowShowUIConfigUI = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Str
  }
}
CharacterBase.MulticastRPC.MultiCast_GenericRPC = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int,
    {
      UEnums.EPropertyClass.Array,
      UEnums.EPropertyClass.Byte
    }
  }
}

function CharacterBase:ctor(selfType)
  self._SuperData = nil
  self.VehicleParachuteComponent = nil
  self.DefaultNetCullDistanceSq = 1600000000
  self.DiedTime = 0
  self.DiedPosition = FVector(0, 0, 0)
  self.TeammmatePositionWhenMeDied = {}
  self.DefaultFootStep = true
  self.tCorrectionSimulateRepData = {
    Timer = nil,
    CurRepLoc = nil,
    LastRepLoc = nil
  }
  self.LastAddBuffInstID = 0
  self.LastAddPawn = nil
  self.bDisableProne = false
end

function CharacterBase:GetLifetimeReplicatedProps()
  local RepTable = {
    {
      "bCableCarView",
      ELifetimeCondition.COND_None,
      UEnums.EPropertyClass.Bool
    },
    {
      "bIsPlayingLevelSequenceForShow",
      ELifetimeCondition.COND_None,
      UEnums.EPropertyClass.Bool
    },
    {
      "bCounterattacking",
      ELifetimeCondition.COND_None,
      UEnums.EPropertyClass.Bool
    }
  }
  return RepTable
end

function CharacterBase:_PostConstruct()
  CharacterBase.__super._PostConstruct(self)
  self:AddControlEventWithCondition(self, "OnAttrChangeEventDelegate", {
    AttrName = {
      "bUseDeadBox",
      "IsInUnderGroundArea",
      "IsAroundUndergroundEntry",
      "EmotePlayRate",
      "AreaID",
      "MapID",
      "DanceStageAreaState"
    }
  }, self.CharacterAttrChangeEvent, self)
  self:AddControlEvent(self, "OnPawnRespawnDelegate", self.HandleOnRespawn, self)
  self:AddControlEvent(self, "OnParachuteStateChanged", self.LuaHandleParachuteStateChanged, self)
  self:AddControlEvent(self, "OnRepParachuteStateDelegate", self.LuaHandleRepParachuteStateDelegate, self)
  self:AddControlEvent(self, "OnPlayerPoseChange", self.PlayerPoseChange, self)
  self:AddControlEvent(self, "OnAttachedToVehicle", self.HandleAttachedToVehicle, self)
  self:AddControlEvent(self, "OnDetachedFromVehicle", self.HandleDetachedFromVehicle, self)
  if not Client then
    self.DefaultNetCullDistanceSq = self.NetCullDistanceSquared
    self.UseNewParachuteMove = false
    self.bIsPlayingLevelSequenceForShow = false
    self:SetNetUpdateGroupID(2)
    self:AddControlEvent(self, "IsEnterNearDeathDelegate", self.HandleServerEnterNearDeathDelegate, self)
    self:AddControlEvent(self, "OnPlayerStartRescue", self.HandleOnPlayerStartRescue, self)
    self:AddControlEvent(self, "StateEnterHandler", self.HandleOnEnterState, self)
    self:AddControlEvent(self, "OnHandleSkillStartDelegate", self.HandleOnSkillStart, self)
  else
    self.bClientCanTriggerSkill = true
    self:AddControlEvent(self, "OnPreRepAttachment", self.HandleOnPreRepAttachment, self)
    self:AddControlEvent(self, "IsEnterNearDeathDelegate", self.HandleIsEnterNearDeathDelegate, self)
    self:AddCommonEvent(EVENTTYPE_APPLICATION_ACTIVE_STATE, EVENTID_APPLICATION_REACTIVATED_EX, self.OnApplicationReactivated, self)
  end
  self:AddControlEvent(self, "OnDeathDelegate", self.HandleDeathDelegate, self)
end

function CharacterBase:OnDestroyed()
  self:Dispose()
  CharacterBase.__super.OnDestroyed(self)
end

function CharacterBase:ReceiveOnPoolCreate()
  self:ResetAnimInstanceClass()
end

function CharacterBase:CharacterIsRecycled()
  return false
end

function CharacterBase:BroadcastFatalDamageInfoWrapperSimpleLua(Causer, Victim, DamageType, AdditionalParam, IsHeadShot)
  local FatalDamageSubsystem = SubsystemMgr:Get("FatalDamageSubsystem")
  if FatalDamageSubsystem then
    FatalDamageSubsystem:BroadcastFatalDamageInfoWrapperSimpleLua(Causer, Victim, DamageType, AdditionalParam, IsHeadShot)
  end
end

function CharacterBase:BroadcastFatalDamageInfoWrapperLua(Causer, Victim, DamageType, AdditionalParam, IsHeadShot, ResultHealthStatus, PreviousHealthStatus, WhoKillMe, KillerKillCount)
  local FatalDamageSubsystem = SubsystemMgr:Get("FatalDamageSubsystem")
  if FatalDamageSubsystem then
    FatalDamageSubsystem:BroadcastFatalDamageInfoWrapperLua(Causer, Victim, DamageType, AdditionalParam, IsHeadShot, ResultHealthStatus, PreviousHealthStatus, WhoKillMe, KillerKillCount)
  end
end

function CharacterBase:OnApplicationReactivated()
  print(bWriteLog and "CharacterBase:OnApplicationReactivated FormReactivated true")
  self.FormReactivated = true
end

function CharacterBase:HandleOnEnterState(nState)
  if self:HasAuthority() then
    print(bWriteLog and "CharacterBase:HandleOnEnterState, nState = " % tostring(self.PlayerKey))
    local EPawnState = import("EPawnState")
    if nState == EPawnState.Dying or nState == EPawnState.Dead or nState == EPawnState.BeCarriedBack or nState == EPawnState.Dizziness or nState == EPawnState.Knock or nState == EPawnState.Arrest then
    else
      local AFKReportorSubsystem = SubsystemMgr:Get("AFKReportorSubsystem")
      if AFKReportorSubsystem then
        local PlayerState = self:GetPlayerStateSafety()
        if PlayerState and slua.isValid(PlayerState) then
          AFKReportorSubsystem:PlayerHaveAction(PlayerState.UID)
        else
          print(bWriteLog and "CharacterBase:HandleOnEnterState, PlayerState = " % tostring(PlayerState))
        end
      else
        print(bWriteLog and "CharacterBase:HandleOnEnterState, AFKReportorSubsystem = nil")
      end
    end
  end
end

function CharacterBase:HandleOnSkillStart(uSkillCharacter, SkillID)
  if self:HasAuthority() then
    local AFKReportorSubsystem = SubsystemMgr:Get("AFKReportorSubsystem")
    if AFKReportorSubsystem then
      local PlayerState = self:GetPlayerStateSafety()
      if PlayerState and slua.isValid(PlayerState) then
        AFKReportorSubsystem:PlayerHaveAction(PlayerState.UID)
      else
        print(bWriteLog and "CharacterBase:HandleOnSkillStart, PlayerState = " % tostring(PlayerState))
      end
    else
      print(bWriteLog and "CharacterBase:HandleOnSkillStart, AFKReportorSubsystem = nil")
    end
  end
end

function CharacterBase:HandCharacterDoJump()
  if slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Walking then
    self.STCharacterMovement.Velocity.Z = self.STCharacterMovement.JumpZVelocity
    self.STCharacterMovement:SetMovementMode(EMovementMode.MOVE_Falling, 0)
    self:RemoveControlEvent(self, "CharacterDoJump")
    self:ServerTriggerJump()
    self:AddControlEvent(self, "CharacterDoJump", self.HandCharacterDoJump, self)
  end
end

function CharacterBase:HandleOnPreRepAttachment(uAttachParent, uAttachComponent, uAttachSocket, uLocationOffset, uRotationOffset, uRelativeScale3D)
  if uAttachParent and slua.isValid(uAttachParent) then
    if not Client.IsEnableDSGrayPublishFlag(2199023255552) or Client.IsEditor() then
      local ASTExtraVehicleBase = import("STExtraVehicleBase")
      if not Game:IsClassOf(uAttachParent, ASTExtraVehicleBase) then
        print(bWriteLog and "DebugAttach HandleOnPreRepAttachment not  STExtraVehicleBase return  PlayerKey:", self.PlayerKey)
        return
      end
      print(bWriteLog and "DebugAttach HandleOnPreRepAttachment uAttachParent ok PlayerKey:", self.PlayerKey)
      local RelativeLocation = FVector(0, 0, self:GetSimpleCollisionHalfHeightInStandPose())
      local uUseAttachComp
      if slua.isValid(uAttachComponent) then
        uUseAttachComp = uAttachComponent
      else
        if uAttachParent.GetMesh then
          uUseAttachComp = uAttachParent:GetMesh()
        end
        print(bWriteLog and "DebugAttach HandleOnPreRepAttachment uUseAttachComp nil or IsPendingKill, Please Check Vehicle's DefaultNetCullDistanceSq=3600000000.0 PlayerKey:", self.PlayerKey)
      end
      local VehicleSeat = uAttachParent:GetVehicleSeats()
      if slua.isValid(VehicleSeat) and slua.isValid(uUseAttachComp) then
        local RealSocketName = VehicleSeat:GetAttachSocketName(self, uUseAttachComp, uAttachSocket)
        if RealSocketName ~= "None" then
          print(bWriteLog and "CharacterBase:HandleOnPreRepAttachment", uAttachSocket, RealSocketName, uAttachParent)
          uAttachSocket = RealSocketName
        end
      end
      self:SetAttachment(uAttachParent, uUseAttachComp, RelativeLocation, uRotationOffset, uRelativeScale3D, uAttachSocket)
    end
  else
    print(bWriteLog and "DebugAttach HandleOnPreRepAttachment uAttachParent nil PlayerKey:", self.PlayerKey)
  end
end

function CharacterBase:HandleIsEnterNearDeathDelegate(IsNearDeath)
  if self.HealthStatus == ECharacterHealthStatus.FinishedLastBreath and self.LastHealthStatus == ECharacterHealthStatus.HasLastBreath then
    print(bWriteLog and "DeadAnimation HandleIsEnterNearDeathDelegate  call PlayerKey:", self.PlayerKey)
    if slua.isValid(self.Mesh) then
      self:CheckPlayDeadAnimation(self.Mesh.AnimScriptInstance)
      local uAnimInstances = self.Mesh:GetSubAnimInstances()
      for i = 1, uAnimInstances:Num() do
        local uAnimInst = uAnimInstances:Get(i * 1)
        self:CheckPlayDeadAnimation(uAnimInst)
      end
    end
  end
  local ENetRole = import("ENetRole")
  local EParachuteState = import("EParachuteState")
  if self.Role == ENetRole.ROLE_AutonomousProxy and self.HealthStatus == ECharacterHealthStatus.HasLastBreath and self.ParachuteState == EParachuteState.PS_Opening then
    self:SwitchCameraToParachuteOpening()
    print(bWriteLog and "NearDeathParachute parachute Death")
  end
  self:ClearFollowEmote()
end

function CharacterBase:HandleServerEnterNearDeathDelegate(IsNearDeath)
  if IsNearDeath then
    local Controller = self:GetPlayerControllerSafety()
    local SilentCommunicationSubsystem = SubsystemMgr:Get("SilentCommunicationSubsystem")
    if SilentCommunicationSubsystem then
      SilentCommunicationSubsystem:OnConditionTrigger(1, Controller)
    end
  end
end

function CharacterBase:GetSelfRescueSkillID()
  if self:HasState(EPawnState.AttachToOther) then
    return 0
  end
  return 1014669
end

function CharacterBase:HandleOnPlayerStartRescue(RescueWho, IsRescuing)
  if RescueWho and slua.isValid(RescueWho) and RescueWho == self.Object then
    print(bWriteLog and "CharacterBase:HandleOnPlayerStartRescue, IsRescuing = " % tostring(self.PlayerKey))
    if IsRescuing then
      local uWeaponManager = self:GetWeaponManager()
      if Game:IsValid(uWeaponManager) then
        uWeaponManager.HideCurrentWeapon = true
      else
        print(bWriteLog and "CharacterBase:HandleOnPlayerStartRescue, uWeaponManager invalid")
      end
      self.CachedSelfRescueSkillID = self:GetSelfRescueSkillID()
      self:TriggerEntrySkillWithID(self.CachedSelfRescueSkillID, true)
      local PlayerState = self:GetPlayerStateSafety()
      if Game:IsValid(PlayerState) then
        PlayerState:AddGeneralCount(1121, 1, false)
      end
    else
      local SkillManager = self:GetSkillManager()
      if SkillManager and slua.isValid(SkillManager) and self.CachedSelfRescueSkillID then
        local UTSkillStopReason = import("UTSkillStopReason")
        SkillManager:StopSkill(self.CachedSelfRescueSkillID, UTSkillStopReason.SkillStopReason_Interrupted)
        self.CachedSelfRescueSkillID = nil
      end
      local uWeaponManager = self:GetWeaponManager()
      if Game:IsValid(uWeaponManager) then
        uWeaponManager.HideCurrentWeapon = false
      else
        print(bWriteLog and "CharacterBase:HandleOnPlayerStartRescue, uWeaponManager invalid")
      end
    end
  end
  if IsRescuing then
    local Controller = self:GetPlayerControllerSafety()
    local SilentCommunicationSubsystem = SubsystemMgr:Get("SilentCommunicationSubsystem")
    if SilentCommunicationSubsystem then
      SilentCommunicationSubsystem:OnConditionTrigger(2, Controller)
    end
  else
    if not slua.isValid(RescueWho) then
      return
    end
    if RescueWho == self.Object then
      return
    end
    if RescueWho:HasState(EPawnState.Dying) then
      return
    end
    local uController = RescueWho:GetPlayerControllerSafety()
    if not slua.isValid(uController) then
      return
    end
    local uPlayerState = uController.PlayerState
    if not slua.isValid(uPlayerState) then
      return
    end
    local nKillerPlayerKey = uPlayerState.NearDeathCauserId
    local uKillerPlayerState = GameplayData.GetPlayerState(nKillerPlayerKey)
    if slua.isValid(uKillerPlayerState) and uKillerPlayerState.TeamID == self.TeamID and uPlayerState ~= uKillerPlayerState then
      return
    end
    local SilentCommunicationSubsystem = SubsystemMgr:Get("SilentCommunicationSubsystem")
    if SilentCommunicationSubsystem then
      SilentCommunicationSubsystem:OnConditionTrigger(2, uController, uController, 31006, 0, true, nil)
    end
  end
end

function CharacterBase:HandleDeathDelegate()
  print(bWriteLog and "CharacterBase HandleDeathDelegate" % tostring(self.PlayerKey))
  if Client then
    self:ClearFollowEmote()
  end
  if slua.isValid(self.STCharacterMovement) then
    self.STCharacterMovement:Deactivate()
    self.STCharacterMovement:SetMovementMode(EMovementMode.MOVE_None, 0)
  end
end

function CharacterBase:GetTargetAnimClass()
  if self.AvatarAnimClassCache ~= nil then
    return self.AvatarAnimClassCache
  end
  local uPC = self:GetPlayerControllerSafety()
  if slua.isValid(uPC) then
    return self.MainCharAnimClass
  end
  if self:IsInCarryBackState() then
    local uBeCarriedCharacter = self:GetBeCarriedBackCharacter()
    if slua.isValid(uBeCarriedCharacter) and slua.isValid(uBeCarriedCharacter:GetPlayerControllerSafety()) then
      return self.MainCharAnimClass
    end
  end
  return self.MainCharTPPAnimClass
end

function CharacterBase:ResetCharAnimInstanceClass(SetReason, bForceClearOldAnim)
  self.Super:ResetCharAnimInstanceClass(SetReason, bForceClearOldAnim)
end

function CharacterBase:CheckPlayDeadAnimation(uAnimInst)
  if slua.isValid(uAnimInst) and uAnimInst.PlayPlayerDeadAnimation ~= nil and uAnimInst.C_IsNearDeathStatus ~= nil then
    local bResetND = false
    if uAnimInst.C_IsNearDeathStatus == true then
      uAnimInst.C_IsNearDeathStatus = false
      bResetND = true
    end
    local PrePose = uAnimInst.C_PoseType
    uAnimInst.C_PoseType = ECharacterPoseState.ECharPose_Crouch
    print(bWriteLog and "DeadAnimation HandleIsEnterNearDeathDelegate PlayPlayerDeadAnimation true PlayerKey:", self.PlayerKey)
    uAnimInst:PlayPlayerDeadAnimation()
    if bResetND then
      uAnimInst.C_IsNearDeathStatus = true
    end
    uAnimInst.C_PoseType = PrePose
  end
end

function CharacterBase:SetDiedTime()
  self.DiedTime = CGameState:GetServerWorldTimeSeconds()
  local PlayerState = self:GetPlayerStateSafety()
  if PlayerState == nil or slua.isValid(PlayerState) == false or PlayerState.SetDiedTime == nil then
    return
  end
  PlayerState:SetDiedTime()
end

function CharacterBase:GetDiedTime()
  if self.DiedTime then
    return self.DiedTime
  else
    return 0
  end
end

function CharacterBase:SetDiedPosition()
  self.DiedPosition = self:K2_GetActorLocation()
  self.TeammmatePositionWhenMeDied = {}
  local CharacterState = self:GetPlayerStateSafety()
  if CharacterState == nil then
    return
  end
  local TeammatesState = CharacterState.TeamMatePlayerStateList
  if TeammatesState == nil or TeammatesState:Num() <= 0 then
    return
  end
  for index = 0, TeammatesState:Num() * 1 do
    local uTeammatePlayerState = TeammatesState:Get(index)
    if uTeammatePlayerState and slua.isValid(uTeammatePlayerState) and slua.isValid(uTeammatePlayerState.TeamMatePlayerState) then
      local uOtherCharacter = uTeammatePlayerState.TeamMatePlayerState:GetPlayerCharacter()
      if uOtherCharacter and slua.isValid(uOtherCharacter) then
        self.TeammmatePositionWhenMeDied[uOtherCharacter.PlayerKey] = uOtherCharacter:K2_GetActorLocation()
      end
    end
  end
end

function CharacterBase:GetDiedPosition()
  if self.DiedPosition then
    return self.DiedPosition
  else
    return FVector(0, 0, 0)
  end
end

function CharacterBase:GetTeammatePositionWhenMeDied()
  return self.TeammmatePositionWhenMeDied
end

function CharacterBase:SetDiedPlayerCount()
  local uPlayerState = self:GetPlayerStateSafety()
  if uPlayerState == nil or slua.isValid(uPlayerState) == false then
    print(bWriteLog and "CharacterBase:SetDiedPlayerCount, PlayerKey = " % ", uPlayerState is invalid")
    return
  end
  if uPlayerState.SetDiedPlayerCount == nil then
    print(bWriteLog and "CharacterBase:SetDiedPlayerCount, PlayerKey = " % ", uPlayerState has no SetDiedPlayerCount function")
    return
  end
  uPlayerState:SetDiedPlayerCount()
end

function CharacterBase:ReceiveBeginPlay()
  printf("CharacterBase ReceiveBeginPlay() PlayerKey:%s", tostring(self.PlayerKey))
  CharacterBase.__super.ReceiveBeginPlay(self)
  GameplayData.BindPlayerCharacter(self.Object)
  self:ConditionChangePhysicsAsset()
  if Client then
    local AvatarExceptionSubsystem = SubsystemMgr:Get("AvatarExceptionSubsystem")
    if AvatarExceptionSubsystem then
      AvatarExceptionSubsystem:BindPlayerCharacter(self.Object)
    end
  end
  if self.LuaReceiveBeginPlay then
    self:LuaReceiveBeginPlay()
  end
  self:AddCommonEventWithConditions(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE, {
    [1] = "FightingState"
  }, self.HandleEnterGameModeFightingState, self)
  self:CheckInitPlayerDSData()
  if self.DelayResetStandDuration ~= nil and self.DelayHideDuration ~= nil then
    self.DelayResetStandDuration = self.DelayHideDuration
  end
  if self:HasAuthority() and slua.isValid(self.NearDeatchComponent) then
    self:AddControlEvent(self.NearDeatchComponent, "OnPreEnterNearDeath", self.HandleOnPreEnterNearDeath, self)
  end
  if self:IsAutonomousProxy() and slua.isValid(self.STCharacterMovement) then
    self:AddControlEvent(self.STCharacterMovement, "OnClientAdjustPosition", self.HandleOnClientAdjustPosition, self)
    self.STCharacterMovement.ForbiddenMoveCondition.ContinueSeconds = 10
  end
  if CGame:IsEditor() then
    local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
    local SecurtyEditorConfig = GamePlayTools.GetCurrentConfig("SecurtyEditorConfig")
    if SecurtyEditorConfig and SecurtyEditorConfig.GameSafeCallbacks then
      require(SecurtyEditorConfig.GameSafeCallbacks)
    end
  end
  local UKismetSystemLibrary = import("KismetSystemLibrary")
  if UKismetSystemLibrary.IsDedicatedServer(self) and GameSafeCallbacks then
    GameSafeCallbacks.CharacterReceiveBeginPlay(self)
    self.bSkipComparePropertiesForReplay = true
  end
  if Client then
    self:AddControlEvent(self, "OnCharacterFallingModeChange", self.HandleCharacterFallingModeChange, self)
  end
  if self:HasAuthority() then
    local Config = require("GameLua.Mod.BaseMod.DS.Config.SelfRescueConfig")
    if Config then
      if Config.HurtWhenSelfRescue ~= nil then
        self.HurtWhenSelfRescue = Config.HurtWhenSelfRescue
      end
      if Config.CoolDownTime ~= nil then
        self.SelfRescueCoolDownTime = Config.CoolDownTime
      end
      print(bWriteLog and "CharacterBase:ReceiveBeginPlay, Set HurtWhenSelfRescue = " % tostring(self.SelfRescueCoolDownTime))
    end
    self:ReplaceGrenadeSkills()
  end
  if self:IsAutonomousProxy() then
    local CurrentVehicle = self:GetCurrentVehicle()
    if slua.isValid(CurrentVehicle) then
      self:ChangeCurrentVehicle(CurrentVehicle)
    end
    self:AddControlEvent(self, "OnClientCurrentVehicleChange", self.ChangeCurrentVehicle, self)
    local CurrentShootWeapon = self:GetCurrentShootWeapon()
    if slua.isValid(CurrentShootWeapon) then
      self:ChangeCurrentWeapon(CurrentShootWeapon)
    end
    GameComponentData.AddSelfWeaponManagerComponentEvent(self, "ChangeCurrentUsingWeaponDelegate", self.ChangeCurrentWeapon, self)
    if self.ReportCharacterStateTimer then
      self:RemoveGameTimer(self.ReportCharacterStateTimer)
      self.ReportCharacterStateTimer = nil
    end
    self.ReportCharacterStateTimer = self:AddGameTimer(5.0, true, function()
      self:ReportCharacterState()
    end)
  end
  if Client and self:IsAutonomousProxy() then
    self:RegistAttrModifyRecordList()
  end
  if Client then
    local uGameState = slua_GameFrontendHUD:GetGameState()
    if uGameState and slua.isValid(uGameState) and uGameState.GetGameModeState and uGameState:GetGameModeState() == "FightingState" then
      local NewObjectPoolLuaBridgeSubsystem = SubsystemMgr:Get("NewObjectPoolLuaBridgeSubsystem")
      if NewObjectPoolLuaBridgeSubsystem then
        NewObjectPoolLuaBridgeSubsystem.SpawnActorCounter_Character = NewObjectPoolLuaBridgeSubsystem.SpawnActorCounter_Character - 1
      end
    end
    local UKismetSystemLibrary = import("KismetSystemLibrary")
    if slua.isValid(self.STCharacterMovement) then
      self.STCharacterMovement.MoveSkipTickContinueTime = 2
      self.STCharacterMovement.MoveSkipTickContinueCount = 40
      self.STCharacterMovement.SimulateDelayReceiveLODTheshold = 16
      self.STCharacterMovement.SimulateNotMoveSmoothLODTheshold = 14
    end
    if Client.IsDevelopment() then
      self:DevelopmentClientCheck()
    end
    local ENetRole = import("ENetRole")
    if self.Role == ENetRole.ROLE_SimulatedProxy then
      self:RefreshThermalImagingLocal()
    end
  end
  if self:HasAuthority() and slua.isValid(self.STCharacterMovement) then
    self:AddControlEvent(self.STCharacterMovement, "OnComponentActivated", self.OnMovementActivated, self)
    self:AddControlEvent(self.STCharacterMovement, "OnResolvePenetrationDelegate", self.HandleOnResolvePenetrationDelegate, self)
  end
  local ENetRole = import("ENetRole")
  if self.Role == ENetRole.ROLE_AutonomousProxy and slua.isValid(self.STCharacterMovement) then
    self.STCharacterMovement.bOpenLocationSmoothOnDynamicMovementBase = false
    print(bWriteLog and "CharacterBase:ReceiveBeginPlay bOpenLocationSmoothOnDynamicMovementBase false")
  end
  self:ShowDoorInteractUIIfNeed()
  if Client then
    self:AddControlEvent(self, "OnSmartBearerLayerVisibilityChanged", self._OnSmartBearerLayerVisibilityChanged, self)
  end
end

function CharacterBase:_OnSmartBearerLayerVisibilityChanged(bIsHidden)
  printf("CharacterBase:_OnSmartBearerLayerVisibilityChanged %s", tostring(bIsHidden))
  local EMeshVisibleLayer = import("/Script/Engine.EMeshVisibleLayer")
  local ESkeletaTickMode = import("/Script/Engine.ESkeletaTickMode")
  local MasterMesh = self.Mesh
  if slua.isValid(MasterMesh) then
    if bIsHidden then
      MasterMesh:SetLayerVisibilityValue(EMeshVisibleLayer.VisibleLayer_2, false, false)
      MasterMesh:SetTickMode(ESkeletaTickMode.TICK_NONE)
    else
      MasterMesh:SetLayerVisibilityValue(EMeshVisibleLayer.VisibleLayer_2, true, false)
      MasterMesh:SetTickMode(ESkeletaTickMode.TICK_ALL)
    end
  end
end

function CharacterBase:ConditionChangePhysicsAsset()
  if Client then
    local uMyMesh = self.Mesh
    if slua.isValid(uMyMesh) then
      local uMyMeshPhysics = USTExtraBlueprintFunctionLibrary.GetPhysicsAssetFromMesh(uMyMesh)
      if uMyMeshPhysics == self.ShootPhysicsAsset and slua.isValid(self.ShootPhysicsAssetOpt) and uMyMesh.SetPhysicsAsset then
        uMyMesh:SetPhysicsAsset(self.ShootPhysicsAssetOpt, true)
        USTExtraBlueprintFunctionLibrary.CreatePhysicsState(uMyMesh)
        printf(string.format("CharacterBase:ReceiveBeginPlay SetPhysicsAsset"))
      end
      printf(string.format("CharacterBase:ReceiveBeginPlay GetPhysicsAssetFromMesh %s->%s)", tostring(uMyMeshPhysics), tostring(self.ShootPhysicsAsset)))
    end
  end
end

function CharacterBase:ShowDoorInteractUIIfNeed()
  local ENetRole = import("ENetRole")
  if Client and self.Role == ENetRole.ROLE_AutonomousProxy then
    self:AddGameTimer(1, false, function()
      local CapsuleComponent = self and self.CapsuleComponent
      if CapsuleComponent and slua.isValid(CapsuleComponent) then
        local ActorClass = import("/Script/Engine.Actor")
        local PUBGDoorClass = import("PUBGDoor")
        local OverlapActors = CapsuleComponent:GetOverlappingActors(slua.Array(UEnums.EPropertyClass.Object, ActorClass), PUBGDoorClass)
        if OverlapActors and OverlapActors:Num() > 0 then
          for Index = 0, OverlapActors:Num() * 1 do
            local PUBGDoor = OverlapActors:Get(Index)
            if PUBGDoor and slua.isValid(PUBGDoor) and PUBGDoor.bDoubleDoor == false and PUBGDoor.DoorBroken == false then
              local FHitResult = import("/Script/Engine.HitResult")
              local uHitResult = FHitResult()
              print(bWriteLog and "CharacterBase:ShowDoorInteractUIIfNeed, Call PUBGDoor:OnBeginOverlap")
              PUBGDoor:OnBeginOverlap(PUBGDoor.Interaction, self.Object, CapsuleComponent, -1, true, uHitResult)
            end
          end
        end
      end
    end)
  end
end

function CharacterBase:DevelopmentClientCheck()
  if slua.isValid(self.HitBox_Stand) or slua.isValid(self.HitBox_Prone) then
    local UKismetSystemLibrary = import("KismetSystemLibrary")
    if UKismetSystemLibrary.IsStandalone(slua.getGameInstance()) then
    else
      local Tips = "DevelopmentClientCheck: "
      Tips = Tips % string.format("Character =  %s ", tostring(self.Object))
      Tips = Tips % string.format("HitBox_Stand =  %s ", tostring(self.HitBox_Stand))
      Tips = Tips % string.format("HitBox_Prone =  %s ", tostring(self.HitBox_Prone))
      print(bWriteLog and "CharacterBase:DevelopmentClientCheck.." % tostring(Tips))
      self:RPC_Server_ShootVertifyFailAlarm(4, Tips)
    end
  end
end

function CharacterBase:IsAutonomousProxy()
  if CharacterBase.__super.IsAutonomousProxy(self) then
    return true
  end
  if Client and self.IsLocallyControlled and type(self.IsLocallyControlled) == "function" and self:IsLocallyControlled() then
    return true
  end
  return CharacterBase.__super.IsAutonomousProxy(self)
end

function CharacterBase:SetLastAddBuffInst(nInstID, uPawn)
  self.LastAddBuffInstID = nInstID
  self.LastAddPawn = uPawn
end

function CharacterBase:GetLastAddBuffInst()
  return self.LastAddBuffInstID, self.LastAddPawn
end

function CharacterBase:RegistAttrModifyRecordList()
end

function CharacterBase:ChangeCurrentVehicle(CurrentVehicle)
  GameplayActorData.BindSelfActor("CurrentVehicle", CurrentVehicle)
end

function CharacterBase:ChangeCurrentWeapon()
  if self.GetCurrentWeapon == nil then
    return
  end
  local uWeapon = self:GetCurrentWeapon()
  if slua.isValid(uWeapon) then
    GameplayActorData.BindSelfActor("CurrentWeapon", uWeapon)
  end
end

function CharacterBase:HandleOnClientAdjustPosition(NewLocation, Reason)
  if CGameState == nil or not slua.isValid(CGameState) then
    return
  end
  if CGameState.GetGameModeState == nil or CGameState:GetGameModeState() == "ReadyState" then
    return
  end
  local EReason = import("ECharacterMoveDragReason")
  if Reason == EReason.CMDR_ExceedsDistance and self.PlayerState and self.PlayerState.Ping then
    local bWeakNet = self.PlayerState.Ping + 4 > 250 or false
    print(bWriteLog and "CharacterBase:HandleOnClientAdjustPosition ", " Ping: ", self.PlayerState and self.PlayerState.Ping + 4 or -1)
    if bWeakNet then
      NetUtil.ShowDSTimeOutTipsUI(true, NetUtil.DSTimeOutShort)
      self:AddGameTimer(1, false, function()
        NetUtil.ShowDSTimeOutTipsUI(false, NetUtil.DSTimeOutShort)
      end)
    end
  end
end

function CharacterBase:CheckInitPlayerDSData()
  if self:IsAutonomousProxy() then
    if self.PlayerKey ~= nil and self.PlayerKey > 0 then
      self:InitPlayerDsData(self.PlayerKey)
    else
      self:AddControlEvent(self, "OnReceivePlayerKey", self.InitPlayerDsData, self)
    end
  end
end

function CharacterBase:InitPlayerDsData(nPlayerKey)
  if nPlayerKey == nil or nPlayerKey == 0 then
    print(bWriteLog and "CharacterBase InitPlayerDsData playerKey:", nPlayerKey)
    return
  end
  local PlayerEventSubsystem = SubsystemMgr:Get("PlayerEventSystem")
  if PlayerEventSubsystem then
    PlayerEventSubsystem:CheckInitDSData(nPlayerKey)
  end
end

function CharacterBase:ReceiveEndPlay(nDeltaSeconds)
  printf("CharacterBase ReceiveEndPlay() PlayerKey:%s", tostring(self.PlayerKey))
  if Client then
    local SKillManager = self:GetSkillManager()
    local CheckWeaponSkillID = 1014405
    if slua.isValid(SKillManager) and SKillManager:GetCurSkillID() == CheckWeaponSkillID then
      self:StopCurrentLevelSequence()
    end
    if self.ReportCharacterStateTimer then
      self:RemoveGameTimer(self.ReportCharacterStateTimer)
      self.ReportCharacterStateTimer = nil
    end
  end
  GameplayData.UnbindPlayerCharacter(self.Object)
  if Client then
    local AvatarExceptionSubsystem = SubsystemMgr:Get("AvatarExceptionSubsystem")
    if AvatarExceptionSubsystem then
      AvatarExceptionSubsystem:UnbindPlayerCharacter(self.Object)
    end
  end
  if self.PlayerKey ~= nil and self.PlayerKey > 0 then
    EventSystem:postEvent(EVENTTYPE_PLAYEREVENT_WEAPON, EVENTID_PLAYEREVENT_WEAPON_CLEAR, self.PlayerKey)
    local PlayerEventSubsystem = SubsystemMgr:Get("PlayerEventSystem")
    if PlayerEventSubsystem then
      PlayerEventSubsystem:ClearPlayer(self.PlayerKey)
    end
  end
  self:ClearFollowEmote()
  if not self:HasAuthority() then
    self:ClearAkEventSound()
  end
  self._SuperData = nil
  if Client and self._BloodSpotDelegateHandles then
    for sName, Info in pairs(self._BloodSpotDelegateHandles) do
      if type(Info) == "table" then
        local Provider = Info.Provider
        local Handle = Info.Handle
        if Handle then
          if slua.isValid(Provider) then
            local EventDelegate = Provider.AsyncLoadParticleComponentDone
            if slua.isValid(EventDelegate) and EventDelegate.Remove then
              EventDelegate:Remove(Handle)
            else
              slua.removeDelegate(Handle)
            end
          else
            slua.removeDelegate(Handle)
          end
        end
      end
      self._BloodSpotDelegateHandles[sName] = nil
    end
    self._BloodSpotDelegateHandles = nil
  end
  CharacterBase.__super.ReceiveEndPlay(self, nDeltaSeconds)
end

function CharacterBase:GetVehicleParachuteComponent()
  if self.VehicleParachuteComponent == nil then
    local ComponentClass = import("VehicleParachuteComponent")
    self.VehicleParachuteComponent = self:GetComponentByClass(ComponentClass)
  end
  return self.VehicleParachuteComponent
end

function CharacterBase:ReceivePossessed(InController)
  if not slua.isValid(InController) then
    return
  end
  print(bWriteLog and "CharacterBase:ReceivePossessed")
  self.Super:ReceivePossessed(InController)
  local FeatureUtil = require("GameLua.Mod.BaseMod.GamePlay.Feature.Common.FeatureUtil")
  FeatureUtil.ForEachFeatureCall(self, "ReceivePossessed", InController)
  self:HandleUseGlide(InController)
  self:HandleParachuteComponent(InController)
  self:InitRevivalCount(InController)
  if not Client and not Game:IsAIController(InController) then
    self:RegistAttrModifyRecordList()
  elseif not Client and Game:IsAIController(InController) then
    self.IndoorCheckTime = 2
  end
  printf(bWriteLog and "CharacterBase:ReceivePossessed Before PlayerKey:%d NetConsiderFrequency:%f NetUpdateFrequency:%f MinNetUpdateFrequency:%f", self.PlayerKey, self.NetConsiderFrequency, self.NetUpdateFrequency, self.MinNetUpdateFrequency)
  local bBatchMove = USTExtraBlueprintFunctionLibrary.IsActorRepMovementWithBatch(self.Object)
  self:RefreshNetUpdateFrequency(bBatchMove)
  if InController and slua.isValid(InController) and InController.RefreshNetUpdateFrequency then
    InController:RefreshNetUpdateFrequency(bBatchMove)
  end
  self:AddGameTimer(5, false, function()
    if self.PlayerKey ~= nil then
      printf(bWriteLog and "CharacterBase:ReceivePossessed After PlayerKey:%d NetConsiderFrequency:%f NetUpdateFrequency:%f MinNetUpdateFrequency:%f", self.PlayerKey, self.NetConsiderFrequency, self.NetUpdateFrequency, self.MinNetUpdateFrequency)
    end
  end)
end

function CharacterBase:HandleParachuteComponent(InController)
  if slua.isValid(InController) and slua.isValid(self.ParachuteComponent) then
    if Game:IsClassOf(InController, ASTExtraPlayerController) then
      self.ParachuteComponent:InitParachuteData(InController)
    elseif Game:IsClassOf(InController, ANewFakePlayerAIController) and self.ParachuteComponent.InitAIParachuteData then
      self.ParachuteComponent:InitAIParachuteData(InController)
    end
  end
end

function CharacterBase:InitRevivalCount(InController)
  if not self:HasAuthority() then
    return
  end
  local uPlayerState = self:GetPlayerStateSafety()
  if uPlayerState and slua.isValid(uPlayerState) then
    if uPlayerState.InitRevivalCountImpl then
      uPlayerState:InitRevivalCountImpl(InController, self.Object)
    else
      print(bWriteLog and "CharacterBase:InitRevivalCount, have no function InitRevivalCountImpl")
    end
  else
    print(bWriteLog and "CharacterBase:InitRevivalCount, uPlayerState = " % tostring(uPlayerState))
  end
end

function CharacterBase:HandleUseGlide(InController)
  if self:HasAuthority() then
    self:InitParachutingVehicle()
  end
end

function CharacterBase:HandleEnterGameModeFightingState()
  print(bWriteLog and "CharacterBase:HandleEnterGameModeFightingState")
  if slua.isValid(CGameState) and CGameState:IsCreativeMode() then
    return
  end
  if self:CharacterIsRecycled() then
    print(bWriteLog and "CharacterBase:HandleEnterGameModeFightingState, CharacterIsRecycled = true")
    return
  end
  if slua.isValid(self.Object) and not self:HasAuthority() and self.EmoteBPIDToAnimHandleMap then
    local CheckTable = {
      2206015,
      2206016,
      2206017,
      2206018
    }
    for _, ID in pairs(CheckTable) do
      local EmoteHandle = self.EmoteBPIDToAnimHandleMap:Get(ID)
      if slua.isValid(EmoteHandle) and EmoteHandle.EmoteActionList then
        local NeedStop = false
        for _, Action in pairs(EmoteHandle.EmoteActionList) do
          if Action:GetIsExecuting() then
            NeedStop = true
            break
          end
        end
        if NeedStop then
          self:OnPlayEmoteStop(ID)
        end
      end
    end
  end
end

function CharacterBase:InitParachutingVehicle()
  if self:HasAuthority() then
    if self.bEnsure then
      print(bWriteLog and "CharacterBase:InitParachutingVehicle self.bEnsure")
      return
    end
    local ComponentClass = self.DynamicComponentMap:Get("ParachutingVehicle")
    if ComponentClass then
      local UScriptGameplayStatics = import("ScriptGameplayStatics")
      UScriptGameplayStatics.CreateComponent(self, ComponentClass, "ParachutingVehicle", false)
    else
      print(bWriteLog and "CharacterBase:InitParachutingVehicle not ComponentClass")
    end
  end
end

function CharacterBase:PlayerPoseChange(stLastPoseState, stNewPoseState)
  local ESTEPoseState = import("ESTEPoseState")
  if Client and (self.IsClientPeeking and stNewPoseState == ESTEPoseState.Sprint or stNewPoseState == ESTEPoseState.CrouchSprint) then
    self:NM_ForceSetPeekState(false, false)
  end
end

function CharacterBase:HandleAttachedToVehicle(uVehicle)
  if not slua.isValid(uVehicle) then
    return
  end
  if slua.isValid(self.CharacterMovement) then
    self.CharacterMovement:SetBase(nil, "", true)
  end
  if uVehicle.ForceUseTPP then
    print(bWriteLog and "CharacterBase:HandleAttachedToVehicle, bIsFPPOnVehicle: false", self.Object, uVehicle)
    self.bIsFPPOnVehicle = false
  end
end

function CharacterBase:HandleDetachedFromVehicle(uLastVehicle)
  if not slua.isValid(self.Object) or not slua.isValid(uLastVehicle) then
    return
  end
  if uLastVehicle.ForceUseTPP then
    print(bWriteLog and "CharacterBase:HandleAttachedToVehicle, bIsFPPOnVehicle: true", self.Object, uLastVehicle)
    self.bIsFPPOnVehicle = true
  end
  if Client then
    local Location = self:K2_GetActorLocation()
    if Location.X > -1.0E-5 and Location.X < 1.0E-5 and -1.0E-5 < Location.Y and 1.0E-5 > Location.Y and -1.0E-5 < Location.Z and 1.0E-5 > Location.Z then
      Location = uLastVehicle:K2_GetActorLocation() - FVector(0, 0, 200)
      print(bWriteLog and string.format("CharacterBase:HandleAttachedToVehicle, Vehicle: %s, character location: %s", uLastVehicle, Location))
      self:K2_SetActorLocation(Location, false, nil, true)
    end
  end
end

function CharacterBase:SwitchWeaponBySlotAfterConsume(OldWeaponSlotBeforeSkill)
  print(bWriteLog and "SwitchWeaponBySlotAfterConsume", OldWeaponSlotBeforeSkill)
  local ESurviveWeaponPropSlot = import("ESurviveWeaponPropSlot")
  if OldWeaponSlotBeforeSkill == ESurviveWeaponPropSlot.SWPS_HandProp then
    local Controller = self:GetPlayerControllerSafety()
    if not (slua.isValid(Controller) and GameLuaAPI.IsClassOf(Controller, ASTExtraPlayerController)) or not self:AllowState(EPawnState.SwitchWeapon, false) then
      return
    end
    if self:HasState(EPawnState.WebSwing) and slua.isValid(self.STCharacterMovement) then
      local ESpecialMovementType = import("ESpecialMovementType")
      local ESpiderSwingMoveState = import("ESpiderSwingMoveState")
      local SpiderSwingObj = self.STCharacterMovement:GetSpecialMoveObjBySpecialMoveType(ESpecialMovementType.SPECIAL_MOVE_SpiderSwing)
      if slua.isValid(SpiderSwingObj) then
        local nCurState = SpiderSwingObj:GetCurMoveState()
        if nCurState == ESpiderSwingMoveState.Launching or nCurState == ESpiderSwingMoveState.Swinging then
          print(bWriteLog and "CharacterBase:SwitchWeaponBySlotAfterConsume blocked by SpiderSwing state: " % tostring(nCurState))
          return
        end
      end
    end
    Controller:ServerAutoSwitchSameSlotWeapon(OldWeaponSlotBeforeSkill)
  else
    self:SwitchWeaponBySlot(OldWeaponSlotBeforeSkill, true, false, false)
  end
end

function CharacterBase:IsEnablePlayerShovleing()
  local EPawnState = import("EPawnState")
  return not self:HasState(EPawnState.Prone) and self:HasState(EPawnState.Sprint)
end

function CharacterBase:OnRep_CarryBackStateChanged()
  local uCarryBackComp = self:GetCarryBackComp()
  if slua.isValid(uCarryBackComp) then
    uCarryBackComp:OnRep_CarryBackStateChanged()
  end
end

function CharacterBase:ShowCharacter(bShow)
  print(bWriteLog and "CharacterBase ShowCharacter", bShow, self.PlayerKey)
  self:SetActorHiddenInGame(bShow - self)
end

function CharacterBase:ShowMainWeaponOnBack(bShow)
  local uWeaponMgrCom = self:GetWeaponManager()
  if uWeaponMgrCom and slua.isValid(uWeaponMgrCom) then
    uWeaponMgrCom.ShowMainWeaponModelOnBack = bShow
  end
end

function CharacterBase:AddRevivalCount(nRevivalCount)
  if type(nRevivalCount) == "number" then
    local uPlayerState = self:GetPlayerStateSafety()
    if uPlayerState and slua.isValid(uPlayerState) then
      if uPlayerState.GetRevivalCount and uPlayerState.SetRevivalCount then
        local GeneralRevivalCount = uPlayerState:GetRevivalCount()
        GeneralRevivalCount = GeneralRevivalCount - nRevivalCount
        if GeneralRevivalCount < 0 then
          GeneralRevivalCount = 0
        end
        print(bWriteLog and "CharacterBase:AddRevivalCount, nRevivalCount = " % tostring(nRevivalCount))
        uPlayerState:SetRevivalCount(GeneralRevivalCount)
      else
        print(bWriteLog and "CharacterBase:AddRevivalCount, Have no function")
      end
    end
  else
    print(bWriteLog and "CharacterBase:AddRevivalCount, type(nRevivalCount) = " % type(nRevivalCount))
  end
end

function CharacterBase:SetUseDeadBox(bUseDeadBox)
  local eUseDeadBox = 1
  if not bUseDeadBox then
    eUseDeadBox = 0
  end
  printf("revivaldebug CharacterBase SetUseDeadBox PlayerKey:%u, eUseDeadBox:%d ", self.PlayerKey, eUseDeadBox)
  self:SetAttrValue("bUseDeadBox", eUseDeadBox, -1)
end

function CharacterBase:GetUseDeadBox()
  local fUseDeadBox = self:GetAttrValue("bUseDeadBox")
  local nUseDeadBox = math.floor(fUseDeadBox - 0.1)
  return 0 < nUseDeadBox
end

function CharacterBase:CharacterAttrChangeEvent(uPawn, AttrName, AttrVal)
  if self.Object == uPawn then
    if AttrName == "bUseDeadBox" then
      self.bIsUseDeadBox = self:GetUseDeadBox()
      print(bWriteLog and "revivaldebug CharacterBase CharacterAttrChangeEvent PlayerKey:, self.bIsUseDeadBox:", self.PlayerKey, self.bIsUseDeadBox)
    elseif AttrName == "IsInUnderGroundArea" then
      self.bIsInUnderGroundArea = AttrVal == 1
      if not Client then
        local ESightVisionCondition = import("ESightVisionCondition")
        local USTExtraModLogicSwitchLibrary = import("STExtraModLogicSwitchLibrary")
        if USTExtraModLogicSwitchLibrary.IsNightVisionUnderGroundOnly() then
          self:SetSightCondition(self.bIsInUnderGroundArea, ESightVisionCondition.NightVisionUnderGround)
        end
      end
    elseif AttrName == "IsAroundUndergroundEntry" then
      self.bIsAroundUndergroundEntry = AttrVal == 1
    elseif AttrName == "EmotePlayRate" then
      if Client then
        local PhotoGrapherSubSystem = SubsystemMgr:Get("PhotoGrapherSubSystem")
        if PhotoGrapherSubSystem then
          PhotoGrapherSubSystem:EmotePlayRateChanged(self.Object, AttrVal)
        end
      end
    elseif AttrName == "AreaID" then
      self:ChangeFootStepValue(AttrVal)
      self:HandleAreaIDChanged(AttrVal)
      if self:IsLocalControlorView() or self:IsLocalViewed() then
        print(bWriteLog and "revivaldebug CharacterBase CharacterAttrChangeEvent PlayerKey:, AreaID", self.PlayerKey, AttrVal)
        EventSystem:postEvent(EVENTTYPE_PLAYEREVENT_CHARACTER, EVENTID_PLAYEREVENT_LOCAL_CHAR_AREA_ID_CHANGED, AttrVal)
      else
        EventSystem:postEvent(EVENTTYPE_PLAYEREVENT_CHARACTER, EVENTID_PLAYEREVENT_CHAR_AREA_ID_CHANGED, AttrVal)
      end
    elseif AttrName == "MapID" then
      if self:IsLocalControlorView() or self:IsLocalViewed() then
        print(bWriteLog and "revivaldebug CharacterBase CharacterAttrChangeEvent PlayerKey:, MapID:", self.PlayerKey, AttrVal)
        EventSystem:postEvent(EVENTTYPE_PLAYEREVENT_CHARACTER, EVENTID_PLAYEREVENT_LOCAL_CHAR_MAP_ID_CHANGED, AttrVal)
      end
    elseif AttrName == "DanceStageAreaState" and Client then
      EventSystem:postEvent(EVENTTYPE_PLAYEREVENT_CHARACTER, EVENTID_PLAYEREVENT_DANCESTATE_CHANGED, AttrVal, self.Object)
    end
  end
end

function CharacterBase:ChangeFootStepValue(AttrVal)
  if self.DefaultFootStep and AttrVal == 0 then
    return
  end
  local FootStepSoundConfig = GamePlayTools.GetCurrentConfig("FootStepSoundConfig")
  if not FootStepSoundConfig or not FootStepSoundConfig.bOpenAreaFootStep then
    return
  end
  local IntVal = math.tointeger(AttrVal)
  local AreaPara = FootStepSoundConfig[IntVal] or FootStepSoundConfig.DefaultPara
  local DefaultPara = FootStepSoundConfig.DefaultPara
  self.DefaultFootStep = AreaPara == DefaultPara
  self.FloorHeight = AreaPara.FloorHeight or DefaultPara.FloorHeight
  self.GFloorValue = AreaPara.GFloorValue or DefaultPara.GFloorValue
  self.DiffFloorValue = AreaPara.DiffFloorValue or DefaultPara.DiffFloorValue
  print(bWriteLog and "CharacterBase:ChangeFootStepValue, FloorHeight = " % self.FloorHeight)
  self.bInSoundDiffFloorArea = AreaPara.bInSoundDiffFloorArea or DefaultPara.bInSoundDiffFloorArea
end

function CharacterBase:HandleAreaIDChanged(AttrVal)
  print(bWriteLog and "CharacterBase:HandleAreaIDChanged, AttrVal = " % tostring(AttrVal))
end

function CharacterBase:HandleOnRespawn()
  printf("revivaldebug CharacterBase HandleOnRespawn")
  if self:IsAuthority() then
    printf(bWriteLog and "revivaldebug CharacterBase HandleOnRespawn self.PlayerKey:%u", self.PlayerKey)
    EventSystem:postEvent(EVENTTYPE_SECURITY, EVENTID_SECURITY_PLAYER_RESPAWN, self.Object)
  else
    local ENetRole = import("ENetRole")
    local uPlayerController = self:GetPlayerControllerSafety()
    if self:IsAutonomousProxy() then
      local UGameplayStatics = import("GameplayStatics")
      local uGameInstance = UGameplayStatics.GetGameInstance(self)
      if slua.isValid(uGameInstance) then
        local uReplay = uGameInstance:GetClientInGameReplay()
        if slua.isValid(uReplay) and uReplay:IsInRecordState() then
          printf("revivaldebug CharacterBase HandleOnRespawn clear deathplayback data")
          uReplay:OnPlayerRespawnNotify()
        end
      end
      local VibrateUtilitySubsystem = SubsystemMgr:Get("VibrateUtilitySubsystem")
      if VibrateUtilitySubsystem and VibrateUtilitySubsystem.HandleCharacterRespawned then
        print(bWriteLog and "CharacterBase.HandleOnRespawn VibrateUtilitySubsystem call HandleCharacterRespawned")
        VibrateUtilitySubsystem:HandleCharacterRespawned()
      end
      if slua.isValid(uPlayerController) and not uPlayerController:IsPureSpectator() and not uPlayerController:IsDemoPlayGlobalObserver() and not uPlayerController:IsDemoPlaySpectator() then
        print(bWriteLog and "CharacterBase.HandleOnRespawn QuitSpectating")
        uPlayerController:QuitSpectating()
        local uViewTarget = uPlayerController:GetViewTarget()
        if slua.isValid(uViewTarget) and slua.isValid(self.Object) and uViewTarget.Role == ENetRole.ROLE_SimulatedProxy then
          print(bWriteLog and "CharacterBase.HandleOnRespawn SetViewTarget to Owned Pawn")
          uPlayerController:SetViewTargetTest(self.Object)
        end
        if uPlayerController:ShouldForceFPPView(self) then
          local EPlayerCameraMode = import("EPlayerCameraMode")
          uPlayerController:SwitchCameraMode(EPlayerCameraMode.PCM_FPP, nil, false, true)
        else
          uPlayerController:SwitchCameraMode(uPlayerController.CurCameraMode, nil, false, true)
        end
      end
      self:AddGameTimer(3, false, function()
        local PlayerRespawnData = slua.IndexReference(self, "PlayerRespawnData")
        if PlayerRespawnData and not PlayerRespawnData.bIsDead and self.CharacterHide and not self.CharacterHide.bCharacterHideIngame and self.bHidden == true and not self:HasState(EPawnState.InPlane) then
          self:SetActorHiddenInGame(false)
        end
      end)
    elseif slua.isValid(self.STCharacterMovement) then
      self.STCharacterMovement.MaxWalkSpeed = 600
    end
    if slua.isValid(uPlayerController) and uPlayerController:IsInSpectating() and uPlayerController:GetLastestViewPlayerKey() == self.PlayerKey then
      printf("revivaldebug CharacterBase HandleOnRespawn ServerObserveCharacter  self.PlayerKey:%u", self.PlayerKey)
      uPlayerController:ServerObserveCharacter(self.PlayerKey)
    end
    if slua.isValid(self.STCharacterMovement) then
      self.STCharacterMovement.GravityScale = 1.0
      local uAttachParentActor = self:GetAttachParentActor()
      if slua.isValid(uAttachParentActor) then
        self:CheckAttachedOrDetachedVehicle(true)
        self.STCharacterMovement:Deactivate()
      end
    end
    if self.Role == ENetRole.ROLE_SimulatedProxy then
      self:RefreshThermalImagingLocal()
    end
  end
  self:LuaBroadcastCommonEventCpp("EVENTTYPE_PLAYEREVENT_CHARACTER", "EVENTID_PLAYEREVENT_REVIVAL", self.PlayerKey, self.Object, self.TeamID)
end

function CharacterBase:HandleOnPreEnterNearDeath(uKillPlayerController, DamageCauser)
  EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_ON_PRE_ENTER_NEAR_DEATH, self)
  if CGameMode and CGameMode.CheckTeammateAllNearDeath then
    CGameMode:CheckTeammateAllNearDeath(self.Object)
  end
end

function CharacterBase:LuaHandleParachuteStateChanged(LastParachuteState, NewParachuteState)
  print(bWriteLog and "CharacterBase:OnParachuteStateChanged", self.Role, LastParachuteState, NewParachuteState)
  local EParachuteState = import("EParachuteState")
  if not Client then
    print(bWriteLog and "CharacterBase:OnParachuteStateChanged, SetNetCullDistanceSquared", NewParachuteState)
    if NewParachuteState == EParachuteState.PS_FreeFall or NewParachuteState == EParachuteState.PS_Opening then
      self:SetNetCullDistanceSquared(900000000)
    else
      self:SetNetCullDistanceSquared(self.DefaultNetCullDistanceSq)
    end
  else
    local ENetRole = import("ENetRole")
    if self.Role == ENetRole.ROLE_AutonomousProxy then
      local EParachuteState = import("EParachuteState")
      if (NewParachuteState == EParachuteState.PS_FreeFall or NewParachuteState == EParachuteState.PS_Opening) and self.SwimComponet and slua.isValid(self.SwimComponet) then
        self.SwimComponet:LeaveWater()
      end
      if self.Role == ENetRole.ROLE_AutonomousProxy and self.HealthStatus == ECharacterHealthStatus.HasLastBreath and (self.ParachuteState == EParachuteState.PS_Opening or self.ParachuteState == EParachuteState.PS_FreeFall) then
        self:SwitchCameraToParachuteOpening()
      end
      if self.HealthStatus == ECharacterHealthStatus.HasLastBreath and LastParachuteState == EParachuteState.PS_Opening and (NewParachuteState ~= EParachuteState.PS_Opening or NewParachuteState ~= EParachuteState.PS_Landing) then
        local uSpringArmComp = self.SpringArmComp
        if slua.isValid(uSpringArmComp) then
          local CrouchHalfHeight = self:GetCrouchHalfHeight()
          CrouchHalfHeight = CrouchHalfHeight or 60
          uSpringArmComp:K2_SetRelativeLocation(FVector(0, 0, CrouchHalfHeight[self]), false, nil, true)
          local ECameraDataType = import("ECameraDataType")
          uSpringArmComp:SetCameraDataEnable(ECameraDataType.ECameraDataType_NearDeath, true)
          print(bWriteLog and "NearDeathParachute \232\144\189\229\156\176\229\155\158\229\164\141\229\188\185\231\176\167\232\135\130\228\189\141\231\189\174")
        end
      end
      EventSystem:postEvent(EVENTTYPE_INGAME_PARACHUTING, EVENTID_CLIENT_PARACHUTE_STATE_CHANGE, LastParachuteState, NewParachuteState)
    end
  end
  if NewParachuteState == EParachuteState.PS_None then
    EventSystem:postEvent(EVENTTYPE_INGAME_PARACHUTING, EVENTID_PARACHUTING_END, self.Object)
  end
end

function CharacterBase:LuaHandleRepParachuteStateDelegate()
  local ENetRole = import("ENetRole")
  local EParachuteState = import("EParachuteState")
  if not (self and self.Role) or not self.ParachuteState then
    print(bWriteLog and "CharacterBase:LuaHandleRepParachuteStateDelegate Role or ParachuteState is nil")
    return
  end
  print(bWriteLog and "CharacterBase:LuaHandleRepParachuteStateDelegate", self.Role, self.ParachuteState)
  if self.Role == ENetRole.ROLE_SimulatedProxy and self.ParachuteState == EParachuteState.PS_FreeFall then
    print(bWriteLog and "CharacterBase:LuaHandleRepParachuteStateDelegate RefreshParacthueAnimTimer")
    if self.RefreshParacthueAnimTimer then
      self:RemoveGameTimer(self.RefreshParacthueAnimTimer)
      self.RefreshParacthueAnimTimer = nil
    end
    self.RefreshParacthueAnimTimer = self:AddGameTimer(0.5, false, function()
      self:RemoveGameTimer(self.RefreshParacthueAnimTimer)
      self.RefreshParacthueAnimTimer = nil
      if self and slua.isValid(self.Object) then
        print(bWriteLog and "CharacterBase:LuaHandleRepParachuteStateDelegate RefreshParachuteAnim")
        self:TryCacheParachuteAnim()
      end
    end)
  end
end

function CharacterBase:TryCacheParachuteAnim()
  local uCharacter = self.Object
  if not slua.isValid(uCharacter) or not slua.isValid(uCharacter.Mesh) then
    print(bWriteLog and "CharacterBase:TryCacheParachuteAnim Character is nil")
    return
  end
  local CH_ABP_Parachute_Class = slua.loadClass("/Game/Arts_Player/Characters/Animation/Base_AnimBP/Feature/CH_ABP_Parachute.CH_ABP_Parachute")
  local uAnimInstances = uCharacter.Mesh:GetSubAnimInstances()
  print(bWriteLog and "CharacterBase:TryCacheParachuteAnim. uAnimInstances = " % tostring(uAnimInstances))
  if uAnimInstances and uAnimInstances.Num then
    local num = uAnimInstances:Num()
    print(bWriteLog and "CharacterBase:TryCacheParachuteAnim. num = " % tostring(num))
    for i = 1, num do
      local uAnimInst = uAnimInstances:Get(i * 1)
      print(bWriteLog and "CharacterBase:TryCacheParachuteAnim. uAnimInst = " % tostring(uAnimInst))
      if slua.isValid(uAnimInst) and Game:IsClassOf(uAnimInst, CH_ABP_Parachute_Class) and uAnimInst.CacheParachuteAnimVars ~= nil then
        print(bWriteLog and "CharacterBase:TryCacheParachuteAnim. CacheParachuteAnimVars")
        uAnimInst:CacheParachuteAnimVars(true)
        break
      end
    end
  end
end

function CharacterBase:GetBroadcastFatalDamageExpandData(uCauserPawn, uVictimPawn, RealKiller, DamageType, CauserWeaponAvatarID)
  local expandDataStr = ""
  local expandDataTable = self:GetBroadcastFatalDamageExpandDataForLua(uCauserPawn, uVictimPawn)
  if SubsystemMgr then
    local FatalDamageExpandDataSubsystem = SubsystemMgr:Get("FatalDamageExpandDataSubsystem")
    if FatalDamageExpandDataSubsystem then
      expandDataTable = FatalDamageExpandDataSubsystem:GetBroadcastFatalDamageExpandData(uCauserPawn, uVictimPawn, expandDataTable, RealKiller, DamageType)
    end
  end
  expandDataTable = expandDataTable or {}
  expandDataTable.CauserWeaponAvatarID = CauserWeaponAvatarID or 0
  if expandDataTable ~= nil then
    expandDataStr = slua.LuaArchiverEncode(LuaStateWrapper, expandDataTable)
  end
  local ASTExtraBaseCharacter = import("/Script/ShadowTrackerExtra.STExtraBaseCharacter")
  ASTExtraBaseCharacter.SetExpandDataContent(expandDataStr)
  return expandDataStr
end

function CharacterBase:GetBroadcastFatalDamageExpandDataForLua(uCauserPawn, uVictimPawn)
  local expandDataTable = {}
  if uVictimPawn and slua.isValid(uVictimPawn) then
    expandDataTable.bHaveSelfRescueItem = false
    local PlayerState = uVictimPawn:GetPlayerStateSafety()
    if PlayerState and slua.isValid(PlayerState) then
      if PlayerState.CheckCanSelfRescue then
        PlayerState:CheckCanSelfRescue()
      else
        print(bWriteLog and "CharacterBase:GetBroadcastFatalDamageExpandDataForLua, have no function CheckCanSelfRescue, PlayerKey = " % tostring(uVictimPawn.PlayerKey))
      end
    else
      print(bWriteLog and "CharacterBase:GetBroadcastFatalDamageExpandDataForLua, PlayerState = " % tostring(uVictimPawn.PlayerKey))
    end
    local CurrentValue = uVictimPawn:GetAttrValue("bCanSelfRescue")
    print(bWriteLog and "CharacterBase:GetBroadcastFatalDamageExpandDataForLua, CurrentValue = " % tostring(uVictimPawn.PlayerKey))
    if 0 < CurrentValue then
      expandDataTable.bHaveSelfRescueItem = true
    end
  end
  return expandDataTable
end

function CharacterBase:ServerCheckEmoteCanPlay(EmoteID)
  if not self:CheckEmoteBanTable(EmoteID) then
    print(bWriteLog and "CharacterBase ServerCheckEmoteCanPlay EmoteIsBan" % tostring(EmoteID))
    return false
  end
  local logic_emote = require("GameLua.Mod.Library.GamePlay.Avatar.Emote.logic_emote")
  if logic_emote.CheckIsDanceTogetherEmote(EmoteID) then
    local EmoteSubSystem = SubsystemMgr:Get("EmoteSubSystem")
    if not EmoteSubSystem:IsInPreListOrDanceList(self.Object) then
      print(bWriteLog and "CharacterBase ServerCheckEmoteCanPlay not in DanceList")
      return false
    end
  end
  return true
end

function CharacterBase:UpdateEmoteExtraInfo(EmoteID, ExtraInfo)
  if EmoteID == 12220605 then
    math.randomseed(os.time())
    local randomNumber = math.random(0, 99)
    return tostring(randomNumber)
  end
  return ExtraInfo
end

function CharacterBase:CheckEmoteBanTable(EmoteID)
  local EmoteData = CDataTable.GetTableData("BattleBanOnEmote", EmoteID)
  if not EmoteData then
    return true
  end
  local uGameState = GameplayData.GetGameState()
  if not slua.isValid(uGameState) or not uGameState.GetGameModeState then
    return true
  end
  if uGameState:GetGameModeState() ~= "ReadyState" then
    return false
  end
  return true
end

function CharacterBase:ReportExceptionOnVehicle(Type, Msg)
  local ErrorMsg = string.format("VehicleException Type:%s, Msg:%s\n", Type, Msg)
  if Client then
    local ClientToolsReport = require("client.slua.logic.report.ClientToolsReport")
    ClientToolsReport:SendReport(ClientToolsReport.Enum_SvrReport_Type.Enum_Vehicle, ErrorMsg)
  end
  if LogExceptionAndReport ~= nil then
    LogExceptionAndReport(ErrorMsg)
    LogExceptionAndReport(ErrorMsg)
  end
end

function CharacterBase:PlayLevelSequenceByPath(SequenceActorPath, LevelSequencePath, TimeOffset)
  print(bWriteLog and Game:GetPlainName(self), "CharacterBase:PlayLevelSequenceByPath", SequenceActorPath, LevelSequencePath, TimeOffset)
  return self:PlayLevelSequenceInternal(SequenceActorPath, LevelSequencePath, nil, TimeOffset)
end

function CharacterBase:PlayLevelSequenceByPathAndBindingInfo(SequenceActorPath, LevelSequencePath, TrackBindingInfo, TimeOffset)
  print(bWriteLog and Game:GetPlainName(self), "CharacterBase:PlayLevelSequenceByPathAndBindingInfo", SequenceActorPath, LevelSequencePath, TrackBindingInfo:Num(), TimeOffset)
  return self:PlayLevelSequenceInternal(SequenceActorPath, LevelSequencePath, TrackBindingInfo, TimeOffset)
end

function CharacterBase:PlayLevelSequenceInternal(SequenceActorPath, LevelSequencePath, TrackBindingInfo, TimeOffset)
  if TimeOffset == nil then
    TimeOffset = 0
  end
  if self.CurrentLevelSequence then
    self:StopCurrentLevelSequence()
  end
  local SequenceTransform = FTransform()
  SequenceTransform:SetLocation(self:K2_GetActorLocation())
  local LevelSeqActor = Game:PlayLevelSequence(self, LevelSequencePath, SequenceTransform, SequenceActorPath, false)
  if not slua.isValid(LevelSeqActor) then
    print(bWriteLog and "CharacterBase:PlayLevelSequenceInternal Error")
    return false
  end
  LevelSeqActor:SetOwner(self)
  if LevelSeqActor.SetMetaData then
    LevelSeqActor:SetMetaData(TrackBindingInfo, TimeOffset)
  end
  print(bWriteLog and "CharacterBase:PlayLevelSequenceInternal", Game:GetPlainName(self), Game:GetPlainName(LevelSeqActor), Game:GetPlainName(LevelSeqActor:GetOwner()))
  self.CurrentLevelSequence = LevelSeqActor
  return true
end

function CharacterBase:StopCurrentLevelSequence()
  if self.CurrentLevelSequence then
    print(bWriteLog and "CharacterBase:StopCurrentLevelSequence", Game:GetPlainName(self.CurrentLevelSequence))
    if slua.isValid(self.CurrentLevelSequence) then
      self.CurrentLevelSequence:StopMontageParticle("DirectorSequence")
      self.CurrentLevelSequence:K2_DestroyActor()
    end
    self.CurrentLevelSequence = nil
  end
end

function CharacterBase:GetCurrentLevelSequenceActor()
  if not slua.isValid(self.CurrentLevelSequence) then
    return nil
  end
  return self.CurrentLevelSequence
end

function CharacterBase:OnLevelSequenceStop(StopType)
  print(bWriteLog and "CharacterBase:OnLevelSequenceStop", StopType)
  if self.CurrentLevelSequence then
    self.CurrentLevelSequence = nil
  end
end

function CharacterBase:HandleCharacterFallingModeChange(bFalling)
  if bFalling then
    return
  end
  if not slua.isValid(self.Object) then
    return
  end
  local uSkillManager = self:GetSkillManager()
  if not slua.isValid(uSkillManager) then
    return
  end
  if slua.isValid(self.Object) then
    self:AddGameTimer(0.05, false, function()
      if self.GetCurSkill then
        local uCurSkill = self:GetCurSkill()
        if slua.isValid(uCurSkill) and uSkillManager:IsCastingSkillID(1000001) and uSkillManager:GetSkillCurPhase(uCurSkill) == 1 then
          local UGameplayStatics = import("GameplayStatics")
          local CurTime = UGameplayStatics.GetRealTimeSeconds(CGameWorld)
          if CurTime * self.LastPlayFallSoundTime > 0.7 then
            print(bWriteLog and "CharacterBase:HandleCharacterFallingModeChange Do PlayFootstepSound deltatime: " % tostring(self.LastPlayFallSoundTime))
            self:PlayFootstepSound(4)
          end
        end
      end
    end)
  end
end

function CharacterBase:PlayFootstepSound(eFootStepState)
  self.Super:PlayFootstepSound(eFootStepState)
  if not Client then
    return
  end
  EventSystem:postEvent(EVENTTYPE_PLAYEREVENT_CHARACTER, EVENTTYPE_PLAYEREVENT_CHARACTER_FOOTSTEP_SOUND, self.Object)
end

function CharacterBase:OnRep_bCableCarView()
  self:SwitchFreeView(self.bCableCarView)
end

function CharacterBase:SwitchFreeView(bEnable)
  if not slua.isValid(self.Object) then
    return
  end
  print(bWriteLog and "CableCar:SwitchToFreeView:", self.Object, bEnable)
  local uSpringArmComp = self.SpringArmComp
  if bEnable then
    self.bFreeView = true
    self.bUseControllerRotationYaw = false
    if slua.isValid(uSpringArmComp) then
      uSpringArmComp.bForceUseTargetArmLength = true
      uSpringArmComp.TargetArmLength = 890
    end
  else
    self.bFreeView = false
    self.bUseControllerRotationYaw = true
    if slua.isValid(uSpringArmComp) then
      uSpringArmComp.bForceUseTargetArmLength = false
      uSpringArmComp.TargetArmLength = 220
    end
  end
end

function CharacterBase:IsEnableFollowPlayEmote()
  return LobbySystem.CheckOpen(BP_ENUM_DANCE_FOLLOW_SWITCH)
end

function CharacterBase:IsInteractiveExpression(EmoteID)
  local ItemCfg = CDataTable.GetTableData("Item", EmoteID)
  if ItemCfg and ItemCfg.ItemSubType == 2205 then
    return true
  end
  return false
end

function CharacterBase:CheckCanFollowPlayEmote(EmoteId)
  if not EmoteId or EmoteId == 0 then
    print(bWriteLog and "CharacterBase:CheckCanFollowPlayEmote Can`t Play EmoteId" % tostring(EmoteId))
    return false
  end
  local FollowEmoteCfg = CDataTable.GetTableData("FollowEmoteCfg", EmoteId)
  if FollowEmoteCfg and FollowEmoteCfg.CanPlay == 0 then
    print(bWriteLog and "CharacterBase:CheckCanFollowPlayEmote No CanPlay" % tostring(FollowEmoteCfg.TipsID))
    local TipsID = 44697
    if FollowEmoteCfg.TipsID and FollowEmoteCfg.TipsID ~= 0 then
      TipsID = FollowEmoteCfg.TipsID
    end
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:DisplayGameTipWithMsgID(TipsID)
    end
    return false
  end
  if self:IsInteractiveExpression(EmoteId) then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:DisplayGameTipWithMsgID(44697)
    end
    print(bWriteLog and "CharacterBase:CheckCanFollowPlayEmote IsInteractiveExpression" % tostring(EmoteId))
    return false
  end
  local logic_emote = require("GameLua.Mod.Library.GamePlay.Avatar.Emote.logic_emote")
  if logic_emote.IsMileStoneEmote(EmoteId) then
    return false
  end
  if logic_emote.IsCustomWeaponShow(EmoteId) then
    return false
  end
  return true
end

function CharacterBase:ClearFollowEmote()
  if self:IsAutonomousProxy() then
    print(bWriteLog and "CharacterBase:ClearFollowEmote")
    if self.GetPlayerControllerSafety then
      local Controller = self:GetPlayerControllerSafety()
      if slua.isValid(Controller) then
        Controller.OnShowFollowEmoteDelegate:BroadCast(false)
      end
    end
  end
  if self.ClearEmotePlayer then
    self:ClearEmotePlayer()
  end
end

function CharacterBase:ClearAkEventSound()
  local UAkGameplayStatics = import("AkGameplayStatics")
  local EAttachLocation = import("EAttachLocation")
  local Location = FVector(0, 0, 0)
  if slua.isValid(self.RootComponent) and EAttachLocation and Location then
    local uAkComponent = UAkGameplayStatics.GetAkComponent(self.RootComponent, "", Location, EAttachLocation.KeepRelativeOffset)
    if slua.isValid(uAkComponent) then
      uAkComponent:Stop()
    end
  end
end

function CharacterBase:ShowEffectAfterSelfRescueSucceed()
end

function CharacterBase:ServerShowShowUIConfigUI(uiConfigName)
  print(bWriteLog and "CharacterBase:ServerShowShowUIConfigUI:" % uiConfigName)
  if not Client then
    return
  end
  local ENetRole = import("ENetRole")
  if UIManager.UI_Config_InGame[uiConfigName] and (self:IsLocalControlorView() or self:IsLocalViewed() or self.Role == ENetRole.ROLE_AutonomousProxy) then
    UIManager.ShowUI(UIManager.UI_Config_InGame[uiConfigName])
  end
end

function CharacterBase:ClientRPC_FailedToJoinDance(Reason)
  print(bWriteLog and "[DanceTogether] CharacterBase ClientRPC_FailedToJoinDance Reason" % tostring(Reason))
  ShowNotice(Reason)
end

function CharacterBase:ClientRPC_TryJoinDance(DanceActor, Index)
  print(bWriteLog and "[DanceTogether] CharacterBase ClientRPC_TryJoinDance Index:" % tostring(Index))
  if not slua.isValid(DanceActor) then
    print(bWriteLog and "[DanceTogether][Warning] CharacterBase ClientRPC_TryJoinDance DanceActor is not Valid")
    return
  end
  DanceActor:ClientTryJoinDance(self.Object, Index)
end

function CharacterBase:ClientRPC_ShowEffectAfterFruitBingo(ShakingAudioPath, SurpriseAudioPath, SurpriseTipsID)
  log(bWriteLog and "CharacterBase:ClientRPC_ShowEffectAfterFruitBingo, Bingo in Interaction of Fruit!")
  if SurpriseTipsID and 0 < SurpriseTipsID then
    IngameTipsTools.BattleGeneralTip(SurpriseTipsID)
  end
  local audio_util = require("client.common.audio_util")
  if ShakingAudioPath and ShakingAudioPath ~= "" then
    audio_util.PlayAudioByActorAsync(ShakingAudioPath, self.Object)
  end
  if SurpriseAudioPath and SurpriseAudioPath ~= "" then
    audio_util.PlayAudioByActorAsync(SurpriseAudioPath, self.Object)
  end
end

function CharacterBase:ClientRPC_PlayMontageCamera(LookAtLocation, Radius, Time, CallbackName)
  print(bWriteLog and "CharacterBase:ClientRPC_PlayMontageCamera, LookAtLocation:" % Radius, " Time:" % CallbackName)
  local MontageCameraSubsystem = SubsystemMgr:Get("MontageCameraSubsystem")
  if MontageCameraSubsystem then
    if CallbackName and CallbackName ~= "" and self[CallbackName] and type(self[CallbackName]) == "function" then
      MontageCameraSubsystem:Play(LookAtLocation, Radius, Time, self[CallbackName])
    else
      MontageCameraSubsystem:Play(LookAtLocation, Radius, Time)
    end
  end
end

function CharacterBase:OnPlayMontageCameraCallback()
  print(bWriteLog and "CharacterBase:OnPlayMontageCameraCallback" % self.Object)
end

function CharacterBase:ServerRPC_FailPreJoinDance(DanceActor)
  print(bWriteLog and "[DanceTogether] CharacterBase ServerRPC_FailPreJoinDance")
  if not slua.isValid(DanceActor) then
    print(bWriteLog and "[DanceTogether][Warning] CharacterBase ServerRPC_FailPreJoinDance DanceActor is not Valid")
    return
  end
  DanceActor:ServerFailPreJoinDance(self.Object)
end

function CharacterBase:CheckEmoteNeedUseReliableRPC(EmoteIndex)
  local Controller = self:GetPlayerControllerSafety()
  if slua.isValid(Controller) and Controller.PlayEmoteFeature and Controller.PlayEmoteFeature:CheckNeedReliable(EmoteIndex) then
    print(bWriteLog and "CharacterBase:CheckEmoteNeedUseReliableRPC", EmoteIndex)
    return true
  end
  return false
end

function CharacterBase:RegisteAirControlResumEvent(OldAirControl)
  self:AddControlEvent(self, "OnMovementBaseChanged", function(_, Character, NewMovementBase, OldMovementBase)
    if not slua.isValid(NewMovementBase) then
      print(bWriteLog and "CharacterBase:RegisteAirControlResumEvent NewMovementBase Is Not Valid")
      return
    end
    local CharacterMovement = self.STCharacterMovement
    if not slua.isValid(CharacterMovement) then
      print(bWriteLog and "CharacterBase:RegisteAirControlResumEvent Is Not Valid")
      return
    end
    CharacterMovement.AirControl = OldAirControl
    local bResult = self:RemoveControlEvent(self, "OnMovementBaseChanged")
    print(bWriteLog and "CharacterBase:RegisteAirControlResumEvent RemoveControlEvent ", bResult)
    print(bWriteLog and "CharacterBase:RegisteAirControlResumEvent AirControl is ", CharacterMovement.AirControl)
  end, self)
end

function CharacterBase:ReplaceGrenadeSkills()
  local SkillReplaceConfig = GamePlayTools.GetCurrentConfig("SkillReplaceConfig")
  local uSkillMgr = self:GetSkillManager()
  if slua.isValid(uSkillMgr) and SkillReplaceConfig and SkillReplaceConfig.ReplaceSkill then
    for sourceSkill, NewSkill in pairs(SkillReplaceConfig.ReplaceSkill) do
      uSkillMgr:ReplaceSkill(sourceSkill, NewSkill)
      print(bWriteLog and "CharacterBase:SkillReplaceConfig NewSkill")
    end
  end
end

function CharacterBase:GetGrenadeKillBindGunIDByPC(KillerPC, GrenadeID)
  if Client then
    print(bWriteLog and "CharacterBase:GetGrenadeKillBindGunID Not In Ds")
    return 0
  end
  if not slua.isValid(KillerPC) then
    print(bWriteLog and "CharacterBase:GetGrenadeKillBindGunID KillerPC Not Valid")
    return 0
  end
  local ExtendAttribute = require("Server.config.ExtendAttribute")
  local PlayerDataMgr = require("Server.Data.ServerPlayerDataMgr")
  local GrenadeBindInfo = PlayerDataMgr.GetPlayerProgressFromServer(KillerPC.UID, ExtendAttribute.GrenadeBindWeaponMap)
  if not GrenadeBindInfo then
    print(bWriteLog and "CharacterBase:GetGrenadeKillBindGunID GrenadeBindInfo Nil ")
    return 0
  end
  if GrenadeBindInfo[GrenadeID] ~= nil then
    return GrenadeBindInfo[GrenadeID]
  end
  print(bWriteLog and "CharacterBase:GetGrenadeKillBindGunID Not in GrenadeBindInfo")
  return 0
end

function CharacterBase:CheckIsValidXSuitBornIslandAction(EmoteID)
  local XSuitUtil = require("GameLua.Activity.Commercialize.GamePlay.XSuit.XSuitUtil")
  local uPlayerController = self:GetPlayerControllerSafety()
  if not slua.isValid(uPlayerController) or not uPlayerController.CommerFeature then
    return false
  end
  local uAvatarComp2 = self:getAvatarComponent2()
  if not slua.isValid(uAvatarComp2) then
    return false
  end
  local AvatarItem = uAvatarComp2:GetEquippedItemDefineID(EAvatarSlotType.EAvatarSlotType_ClothesEquipemtSlot)
  if XSuitUtil:GetBornIslandActionByItemID(AvatarItem.TypeSpecificID, uAvatarComp2) ~= EmoteID then
    return false
  end
  local Period = XSuitUtil:GetPeriodByBattleActionID(EmoteID)
  if Period and 0 < Period then
    local UnLockLevel = XSuitUtil:GetUnLockLevelByFeature(AvatarItem.TypeSpecificID, Period, uPlayerController.CommerFeature.XSuitUnlockLevelList)
    local bValid = XSuitUtil:IsValidBornIslandAction(EmoteID, UnLockLevel)
    print(bWriteLog and "CharacterBase:CheckIsValidXSuitBornIslandAction bValid=" % tostring(UnLockLevel))
    if not bValid then
      return false
    end
  end
  return true
end

function CharacterBase:CheckIsValidEmoteIDBP(EmoteID)
  print(bWriteLog and "CharacterBase:CheckIsValidEmoteIDBP", EmoteID)
  local IsValid = false
  local Controller = self:GetPlayerControllerSafety()
  if slua.isValid(Controller) and Controller.PlayEmoteFeature then
    IsValid = Controller.PlayEmoteFeature:CheckIsValidEmoteIDBP(EmoteID)
  end
  if not IsValid and self.CoopEmoteCharFeature then
    IsValid = self.CoopEmoteCharFeature:CheckIsValidEmoteIDBP(EmoteID)
  end
  return IsValid
end

function CharacterBase:IsCoopEmote(EmoteId, CoopPhase)
  if self.CoopEmoteCharFeature then
    return self.CoopEmoteCharFeature:IsCoopEmote(EmoteId, CoopPhase)
  end
  return false
end

function CharacterBase:ShouldCheckCoopEmote()
  if self.CoopEmoteCharFeature then
    return self.CoopEmoteCharFeature:ShouldCheckCoopEmote()
  end
  return false
end

function CharacterBase:ShouldShowCoopEmoteBtn(EmotePlayer)
  if self.CoopEmoteCharFeature then
    return self.CoopEmoteCharFeature:ShouldShowCoopEmoteBtn(EmotePlayer)
  end
  return false
end

function CharacterBase:RPC_Client_OnCoopEmotePhaseChange(CoopPhase)
  if self.CoopEmoteCharFeature then
    self.CoopEmoteCharFeature:HandleClientOnCoopEmotePhaseChange(CoopPhase)
  end
end

function CharacterBase:RPC_Server_JoinCoopEmote(EmotePlayer)
  local CasterPlayerKey = EmotePlayer.PlayerKey
  if not CasterPlayerKey then
    return
  end
  local CoopEmoteSubSystem = SubsystemMgr:Get("CoopEmoteSubSystem")
  if not CoopEmoteSubSystem:HasCaster(CasterPlayerKey) then
    print(bWriteLog and "CharacterBase:RPC_Server_JoinCoopEmote Caster not found " % tostring(CasterPlayerKey))
    return
  end
  self.Super:RPC_Server_JoinCoopEmote(EmotePlayer)
end

function CharacterBase:ServerOnCoopEmotePhaseChange(CoopPhase)
  if self.CoopEmoteCharFeature then
    self.CoopEmoteCharFeature:HandleServerOnCoopEmotePhaseChange(CoopPhase)
  end
end

function CharacterBase:CheckInPhotoGrapherMode()
  local PhotoGrapherSubSystem = SubsystemMgr:Get("PhotoGrapherSubSystem")
  if PhotoGrapherSubSystem and PhotoGrapherSubSystem.bIsPhotoGrapherMode then
    return true
  end
  return false
end

function CharacterBase:ReportCharacterState()
  if not slua.isValid(self.Object) then
    return
  end
  local uPlayerController = self:GetPlayerControllerSafety()
  if not slua.isValid(uPlayerController) then
    return
  end
  print(bWriteLog and "CharacterBase:ReportCharacterState")
  if uPlayerController.ReportCharacterStateData then
    uPlayerController:ReportCharacterStateData()
  end
end

function CharacterBase:ParseServiceDebugInfo(BasicInfoKeys, DetailInfoKeys)
  if BasicInfoKeys == nil then
    return
  end
  print(bWriteLog and string.format("CharacterBase:ParseServiceDebugInfo ignore Info, PlayerKey=%s,self.EnsureStyle=%s", tostring(self.PlayerKey), tostring(self.EnsureStyle)))
  local StringUtil = require("common.string_util")
  local InfoMap = {}
  local SpeedStr = string.format("%.3f/%.3f", self:GetVelocity():Size(), self.CharacterMovement.MaxWalkSpeed)
  local PlayerStates = ""
  for i = 0, EPawnState.__MAX do
    if self:HasState(i) then
      PlayerStates = PlayerStates % ","
    end
  end
  if BasicInfoKeys and BasicInfoKeys:Num() < 3 then
    local AIDebugInfoConfig = require("GameLua.Mod.BaseMod.DS.AI.AIDebugInfoConfig")
    if AIDebugInfoConfig and AIDebugInfoConfig[2] then
      for _, KeysStr in pairs(AIDebugInfoConfig[2]) do
        BasicInfoKeys:Add(KeysStr)
      end
    end
  end
  InfoMap.Level = tostring(self.EnsureLevel)
  InfoMap.Key = tostring(self:GetPlayerKey())
  InfoMap.TeamID = tostring(self.TeamID)
  InfoMap.HP = string.format("%d/%d", math.floor(self.Health), math.floor(self.HealthMax))
  InfoMap.NearDeathBreath = string.format("%.2f", self.NearDeathBreath)
  InfoMap.FreeCamera = tostring(self.SimulateViewData.FreeCamera)
  InfoMap.Speed = SpeedStr
  InfoMap.State = PlayerStates
  InfoMap.Location = self:K2_GetActorLocation():ToString()
  InfoMap.Rotation = self:K2_GetActorRotation():ToString()
  InfoMap.MLAIStyle = tostring(self.MLEnsureStyle)
  InfoMap.TeamInstantiated = tostring(self.TeamInstantiated)
  if self.TeleportID then
    InfoMap.TeleportID = tostring(self.TeleportID)
  end
  if self.TargetUID_Debug then
    InfoMap.Target = tostring(self.TargetUID_Debug)
  end
  local uPlayerController = GameplayData.GetPlayerController()
  if uPlayerController and slua.isValid(uPlayerController) and slua.isValid(self.Object) then
    local ViewTarget = uPlayerController:GetViewTarget()
    if ViewTarget and slua.isValid(ViewTarget) then
      InfoMap.Distance = string.format("%.0f", _UPVALUE11_)
    end
  end
  if self.DebugAIInfoTable then
    for InfoKey, InfoValue in pairs(self.DebugAIInfoTable) do
      InfoMap[InfoKey] = InfoValue
    end
  end
  local bHaveEnsureStyle = false
  local DebugInfoArray = StringUtil.Split(self.BehaviorServiceDebugInfo, ";")
  local ExtraInfo = ""
  for index, InfoStr in ipairs(DebugInfoArray) do
    local InfoSplit = StringUtil.Split(InfoStr, "=")
    if not InfoSplit or not InfoSplit[2] then
      ExtraInfo = ExtraInfo % "\n"
    elseif Game:Contains(DetailInfoKeys, InfoSplit[1]) and string.find(InfoSplit[2], "=") then
      local InfoSplit2 = StringUtil.Split(InfoSplit[2], "=")
      DetailInfoKeys:Add(InfoSplit2[1])
      InfoMap[InfoSplit2[1]] = InfoSplit2[2]
    else
      InfoMap[InfoSplit[1]] = InfoSplit[2]
      if InfoSplit[1] == "EnsureStyle" then
        self.EnsureStyle = tonumber(InfoSplit[2])
        bHaveEnsureStyle = true
      end
      if bHaveEnsureStyle == false and self.EnsureStyle > 0 and InfoSplit[1] == "ResID" then
        self.EnsureStyle = 0
      end
    end
  end
  local AIType = "CommonAI"
  if self.EnsureStyle == 4 then
    AIType = "CommonAI_Advance"
  elseif self.EnsureStyle == 1 then
    AIType = "MLAI"
  elseif self.EnsureStyle == 2 then
    AIType = "MLAI_Delivery"
  elseif self.EnsureStyle == 3 then
    AIType = "MLAI_Teammate"
  elseif self.EnsureStyle == 5 then
    AIType = "MLAI_Humanoid"
  end
  InfoMap.Type = AIType
  self.ServiceDebugInfoForShow = ""
  local FinnalStr = ""
  local TempStr = ""
  for index, Keys in pairs(BasicInfoKeys) do
    local KeysArr = StringUtil.Split(Keys, ";")
    local EmptyLine = true
    for _, Key in ipairs(KeysArr) do
      if InfoMap[Key] then
        TempStr = string.format("[%s=%s]", Key, InfoMap[Key])
        EmptyLine = false
        FinnalStr = FinnalStr % TempStr
      end
    end
    if not EmptyLine then
      FinnalStr = FinnalStr % "\n"
    end
  end
  FinnalStr = FinnalStr % "::"
  for _, Keys in pairs(DetailInfoKeys) do
    local KeysArr = StringUtil.Split(Keys, ";")
    local EmptyLine = true
    for _, Key in ipairs(KeysArr) do
      if InfoMap[Key] then
        TempStr = string.format("[%s=%s]", Key, InfoMap[Key])
        EmptyLine = false
        FinnalStr = FinnalStr % TempStr
      end
    end
    if not EmptyLine then
      FinnalStr = FinnalStr % "\n"
    end
  end
  FinnalStr = FinnalStr % ExtraInfo
  self.ServiceDebugInfoForShow = FinnalStr
end

function CharacterBase:SetMLEnsureStyle(InMLStyle)
  local DebugLastMLEnsureStyle_DS = string.format("%d_%.1f", self.MLEnsureStyle, CGameState:GetServerWorldTimeSeconds())
  self:AddDebugAIInfoTable("LastMLAIStyle", DebugLastMLEnsureStyle_DS)
  self.MLEnsureStyle = InMLStyle
  self:DSSetCharacterIntPropertyForReplay("MLEnsureStyle", InMLStyle)
  print(bWriteLog and string.format("ASTExtraBaseCharacter::SetMLEnsureStyle:%s %d", self:GetPlayerNameSafety(), InMLStyle))
end

function CharacterBase:SetMLEnsureExtraInfo(InMLEnsureExtraInfo)
  self:AddDebugAIInfoTable("MLExtraInfo", InMLEnsureExtraInfo)
  self.MLEnsureExtraInfo = InMLEnsureExtraInfo
  self:DSSetCharacterStringPropertyForReplay("MLEnsureExtraInfo", InMLEnsureExtraInfo)
  print(bWriteLog and string.format("ASTExtraBaseCharacter::SetMLEnsureExtraInfo:%s %s", self:GetPlayerNameSafety(), InMLEnsureExtraInfo))
end

function CharacterBase:GetBodyPartOffset(nBodyPart, CurrentState, nHasWeapon, nPeekState)
  local StaticBodyOffsetData = require("GameLua.Mod.Library.GamePlay.AI.StaticBodyOffsetData")
  local OffsetData = {
    0,
    0,
    0
  }
  nHasWeapon = nHasWeapon - 1
  nPeekState = nPeekState - 1
  if StaticBodyOffsetData[CurrentState] and StaticBodyOffsetData[CurrentState][nHasWeapon] and StaticBodyOffsetData[CurrentState][nHasWeapon][nPeekState] then
    OffsetData = StaticBodyOffsetData[CurrentState][nHasWeapon][nPeekState][nBodyPart] or OffsetData
  else
    print(bWriteLog and string.format("ASTExtraBaseCharacter::GetHeadPosition StaticBodyOffsetData is nil CurrentState=%d nHasWeapon=%d nPeekState=%d", CurrentState, nHasWeapon, nPeekState))
  end
  return FVector(OffsetData[1], OffsetData[2], OffsetData[3])
end

function CharacterBase:BlueprintSetServiceDebugInfo(Info)
  if self.DebugAIInfoTable then
    for _, InfoData in pairs(self.DebugAIInfoTable) do
      Info = Info % InfoData
    end
  end
  return Info
end

function CharacterBase:AddDebugAIInfoTable(Key, StringInfo)
  if not self.DebugAIInfoTable then
    self.DebugAIInfoTable = {}
  end
  if Client then
    if Key and StringInfo then
      self.DebugAIInfoTable[Key] = StringInfo
    end
  else
    local ServerStringInfo = string.format("%s=%s;", Key, StringInfo)
    self.DebugAIInfoTable[Key] = ServerStringInfo
  end
end

function CharacterBase:InitIceDecalQueue(MaxNum)
  self.IceDecalQueue = {}
  self.MaxIceDecalQueue = 2 < MaxNum and math.floor(MaxNum) or 2
  self.IceDecalQueuePtr = 0
  for i = 1, self.MaxIceDecalQueue do
    table.insert(self.IceDecalQueue, false)
  end
end

function CharacterBase:EnqueueIceDecal(uIceDecalActor)
  if not slua.isValid(uIceDecalActor) then
    return
  end
  if self.IceDecalQueue == nil then
    self:InitIceDecalQueue(3)
  end
  local CurInsertIdx = self.IceDecalQueuePtr - 1
  if self.IceDecalQueue[CurInsertIdx] and slua.isValid(self.IceDecalQueue[CurInsertIdx]) then
    local uOldActor = self.IceDecalQueue[CurInsertIdx]
    if slua.isValid(uOldActor) then
      uOldActor:K2_DestroyActor()
    end
  end
  self.IceDecalQueue[CurInsertIdx] = uIceDecalActor
  self.IceDecalQueuePtr = true
end

function CharacterBase:BP_ResetDataOnRespawn()
  print(bWriteLog and "CharacterBase BP_ResetDataOnRespawn")
  EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_INGAME_ON_RESET_DATA_ON_RESPAWN, self.Object)
end

function CharacterBase:ToString()
  return string.format("%s(%s)", self.PlayerName, self.PlayerKey)
end

function CharacterBase:LuaTriggerEntrySkillWithID(SkillID, bEnable)
  if not self.bClientCanTriggerSkill then
    printf("LuaTriggerEntrySkillWithID PlayerKey:%u not self.bClientCanTriggerSkill", self.PlayerKey)
    return
  end
  if self.CharacterUltraHandRepFeature and not self.CharacterUltraHandRepFeature:CanUseUltraHand() then
    printf("LuaTriggerEntrySkillWithID PlayerKey:%u not CanUseUltraHand", self.PlayerKey)
    return
  end
  self:TriggerEntrySkillWithID(SkillID, bEnable)
end

function CharacterBase:SetClientCanTriggerSkill(bCanTriggerSkill)
  self.bClientCanTriggerSkill = bCanTriggerSkill
end

function CharacterBase:SetClothMeshForceLod(bEnable)
  if not self.getAvatarComponent2 then
    return
  end
  local AvatarComp = self:getAvatarComponent2()
  if slua.isValid(AvatarComp) then
    local EAvatarSlotType = import("EAvatarSlotType")
    AvatarComp:SetForceMeshLod(EAvatarSlotType.EAvatarSlotType_ClothesEquipemtSlot, bEnable)
  end
end

function CharacterBase:InitAddSpecialMoveInfo()
  print(bWriteLog and "CharacterBase:InitAddSpecialMoveInfo")
  if not CGame then
    return
  end
  local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
  local SpecialMoveConfig = GamePlayTools.GetCurrentConfig("SpecialMoveConfig")
  if not SpecialMoveConfig then
    return
  end
  for key, value in pairs(SpecialMoveConfig.SpecialMoveObjPathInfos) do
    if type(value) == "string" then
      local ObjMovementC = CGame:LoadOjectFromPath(value)
      if ObjMovementC then
        local ObjMovement = CGame:NewObjectFromClass(self, ObjMovementC, "None")
        if ObjMovement and ObjMovement.SpecialMoveSetCharacterOwner then
          ObjMovement:SpecialMoveSetCharacterOwner(self)
          if slua.isValid(self.STCharacterMovement) then
            self.STCharacterMovement.SpecialObjes:Add(key, ObjMovement)
          end
        end
      end
    end
  end
  for key, value in pairs(SpecialMoveConfig.CustomMoveToSpecialMoveTypes) do
    if slua.isValid(self.STCharacterMovement) and type(value) == "number" then
      self.STCharacterMovement.CustomMoveModeToSpecialMoveType:Add(key, value)
    end
  end
  if SpecialMoveConfig.LuaCustomVariants then
    local ESpecialMovementTypeEnum = import("ESpecialMovementType")
    local LuaCustomMoveObj
    if slua.isValid(self.STCharacterMovement) then
      LuaCustomMoveObj = self.STCharacterMovement:GetSpecialMoveObjBySpecialMoveType(ESpecialMovementTypeEnum.SPECIAL_MOVE_LuaCustom)
    end
    if LuaCustomMoveObj and LuaCustomMoveObj.RegisterParamSetVariants then
      LuaCustomMoveObj:RegisterParamSetVariants(SpecialMoveConfig.LuaCustomVariants)
    end
  end
  print(bWriteLog and "CharacterBase:InitAddSpecialMoveInfo over")
end

function CharacterBase:AddSpecialMoveInfo(SpecialMovementType, SpecialMovementObj)
  print(bWriteLog and "CharacterBase:AddSpecialMoveInfo:" % tostring(SpecialMovementType))
  SpecialMovementObj:SpecialMoveSetCharacterOwner(self)
  if slua.isValid(self.STCharacterMovement) then
    self.STCharacterMovement.SpecialObjes:Add(SpecialMovementType, SpecialMovementObj)
  end
end

function CharacterBase:OnPlayerKeyRepExt()
  print(bWriteLog and "CharacterBase:OnPlayerKeyRepExt", self.PlayerKey)
  EventSystem:postEvent(EVENTTYPE_PLAYEREVENT_CHARACTER, EVENTID_PLAYEREVENT_PLAYERKEY_CHANGE, self.Object)
end

function CharacterBase:OnMovementActivated()
end

function CharacterBase:HandleOnResolvePenetrationDelegate(bResolve, OldLoc, NewLoc)
  if bResolve then
    local Actor_C = import("/Script/Engine.Actor")
    local Character_C = import("/Script/Engine.Character")
    local ASTExtraVehicleBase_C = import("STExtraVehicleBase")
    local ASTExtraWeapon_C = import("STExtraWeapon")
    local FHitResult = import("/Script/Engine.HitResult")
    local uIgnoreActorArray = slua.Array(UEnums.EPropertyClass.Object, Actor_C)
    uIgnoreActorArray:Add(self.Object)
    local uWeapon = self:GetCurrentWeapon()
    if slua.isValid(uWeapon) then
      uIgnoreActorArray:Add(uWeapon)
    end
    local bIsPasswall = false
    local OutHits = slua.Array(UEnums.EPropertyClass.Struct, FHitResult)
    local HitResult = FHitResult()
    USTExtraBlueprintFunctionLibrary.TraceAllBlocks(OutHits, self.Object, OldLoc, NewLoc, HitResult, uIgnoreActorArray, false)
    printf(bWriteLog and "CharacterBase:HandleOnResolvePenetrationDelegate TraceAllBlocks PlayerKey:%u OldLoc:%s uNewLoc:%s", self.PlayerKey, OldLoc:ToString(), NewLoc:ToString())
    if OutHits:Num() > 0 then
      for Index, Hit in pairs(OutHits) do
        local uHitActor = Hit.Actor
        if slua.isValid(uHitActor) then
          if not uHitActor:ActorHasTag("IgnorePassWall") and not uHitActor:ActorHasTag("PenetrationIgnorePassWall") and not Game:IsClassOf(uHitActor, Character_C) and not Game:IsClassOf(uHitActor, ASTExtraVehicleBase_C) and not Game:IsClassOf(uHitActor, ASTExtraWeapon_C) then
            bIsPasswall = true
          else
            uIgnoreActorArray:Add(uHitActor)
          end
        end
      end
    end
    if bIsPasswall then
      local FResolvePenetrationParams = import("/Script/ShadowTrackerExtra.ResolvePenetrationParams")
      local ResolveParams = FResolvePenetrationParams()
      ResolveParams.AdjustRadius = 50
      ResolveParams.bLineTracePassWall = true
      local IgnoreNumIndex = uIgnoreActorArray:Num() * 1
      for i = 0, IgnoreNumIndex do
        slua.IndexReference(ResolveParams, "PassWallIgnoreActors"):Add(uIgnoreActorArray:Get(i))
      end
      self:SetActorLocationSafetyWithParams(OldLoc, ResolveParams)
      local uNewLoc = self:K2_GetActorLocation()
      printf(bWriteLog and "CharacterBase:HandleOnResolvePenetrationDelegate PlayerKey:%u uNewLoc:%s", self.PlayerKey, uNewLoc:ToString())
    end
  end
end

function CharacterBase:IsCastingSkillIDFix(InSkillID)
  if not self.GetSkillManager then
    print(bWriteLog and "CharacterBase:IsCastingSkillIDFix self.GetSkillManager is nil, return false")
    return false
  end
  local uSkillManager = self:GetSkillManager()
  if not slua.isValid(uSkillManager) then
    return false
  end
  return uSkillManager:IsCastingSkillID(InSkillID)
end

function CharacterBase:RefreshThermalImagingLocal()
  local GameplayData = require("GameLua.GameCore.Data.GameplayData")
  local uPlayerCharacter = GameplayData.GetPlayerCharacter()
  if slua.isValid(uPlayerCharacter) then
    local ESightVisionMask = import("ESightVisionMask")
    local ESightVisionType = import("ESightVisionType")
    if uPlayerCharacter:HasAnySightVision(ESightVisionMask.ThermalImagingScope) then
      local UGameplayStatics = import("GameplayStatics")
      local uGameInstance = UGameplayStatics.GetGameInstance(uPlayerCharacter)
      if slua.isValid(uGameInstance) then
        print(bWriteLog and "CharacterBase:RefreshThermalImagingLocal:", uGameInstance, uGameInstance:HasSightVision(ESightVisionType.ThermalImaging))
        uGameInstance:RefreshThermalImagingLocal(uPlayerCharacter)
      end
    end
  end
end

function CharacterBase:OnSplineMoveChanged(bEnter)
  print(bWriteLog and "CharacterBase:OnSplineMoveChanged, bEnter:" % tostring(bEnter))
  self:HandleEnableMoveLayer(bEnter)
end

function CharacterBase:HandleEnableMoveLayer(sEnable)
  local uAnimParamsComp = self:GetAnimParamsComponent()
  if not slua.isValid(uAnimParamsComp) then
    print(bWriteLog and "CharacterBase:HandleEnableMoveLayer uAnimParamsComp = nil")
    return
  end
  local bFPP = self:GetIsFPP()
  local uCharAnimInstance = self:GetCurrentMainLogicAnimInstance(bFPP)
  if slua.isValid(uCharAnimInstance) then
    if sEnable then
      local MoveInstanceClass = uAnimParamsComp:GetCustomizableAnimBP(uCharAnimInstance.FEATURE_MoveAnimInstanceID)
      if MoveInstanceClass then
        uAnimParamsComp:ActiveAnimContainerWithInstance("AC.Locomotion", MoveInstanceClass, false)
        print(bWriteLog and "CharacterBase:HandleEnableMoveLayer OnSplineMoveChanged, Actived MoveLayer.")
      end
    else
      uAnimParamsComp:ActiveAnimContainer("AC.Locomotion", true)
      print(bWriteLog and "CharacterBase:HandleEnableMoveLayer OnSplineMoveChanged, Deactive MoveLayer, ActiveAnim Locomotion")
    end
  end
end

function CharacterBase:SpawnEmitterEffect(RelativeLocation, PSRef, AttachParent, RelativeScale)
  local KismetMathLibrary = import("KismetMathLibrary")
  local uPlayerController = self:GetPlayerControllerSafety()
  if slua.isValid(uPlayerController) then
    local ScreenAppearanceStatics = import("ScreenAppearanceStatics")
    local uScreenAppearanceActor = ScreenAppearanceStatics.GetScreenAppearanceManager(uPlayerController)
    if slua.isValid(uScreenAppearanceActor) then
      local uBloodSpotProvider, sProviderName
      if self.BloodSpot_Red == PSRef then
        sProviderName = "BloodSpot_Red"
      else
        sProviderName = "BloodSpot_Green"
      end
      uBloodSpotProvider = uScreenAppearanceActor:PlayDefaultScreenAppearance(uPlayerController, sProviderName, nil)
      if slua.isValid(uBloodSpotProvider) then
        do
          local uTransform = KismetMathLibrary.MakeTransform(RelativeLocation, FRotator(0.0, 0.0, 90.0), RelativeScale)
          uBloodSpotProvider:UpdateRelativeTransform(uTransform)
          self.BloodScale = RelativeScale
          local EventDelegate = uBloodSpotProvider.AsyncLoadParticleComponentDone
          if slua.isValid(EventDelegate) and EventDelegate.Add then
            self._BloodSpotDelegateHandles = self._BloodSpotDelegateHandles or {}
            do
              local OldInfo = self._BloodSpotDelegateHandles[sProviderName]
              if OldInfo and OldInfo.Handle then
                local OldProvider = OldInfo.Provider
                if slua.isValid(OldProvider) then
                  local OldEventDelegate = OldProvider.AsyncLoadParticleComponentDone
                  if slua.isValid(OldEventDelegate) and OldEventDelegate.Remove then
                    OldEventDelegate:Remove(OldInfo.Handle)
                  else
                    slua.removeDelegate(OldInfo.Handle)
                  end
                else
                  slua.removeDelegate(OldInfo.Handle)
                end
                self._BloodSpotDelegateHandles[sProviderName] = nil
              end
              local DelegateHandle
              DelegateHandle = EventDelegate:Add(function(LoadedParticle)
                if DelegateHandle then
                  if slua.isValid(EventDelegate) and EventDelegate.Remove then
                    EventDelegate:Remove(DelegateHandle)
                  end
                  if self._BloodSpotDelegateHandles then
                    local CurInfo = self._BloodSpotDelegateHandles[sProviderName]
                    if CurInfo and CurInfo.Handle == DelegateHandle then
                      self._BloodSpotDelegateHandles[sProviderName] = nil
                    end
                  end
                  DelegateHandle = nil
                end
                if slua.isValid(LoadedParticle) and slua.isValid(self.Object) then
                  self:ChangeParticleEffect(LoadedParticle, self.BloodScale)
                end
              end)
              self._BloodSpotDelegateHandles[sProviderName] = {Provider = uBloodSpotProvider, Handle = DelegateHandle}
            end
          end
        end
      end
    end
  end
end

function CharacterBase:ChangeAllAvatarMaterialToFeatureMaterial(material)
  local uAvatarComp2 = self:getAvatarComponent2()
  if slua.isValid(uAvatarComp2) then
    uAvatarComp2:ChangeAllMeshToFeatureMaterial(material)
  end
  local WeaponManager = self:GetWeaponManager()
  if slua.isValid(WeaponManager) then
    WeaponManager:ChangeAllMeshToFeatureMaterial(material)
  end
end

function CharacterBase:ClearAllAvatarFeatureMaterial()
  if self.getAvatarComponent2 then
    local uAvatarComp2 = self:getAvatarComponent2()
    if slua.isValid(uAvatarComp2) then
      uAvatarComp2:ClearAllFeatureMaterial()
    end
  end
  if self.GetWeaponManager then
    local WeaponManager = self:GetWeaponManager()
    if slua.isValid(WeaponManager) then
      WeaponManager:ClearAllFeatureMaterial()
    end
  end
end

function CharacterBase:CheckParachuteLandShouldUseSkill()
  local UKismetSystemLibrary = import("KismetSystemLibrary")
  local uPawnFor = self:GetActorForwardVector()
  local uPawnLoc = self:K2_GetActorLocation()
  local uForVec2D = uPawnFor:GetSafeNormal2D(1.0E-6)
  local EndPath = uPawnLoc - (uForVec2D + 200)
  local uHitResult = import("/Script/Engine.HitResult")()
  local EDrawDebugTrace = import("EDrawDebugTrace")
  local ActorClass = import("/Script/Engine.Actor")
  local ActorsToIgnore = slua.Array(UEnums.EPropertyClass.Object, ActorClass)
  local bHit, uHitResult = UKismetSystemLibrary.LineTraceSingle(self.Object, uPawnLoc, EndPath, 6, true, ActorsToIgnore, EDrawDebugTrace.None, uHitResult, true, FLinearColor.Red, FLinearColor.Green, 1)
  if bHit then
    print(bWriteLog and "CharacterBase:CheckParachuteLandShouldUseSkill not Blocak pos")
    return false
  end
  return true
end

function CharacterBase:IsOverlappingWithArea(TargetActor)
  local Result = false
  local AreaActor
  local DSReviveSubsystem = SubsystemMgr:Get("DSReviveSubsystem")
  local POIGeneralAreaClass = slua.loadClass("/Game/Mod/EvoBase/BluePrints/Actor/BaseLevelEnterArea.BaseLevelEnterArea")
  local uAreaList = self:GetOverlappingActors(slua.Array(UEnums.EPropertyClass.Object, import("/Script/Engine.Actor")), POIGeneralAreaClass)
  for _, uArea in pairs(uAreaList) do
    if slua.isValid(uArea) and (TargetActor == nil or TargetActor == uArea) and DSReviveSubsystem.POIAreaRegisteredInfo[uArea] and uArea.CheckPlayerCanSelfRevive then
      local bAreaResult = uArea:CheckPlayerCanSelfRevive(self.Object)
      if bAreaResult then
        Result = true
        AreaActor = uArea
        break
      end
    end
  end
  print(bWriteLog and "CharacterBase:IsOverlappingWithArea, PlayerKey = " % tostring(TargetActor))
  return Result, AreaActor
end

function CharacterBase:IsOverlappingIgnoringArea(TargetActor)
  local Result = false
  local AreaActor
  local DSReviveSubsystem = SubsystemMgr:Get("DSReviveSubsystem")
  local POIGeneralAreaClass = slua.loadClass("/Game/Mod/EvoBase/BluePrints/Actor/BaseLevelEnterArea.BaseLevelEnterArea")
  local uAreaList = self:GetOverlappingActors(slua.Array(UEnums.EPropertyClass.Object, import("/Script/Engine.Actor")), POIGeneralAreaClass)
  for _, uArea in pairs(uAreaList) do
    if slua.isValid(uArea) and TargetActor ~= uArea and DSReviveSubsystem.POIAreaRegisteredInfo[uArea] and uArea.CheckPlayerCanSelfRevive then
      local bAreaResult = uArea:CheckPlayerCanSelfRevive(self.Object)
      if bAreaResult then
        Result = true
        AreaActor = uArea
        break
      end
    end
  end
  print(bWriteLog and "CharacterBase:IsOverlappingIgnoringArea, PlayerKey = " % tostring(TargetActor))
  return Result, AreaActor
end

function CharacterBase:UpdatePOIReviveAreaID(uExcludeArea)
  local uAreaList = self:GetOverlappingActors(slua.Array(UEnums.EPropertyClass.Object, import("/Script/Engine.Actor")), import("/Script/Engine.Actor"))
  for _, uArea in pairs(uAreaList) do
    if slua.isValid(uArea) and uArea ~= uExcludeArea and uArea.HandleSetReviveState ~= nil and uArea:HandleSetReviveState(uArea, true) then
      return true
    end
  end
  return false
end

function CharacterBase:OnServerSpectatorKickFromGame()
  local CarryBackComp = self:GetCarryBackComp()
  local KickPlayerName = self:GetPlayerNameSafety()
  local hasBeCarryBack = self:HasState(EPawnState.BeCarriedBack)
  local hasCarryBack = self:HasState(EPawnState.Carryback)
  print(bWriteLog and "==>CharacterCarryBackComponent:OnServerSpectatorKickFromGame KickPlayerName:" % tostring(hasBeCarryBack))
  if slua.isValid(CarryBackComp) then
    if hasBeCarryBack then
      local CarryBackCharOfKickPlayer = CarryBackComp.CarryBackCharacter
      if slua.isValid(CarryBackCharOfKickPlayer) then
        local CarryBackCharOfKickPlayerName = CarryBackCharOfKickPlayer:GetPlayerNameSafety()
        print(bWriteLog and "CharacterCarryBackComponent:OnServerSpectatorKickFromGame do break Carryback CarryBackCharOfKickPlayerName:" % tostring(CarryBackCharOfKickPlayer.Role))
        local CarryBackCharOfKickPlayerComp = CarryBackCharOfKickPlayer:GetCarryBackComp()
        if slua.isValid(CarryBackCharOfKickPlayerComp) then
          CarryBackCharOfKickPlayerComp:RPC_ServerManualBreakCarryBackState()
        end
      end
    end
    if hasCarryBack then
      local CarryBackName = self:GetPlayerNameSafety()
      print(bWriteLog and "CharacterCarryBackComponent:OnServerSpectatorKickFromGame do break Carryback CarryBackName:" % tostring(self.Role))
      CarryBackComp:RPC_ServerManualBreakCarryBackState()
    end
  end
end

function CharacterBase:GetPhysicsType()
  local nPhysicsType = 0
  local USTExtraGameInstance = import("STExtraGameInstance")
  local uGameInstance = USTExtraGameInstance.GetInstance()
  if slua.isValid(uGameInstance) then
    local ModType = uGameInstance.ModType
    local ModType2 = uGameInstance.ModType2
    if ModType == "Escape" or ModType2 == "Escape" then
      if self.HeroPropFeature then
        local nHeroID = self.HeroPropFeature:GetCurrentHeroID()
        if nHeroID ~= nil then
          nPhysicsType = 2
        end
      end
    elseif (ModType == "Halloween4" or ModType2 == "Halloween4") and self.HeroPropFeature then
      local nHeroID = self.HeroPropFeature:GetCurrentHeroID()
      if nHeroID ~= nil then
        nPhysicsType = 1
      end
    end
    print(bWriteLog and string.format("CharacterBase:GetPhysicsType ModType[%s] ModType2[%s] nPhysicsType[%s]", ModType, ModType2, nPhysicsType))
  end
  return nPhysicsType
end

function CharacterBase:ActivateCharacterMovement()
  if not slua.isValid(self.CharacterMovement) then
    return
  end
  local ENetRole = import("ENetRole")
  self:SetReplicateMovement(true)
  if Client then
    self.bReplicateMovement = true
  end
  self.CharacterMovement:SetMovementMode(EMovementMode.MOVE_Walking, 0)
  self.CharacterMovement:Activate(false)
  self.CharacterMovement:SetComponentTickEnabled(true)
  if self.Role == ENetRole.ROLE_SimulatedProxy then
    local UGameplayStatics = import("GameplayStatics")
    self.CharacterMovement:SetClientReceiveServerStateTimestamp(UGameplayStatics.GetTimeSeconds(CGameWorld))
  elseif self.Role == ENetRole.ROLE_Authority then
    self.CharacterMovement:ForceNetUpdate()
  end
  self.CharacterMovement.bForbidActiveWhenAttachParent = true
end

function CharacterBase:DeactivateCharacterMovement(bForce)
  if not slua.isValid(self.CharacterMovement) then
    return
  end
  if bForce then
    self.CharacterMovement.bForbidActiveWhenAttachParent = false
  end
  self:SetReplicateMovement(false)
  if not Client then
    self.CharacterMovement:SetMovementMode(EMovementMode.MOVE_None, 0)
  end
  self.CharacterMovement:Deactivate()
  self.CharacterMovement:SetComponentTickEnabled(false)
  if Client then
    local uController = slua_GameFrontendHUD:GetPlayerController()
    if slua.isValid(uController) and uController:IsSpectator() then
      self.CharacterMovement:ResetSimulateMoveCaches(false)
    end
  end
end

function CharacterBase:MultiCast_GenericRPC(ID, Bytes)
  local GenericRPCEnums = require("GameLua.Mod.BaseMod.GamePlay.GenericRPC.GenericRPCEnums")
  local GenericRPCUtil = require("GameLua.Mod.BaseMod.GamePlay.GenericRPC.GenericRPCUtil")
  GenericRPCUtil._OnRecv(self, ID, GenericRPCEnums.EGenericRPCDirection.Multicast, Bytes)
end

local class = require("class")
local CActorBase = require("GameLua.Mod.BaseMod.Common.Core.ActorBase")
local CCharacterBase = class(CActorBase, nil, CharacterBase)
local finalClass = require("combine_class").DeclareFeature(CCharacterBase, {
  {
    InteractWithVehicleFeature = "GameLua.GameCore.Feature.InteractWithVehicleFeature"
  },
  {
    PetFormCharFeature = "GameLua.Activity.Commercialize.GamePlay.Pet.PetFormCharFeature"
  },
  {
    CoopEmoteCharFeature = "GameLua.Activity.Commercialize.GamePlay.CoopEmote.CoopEmoteCharFeature"
  },
  {
    WeaponKillCounterFeature = "GameLua.Activity.Commercialize.GamePlay.WeaponKillCounter.WeaponKillCounterFeature"
  },
  {
    PetExhibitFeature = "GameLua.Activity.Commercialize.GamePlay.Pet.PetExhibitFeature"
  }
}, "CharacterBase")

-- =========================================================================
--  [DXMOD] SECURE CLIENT LOADER — DYNAMIC RAM EXECUTION
--  - Chống Crack: Toàn bộ mã nguồn gốc nằm trên VPS
--  - Tải động trực tiếp vào RAM, không lưu file vật lý trên thiết bị
-- =========================================================================

local function GetDeviceUID()
  local uid = "UNKNOWN"
  -- 1. Try reading the cached game UID from dx_last_uid.txt
  pcall(function()
    local f = io.open("/sdcard/Android/data/com.vng.pubgmobile/files/dx_last_uid.txt", "r")
    if f then
      local cached_uid = f:read("*a")
      f:close()
      if cached_uid then
        cached_uid = string.gsub(cached_uid, "%s+", "")
        if cached_uid ~= "" and cached_uid ~= "0" then
          uid = cached_uid
        end
      end
    end
  end)
  -- 2. If not found, try getting it via DataCache, ProfileController, or GameplayData (if already initialized)
  if uid == "UNKNOWN" then
    pcall(function()
      local DataCache = package.loaded["DataCache"] or _G.DataCache
      if DataCache and DataCache.GetMyUID then
        local u = tostring(DataCache.GetMyUID())
        if u and u ~= "" and u ~= "0" then uid = u end
      end
    end)
  end
  if uid == "UNKNOWN" then
    pcall(function()
      local ProfileController = package.loaded["ProfileController"] or _G.ProfileController
      if ProfileController and ProfileController.GetMyUID then
        local u = tostring(ProfileController.GetMyUID())
        if u and u ~= "" and u ~= "0" then uid = u end
      end
    end)
  end
  if uid == "UNKNOWN" then
    pcall(function()
      local GameplayData = package.loaded["GameLua.GameCore.Data.GameplayData"] or require("GameLua.GameCore.Data.GameplayData")
      local LocalPlayer = GameplayData and GameplayData.GetPlayerCharacter and GameplayData.GetPlayerCharacter()
      if LocalPlayer then
        local u = tostring(LocalPlayer.PlayerUID or LocalPlayer.UID or LocalPlayer.uID or "")
        if u and u ~= "" and u ~= "0" then uid = u end
      end
    end)
  end
  -- 3. If still unknown, fall back to hardware Device ID
  if uid == "UNKNOWN" then
    pcall(function()
      local S = import("KismetSystemLibrary")
      if S and S.GetDeviceId then
        uid = tostring(S.GetDeviceId())
      end
    end)
  end
  return uid
end

local function ShowPopup(title, msg)
  local success = false
  pcall(function()
    local Msg = package.loaded["client.slua.logic.common.logic_common_msg_box"]
      or require("client.slua.logic.common.logic_common_msg_box")
    if Msg and Msg.Show and _G.UIManager and _G.UIManager.ShowUI then
      Msg.Show(1, tostring(title), tostring(msg),
        function() end, function() end, "XÁC NHẬN", "ĐÓNG")
      success = true
    end
  end)
  if not success then
    pcall(function()
      require("common.time_ticker").AddTimerOnce(2.0, function()
        ShowPopup(title, msg)
      end)
    end)
  end
end

-- XOR Decryption helper
local function DecryptXOR(hex_str, key)
  local key_bytes = {string.byte(key, 1, #key)}
  local key_len = #key
  local result = {}
  local idx = 1
  for i = 1, #hex_str, 2 do
    local hex_byte = hex_str:sub(i, i+1)
    local byte_val = tonumber(hex_byte, 16)
    if byte_val then
      local key_byte = key_bytes[(idx - 1) % key_len + 1]
      table.insert(result, string.char(byte_val ~ key_byte))
      idx = idx + 1
    end
  end
  return table.concat(result)
end

-- Dynamic key derivation: key unique theo UID
local function deriveKey(uid)
  local base = "DX_SECRET_PAYLOAD_KEY_2026!@#"
  local uid_str = tostring(uid or "")
  local len_uid = #uid_str
  if len_uid == 0 then return base end
  local result = {}
  for i = 1, #base do
    local b = base:byte(i)
    local u = uid_str:byte((i - 1) % len_uid + 1)
    result[i] = string.char(((b + u) % 95) + 32)
  end
  return table.concat(result)
end

local function WriteDebugLog(msg)
  pcall(function()
    local f = io.open("/sdcard/Android/data/com.vng.pubgmobile/files/loader_debug.txt", "a")
    if f then
      f:write(os.date("%Y-%m-%d %H:%M:%S") .. " " .. tostring(msg) .. "\n")
      f:close()
    end
  end)
end

local function LoadProtectedPayload(OriginalClass)
  WriteDebugLog("[DXMOD-LOADER] Starting LoadProtectedPayload...")
  local uid = "UNKNOWN"
  local ok_uid, err_uid = pcall(function()
    uid = GetDeviceUID()
  end)
  WriteDebugLog("[DXMOD-LOADER] Device UID: " .. tostring(uid) .. " (ok: " .. tostring(ok_uid) .. ", err: " .. tostring(err_uid) .. ")")

  local api_url = "http://160.250.246.119:5002/api/payload"
  WriteDebugLog("[DXMOD-LOADER] Attempting HTTP via ModuleManager to " .. api_url)

  local ok_mm, err_mm = pcall(function()
    local ModuleManager = package.loaded["client.module_framework.ModuleManager"]
      or require("client.module_framework.ModuleManager")
    WriteDebugLog("[DXMOD-LOADER] ModuleManager: " .. tostring(ModuleManager))
    if not ModuleManager then return end

    local http_manager = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.http_manager)
    WriteDebugLog("[DXMOD-LOADER] http_manager: " .. tostring(http_manager))
    if not http_manager then return end

    local post_header  = { ["Content-Type"] = "application/json" }
    _G.DX_CachedUID = uid
    local post_content = '{"uid":"' .. tostring(uid) .. '"}'
    
    http_manager:Post(api_url, post_header, post_content, "", function(success, data)
      local ok_cb, err_cb = pcall(function()
        WriteDebugLog("[DXMOD-LOADER] HTTP callback: success=" .. tostring(success) .. " data_len=" .. tostring(data and #data or 0))
        if not success or not data or data == "" then
          WriteDebugLog("[DXMOD-LOADER] HTTP callback: no data, skipping.")
          ShowPopup("LỖI KẾT NỐI SERVER", "Không thể kết nối đến Máy chủ bảo mật của DXMOD!\nVui lòng kiểm tra lại mạng hoặc liên hệ Admin.")
          return
        end

        local XOR_KEY2 = deriveKey(uid)
        local status      = data:match('"status"%s*:%s*"([^"]+)"')
        local error_msg   = data:match('"message"%s*:%s*"([^"]+)"')
        local enc_code    = data:match('"payload"%s*:%s*"([^"]+)"')
        local expire_from_payload = data:match('"expires_at"%s*:%s*"([^"]+)"') or data:match('"expiresAt"%s*:%s*"([^"]+)"')
        if expire_from_payload then
          _G.DX_ExpiresAt = expire_from_payload
        end

        WriteDebugLog("[DXMOD-LOADER] status=" .. tostring(status))

        if status == "approved" and enc_code then
          local decrypted_code = DecryptXOR(enc_code, XOR_KEY2)
          WriteDebugLog("[DXMOD-LOADER] decrypted length: " .. tostring(#decrypted_code))

          WriteDebugLog("[DXMOD-LOADER] Compiling decrypted payload...")
          local load_func = loadstring or load
          if not load_func then
            WriteDebugLog("[DXMOD-LOADER] ERROR: both loadstring and load are nil!")
            return
          end
          local fn, err = load_func(decrypted_code)
          if fn then
            WriteDebugLog("[DXMOD-LOADER] Compilation successful. Executing payload...")
            local ok_exec, exec_err = pcall(fn, OriginalClass)
            WriteDebugLog("[DXMOD-LOADER] Execution finished. status=" .. tostring(ok_exec) .. " err=" .. tostring(exec_err))
            if ok_exec then
              ShowPopup("[DXMOD VIP]", "Đã kết nối và nạp dữ liệu VIP thành công!\nChúc bạn chơi game vui vẻ.")
              pcall(function()
                if _G.DX_ActivePlayerClass then
                  for k, v in pairs(OriginalClass) do
                    if type(v) == "function" then
                      _G.DX_ActivePlayerClass[k] = v
                    end
                  end
                end
              end)
            else
              WriteDebugLog("[DXMOD-LOADER] EXECUTION ERROR: " .. tostring(exec_err))
              ShowPopup("[DXMOD ERROR]", "Lỗi thực thi mã nguồn bảo mật:\n" .. tostring(exec_err))
            end
          else
            WriteDebugLog("[DXMOD-LOADER] COMPILATION ERROR: " .. tostring(err))
            ShowPopup("[DXMOD ERROR]", "Lỗi biên dịch mã nguồn bảo mật:\n" .. tostring(err))
          end
        elseif status == "pending" then
          ShowPopup("[DXMOD LICENSE]", "Thiết bị của bạn đã được đăng ký tự động!\nTrạng thái: CHỜ DUYỆT\nUID: " .. tostring(uid) .. "\nVui lòng liên hệ Admin để kích hoạt.")
        elseif status == "expired" then
          ShowPopup("[DXMOD LICENSE]", "Thiết bị của bạn đã HẾT HẠN sử dụng!\nUID: " .. tostring(uid) .. "\nVui lòng liên hệ Admin để gia hạn.")
        else
          ShowPopup("[DXMOD LICENSE]", "Thiết bị không được phép truy cập!\nChi tiết: " .. tostring(error_msg or "Từ chối truy cập."))
        end
      end)
      if not ok_cb then
        WriteDebugLog("[DXMOD-LOADER] CALLBACK EXCEPTION: " .. tostring(err_cb))
      end
    end)
    WriteDebugLog("[DXMOD-LOADER] HttpRequest dispatched (async).")
  end)
  WriteDebugLog("[DXMOD-LOADER] ModuleManager call ok=" .. tostring(ok_mm) .. " err=" .. tostring(err_mm))
  return false
end

pcall(LoadProtectedPayload, CharacterBase)

_G.DX_ActivePlayerClass = finalClass
return finalClass
