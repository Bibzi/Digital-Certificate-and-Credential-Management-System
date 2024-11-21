#[test_only]
module credentials::test_games {
    use sui::test_scenario::{Self as ts, next_tx};
    use sui::coin::{mint_for_testing};
    use sui::sui::{SUI};

    use std::string::{Self};

    use credentials::helpers::init_test_helper;
    use credentials::certifications::{Self as cert, Platform, InstitutionRegistry, CertificateRegistry, Institution};

    const ADMIN: address = @0xe;
    const TEST_ADDRESS1: address = @0xee;
    const TEST_ADDRESS2: address = @0xbb;

    #[test]
    public fun test1() {
        let mut scenario_test = init_test_helper();
        let scenario = &mut scenario_test;

        // test shared objects with init 
        next_tx(scenario, TEST_ADDRESS1);
        {
            let platfrom = ts::take_shared<Platform>(scenario);
            let registry = ts::take_shared<InstitutionRegistry>(scenario);
            let certificate_registry = ts::take_shared<CertificateRegistry>(scenario);

            ts::return_shared(platfrom);
            ts::return_shared(registry);
            ts::return_shared(certificate_registry);
        };

        // register_institution
        next_tx(scenario, TEST_ADDRESS1);
        {
            let mut insitu = ts::take_shared<InstitutionRegistry>(scenario);
            let name = string::utf8(b"address1");

            cert::register_institution(&mut insitu, name, ts::ctx(scenario));

            ts::return_shared(insitu);
        };

        // create_credential 
        next_tx(scenario, TEST_ADDRESS1);
        {
            let mut registiry = ts::take_from_sender<Institution>(scenario);
            let institution = ts::take_shared<InstitutionRegistry>(scenario);
            
            let title = string::utf8(b"title");
            let description = string::utf8(b"desc");
            let expiry_period = option::some<u64>(24);

            cert::create_credential(&institution, &mut registiry, title, description, expiry_period, ts::ctx(scenario));

            ts::return_to_sender(scenario, registiry);
            ts::return_shared(institution);
        };

        





        ts::end(scenario_test);
    }

}
