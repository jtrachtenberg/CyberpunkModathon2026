module TsunamiSai

@wrapMethod(UIItemsHelper)
public final static func GetItemTypeKey(itemID: TweakDBID, itemType: gamedataItemType, weaponEvolutionType: gamedataWeaponEvolution) -> String {
  if itemID == t"Items.tsunamisai_weapon" || itemID == t"Items.tsunamisai_weapon_left" {
    return GetLocalizedTextByKey(n"TsunamiSai-WeaponType");
  }
  return wrappedMethod(itemID, itemType, weaponEvolutionType);
}

@wrapMethod(InventoryItemDisplayController)
protected func NewUpdateWeaponType(itemData: wref<UIInventoryItem>) -> Void {
  wrappedMethod(itemData);
  if IsDefined(itemData) && itemData.GetTweakDBID() == t"Items.tsunamisai_weapon" {
    inkTextRef.SetText(this.m_weaponType, GetLocalizedTextByKey(n"TsunamiSai-WeaponType"));
  }
}

@wrapMethod(InventoryItemDisplayController)
protected func RefreshUI() -> Void {
  wrappedMethod();
  if ItemID.GetTDBID(InventoryItemData.GetID(this.m_itemData)) == t"Items.tsunamisai_weapon" {
    inkTextRef.SetText(this.m_weaponType, GetLocalizedTextByKey(n"TsunamiSai-WeaponType"));
  }
}

@wrapMethod(PlayerPuppet)
protected cb func OnItemAddedToSlot(evt: ref<ItemAddedToSlot>) -> Bool {
    let isItemAddedToSlot = wrappedMethod(evt);
    if TsunamiSai_IsTsunamiSai(evt.GetItemID()) && evt.GetSlotID() == t"AttachmentSlots.WeaponRight" {
      TsunamiSai_AddLeftSai(this);
      TsunamiSai_ShowLeftSaiIfBack(this);
    }
    if ItemID.GetTDBID(evt.GetItemID()) == t"Items.tsunamisai_weapon_left" {
      AnimationControllerComponent.SetAnimWrapperWeight(this, n"w_tsunamisai", 1.0);
      TsunamiSai_ShowLeftSaiIfBack(this);
    }
    // handle grenades and other left hand items
    if evt.GetSlotID() == t"AttachmentSlots.WeaponLeft" {
      TsunamiSai_ShowLeftSaiIfBack(this);
    }        
    return isItemAddedToSlot;
}

@wrapMethod(PlayerPuppet)
protected cb func OnItemRemovedFromSlot(evt: ref<ItemRemovedFromSlot>) -> Bool {
  let isItemRemovedFromSlot = wrappedMethod(evt);

  if TsunamiSai_IsTsunamiSai(evt.GetItemID()) && evt.GetSlotID() == t"AttachmentSlots.WeaponRight" {
    if IsDefined(TsunamiSai_GetLeftSaiObject(this)) {
      GameInstance.GetTransactionSystem(this.GetGame()).RemoveItemFromSlot(this, t"AttachmentSlots.TSaiLeftGrip", true);
    }
    AnimationControllerComponent.SetAnimWrapperWeight(this, n"w_tsunamisai", 0.0);
  }

  if evt.GetSlotID() == t"AttachmentSlots.WeaponLeft" {
    TsunamiSai_ShowLeftSaiIfBack(this);
  }

  return isItemRemovedFromSlot;
}

@wrapMethod(PlayerPuppet)
private final func OnHitBlockedOrDeflected(hitEvent: ref<gameHitEvent>) -> Void {
  wrappedMethod(hitEvent);
  if TsunamiSai_HasLeftSai(this) && !StatusEffectSystem.ObjectHasStatusEffect(this, t"BaseStatusEffect.BlockBroken") {
    //GameObject.PlaySoundEvent(this, n"block");
    GameObject.PlaySound(this, n"w_melee_katana_impact_block");
  }
}

@wrapMethod(DamageManager)
private final static func ProcessDefensiveState(hitEvent: ref<gameHitEvent>) -> Void {
  let player = hitEvent.target as PlayerPuppet;

  if !IsDefined(player) || !AttackData.IsMelee(hitEvent.attackData.GetAttackType()) || !TsunamiSai_HasLeftSai(player) {
    wrappedMethod(hitEvent);
    return;
  }

  let stats = GameInstance.GetStatsSystem(player.GetGame());
  let id = Cast<StatsObjectID>(player.GetEntityID());

  if stats.GetStatValue(id, gamedataStatType.IsBlocking) > 0.0 || stats.GetStatValue(id, gamedataStatType.IsDeflecting) > 0.0 {
    wrappedMethod(hitEvent);
    return;
  }

  let flag = RPGManager.CreateStatModifier(gamedataStatType.IsBlocking, gameStatModifierType.Additive, 1.0);
  stats.AddModifier(id, flag);
  wrappedMethod(hitEvent);
  stats.RemoveModifier(id, flag);
}

