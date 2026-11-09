module TsunamiSai

private func TsunamiSai_IsTsunamiSai(id: ItemID) -> Bool {
    return ItemID.GetTDBID(id) == t"Items.tsunamisai_weapon";
}

private func TsunamiSai_GetLeftSaiObject(player: ref<PlayerPuppet>) -> ref<ItemObject> {
  let ts = GameInstance.GetTransactionSystem(player.GetGame());
  let leftHandItem = ts.GetItemInSlot(player, t"AttachmentSlots.TSaiLeftGrip");
  if !IsDefined(leftHandItem) {
    leftHandItem = ts.GetItemInSlot(player, t"AttachmentSlots.TSaiLeftGripDT");
  }
  if IsDefined(leftHandItem) && ItemID.GetTDBID(leftHandItem.GetItemID()) == t"Items.tsunamisai_weapon_left" {
    return leftHandItem;
  }
  return null;
}

private func TsunamiSai_HasLeftSai(player: ref<PlayerPuppet>) -> Bool {
    return IsDefined(TsunamiSai_GetLeftSaiObject(player)) && TsunamiSai_IsLeftHandFree(player);
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
  transactionSystem.AddItemToSlot(player, TsunamiSai_LeftGripSlot(player), leftHandItem, true, null, ERenderingPlane.RPl_Weapon);
}

private func TsunamiSai_IsLeftHandFree(player: ref<PlayerPuppet>) -> Bool {
  let inWeaponLeft = GameInstance.GetTransactionSystem(player.GetGame()).GetItemInSlot(player, t"AttachmentSlots.WeaponLeft");
  return !IsDefined(inWeaponLeft) && !TsunamiSai_IsThrownSaiAway(player);
}

// Basically 'still reloading'
private func TsunamiSai_IsThrownSaiAway(player: ref<PlayerPuppet>) -> Bool {
  let right = GameInstance.GetTransactionSystem(player.GetGame()).GetItemInSlot(player, t"AttachmentSlots.WeaponRight");
  if !IsDefined(right) || !TsunamiSai_IsTsunamiSai(right.GetItemID()) {
    return false;
  }
  return !GameInstance.GetStatPoolsSystem(player.GetGame()).HasStatPoolValueReachedMax(Cast<StatsObjectID>(right.GetEntityID()), gamedataStatPoolType.ThrowRecovery);
}

private func TsunamiSai_ShowLeftSaiIfBack(player: ref<PlayerPuppet>) -> Void {
  let left = TsunamiSai_GetLeftSaiObject(player) as WeaponObject;
  if IsDefined(left) {
    left.SetVisible(TsunamiSai_IsLeftHandFree(player));
  }
}

private func TsunamiSai_HasAutoBlockPerk(player: ref<PlayerPuppet>) -> Bool {
  return PlayerDevelopmentSystem.GetData(player).IsNewPerkBoughtAnyLevel(gamedataNewPerkType.Cool_Right_Perk_3_3);
}

private func TsunamiSai_TequilaStacks(player: ref<PlayerPuppet>) -> Int32 {
  let appliedStats: array<ref<StatusEffect>>;
  GameInstance.GetStatusEffectSystem(player.GetGame()).GetAppliedEffectsWithID(player.GetEntityID(), t"BaseStatusEffect.Triple_Tequila_Stack", appliedStats);
  return ArraySize(appliedStats) > 0 ? Cast<Int32>(appliedStats[0].GetStackCount()) : 0;
}

//Add UI for new Perk
private func TsunamiSai_MakeWire(name: CName, part: CName, anchor: inkEAnchor, anchorX: Float, width: Float) -> ref<inkImage> {
  let wire = new inkImage();
  wire.SetName(name);
  wire.SetAtlasResource(r"base\\gameplay\\gui\\fullscreen\\perks\\perks_new.inkatlas");
  wire.SetTexturePart(part);
  wire.SetFitToContent(false);
  wire.SetSize(width, 58.0);
  wire.SetAnchor(anchor);
  wire.SetAnchorPoint(anchorX, 1.0);
  wire.SetMargin(0.0, 0.0, 0.0, 55.0);   // WIRE_MARGIN_BOTTOM
  wire.BindProperty(n"tintColor", n"PerkWire.wireColor");
  wire.SetVisible(false);
  return wire;
}

//left Attack
@addField(PlayerPuppet)
public let m_tsunamiSaiLeftAttackPending: Bool;

private func TsunamiSai_HasDoubleTrouble(player: ref<PlayerPuppet>) -> Bool {
  return PlayerDevelopmentSystem.GetData(player).IsNewPerkBoughtAnyLevel(gamedataNewPerkType.Cool_Central_Milestone_2);
}

