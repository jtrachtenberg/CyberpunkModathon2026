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
      AnimationControllerComponent.SetAnimWrapperWeight(this, n"w_tsunamisai_dt", TsunamiSai_HasDoubleTrouble(this) ? 1.0 : 0.0);
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
    TsunamiSai_RemoveLeftSai(this);
    AnimationControllerComponent.SetAnimWrapperWeight(this, n"w_tsunamisai", 0.0);
    AnimationControllerComponent.SetAnimWrapperWeight(this, n"w_tsunamisai_dt", 0.0);
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

@wrapMethod(PlayerDevelopmentData)
public func BuyNewPerk(perkType: gamedataNewPerkType, opt forceBuy: Bool) -> Bool {
  let bought = wrappedMethod(perkType, forceBuy);
  if bought && Equals(perkType, gamedataNewPerkType.Cool_Central_Milestone_2) {
    let player = this.m_owner as PlayerPuppet;
    if IsDefined(player) {
      TsunamiSai_RefreshDoubleTrouble(player);
    }
  }
  return bought;
}

@wrapMethod(PlayerDevelopmentData)
public func SellNewPerk(perkType: gamedataNewPerkType, out perkLevelSold: Int32) -> Bool {
  let sold = wrappedMethod(perkType, perkLevelSold);
  if sold && Equals(perkType, gamedataNewPerkType.Cool_Central_Milestone_2) {
    let player = this.m_owner as PlayerPuppet;
    if IsDefined(player) {
      TsunamiSai_RefreshDoubleTrouble(player);
    }
  }
  return sold;
}

@wrapMethod(PlayerDevelopmentData)
public func ForceSellNewPerk(perkType: gamedataNewPerkType, out perkLevelSold: Int32) -> Bool {
  let sold = wrappedMethod(perkType, perkLevelSold);
  if sold && Equals(perkType, gamedataNewPerkType.Cool_Central_Milestone_2) {
    let player = this.m_owner as PlayerPuppet;
    if IsDefined(player) {
      TsunamiSai_RefreshDoubleTrouble(player);
    }
  }
  return sold;
}

//Triple Tequila
@wrapMethod(PlayerPuppet)
protected cb func OnTargetNeutraliziedEvent(evt: ref<TargetNeutraliziedEvent>) -> Bool {
  let stacks: Int32 = TsunamiSai_TequilaStacks(this);
  let result = wrappedMethod(evt);
  if !TsunamiSai_HasLeftSai(this) {
    return result;
  }
  let perks = PlayerDevelopmentSystem.GetData(this);

  if perks.IsNewPerkBoughtAnyLevel(gamedataNewPerkType.Cool_Central_Perk_2_2)
    && !StatusEffectSystem.ObjectHasStatusEffect(this, t"BaseStatusEffect.ValentinosFrenzySE") {
    StatusEffectHelper.ApplyStatusEffect(this, t"BaseStatusEffect.Triple_Tequila_Stack", this.GetEntityID());
  }  

  //Keep 'em comin'
  if perks.IsNewPerkBoughtAnyLevel(gamedataNewPerkType.Cool_Central_Perk_2_4) {
    let bonus: Float = 40.0 + 20.0 * Cast<Float>(stacks);
    if StatusEffectSystem.ObjectHasStatusEffect(this, t"BaseStatusEffect.HighTabLogic") {
      bonus -= 40.0;
    }
    PlayerStaminaHelpers.ModifyStamina(this, bonus);
  }
  return result;  
}