//prevent return to rest after an attack and stay on ready
@wrapMethod(MeleeAttackGenericEvents)
public func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  let numberSent: Int32 = stateContext.GetIntParameter(n"meleeAttackNumber", true);
  wrappedMethod(stateContext, scriptInterface);

  let weapon: ref<WeaponObject> = MeleeTransition.GetWeaponObject(scriptInterface);
  if IsDefined(weapon) && TsunamiSai_IsTsunamiSai(weapon.GetItemID()) {
    let numberNow: Int32 = stateContext.GetIntParameter(n"meleeAttackNumber", true);
    stateContext.SetPermanentIntParameter(n"meleeAttackNumber", numberSent, true);
    this.SendAnimFeatureData(stateContext, scriptInterface);
    stateContext.SetPermanentIntParameter(n"meleeAttackNumber", numberNow, true);
  }
}

@wrapMethod(MeleeAttackGenericEvents)
protected func SendAnimationSlotData(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>, const attackData: ref<MeleeAttackData>) -> Bool {
  let weapon: ref<WeaponObject> = MeleeTransition.GetWeaponObject(scriptInterface);
  if IsDefined(this as MeleeDeflectAttackEvents) && IsDefined(weapon) && TsunamiSai_IsTsunamiSai(weapon.GetItemID()) {
    let number: Int32 = stateContext.GetIntParameter(n"meleeAttackNumber", true);
    stateContext.SetPermanentIntParameter(n"meleeAttackNumber", 3, true);
    let result: Bool = wrappedMethod(stateContext, scriptInterface, attackData);
    stateContext.SetPermanentIntParameter(n"meleeAttackNumber", number, true);
    return result;
  }
  return wrappedMethod(stateContext, scriptInterface, attackData);
}

@wrapMethod(DamageSystem)
private final func ProcessBlockAndDeflect(hitEvent: ref<gameHitEvent>) -> Void {
  let player = hitEvent.target as PlayerPuppet;
  if !IsDefined(player) || !hitEvent.attackData.WasBlocked() || !TsunamiSai_HasLeftSai(player) {
    wrappedMethod(hitEvent);
    return;
  }
  let stats = GameInstance.GetStatsSystem(player.GetGame());
  let id = Cast<StatsObjectID>(player.GetEntityID());

  if stats.GetStatValue(id, gamedataStatType.IsBlocking) > 0.0 {
    wrappedMethod(hitEvent);
    return;
  }

  let cost = RPGManager.CreateStatModifier(gamedataStatType.BlockFactor, gameStatModifierType.Multiplier, 0.8);
  stats.AddModifier(id, cost);
  wrappedMethod(hitEvent);
  stats.RemoveModifier(id, cost);

  if hitEvent.attackData.WasBlocked() && !StatusEffectSystem.ObjectHasStatusEffect(player, t"BaseStatusEffect.BlockBroken") {
    AnimationControllerComponent.PushEvent(player, n"MeleeDeflect");
  }
}

@wrapMethod(MeleeDeflectDecisions)
protected const func ToMeleeBlock(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  let weapon: ref<WeaponObject> = MeleeTransition.GetWeaponObject(scriptInterface);
  if IsDefined(weapon) && TsunamiSai_IsTsunamiSai(weapon.GetItemID()) {
    return false;
  }
  return wrappedMethod(stateContext, scriptInterface);  
}

@wrapMethod(MeleeDeflectDecisions)
protected const func EnterCondition(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  if wrappedMethod(stateContext, scriptInterface) {
    return true;
  }
  let weapon: ref<WeaponObject> = MeleeTransition.GetWeaponObject(scriptInterface);
  if !IsDefined(weapon) || !TsunamiSai_IsTsunamiSai(weapon.GetItemID()) {
    return false;
  }

  //disable parry without doubletrouble
  if !PlayerDevelopmentSystem.GetData(scriptInterface.executionOwner).IsNewPerkBoughtAnyLevel(gamedataNewPerkType.Cool_Central_Milestone_2) {
    return false;
  }

  //also if the left sai is in the right hand waiting after a throw
  if !TsunamiSai_HasLeftSai(scriptInterface.executionOwner as PlayerPuppet) {
    return false;
  }

  //default to throw when not in combat
  if !this.IsPlayerInCombat(scriptInterface) {
    return false;
  }
  return this.IsBlockPressed(stateContext, scriptInterface)
    && this.CanWeaponDeflect(stateContext, scriptInterface)
    && !this.GetStaticBoolParameterDefault("disabled", false)
    && !GameObject.IsCooldownActive(scriptInterface.owner, n"Deflect");
}

@wrapMethod(MeleeBlockDecisions)
protected const func ExitCondition(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  let weapon: ref<WeaponObject> = MeleeTransition.GetWeaponObject(scriptInterface);
  if IsDefined(weapon) && TsunamiSai_IsTsunamiSai(weapon.GetItemID()) {
    return true;
  }
  return wrappedMethod(stateContext, scriptInterface);
}

