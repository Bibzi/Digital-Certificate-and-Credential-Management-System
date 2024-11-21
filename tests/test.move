#[test_only]
module credentials::test_games {
    use sui::test_scenario::{Self as ts, next_tx};
    use sui::coin::{mint_for_testing};
    use sui::sui::{SUI};

    use std::string::{Self};

    use credentials::helpers::init_test_helper;
    use credentials::certifications::{Self as cert, Platform, InstitutionRegistry, CertificateRegistry};

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

        

        ts::end(scenario_test);
    }

}
