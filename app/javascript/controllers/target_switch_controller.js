import { Controller } from "@hotwired/stimulus"

// Formulaire « Ajouter un document » : n'affiche que le choix (équipement ou
// modèle) qui correspond au bouton radio coché. Le choix non retenu est masqué
// ET désactivé : il n'est donc jamais envoyé avec le formulaire.
export default class extends Controller {
  static targets = ["equipment", "model"]

  connect() {
    this.update()
  }

  update() {
    const checked = this.element.querySelector("input[name='document[target_kind]']:checked")
    const kind = checked ? checked.value : "equipment"

    this.toggle(this.equipmentTarget, kind === "equipment")
    this.toggle(this.modelTarget, kind === "model")
  }

  toggle(container, visible) {
    container.hidden = !visible
    container.querySelectorAll("select").forEach((select) => {
      select.disabled = !visible
    })
  }
}
