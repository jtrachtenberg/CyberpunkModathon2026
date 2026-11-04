module TsunamiSai

private func TsunamiSai_IsTsunamiSai(id: ItemID) -> Bool {
    return ItemID.GetTDBID(id) == t"Items.tsunamisai_weapon";
}

private func TsunamiSai_HasLeftSai(player: ref<PlayerPuppet>) -> Bool {
  let left = GameInstance.GetTransactionSystem(player.GetGame()).GetItemInSlot(player, t"AttachmentSlots.WeaponLeft");
  return IsDefined(left) && ItemID.GetTDBID(left.GetItemID()) == t"Items.tsunamisai_weapon_left";
}

private func TsunamiSai_GetFreeSaiID(player: ref<PlayerPuppet>, rightHandItemId: ItemID) -> ItemID {
    let transactionSystem: ref<TransactionSystem> = GameInstance.GetTransactionSystem(player.GetGame());
    let equipment: ref<EquipmentSystemPlayerData> = EquipmentSystem.GetData(player);
    let items: array<wref<gameItemData>>;
    transactionSystem.GetItemList(player, items);
    for item in items {
        if TsunamiSai_IsTsunamiSai(item.GetID()) && item.GetID() != rightHandItemId && !equipment.IsEquipped(item.GetID()) {
            return item.GetID();
        }
    }
    return ItemID.None();
}

//reuse to allow a vanilla path to reequip the left hand after gadget when a Sai in drawn
private func TsunamiSai_FindLeftSai(player: ref<PlayerPuppet>) -> ItemID {
  let transactionSystem: ref<TransactionSystem> = GameInstance.GetTransactionSystem(player.GetGame());
  let weaponLeftRecord: TweakDBID = t"Items.tsunamisai_weapon_left";
  let leftHandItem: ItemID = ItemID.None();
  let inv: array<wref<gameItemData>>;
  transactionSystem.GetItemList(player, inv);
  for item in inv {
      if ItemID.GetTDBID(item.GetID()) == weaponLeftRecord {
          leftHandItem = item.GetID();
      }
  }

  return leftHandItem;
}

private func TsunamiSai_AddLeftSai(player: ref<PlayerPuppet>) -> Void {
  let transactionSystem: ref<TransactionSystem> = GameInstance.GetTransactionSystem(player.GetGame());
  let leftHandItem: ItemID = TsunamiSai_FindLeftSai(player);

  //first draw
  if !ItemID.IsValid(leftHandItem) {
      leftHandItem = ItemID.FromTDBID(t"Items.tsunamisai_weapon_left");
      transactionSystem.GiveItem(player, leftHandItem, 1);
  }
  transactionSystem.AddItemToSlot(player, t"AttachmentSlots.WeaponLeft", leftHandItem);
}

@wrapMethod(PlayerPuppet)
protected cb func OnItemAddedToSlot(evt: ref<ItemAddedToSlot>) -> Bool {
    let isItemAddedToSlot = wrappedMethod(evt);
    if TsunamiSai_IsTsunamiSai(evt.GetItemID()) && evt.GetSlotID() == t"AttachmentSlots.WeaponRight" {
      TsunamiSai_AddLeftSai(this);
    }
    return isItemAddedToSlot;
}

@wrapMethod(PlayerPuppet)
protected cb func OnItemRemovedFromSlot(evt: ref<ItemRemovedFromSlot>) -> Bool {
    let isItemRemovedFromSlot = wrappedMethod(evt);

    if TsunamiSai_IsTsunamiSai(evt.GetItemID()) && evt.GetSlotID() == t"AttachmentSlots.WeaponRight" {
        let transactionSystem: ref<TransactionSystem> = GameInstance.GetTransactionSystem(this.GetGame());
        let left: ref<ItemObject> = transactionSystem.GetItemInSlot(this, t"AttachmentSlots.WeaponLeft");
        if IsDefined(left) && ItemID.GetTDBID(left.GetItemID()) == t"Items.tsunamisai_weapon_left" {
            transactionSystem.RemoveItemFromSlot(this, t"AttachmentSlots.WeaponLeft", true);
        }
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

//return the left sai if equipped in the right hand after a gadget
@wrapMethod(EquipmentSystemPlayerData)
public func GetItemIDfromEquipmentManipulationAction(eqManipulationAction: EquipmentManipulationAction, currentState: SSlotActiveItems) -> SSlotActiveItems {
  let state: SSlotActiveItems = wrappedMethod(eqManipulationAction, currentState);
  if this.IsEquipmentManipulationAnUnequipRequest(eqManipulationAction)
      && Equals(this.GetRequestSlotFromEquipmentManipulationAction(eqManipulationAction), EquipmentManipulationRequestSlot.Left)
      && !ItemID.IsValid(state.leftHandItem)
      && TsunamiSai_IsTsunamiSai(state.rightHandItem) {
    let player: ref<PlayerPuppet> = this.m_owner as PlayerPuppet;
    if IsDefined(player) {
      let leftSai: ItemID = TsunamiSai_FindLeftSai(player);
      if ItemID.IsValid(leftSai) {
        state.leftHandItem = leftSai;
      }
    }
  }
  return state;
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

  //default to throw when not in combat
  if !this.IsPlayerInCombat(scriptInterface) {
    return false;
  }
  return this.IsBlockPressed(stateContext, scriptInterface)
    && this.CanWeaponDeflect(stateContext, scriptInterface)
    && !this.GetStaticBoolParameterDefault("disabled", false)
    && !GameObject.IsCooldownActive(scriptInterface.owner, n"Deflect");
}

@wrapMethod(MeleeDeflectDecisions)
protected const func ToMeleeBlock(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  let weapon: ref<WeaponObject> = MeleeTransition.GetWeaponObject(scriptInterface);
  if IsDefined(weapon) && TsunamiSai_IsTsunamiSai(weapon.GetItemID()) {
    return false;
  }
  return wrappedMethod(stateContext, scriptInterface);  
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