module TsunamiSai

enum TsunamiSaiGlow {
  Red = 0,
  Pink = 1,
  Blue = 2,
  Green = 3,
  White = 4,
  Black = 5,
  Off = 6,
}

public class TsunamiSaiSettings extends ScriptableSystem {
  @runtimeProperty("ModSettings.mod", "Tsunami Sai")
  @runtimeProperty("ModSettings.category", "Flurry")
  @runtimeProperty("ModSettings.displayName", "Flurry attack speed bonus")
  @runtimeProperty("ModSettings.description", "Flurry attack speed bonus: 0.33 = 33% faster. Applies from the next stab.")
  @runtimeProperty("ModSettings.step", "0.05")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "2.0")
  public let flurrySpeed: Float = 0.33;

  @runtimeProperty("ModSettings.mod", "Tsunami Sai")
  @runtimeProperty("ModSettings.category", "Appearance")
  @runtimeProperty("ModSettings.displayName", "Glow colour")
  @runtimeProperty("ModSettings.description", "The colour of the sai's glow. Off turns the glow off.")
  @runtimeProperty("ModSettings.displayValues.Red", "Red")
  @runtimeProperty("ModSettings.displayValues.Pink", "Pink")
  @runtimeProperty("ModSettings.displayValues.Blue", "Blue")
  @runtimeProperty("ModSettings.displayValues.Green", "Green")
  @runtimeProperty("ModSettings.displayValues.White", "White")
  @runtimeProperty("ModSettings.displayValues.Black", "Black")
  @runtimeProperty("ModSettings.displayValues.Off", "Off")
  public let glowColor: TsunamiSaiGlow = TsunamiSaiGlow.Red;  


  private func OnAttach() -> Void {
    this.ListenToModSettings(true);
  }

  private func OnDetach() -> Void {
    this.ListenToModSettings(false);
  }

  @if(ModuleExists("ModSettingsModule"))
  private final func ListenToModSettings(on: Bool) -> Void {
    if on {
      ModSettings.RegisterListenerToClass(this);          // keeps flurrySpeed up to date
      ModSettings.RegisterListenerToModifications(this);  // calls OnModSettingsChange
    } else {
      ModSettings.UnregisterListenerToModifications(this);
      ModSettings.UnregisterListenerToClass(this);
    }
  }

  @if(!ModuleExists("ModSettingsModule"))
  private final func ListenToModSettings(on: Bool) -> Void {}

  public func OnModSettingsChange() -> Void {
    let player = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if IsDefined(player) {
        TsunamiSai_ApplyGlow(player);
    }    
  }

  public final static func Get(game: GameInstance) -> ref<TsunamiSaiSettings> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(n"TsunamiSai.TsunamiSaiSettings") as TsunamiSaiSettings;
  }
}