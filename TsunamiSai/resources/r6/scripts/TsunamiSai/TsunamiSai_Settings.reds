module TsunamiSai

public class TsunamiSaiSettings extends ScriptableSystem {
  @runtimeProperty("ModSettings.mod", "Tsunami Sai")
  @runtimeProperty("ModSettings.category", "Flurry")
  @runtimeProperty("ModSettings.displayName", "Flurry attack speed bonus")
  @runtimeProperty("ModSettings.description", "Flurry attack speed bonus: 0.33 = 33% faster. Applies from the next stab.")
  @runtimeProperty("ModSettings.step", "0.05")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "2.0")
  public let flurrySpeed: Float = 0.33;

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
  }

  public final static func Get(game: GameInstance) -> ref<TsunamiSaiSettings> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(n"TsunamiSai.TsunamiSaiSettings") as TsunamiSaiSettings;
  }
}