private func TsunamiSai_CanLeftAttack(player: ref<PlayerPuppet>, weapon: ref<WeaponObject>) -> Bool {
  return IsDefined(player) && IsDefined(weapon) && TsunamiSai_IsTsunamiSai(weapon.GetItemID())
    && TsunamiSai_HasLeftSai(player) && TsunamiSai_HasDoubleTrouble(player);
}

private func TsunamiSai_LeftGripSlot(player: ref<PlayerPuppet>) -> TweakDBID {
  if TsunamiSai_HasDoubleTrouble(player) {
    return t"AttachmentSlots.TSaiLeftGripDT";
  }
  return t"AttachmentSlots.TSaiLeftGrip";
}

private func TsunamiSai_RemoveLeftSai(player: ref<PlayerPuppet>) -> Void {
  let ts = GameInstance.GetTransactionSystem(player.GetGame());
  if IsDefined(ts.GetItemInSlot(player, t"AttachmentSlots.TSaiLeftGrip")) {
    ts.RemoveItemFromSlot(player, t"AttachmentSlots.TSaiLeftGrip", true);
  }
  if IsDefined(ts.GetItemInSlot(player, t"AttachmentSlots.TSaiLeftGripDT")) {
    ts.RemoveItemFromSlot(player, t"AttachmentSlots.TSaiLeftGripDT", true);
  }
}

//register anims change on perk if drawn
private func TsunamiSai_RefreshDoubleTrouble(player: ref<PlayerPuppet>) -> Void {
  let right = GameInstance.GetTransactionSystem(player.GetGame()).GetItemInSlot(player, t"AttachmentSlots.WeaponRight");
  if !IsDefined(right) || !TsunamiSai_IsTsunamiSai(right.GetItemID()) {
    return;
  }
  AnimationControllerComponent.SetAnimWrapperWeight(player, n"w_tsunamisai_dt", TsunamiSai_HasDoubleTrouble(player) ? 1.0 : 0.0);
}

//left attack FX

@addField(PlayerPuppet)
public let m_tsunamiSaiLeftStab: Bool;
@addField(PlayerPuppet)
public let m_tsunamiSaiLeftTrailOn: Bool;
@addField(PlayerPuppet)
public let m_tsunamiSaiLeftTrailDone: Bool;

private func TsunamiSai_LeftTrail(player: ref<PlayerPuppet>, start: Bool) -> Void {
  let left = TsunamiSai_GetLeftSaiObject(player);
  let right = GameInstance.GetTransactionSystem(player.GetGame()).GetItemInSlot(player, t"AttachmentSlots.WeaponRight") as WeaponObject;
  if !IsDefined(left) || !IsDefined(right) {
    return;
  }

  let name = StringToName(NameToString(right.GetCurrentMeleeTrailEffectName()) + "_tsai");
  if start {
    GameObjectEffectHelper.StartEffectEvent(left, name);
  } else {
    GameObjectEffectHelper.BreakEffectLoopEvent(left, name);
  }
}

//Flurry
@addField(PlayerPuppet) public let m_tsunamiSaiFlurryStart: Bool;
@addField(PlayerPuppet) public let m_tsunamiSaiFlurryEnd: Float;   
@addField(PlayerPuppet) public let m_tsunamiSaiFlurryNextLeft: Bool;
@addField(PlayerPuppet) public let m_tsunamiSaiFlurryStacks: Int32;
@addField(PlayerPuppet) public let m_tsunamiSaiFlurryRefund: Float;

private func TsunamiSai_Now(player: ref<PlayerPuppet>) -> Float {
  return EngineTime.ToFloat(GameInstance.GetSimTime(player.GetGame()));
}

private func TsunamiSai_InFlurry(player: ref<PlayerPuppet>) -> Bool {
  return player.m_tsunamiSaiFlurryEnd > 0.0 && TsunamiSai_Now(player) < player.m_tsunamiSaiFlurryEnd;
}

