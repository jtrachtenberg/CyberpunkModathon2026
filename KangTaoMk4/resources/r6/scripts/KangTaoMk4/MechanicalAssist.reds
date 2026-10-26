// from quickhackEffectors.script

module KangTaoMk4

public class MechanicalAssistEffector extends SetFriendlyEffector {
    private let m_assisted: wref<GameObject>;
    private let m_ownAttitudeToV: EAIAttitude;
    private let m_ownGroup: CName;
    private let m_hasHandedBack: Bool = false;

    private func setAssisted(inOwner: ref<GameObject>) -> Void {
        this.m_assisted = inOwner;
    }

    private func setOwnGroup(inOwnGroup: CName) -> Void {
        this.m_ownGroup = inOwnGroup;
    }

    private func setOwnAttitudeToV(inAttitude: EAIAttitude) -> Void {
        this.m_ownAttitudeToV = inAttitude;
    }

    private func setIsHandedBack( isHandedBack: Bool) -> Void {
        this.m_hasHandedBack = isHandedBack;
    }

    private func IsDrone(inOwner: wref<GameObject>) -> Bool {
        return IsDefined(inOwner as ScriptedPuppet) && Equals((inOwner as ScriptedPuppet).GetNPCType(), gamedataNPCType.Drone);
    }

    private func doHandBack(inOwner: ref<GameObject>) -> Void {
        if this.m_hasHandedBack {
            return;
        }
        this.setIsHandedBack(true);
        let puppet: ref<ScriptedPuppet> = inOwner as ScriptedPuppet;
        if !IsDefined(puppet) || !puppet.IsAttached() {
            return;
        }

        let player: ref<PlayerPuppet> = GetPlayer(inOwner.GetGame());
        let smi: ref<SquadScriptInterface>;
        if IsDefined(player) && AISquadHelper.GetSquadMemberInterface(player, smi) {
            smi.Leave(inOwner);
        }

        let agent: ref<AttitudeAgent> = inOwner.GetAttitudeAgent();
        if IsDefined(agent) && NotEquals(this.m_ownGroup, n"") {
            agent.SetAttitudeGroup(this.m_ownGroup);
            if IsDefined(player) {
                agent.SetAttitudeTowards(player.GetAttitudeAgent(), this.m_ownAttitudeToV);
            }
        }
    }

    protected func ActionOn(owner: ref<GameObject>) -> Void {
        this.setAssisted(owner);
        this.m_hasHandedBack = false;

        let agent: ref<AttitudeAgent> = owner.GetAttitudeAgent();
        let player: ref<PlayerPuppet> = GetPlayer(owner.GetGame());
        if IsDefined(agent) {
            this.setOwnGroup(agent.GetAttitudeGroup());
            if IsDefined(player) {
                this.setOwnAttitudeToV(agent.GetAttitudeTowards(player.GetAttitudeAgent()));
            }
        }

        super.ActionOn(owner);
    }

    protected func ChangeAttitude(owner: wref<GameObject>, target: wref<GameObject>) -> Bool {
        if !IsDefined(owner) || !IsDefined(target) {
            return false;
        }

        let ownerAgent: ref<AttitudeAgent> = owner.GetAttitudeAgent();
        let targetAgent: ref<AttitudeAgent> = target.GetAttitudeAgent();

        if !IsDefined(ownerAgent) || !IsDefined(targetAgent) {
            return false;
        }

        //aiSquadHelper.script
        let mates: array<wref<Entity>>;
        if AISquadHelper.GetSquadmates(target as ScriptedPuppet, mates) {
            for mate in mates {
                let other: ref<GameObject> = mate as GameObject;
                if IsDefined(other) && other != owner {
                    ownerAgent.SetAttitudeTowards(other.GetAttitudeAgent(),EAIAttitude.AIA_Friendly);
                }
            }
        }
        if this.IsDrone(owner) {
            ownerAgent.SetAttitudeGroup(targetAgent.GetAttitudeGroup());
        } else {
            ownerAgent.SetAttitudeGroupUnsavable(targetAgent.GetAttitudeGroup());
        }
        ownerAgent.SetAttitudeTowards(targetAgent, EAIAttitude.AIA_Friendly);

        return true;
    }

    protected func ActionOff(owner: ref<GameObject>) -> Void {
        if !this.IsDrone(owner) {
            this.doHandBack(owner);
        }
    }

    protected func Uninitialize(game: GameInstance) -> Void {
        if IsDefined(this.m_assisted) && !this.IsDrone(this.m_assisted) {
            this.doHandBack(this.m_assisted);
        }
    }
}

@wrapMethod(ScriptedPuppet)
private const func GetQuickHackDuration(quickHackRecord: wref<ObjectAction_Record>, rootObject: wref<GameObject>, targetID: StatsObjectID, instigatorID: EntityID) -> Float {
    if IsDefined(quickHackRecord) && Equals(quickHackRecord.GetID(), t"QuickHack.KangTaoMechanicalAssist") {
        if Equals(this.GetNPCType(), gamedataNPCType.Drone) {
            return wrappedMethod(TweakDBInterface.GetObjectActionRecord(t"QuickHack.KangTaoMechanicalAssistDrone"), rootObject, targetID, instigatorID);
        }
        if Equals(this.GetNPCType(), gamedataNPCType.Android) {
            return wrappedMethod(TweakDBInterface.GetObjectActionRecord(t"QuickHack.KangTaoMechanicalAssistAndroid"), rootObject, targetID, instigatorID);
        }        

        return 0.0;
    }
    return wrappedMethod(quickHackRecord, rootObject, targetID, instigatorID);
}