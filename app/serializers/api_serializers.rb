# Représentations JSON de l'API v1. Dates et heures au format ISO 8601.
module ApiSerializers
  module_function

  def user(user)
    {
      id: user.id,
      name: user.name,
      email: user.email_address,
      role: user.role,
      valid_until: user.valid_until&.iso8601,
      departments: user.departments.map { |department| department(department) }
    }
  end

  def department(department)
    { id: department.id, name: department.name, code: department.code }
  end

  def location(location)
    { id: location.id, name: location.name, code: location.code, department: department(location.department) }
  end

  def equipment(equipment)
    model = equipment.equipment_model
    {
      id: equipment.id,
      code: equipment.code,
      serial_number: equipment.serial_number,
      status: equipment.status,
      criticality: equipment.criticality,
      category: { id: model.category.id, name: model.category.name, code_prefix: model.category.code_prefix },
      manufacturer: { id: model.manufacturer.id, name: model.manufacturer.name, code: model.manufacturer.code },
      model: { id: model.id, name: model.name },
      location: location(equipment.location),
      acquired_on: equipment.acquired_on&.iso8601,
      commissioned_on: equipment.commissioned_on&.iso8601,
      warranty_ends_on: equipment.warranty_ends_on&.iso8601,
      decommissioned_on: equipment.decommissioned_on&.iso8601,
      notes: equipment.notes,
      archived: equipment.archived?,
      created_at: equipment.created_at.iso8601,
      updated_at: equipment.updated_at.iso8601
    }
  end

  def incident(incident, user:)
    {
      id: incident.id,
      equipment: { id: incident.equipment.id, code: incident.equipment.code },
      severity: incident.severity,
      nature: incident.nature,
      status: incident.status,
      description: incident.description,
      detected_at: incident.detected_at&.iso8601,
      resolved_at: incident.resolved_at&.iso8601,
      closed_at: incident.closed_at&.iso8601,
      root_cause: incident.root_cause,
      corrective_action: incident.corrective_action,
      mandatory_declaration: incident.mandatory_declaration,
      reported_by: person(incident.reported_by),
      assigned_to: person(incident.assigned_to),
      allowed_transitions: IncidentPolicy.new(user, incident).allowed_targets,
      created_at: incident.created_at.iso8601
    }
  end

  def event(event, user:)
    {
      id: event.id,
      equipment: { id: event.equipment.id, code: event.equipment.code },
      incident_id: event.incident_id,
      event_type: event.event_type,
      status: event.status,
      title: event.title,
      scheduled_on: event.scheduled_on&.iso8601,
      started_at: event.started_at&.iso8601,
      ended_at: event.ended_at&.iso8601,
      performed_by: person(event.performed_by),
      contractor: event.contractor,
      cost_cents: event.cost_cents,
      downtime_minutes: event.downtime_minutes,
      report: event.report,
      allowed_transitions: EventPolicy.new(user, event).allowed_targets,
      created_at: event.created_at.iso8601
    }
  end

  def person(user)
    user && { id: user.id, name: user.name }
  end
end
