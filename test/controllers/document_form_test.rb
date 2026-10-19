require 'test_helper'

class DocumentFormTest < ActionDispatch::IntegrationTest
  setup do
    department = Department.create!(name: 'Caméras', code: 'CAM')
    location = Location.create!(department: department, name: 'Caméra 1', code: 'CAM1')
    category = EquipmentCategory.create!(name: 'SPECT', code_prefix: 'SPECT')
    manufacturer = Manufacturer.create!(name: 'GE', code: 'GE')
    model = EquipmentModel.create!(manufacturer: manufacturer, category: category, name: 'Modèle A')
    @equipment = Equipment.create!(equipment_model: model, location: location)
    @model = model

    @manager = User.create!(name: 'Responsable', email_address: 'resp@example.com', password: 'secret', role: :technical_manager)
  end

  test 'le formulaire relie chaque choix au menu correspondant' do
    sign_in_as @manager

    get new_document_url

    assert_response :success
    assert_select "form[data-controller='target-switch']"
    assert_select "input[type=radio][name='document[target_kind]'][data-action='change->target-switch#update']", 2
    assert_select "[data-target-switch-target='equipment'] select[name='document[equipment_id]']"
    assert_select "[data-target-switch-target='model'] select[name='document[equipment_model_id]']"
  end

  test "depuis la fiche d'un équipement, « un équipement précis » est coché et l'équipement choisi" do
    sign_in_as @manager

    get new_document_url(equipment_id: @equipment.id)

    assert_select 'input#document_target_kind_equipment[checked]'
    assert_select "select[name='document[equipment_id]'] option[selected][value='#{@equipment.id}']"
  end

  test "depuis un modèle, « tous les appareils d'un modèle » est coché" do
    sign_in_as @manager

    get new_document_url(equipment_model_id: @model.id)

    assert_select 'input#document_target_kind_model[checked]'
  end
end
