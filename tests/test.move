#[test_only]
module credentials::test_games {
    use sui::test_scenario::{Self as ts, next_tx};
    use sui::coin::{mint_for_testing};
    use sui::sui::{SUI};

    use std::string::{Self};

    use credentials::helpers::init_test_helper;
    use credentials::certifications::{Self as cert, Platform, InstitutionRegistry, CertificateRegistry, Institution, Certificate};

    const ADMIN: address = @0xe;
    const TEST_ADDRESS1: address = @0xee;
    const TEST_ADDRESS2: address = @0xbb;

    #[test]
    #[expected_failure(abort_code = 0x2::dynamic_field::EFieldAlreadyExists)]    
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

        // issue_certificate
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

    #[test]  
    public fun test2() {
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

        // issue_certificate
        next_tx(scenario, TEST_ADDRESS1);
        {
            let registry = ts::take_shared<InstitutionRegistry>(scenario);
            let mut cert_registry = ts::take_shared<CertificateRegistry>(scenario);
            let institution = ts::take_from_sender<Institution>(scenario);

            let title = string::utf8(b"title");
            let holder_address = TEST_ADDRESS1;

            cert::issue_certificate(
                &registry,
                &mut cert_registry,
                &institution,
                title,
                holder_address,
                ts::ctx(scenario)
            );

            ts::return_to_sender(scenario, institution);
            ts::return_shared(registry);
            ts::return_shared(cert_registry);
        };

           // update_institution_verification
        next_tx(scenario, TEST_ADDRESS1);
        {
            let platform = ts::take_shared<Platform>(scenario);
            let cert_registry = ts::take_shared<InstitutionRegistry>(scenario);
            let mut institution = ts::take_from_sender<Institution>(scenario);

            let verified: bool = true;

    
            cert::update_institution_verification(
                &platform,
                &cert_registry,
                &mut institution,
                verified,
                ts::ctx(scenario)
            );

            ts::return_to_sender(scenario, institution);
            ts::return_shared(platform);
            ts::return_shared(cert_registry);
        };

        // // verify_certificate
        // next_tx(scenario, TEST_ADDRESS1);
        // {
            
        //     let cert_registry = ts::take_shared<CertificateRegistry>(scenario);
        //     let platform = ts::take_shared<Platform>(scenario);
        //     let mut certificate = ts::take_from_sender<Certificate>(scenario);
        //     let mut credentholder = ts :: take_shared<CredentialHolder>(scenario)
         

        //     cert::verify_certificate(
              

        //     );

        //     ts::return_to_sender(scenario, certificate);
        //     ts::return_shared(platform);
        //     ts::return_shared(cert_registry);
        // };

        ts::end(scenario_test);
    }


}
