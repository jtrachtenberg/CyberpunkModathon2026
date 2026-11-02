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

@wrapMethod(PlayerPuppet)
protected cb func OnItemAddedToSlot(evt: ref<ItemAddedToSlot>) -> Bool {
    let isItemAddedToSlot = wrappedMethod(evt);
    if TsunamiSai_IsTsunamiSai(evt.GetItemID()) && evt.GetSlotID() == t"AttachmentSlots.WeaponRight" {
        let transactionSystem: ref<TransactionSystem> = GameInstance.GetTransactionSystem(this.GetGame());
        let leftHandRecord: TweakDBID = t"Items.tsunamisai_weapon_left";
        let leftHand: ItemID = ItemID.None();
        let inv: array<wref<gameItemData>>;
        transactionSystem.GetItemList(this, inv);
        for item in inv {
            if ItemID.GetTDBID(item.GetID()) == leftHandRecord {
                leftHand = item.GetID();
            }
        }
        if !ItemID.IsValid(leftHand) {
            leftHand = ItemID.FromTDBID(leftHandRecord);
            transactionSystem.GiveItem(this, leftHand, 1);
        }

        transactionSystem.AddItemToSlot(this, t"AttachmentSlots.WeaponLeft", leftHand);
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