@wrapMethod(DamageManager)
private final static func ProcessDefensiveState(hitEvent: ref<gameHitEvent>) -> Void {
  let player = hitEvent.target as PlayerPuppet;

  if !IsDefined(player) || !AttackData.IsMelee(hitEvent.attackData.GetAttackType()) || !TsunamiSai_HasLeftSai(player) || !TsunamiSai_HasAutoBlockPerk(player) {
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
public func OnUpdate(timeDelta: Float, stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  wrappedMethod(timeDelta, stateContext, scriptInterface);
  let p = scriptInterface.executionOwner as PlayerPuppet;
  if IsDefined(p) && p.m_tsunamiSaiLeftStab {
    let t = this.GetInStateTime();
    if !p.m_tsunamiSaiLeftTrailOn && t >= 0.1 {
      TsunamiSai_LeftTrail(p, true);
      p.m_tsunamiSaiLeftTrailOn = true;
    } else if p.m_tsunamiSaiLeftTrailOn && !p.m_tsunamiSaiLeftTrailDone && t >= 0.4 {
      TsunamiSai_LeftTrail(p, false);
      p.m_tsunamiSaiLeftTrailDone = true;
    }
  }  
  if this.GetInStateTime() > 0.1 && scriptInterface.IsActionJustPressed(n"Reload") {
    let player = scriptInterface.executionOwner as PlayerPuppet;
    if TsunamiSai_CanLeftAttack(player, MeleeTransition.GetWeaponObject(scriptInterface)) {
      player.m_tsunamiSaiLeftAttackPending = true;
      stateContext.SetConditionBoolParameter(n"LightMeleeAttackPressed", true, true);
    }
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

@wrapMethod(MeleeAttackGenericEvents)
public func OnExit(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  wrappedMethod(stateContext, scriptInterface);
  let player = scriptInterface.executionOwner as PlayerPuppet;
  if IsDefined(player) && player.m_tsunamiSaiLeftStab {
    if player.m_tsunamiSaiLeftTrailOn && !player.m_tsunamiSaiLeftTrailDone {
      TsunamiSai_LeftTrail(player, false);
    }
    player.m_tsunamiSaiLeftStab = false;
  }  
  if IsDefined(player) && !stateContext.GetConditionBool(n"LightMeleeAttackPressed") {
    player.m_tsunamiSaiLeftAttackPending = false;
  }
}

@wrapMethod(MeleeFinalAttackDecisions)
protected const func EnterCondition(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  let player = scriptInterface.executionOwner as PlayerPuppet;
  if IsDefined(player) && player.m_tsunamiSaiLeftAttackPending {
    return false;
  }
  return wrappedMethod(stateContext, scriptInterface);
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
  if !TsunamiSai_HasDoubleTrouble(scriptInterface.executionOwner as PlayerPuppet) {
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

@wrapMethod(MeleeComboAttackDecisions)
protected const func EnterCondition(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  if wrappedMethod(stateContext, scriptInterface) {
    return true;
  }
  if !scriptInterface.IsActionJustPressed(n"Reload") {
    return false;
  }
  let player = scriptInterface.executionOwner as PlayerPuppet;
  if !TsunamiSai_CanLeftAttack(player, MeleeTransition.GetWeaponObject(scriptInterface)) {
    return false;
  }
  if !this.HasAttackRecord(scriptInterface, stateContext.GetIntParameter(n"meleeAttackNumber", true))
    || GameObject.IsCooldownActive(scriptInterface.owner, MeleeTransition.GetMeleeAttackCooldownName())
    || MeleeTransition.IsPlayingSyncedAnimation(scriptInterface) {
    return false;
  }
  player.m_tsunamiSaiLeftAttackPending = true;
  return true;
}

@wrapMethod(MeleeComboAttackEvents)
public func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  let player = scriptInterface.executionOwner as PlayerPuppet;
  if !IsDefined(player) || !player.m_tsunamiSaiLeftAttackPending {
    wrappedMethod(stateContext, scriptInterface);
    return;
  }
  player.m_tsunamiSaiLeftAttackPending = false;
  player.m_tsunamiSaiLeftStab = true;
  player.m_tsunamiSaiLeftTrailOn = false;
  player.m_tsunamiSaiLeftTrailDone = false;
  let chain: Int32 = stateContext.GetIntParameter(n"meleeAttackNumber", true);
  stateContext.SetPermanentIntParameter(n"meleeAttackNumber", 4, true);
  wrappedMethod(stateContext, scriptInterface);
  stateContext.SetPermanentIntParameter(n"meleeAttackNumber", chain, true);
}

@addMethod(NewPerksPerkContainerLogicController)
public func TsunamiSai_AddWire(target: gamedataNewPerkSlotType, wire: ref<inkWidget>) -> Void {
  let ref: inkWidgetRef;
  ref.widget = wire;
  let connection: NewPerksWireConnection;
  connection.m_targetSlot = target;
  ArrayPush(connection.m_wires, ref);
  ArrayPush(this.m_wiresConnections, connection);
}

//Two Right Hands
@wrapMethod(MeleeTransition)
protected func ConsumeStamina(scriptInterface: ref<StateGameScriptInterface>, attackData: ref<MeleeAttackData>) -> Void {
  let player = scriptInterface.executionOwner as PlayerPuppet;
  let weapon = MeleeTransition.GetWeaponObject(scriptInterface);
  if !IsDefined(player) || !IsDefined(weapon) || !TsunamiSai_IsTsunamiSai(weapon.GetItemID())
    || IsDefined(this as MeleeThrowAttackEvents)
    || !PlayerDevelopmentSystem.GetData(player).IsNewPerkBoughtAnyLevel(gamedataNewPerkType.Cool_Central_Perk_2_1) {
    wrappedMethod(scriptInterface, attackData);
    return;
  }
  let cost: Float = attackData.staminaCost;
  attackData.staminaCost = cost * 0.75;
  wrappedMethod(scriptInterface, attackData);
  attackData.staminaCost = cost;
}

@wrapMethod(WeaponRosterGameController)
protected cb func OnWeaponDataChanged(value: Variant) -> Bool {
  let result = wrappedMethod(value);

  if !this.m_isUnholstered || ItemID.IsValid(this.m_activeLeftWeapon.weaponID) {
    return result;
  }
  if !TsunamiSai_IsTsunamiSai(this.m_activeRightWeapon.weaponID) {
    return result;
  }
  let left = TsunamiSai_GetLeftSaiObject(this.m_player);
  if !IsDefined(left) {
    return result;
  }
  
  let data: SlotWeaponData;
  data.weaponID = left.GetItemID();
  this.ChangeWeaponData(data, this.m_leftWeaponItemData, this.m_leftWeaponRecord, this.m_leftWeaponName, true);
  this.ToggleLeftWeaponVisibility(true);
  this.m_activeLeftWeapon = data;
  return result;
}