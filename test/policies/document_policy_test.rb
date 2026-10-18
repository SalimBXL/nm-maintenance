require 'test_helper'

class DocumentPolicyTest < ActiveSupport::TestCase
  setup do
    department = Department.create!(name: 'Caméras', code: 'CAM')
    location = Location.create!(department: department, name: 'Caméra 1', code: 'CAM1')
    category = EquipmentCategory.create!(name: 'SPECT', code_prefix: 'SPECT')
    manufacturer = Manufacturer.create!(name: 'GE', code: 'GE')
    model = EquipmentModel.create!(manufacturer: manufacturer, category: category, name: 'Modèle A')
    @equipment = Equipment.create!(equipment_model: model, location: location)

    @admin = make_user(:admin)
    @manager = make_user(:technical_manager)
    @technician = make_user(:technician)
    @reporter = make_user(:reporter)
  end

  def make_user(role)
    User.create!(name: role.to_s, email_address: "#{role}@example.com", password: 'secret', role: role)
  end

  def document
    record = Document.new(title: 'Manuel', equipment: @equipment)
    record.file.attach(io: StringIO.new('%PDF-1.4 contenu'), filename: 'manuel.pdf', content_type: 'application/pdf')
    record.save!
    record
  end

  test 'tout utilisateur actif consulte et télécharge' do
    [@admin, @manager, @technician, @reporter].each do |user|
      policy = DocumentPolicy.new(user, document)
      assert policy.index?
      assert policy.show?
      assert policy.download?
    end

    assert_not DocumentPolicy.new(nil, document).show?
  end

  test 'seuls administrateur et responsable technique ajoutent et modifient' do
    [@admin, @manager].each do |user|
      assert DocumentPolicy.new(user, Document).create?
      assert DocumentPolicy.new(user, document).update?
    end

    [@technician, @reporter].each do |user|
      assert_not DocumentPolicy.new(user, Document).create?
      assert_not DocumentPolicy.new(user, document).update?
    end
  end

  test 'une nouvelle version ne se crée que sur la version la plus récente' do
    first = document
    newer = Document.new(title: 'Manuel', equipment: @equipment, supersedes: first)
    newer.file.attach(io: StringIO.new('%PDF-1.4 v2'), filename: 'manuel-v2.pdf', content_type: 'application/pdf')
    newer.save!

    assert_not DocumentPolicy.new(@manager, first.reload).new_version?
    assert DocumentPolicy.new(@manager, newer).new_version?
    assert_not DocumentPolicy.new(@technician, newer).new_version?
  end

  test "un document archivé n'accepte plus de nouvelle version" do
    archived = document
    archived.archive!

    assert_not DocumentPolicy.new(@manager, archived).new_version?
  end
end
