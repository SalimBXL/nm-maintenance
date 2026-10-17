module IncidentsHelper
  def severity_label(severity)
    t("enums.incident.severity.#{severity}")
  end

  def nature_label(nature)
    t("enums.incident.nature.#{nature}")
  end

  def incident_status_label(status)
    t("enums.incident.status.#{status}")
  end

  # Choix décrits pour les formulaires : [valeur, libellé, explication].
  def severity_options
    Incident.severities.keys.map { |key| [key, severity_label(key), t("enums.incident.severity_help.#{key}")] }
  end

  def nature_options
    Incident.natures.keys.map { |key| [key, nature_label(key), t("enums.incident.nature_help.#{key}")] }
  end

  def severity_badge(severity)
    tag.span severity_label(severity), class: "badge badge-severity-#{severity}"
  end

  def incident_status_badge(status)
    tag.span incident_status_label(status), class: "badge badge-incident-#{status.to_s.dasherize}"
  end

  def incident_title(incident)
    "Incident ##{incident.id}"
  end

  def transition_label(incident, target)
    case target
    when "qualified" then "Qualifier l'incident"
    when "in_progress" then incident.resolved? ? "Rouvrir (remettre en cours)" : "Prendre en charge (passer en cours)"
    when "resolved" then "Marquer comme résolu"
    when "closed" then "Clôturer l'incident"
    else incident_status_label(target)
    end
  end
end
