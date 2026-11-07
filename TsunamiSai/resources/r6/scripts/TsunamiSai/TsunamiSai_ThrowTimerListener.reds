module TsunamiSai

public class TsunamiSai_ThrowTimerListener extends ScriptStatPoolsListener {
  private let m_player: wref<PlayerPuppet>;

  public func Bind(player: ref<PlayerPuppet>) -> Void {
    this.m_player = player;
  }

  protected cb func OnStatPoolMaxValueReached(value: Float) -> Bool {
    if IsDefined(this.m_player) {
      TsunamiSai_ShowLeftSaiIfBack(this.m_player);
    }
    return true;
  }
}

// Kept on the player so that the listener lives as long as the wait does (vanilla keeps its own in a field too).
@addField(PlayerPuppet)
public let m_tsunamiSaiThrowTimer: ref<TsunamiSai_ThrowTimerListener>;

@addField(PlayerPuppet)
public let m_tsunamiSaiThrowTimerWeapon: EntityID;