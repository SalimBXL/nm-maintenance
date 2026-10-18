module EventsHelper
  def event_type_label(type)
    t("enums.event.event_type.#{type}")
  end

  def event_status_label(status)
    t("enums.event.status.#{status}")
  end

  def event_status_badge(status)
    tag.span event_status_label(status), class: "badge badge-event-#{status.to_s.dasherize}"
  end

  # Choix décrits pour le formulaire : [valeur, libellé, explication].
  def event_type_options
    Event.event_types.keys.map { |key| [key, event_type_label(key), t("enums.event.event_type_help.#{key}")] }
  end

  def event_title(event)
    "Intervention ##{event.id}"
  end

  def event_transition_label(target)
    case target
    when 'in_progress' then "Démarrer l'intervention"
    when 'completed' then 'Terminer et saisir le rapport'
    when 'cancelled' then "Annuler l'intervention"
    else event_status_label(target)
    end
  end

  # 90 -> « 1 h 30 » ; 45 -> « 45 min » ; vide -> « — »
  def format_downtime(minutes)
    return '—' if minutes.nil?

    hours, rest = minutes.divmod(60)
    if hours.zero?
      "#{rest} min"
    elsif rest.zero?
      "#{hours} h"
    else
      "#{hours} h #{rest.to_s.rjust(2, '0')}"
    end
  end

  # 12050 -> « 120,50 € »
  def format_cost(cents)
    return '—' if cents.nil?

    "#{format('%.2f', cents / 100.0).tr('.', ',')} €"
  end

  # Valeur d'un champ date-heure HTML (AAAA-MM-JJTHH:MM) à partir d'une heure.
  def datetime_field_value(time)
    time&.strftime('%Y-%m-%dT%H:%M')
  end
end
