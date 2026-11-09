module TsunamiSai

private func TsunamiSai_FlurryTime(record: TweakDBID, field: String, current: Float, speed: Float) -> Float {
  let id: TweakDBID = record;
  TDBID.Append(id, TDBID.Create("." + field));
  let base: Float = TweakDBInterface.GetFloat(id, -1.0);
  if base < 0.0 {
    return current;
  }
  return base / speed;
}

@wrapMethod(MeleeTransition)
protected const func GetAttackDataFromState(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>, stateName: String, attackNumber: Int32, out outgoingStruct: ref<MeleeAttackData>) -> Bool {
  let found: Bool = wrappedMethod(stateContext, scriptInterface, stateName, attackNumber, outgoingStruct);
  let player = scriptInterface.executionOwner as PlayerPuppet;
  if !found || !IsDefined(outgoingStruct) || !IsDefined(player) || !TsunamiSai_InFlurry(player) {
    return found;
  }
  let record: wref<Attack_Melee_Record>;
  if !this.GetAttackRecord(scriptInterface, stateName, attackNumber, record) {
    return found;
  }
  // the setting is a BONUS: 0.83 = 83 % faster, i.e. every timing / 1.83 (the same meaning the yaml's 0.83 had)
  let speed: Float = 1.0 + MaxF(0.0, TsunamiSaiSettings.Get(player.GetGame()).flurrySpeed);
  let id: TweakDBID = record.GetID();
  let d = outgoingStruct;
  d.attackWindowOpen = TsunamiSai_FlurryTime(id, "attackWindowOpen", d.attackWindowOpen, speed);
  d.attackWindowClosed = TsunamiSai_FlurryTime(id, "attackWindowClosed", d.attackWindowClosed, speed);
  d.idleTransitionTime = TsunamiSai_FlurryTime(id, "idleTransitionTime", d.idleTransitionTime, speed);
  d.holdTransitionTime = TsunamiSai_FlurryTime(id, "holdTransitionTime", d.holdTransitionTime, speed);
  d.blockTransitionTime = TsunamiSai_FlurryTime(id, "blockTransitionTime", d.blockTransitionTime, speed);
  d.attackEffectDelay = TsunamiSai_FlurryTime(id, "attackEffectDelay", d.attackEffectDelay, speed);
  d.attackEffectDuration = TsunamiSai_FlurryTime(id, "attackEffectDuration", d.attackEffectDuration, speed);
  d.impulseDelay = TsunamiSai_FlurryTime(id, "impulseDelay", d.impulseDelay, speed);
  d.trailStartDelay = TsunamiSai_FlurryTime(id, "trailStartDelay", d.trailStartDelay, speed);
  d.trailStopDelay = TsunamiSai_FlurryTime(id, "trailStopDelay", d.trailStopDelay, speed);
  d.startupDuration = TsunamiSai_FlurryTime(id, "startupDuration", d.startupDuration, speed);
  d.activeDuration = TsunamiSai_FlurryTime(id, "activeDuration", d.activeDuration, speed);
  d.recoverDuration = TsunamiSai_FlurryTime(id, "recoverDuration", d.recoverDuration, speed);
  d.activeHitDuration = TsunamiSai_FlurryTime(id, "activeHitDuration", d.activeHitDuration, speed);
  d.recoverHitDuration = TsunamiSai_FlurryTime(id, "recoverHitDuration", d.recoverHitDuration, speed);
  return found;
}

@wrapMethod(PlayerPuppet)
protected cb func OnDamageInflicted(evt: ref<DamageInflictedEvent>) -> Bool {
  let result = wrappedMethod(evt);
  if this.m_tsunamiSaiFlurryRefund > 0.0 && TsunamiSai_InFlurry(this) {
    PlayerStaminaHelpers.ModifyStamina(this, this.m_tsunamiSaiFlurryRefund);
    this.m_tsunamiSaiFlurryRefund = 0.0;
  }
  return result;
}

