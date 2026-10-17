require 'test_helper'

class EquipmentTest < ActiveSupport::TestCase
  setup do
    department = Department.create!(name: 'Caméras', code: 'CAM')
    @camera1 = Location.create!(department: department, name: 'Caméra 1', code: 'CAM1')
    @camera2 = Location.create!(department: department, name: 'Caméra 2', code: 'CAM2')

    @spect = EquipmentCategory.create!(name: 'SPECT', code_prefix: 'SPECT')
    @petct = EquipmentCategory.create!(name: 'PET-CT', code_prefix: 'PETCT')
    @ge = Manufacturer.create!(name: 'GE', code: 'GE')
    @siemens = Manufacturer.create!(name: 'Siemens', code: 'SIEM')

    @ge_spect = EquipmentModel.create!(manufacturer: @ge, category: @spect, name: 'Modèle A')
    @siemens_spect = EquipmentModel.create!(manufacturer: @siemens, category: @spect, name: 'Modèle B')
    @ge_petct = EquipmentModel.create!(manufacturer: @ge, category: @petct, name: 'Modèle C')
  end

  def build_equipment(model, **attributes)
    Equipment.create!(equipment_model: model, location: @camera1, **attributes)
  end

  test 'le code suit le format TYPE-FABRICANT-NN' do
    assert_equal 'PETCT-GE-01', build_equipment(@ge_petct).code
  end

  test 'le compteur est séquentiel par type et par fabricant' do
    assert_equal 'SPECT-GE-01', build_equipment(@ge_spect).code
    assert_equal 'SPECT-SIEM-01', build_equipment(@siemens_spect).code
    assert_equal 'SPECT-GE-02', build_equipment(@ge_spect).code
  end

  test "un numéro n'est jamais réutilisé après archivage" do
    first = build_equipment(@ge_spect)
    build_equipment(@ge_spect)
    first.archive!

    assert_equal 'SPECT-GE-03', build_equipment(@ge_spect).code
  end

  test 'le code ne change jamais' do
    equipment = build_equipment(@ge_spect)
    original = equipment.code

    begin
      equipment.update(code: 'ZZZ-ZZ-99')
    rescue ActiveRecord::ReadonlyAttributeError
      # Selon la configuration de Rails, l'affectation lève une erreur.
    end

    assert_equal original, equipment.reload.code
  end

  test 'un équipement ne peut pas être supprimé' do
    equipment = build_equipment(@ge_spect)

    assert_not equipment.destroy
    assert Equipment.exists?(equipment.id)
  end

  test "un changement de local est enregistré dans l'historique des déplacements" do
    equipment = build_equipment(@ge_spect)
    equipment.update!(location: @camera2)

    move = equipment.equipment_moves.last
    assert_equal @camera1, move.from_location
    assert_equal @camera2, move.to_location
  end

  test 'la mise hors service exige une date' do
    equipment = build_equipment(@ge_spect)

    assert_not equipment.update(status: :decommissioned)
    assert equipment.update(status: :decommissioned, decommissioned_on: Date.current)
  end

  test 'le numéro de série est unique par modèle' do
    build_equipment(@ge_spect, serial_number: 'SN-1')

    assert_not Equipment.new(equipment_model: @ge_spect, location: @camera1, serial_number: 'SN-1').valid?
    assert Equipment.new(equipment_model: @siemens_spect, location: @camera1, serial_number: 'SN-1').valid?
  end
end
