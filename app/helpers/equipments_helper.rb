module EquipmentsHelper
  def status_label(status)
    t("enums.equipment.status.#{status}")
  end

  def criticality_label(criticality)
    t("enums.equipment.criticality.#{criticality}")
  end

  def status_badge(status)
    tag.span status_label(status), class: "badge badge-#{status.to_s.dasherize}"
  end

  def format_date(date)
    date ? l(date) : '—'
  end

  def format_time(time)
    time ? l(time, format: :short) : '—'
  end

  def location_label(location)
    location ? "#{location.department.name} / #{location.name}" : '—'
  end
end