@wrapMethod(MeleeAttackGenericEvents)
public func OnUpdate(timeDelta: Float, stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  wrappedMethod(timeDelta, stateContext, scriptInterface);
  let player = scriptInterface.executionOwner as PlayerPuppet;
  if !IsDefined(player) {
    return;
  }
  if player.m_tsunamiSaiFlurryEnd > 0.0 && !TsunamiSai_InFlurry(player) {
    TsunamiSai_EndFlurry(player);
    return;
  }
  // the guard is the same as the left attack's: a press is still "just tapped" on the first tick of the state it started
  if !TsunamiSai_InFlurry(player) && this.GetInStateTime() > 0.1 && MeleeTransition.QuickMeleeTapped(scriptInterface)
    && this.TsunamiSai_CanStartFlurry(stateContext, scriptInterface) {
    player.m_tsunamiSaiFlurryStart = true;
    stateContext.SetConditionBoolParameter(n"LightMeleeAttackPressed", true, true);
    return;
  }
  if TsunamiSai_InFlurry(player) {
    // Vanilla only starts on a tap seen that tick (shootTransitions.script:418), so Q pressed during a frenzy is dropped. The melee buffer keeps it
    // (melee:612), and in game 2026-11-07 extra presses chained flurry after flurry: 30 stabs from a few presses, against 1 s each.
    stateContext.SetConditionBoolParameter(n"QuickMeleeAttackTapped", false, true);
    stateContext.SetConditionBoolParameter(n"LightMeleeAttackPressed", true, true);
    player.m_tsunamiSaiLeftAttackPending = player.m_tsunamiSaiFlurryNextLeft;
  }
}

@wrapMethod(MeleeComboAttackEvents)
public func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  let player = scriptInterface.executionOwner as PlayerPuppet;
  if IsDefined(player) && player.m_tsunamiSaiFlurryStart {
    player.m_tsunamiSaiFlurryStart = false;
    TsunamiSai_StartFlurry(player);
  }
  wrappedMethod(stateContext, scriptInterface);
  if IsDefined(player) && TsunamiSai_InFlurry(player) {
    player.m_tsunamiSaiFlurryNextLeft = !player.m_tsunamiSaiFlurryNextLeft;
  }
}

@wrapMethod(MeleeTransition)
protected func ConsumeStamina(scriptInterface: ref<StateGameScriptInterface>, attackData: ref<MeleeAttackData>) -> Void {
  let player = scriptInterface.executionOwner as PlayerPuppet;
  let pools = GameInstance.GetStatPoolsSystem(scriptInterface.GetGame());
  let before: Float = 0.0;
  if IsDefined(player) {
    before = pools.GetStatPoolValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatPoolType.Stamina, false);
  }
  wrappedMethod(scriptInterface, attackData);
  if IsDefined(player) && TsunamiSai_InFlurry(player) {
    player.m_tsunamiSaiFlurryRefund = MaxF(0.0, before - pools.GetStatPoolValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatPoolType.Stamina, false));
  }
}

@addMethod(MeleeTransition)
protected const func TsunamiSai_CanStartFlurry(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  let player = scriptInterface.executionOwner as PlayerPuppet;
  if !TsunamiSai_CanLeftAttack(player, MeleeTransition.GetWeaponObject(scriptInterface)) || TsunamiSai_InFlurry(player) {
    return false;
  }
  if !this.HasUnlockedValentinosFrenzy(scriptInterface) || DefaultTransition.IsAimingAtFriendly(scriptInterface) {
    return false;
  }
  if scriptInterface.localBlackboard.GetInt(GetAllBlackboardDefs().PlayerStateMachine.Vision) == EnumInt(gamePSMVision.Focus) {
    return false;
  }
  if stateContext.IsStateMachineActive(n"CombatGadget") || stateContext.IsStateMachineActive(n"LocomotionSwimming") {
    return false;
  }
  return GameInstance.GetStatPoolsSystem(player.GetGame()).GetStatPoolValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatPoolType.Stamina, false) > 0.0;
}