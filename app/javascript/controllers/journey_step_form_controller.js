import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["settingsContainer", "settingsContent", "settingsIcon"]

  toggleSettings() {
    if (this.hasSettingsContentTarget && this.hasSettingsIconTarget) {
      const isHidden = this.settingsContentTarget.classList.contains("hidden")
      
      if (isHidden) {
        this.settingsContentTarget.classList.remove("hidden")
        this.settingsIconTarget.style.transform = "rotate(180deg)"
      } else {
        this.settingsContentTarget.classList.add("hidden")
        this.settingsIconTarget.style.transform = "rotate(0deg)"
      }
    }
  }
}