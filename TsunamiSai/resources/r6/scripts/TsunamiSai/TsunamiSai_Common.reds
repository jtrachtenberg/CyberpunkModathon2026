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