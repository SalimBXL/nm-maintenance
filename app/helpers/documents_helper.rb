module DocumentsHelper
  def document_type_label(type)
    t("enums.document.document_type.#{type}")
  end

  # Choix décrits pour le formulaire : [valeur, libellé, explication].
  def document_type_options
    Document.document_types.keys.map { |key| [key, document_type_label(key), t("enums.document.document_type_help.#{key}")] }
  end

  def version_text(document)
    text = "v#{document.version_number}"
    text += " (#{document.version_label})" if document.version_label.present?
    text
  end

  # À quoi le document est rattaché.
  def document_target(document)
    if document.equipment
      link_to document.equipment.code, document.equipment
    elsif document.equipment_model
      model = document.equipment_model
      "Modèle : #{model.manufacturer.name} – #{model.name}"
    else
      '—'
    end
  end

  def validity_badge(document)
    return '—' if document.valid_until.blank?

    date = l(document.valid_until)
    if document.expired?
      tag.span "Expiré le #{date}", class: 'badge badge-validity-expired'
    elsif document.expiring_soon?
      tag.span "Expire le #{date}", class: 'badge badge-validity-soon'
    else
      date
    end
  end
end