private func TsunamiSai_StartFlurry(player: ref<PlayerPuppet>) -> Void {
  let game = player.GetGame();
  let id = player.GetEntityID();
  let effects = GameInstance.GetStatusEffectSystem(game);
  let stacks: Int32 = TsunamiSai_TequilaStacks(player);
  let atMax: Bool = false;
  let applied: array<ref<StatusEffect>>;
  effects.GetAppliedEffectsWithID(id, t"BaseStatusEffect.Triple_Tequila_Stack", applied);
  if ArraySize(applied) > 0 {
    atMax = applied[0].GetStackCount() >= applied[0].GetMaxStacks();
  }
  let perks = PlayerDevelopmentSystem.GetData(player);
  let duration: Float = GameInstance.GetStatsSystem(game).GetStatValue(Cast<StatsObjectID>(id), gamedataStatType.ValentinosFrenzy_Duration);
  if atMax && perks.IsNewPerkBoughtAnyLevel(gamedataNewPerkType.Cool_Central_Perk_2_3) {
    duration += 1.0;
  }
  StatusEffectHelper.ApplyStatusEffectForTimeWindow(player, t"BaseStatusEffect.ValentinosFrenzySE", id, 0.0, duration);
  if stacks > 0 {
    effects.ApplyStatusEffect(id, t"BaseStatusEffect.TsunamiSaiFlurryTequila", t"", id, Cast<Uint32>(stacks));
  }
  if perks.IsNewPerkBoughtAnyLevel(gamedataNewPerkType.Cool_Central_Perk_2_3) {
    StatusEffectHelper.ApplyStatusEffect(player, t"BaseStatusEffect.TsunamiSaiFlurryRate");
  }
  StatusEffectHelper.RemoveStatusEffect(player, t"BaseStatusEffect.Triple_Tequila_Stack");
  player.m_tsunamiSaiFlurryStacks = stacks;
  player.m_tsunamiSaiFlurryEnd = TsunamiSai_Now(player) + duration;
  player.m_tsunamiSaiFlurryNextLeft = false;
}

// Vanilla's end (ValentinosFrenzyEvents.OnExit, shootTransitions.script:600-607).
private func TsunamiSai_EndFlurry(player: ref<PlayerPuppet>) -> Void {
  if player.m_tsunamiSaiFlurryEnd <= 0.0 {
    return;
  }
  player.m_tsunamiSaiFlurryEnd = 0.0;
  player.m_tsunamiSaiFlurryRefund = 0.0;
  StatusEffectHelper.RemoveStatusEffect(player, t"BaseStatusEffect.ValentinosFrenzySE");
  if player.m_tsunamiSaiFlurryStacks > 0 {
    StatusEffectHelper.RemoveStatusEffect(player, t"BaseStatusEffect.TsunamiSaiFlurryTequila", Cast<Uint32>(player.m_tsunamiSaiFlurryStacks));
  }
  StatusEffectHelper.RemoveStatusEffect(player, t"BaseStatusEffect.TsunamiSaiFlurryRate");
  player.m_tsunamiSaiFlurryStacks = 0;
}

private func TsunamiSai_RefreshHud(player: ref<PlayerPuppet>) -> Void {
  let bb = GameInstance.GetBlackboardSystem(player.GetGame()).Get(GetAllBlackboardDefs().UI_EquipmentData);
  if IsDefined(bb) {
    bb.SignalVariant(GetAllBlackboardDefs().UI_EquipmentData.EquipmentData);
  }
}

private func TsunamiSai_FinisherOffered(player: ref<PlayerPuppet>, scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  if !player.PlayerLastUsedPad() {
    return false;
  }
  let target = DefaultTransition.GetTargetObject(scriptInterface, 5.0);
  if !IsDefined(target) {
    return false;
  }
  let condition = new NewPerkFinisherCondition();
  return condition.Test(player, target);
}

//Heavy Block
@addField(PlayerPuppet)
public let m_tsunamiSaiReloadDownAt: Float;
@addField(PlayerPuppet)
public let m_tsunamiSaiHeavyBlock: Bool;
@addField(PlayerPuppet)
public let m_tsunamiSaiHeavyBlockAt: Float;
@addField(NPCPuppet)
public let m_tsunamiSaiDisarms: Int32;
@addField(PlayerPuppet)
public let m_tsunamiSaiBlockDownAt: Float;  
 
private func TsunamiSai_Disarm(npc: ref<NPCPuppet>) -> Void {
  npc.DropWeapons();
  StatusEffectHelper.ApplyStatusEffect(npc, t"BaseStatusEffect.Stagger");
  npc.m_tsunamiSaiDisarms += 1;
  if npc.m_tsunamiSaiDisarms >= 2 {
    StatusEffectHelper.ApplyStatusEffect(npc, t"BaseStatusEffect.CrippledArmRight");
    let ts = GameInstance.GetTransactionSystem(npc.GetGame());
    let items: array<wref<gameItemData>>;
    ts.GetItemList(npc, items);
    for it in items {
      if IsDefined(it) && (it.HasTag(n"Weapon") || it.HasTag(n"MeleeWeapon") || it.HasTag(n"RangedWeapon")) {
        ts.RemoveItem(npc, it.GetID(), it.GetQuantity());
      }
    }
  }
}

private func TsunamiSai_ParryDisarm(npc: ref<NPCPuppet>) -> Void {
  TsunamiSai_Disarm(npc);
  StatusEffectHelper.ApplyStatusEffect(npc, t"BaseStatusEffect.TsunamiSaiParryStun");
}