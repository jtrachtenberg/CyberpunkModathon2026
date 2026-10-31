module TsunamiSai

private func TsunamiSai_IsTsunamiSai(id: ItemID) -> Bool {
    return ItemID.GetTDBID(id) == t"Items.tsunamisai_weapon";
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