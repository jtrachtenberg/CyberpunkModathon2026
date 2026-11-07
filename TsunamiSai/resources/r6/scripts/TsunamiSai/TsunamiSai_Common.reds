module TsunamiSai

private func TsunamiSai_IsTsunamiSai(id: ItemID) -> Bool {
    return ItemID.GetTDBID(id) == t"Items.tsunamisai_weapon";
}

private func TsunamiSai_GetLeftSaiObject(player: ref<PlayerPuppet>) -> ref<ItemObject> {
  let leftHandItem = GameInstance.GetTransactionSystem(player.GetGame()).GetItemInSlot(player, t"AttachmentSlots.TSaiLeftGrip");
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
  transactionSystem.AddItemToSlot(player, t"AttachmentSlots.TSaiLeftGrip", leftHandItem, true, null, ERenderingPlane.RPl_Weapon);
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