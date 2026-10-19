require_relative 'api_test_case'

class ApiEquipmentsTest < ApiTestCase
  test 'la liste exige un jeton' do
    get api_v1_equipments_url

    assert_response :unauthorized
  end

  test 'tout utilisateur actif consulte la liste avec sa pagination' do
    get api_v1_equipments_url, headers: auth(@reporter)

    assert_response :success
    assert_equal([@equipment.code, @lab_equipment.code], json['data'].map { |equipment| equipment['code'] })
    assert_equal({ 'page' => 1, 'per_page' => 25, 'total' => 2, 'total_pages' => 1 }, json['meta'])
  end

  test "la représentation d'un équipement est complète" do
    get api_v1_equipments_url(q: 'SN-100'), headers: auth(@reporter)

    equipment = json['data'].first
    assert_equal 'SN-100', equipment['serial_number']
    assert_equal 'in_service', equipment['status']
    assert_equal 'SPECT', equipment['category']['code_prefix']
    assert_equal 'GE', equipment['manufacturer']['code']
    assert_equal 'Modèle A', equipment['model']['name']
    assert_equal 'Caméra 1', equipment['location']['name']
    assert_equal 'CAM', equipment['location']['department']['code']
    assert_equal false, equipment['archived']
  end

  test 'filtres par statut, département et recherche' do
    @lab_equipment.update!(status: :out_of_order)

    get api_v1_equipments_url(status: 'out_of_order'), headers: auth(@reporter)
    assert_equal([@lab_equipment.code], json['data'].map { |equipment| equipment['code'] })

    get api_v1_equipments_url(department_id: @cameras.id), headers: auth(@reporter)
    assert_equal([@equipment.code], json['data'].map { |equipment| equipment['code'] })

    get api_v1_equipments_url(q: 'SN-100'), headers: auth(@reporter)
    assert_equal([@equipment.code], json['data'].map { |equipment| equipment['code'] })
  end

  test 'les équipements archivés sont masqués par défaut' do
    @equipment.archive!

    get api_v1_equipments_url, headers: auth(@reporter)
    assert_equal([@lab_equipment.code], json['data'].map { |equipment| equipment['code'] })

    get api_v1_equipments_url(archived: '1'), headers: auth(@reporter)
    assert_equal 2, json['data'].size
  end

  test 'pagination et plafond de per_page' do
    get api_v1_equipments_url(per_page: 1, page: 2), headers: auth(@reporter)

    assert_equal([@lab_equipment.code], json['data'].map { |equipment| equipment['code'] })
    assert_equal 2, json['meta']['total_pages']

    get api_v1_equipments_url(per_page: 500), headers: auth(@reporter)
    assert_equal 100, json['meta']['per_page']
  end

  test "la fiche d'un équipement" do
    get api_v1_equipment_url(@equipment), headers: auth(@reporter)

    assert_response :success
    assert_equal @equipment.code, json['data']['code']
  end

  test 'un équipement inconnu répond 404' do
    get api_v1_equipment_url(0), headers: auth(@reporter)

    assert_response :not_found
  end
end
