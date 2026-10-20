require 'test_helper'

class DocumentTest < ActiveSupport::TestCase
  setup do
    department = Department.create!(name: 'Caméras', code: 'CAM')
    location = Location.create!(department: department, name: 'Caméra 1', code: 'CAM1')
    category = EquipmentCategory.create!(name: 'SPECT', code_prefix: 'SPECT')
    manufacturer = Manufacturer.create!(name: 'GE', code: 'GE')
    @model = EquipmentModel.create!(manufacturer: manufacturer, category: category, name: 'Modèle A')
    @equipment = Equipment.create!(equipment_model: @model, location: location)
    @other_equipment = Equipment.create!(equipment_model: @model, location: location)
  end

  def attach_pdf(document, name: 'manuel.pdf')
    document.file.attach(io: StringIO.new('%PDF-1.4 contenu'), filename: name, content_type: 'application/pdf')
    document
  end

  def build_document(**attributes)
    attach_pdf(Document.new({ title: 'Manuel', equipment: @equipment }.merge(attributes)))
  end

  def create_document(**attributes)
    build_document(**attributes).tap(&:save!)
  end

  def next_version(previous, **attributes)
    attach_pdf(Document.new({ supersedes: previous, title: previous.title,
                              equipment_id: previous.equipment_id,
                              equipment_model_id: previous.equipment_model_id }.merge(attributes)))
  end

  # --- Création

  test 'un document rattaché à un équipement est valide et en version 1' do
    document = create_document

    assert_equal 1, document.version_number
    assert document.current?
    assert document.type_other?
  end

  test 'un document rattaché à un modèle est valide' do
    assert build_document(equipment: nil, equipment_model: @model).valid?
  end

  test 'le document est rattaché à un équipement ou à un modèle, pas aux deux ni à aucun' do
    assert_not build_document(equipment: @equipment, equipment_model: @model).valid?
    assert_not build_document(equipment: nil).valid?
  end

  test 'le titre est obligatoire' do
    assert_not build_document(title: '').valid?
  end

  test 'un fichier est obligatoire' do
    document = Document.new(title: 'Manuel', equipment: @equipment)

    assert_not document.valid?
    assert document.errors[:file].any?
  end

  test 'un type de fichier non accepté est refusé' do
    document = Document.new(title: 'Programme', equipment: @equipment)
    document.file.attach(io: StringIO.new('MZ'), filename: 'programme.exe',
                         content_type: 'application/x-msdownload', identify: false)

    assert_not document.valid?
    assert document.errors[:file].any?
  end

  test 'un fichier trop volumineux est refusé' do
    original = Document.max_file_size
    Document.max_file_size = 5

    assert_not build_document.valid?
  ensure
    Document.max_file_size = original
  end

  # --- Versions

  test 'une nouvelle version référence la précédente et incrémente le numéro' do
    first = create_document
    second = next_version(first, version_label: '2.0')
    second.save!

    assert_equal 2, second.version_number
    assert_equal first, second.supersedes
    assert_not first.reload.current?
    assert second.current?
  end

  test 'seules les versions les plus récentes sont dans la portée current' do
    first = create_document
    second = next_version(first).tap(&:save!)
    other = create_document(title: 'Procédure', equipment: @other_equipment)

    assert_equal [second, other].sort_by(&:id), Document.current.order(:id).to_a
  end

  test "une version ne peut être remplacée qu'une fois" do
    first = create_document
    next_version(first).save!

    duplicate = next_version(first)
    assert_not duplicate.valid?
    assert duplicate.errors[:supersedes].any?
  end

  test 'la nouvelle version garde le rattachement de la précédente' do
    first = create_document
    changed = next_version(first, equipment_id: @other_equipment.id)

    assert_not changed.valid?
  end

  test "l'historique ordonne toutes les versions" do
    first = create_document
    second = next_version(first).tap(&:save!)
    third = next_version(second).tap(&:save!)

    assert_equal [first, second, third], third.chain
    assert_equal [first, second, third], first.reload.chain
  end

  # --- Validité

  test 'un document expiré ou qui expire bientôt est signalé' do
    expired = build_document(valid_until: Time.zone.today - 1)
    soon = build_document(valid_until: Time.zone.today + 30)
    later = build_document(valid_until: Time.zone.today + 300)

    assert expired.expired?
    assert_not expired.expiring_soon?
    assert soon.expiring_soon?
    assert_not later.expiring_soon?
    assert_not build_document.expired?
  end
end
