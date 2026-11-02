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