@wrapMethod(MeleeTargetingEvents)
public func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  wrappedMethod(stateContext, scriptInterface);
  let weapon: ref<WeaponObject> = MeleeTransition.GetWeaponObject(scriptInterface);
  if IsDefined(weapon) && TsunamiSai_IsTsunamiSai(weapon.GetItemID()) {
    scriptInterface.PushAnimationEvent(n"ForceReady");
  }
}

@wrapMethod(MeleeDeflectEvents)
public func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  wrappedMethod(stateContext, scriptInterface);
  let weapon: ref<WeaponObject> = MeleeTransition.GetWeaponObject(scriptInterface);
  if IsDefined(weapon) && TsunamiSai_IsTsunamiSai(weapon.GetItemID()) {
    this.SetIsBlocking(stateContext, false);
    this.SendAnimFeatureData(stateContext, scriptInterface);
    scriptInterface.PushAnimationEvent(n"MeleeDeflect");
  }
}

@wrapMethod(MeleeDeflectAttackEvents)
public func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  wrappedMethod(stateContext, scriptInterface);
  let weapon: ref<WeaponObject> = MeleeTransition.GetWeaponObject(scriptInterface);
  if IsDefined(weapon) && TsunamiSai_IsTsunamiSai(weapon.GetItemID()) {
    
    //prevent duplicate from base game
    this.m_slowMoSet = true;

    if !this.IsTimeDilationActive(stateContext, scriptInterface, n"") {
      scriptInterface.GetTimeSystem().SetTimeDilation(n"deflect",
        TweakDBInterface.GetFloat(t"TsunamiSai.parrySlowMoAmount", 0.2),
        TweakDBInterface.GetFloat(t"TsunamiSai.parrySlowMoDuration", 0.5),
        this.GetStaticCNameParameterDefault("slowMoEaseIn", n"Linear"),
        this.GetStaticCNameParameterDefault("slowMoEaseOut", n"Linear"));
    }
  }
}

@wrapMethod(MeleeThrowReloadEvents)
public func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  wrappedMethod(stateContext, scriptInterface);
  let weapon: ref<WeaponObject> = MeleeTransition.GetWeaponObject(scriptInterface);
  let player = scriptInterface.executionOwner as PlayerPuppet;
  if IsDefined(weapon) && IsDefined(player) && TsunamiSai_IsTsunamiSai(weapon.GetItemID()) {
    let pools = GameInstance.GetStatPoolsSystem(player.GetGame());
    if IsDefined(player.m_tsunamiSaiThrowTimer) {
      pools.RequestUnregisteringListener(Cast<StatsObjectID>(player.m_tsunamiSaiThrowTimerWeapon), gamedataStatPoolType.ThrowRecovery, player.m_tsunamiSaiThrowTimer);
    }
    player.m_tsunamiSaiThrowTimer = new TsunamiSai_ThrowTimerListener();
    player.m_tsunamiSaiThrowTimer.Bind(player);
    player.m_tsunamiSaiThrowTimerWeapon = weapon.GetEntityID();
    pools.RequestRegisteringListener(Cast<StatsObjectID>(weapon.GetEntityID()), gamedataStatPoolType.ThrowRecovery, player.m_tsunamiSaiThrowTimer);
  }
}

@wrapMethod(MeleeThrowReloadEvents)
public func OnExit(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  wrappedMethod(stateContext, scriptInterface);
  let weapon: ref<WeaponObject> = MeleeTransition.GetWeaponObject(scriptInterface);
  let player = scriptInterface.executionOwner as PlayerPuppet;
  if IsDefined(weapon) && IsDefined(player) && TsunamiSai_IsTsunamiSai(weapon.GetItemID()) {
    TsunamiSai_ShowLeftSaiIfBack(player);
  }
}

@wrapMethod(MeleeThrowReloadDecisions)
protected const func ExitCondition(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  let weapon: ref<WeaponObject> = MeleeTransition.GetWeaponObject(scriptInterface);
  if IsDefined(weapon) && TsunamiSai_IsTsunamiSai(weapon.GetItemID()) {
    return this.GetInStateTime() > TweakDBInterface.GetFloat(t"TsunamiSai.handoffDelay", 0.1);
  }
  return wrappedMethod(stateContext, scriptInterface);
}

@wrapMethod(MeleeTargetingDecisions)
protected const func EnterCondition(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  let weapon: ref<WeaponObject> = MeleeTransition.GetWeaponObject(scriptInterface);
  if IsDefined(weapon) && TsunamiSai_IsTsunamiSai(weapon.GetItemID()) && MeleeTransition.IsThrownWeaponReloading(stateContext, scriptInterface) {
    return false;
  }
  return wrappedMethod(stateContext, scriptInterface);
}

