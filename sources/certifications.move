module credentials::certifications {
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::linked_table::{Self, LinkedTable};
    use std::string::{Self, String};

    // Error codes
    const ENotAuthorized: u64 = 0;
    const EInstitutionNotFound: u64 = 1;
    const ECertificateNotFound: u64 = 2;
    const EInvalidCredential: u64 = 3;
    const EAlreadyVerified: u64 = 4;
    const EExpiredCredential: u64 = 5;
    const EInsufficientPoints: u64 = 6;
    const EBadgeNotEarned: u64 = 7;
    const EChallengeNotActive: u64 = 8;
    const EPrerequisitesNotMet: u64 = 9;
    const EInvalidEndorsement: u64 = 10;

    // Core structs
    public struct Platform has key {
        id: UID,
        admin: address,
        revenue: Balance<SUI>,
        verification_fee: u64
    }

    public struct Institution has key {
        id: UID,
        name: String,
        address: address,
        credentials: LinkedTable<String, Credential>,
        reputation_score: u64,
        verified: bool
    }

    public struct Credential has key, store {
        id: UID,
        title: String,
        description: String,
        issuer: address,
        issue_date: u64,
        expiry_date: Option<u64>,
        metadata: LinkedTable<String, String>,
        revoked: bool
    }

    public struct CredentialHolder has key {
        id: UID,
        holder: address,
        // credentials: LinkedTable<String, Certificate>,
        verifications: LinkedTable<String, Verification>
    }

    public struct Certificate has key, store {
        id: UID,
        credential_id: ID,
        holder: address,
        issued_by: address,
        issue_date: u64,
        achievement_data: LinkedTable<String, String>
    }

    public struct Verification has store {
        verifier: address,
        verification_date: u64,
        valid_until: u64,
        verification_notes: String
    }

    public  struct InstitutionRegistry has key {
        id: UID,
        institutions: LinkedTable<address, ID>
    }

    // Add a registry to track certificates
    public struct CertificateRegistry has key {
        id: UID,
        certificates: LinkedTable<ID, ID>, // Maps certificate ID to credential ID
        holders: LinkedTable<address, vector<ID>> // Maps holder address to their certificate IDs
    }

    // Gamification structs
    public struct SkillTree has key {
        id: UID,
        skills: LinkedTable<String, Skill>,
        prerequisites: LinkedTable<String, vector<String>>,
        owner: address
    }

    public struct Skill has store {
        name: String,
        level: u64,
        experience: u64,
        mastery_threshold: u64,
        endorsements: vector<Endorsement>
    }

    public struct Endorsement has store {
        endorser: address,
        weight: u64,
        timestamp: u64,
        notes: String
    }

    // public struct Achievement has key, store {
    //     id: UID,
    //     name: String,
    //     description: String,
    //     points: u64,
    //     rarity: u8, // 1: Common, 2: Rare, 3: Epic, 4: Legendary
    //     requirements: vector<String>,
    //     holders: vector<address>
    // }

    public struct Challenge has key {
        id: UID,
        name: String,
        description: String,
        start_time: u64,
        end_time: u64,
        required_credentials: vector<String>,
        reward_points: u64,
        minimum_points: u64,
        participants: vector<address>,
        completed_by: vector<address>
    }

    public struct ReputationPoints has key {
        id: UID,
        // holder: address,
        total_points: u64,
        point_history: LinkedTable<String, PointEntry>,
        level: u64,
        badges: vector<Badge>
    }

    public struct PointEntry has store {
        amount: u64,
        source: String,
        timestamp: u64,
        category: String
    }

    public struct Badge has store {
        name: String,
        category: String,
        level: u8,
        earned_date: u64,
        special_privileges: vector<String>
    }

    public struct LearningPath has key {
        id: UID,
        name: String,
        description: String,
        required_credentials: vector<String>,
        milestones: LinkedTable<u64, Milestone>,
        completion_reward: u64,
        participants: vector<address>
    }

    public struct Milestone has store {
        description: String,
        required_skills: vector<String>,
        reward_points: u64,
        completed_by: vector<address>
    }

    // Initialize registry, certificate along with platform
    fun init(ctx: &mut TxContext) {
        let platform = Platform {
            id: object::new(ctx),
            admin: tx_context::sender(ctx),
            revenue: balance::zero(),
            verification_fee: 100 // Base fee in SUI
        };

        let registry = InstitutionRegistry {
            id: object::new(ctx),
            institutions: linked_table::new(ctx)
        };

        let certificate_registry = CertificateRegistry {
            id: object::new(ctx),
            certificates: linked_table::new(ctx),
            holders: linked_table::new(ctx)
        };

        transfer::share_object(platform);
        transfer::share_object(registry);
        transfer::share_object(certificate_registry);
    }

    // Core certification functions
    public fun register_institution(
        registry: &mut InstitutionRegistry,
        name: String,
        ctx: &mut TxContext
    ) {
        let institution = Institution {
            id: object::new(ctx),
            name,
            address: tx_context::sender(ctx),
            credentials: linked_table::new(ctx),
            reputation_score: 0,
            verified: false
        };

        let inst_id = object::id(&institution);
        linked_table::push_back(&mut registry.institutions, tx_context::sender(ctx), inst_id);
        transfer::transfer(institution, tx_context::sender(ctx));
    }

    // Function to get institution ID by address
    public fun get_institution_id(
        registry: &InstitutionRegistry,
        institution_address: address
    ): ID {
        assert!(verify_institution_exists(registry, institution_address), EInstitutionNotFound);
        *linked_table::borrow(&registry.institutions, institution_address)
    }

    // Function to create credential with institution validation
    public fun create_credential(
        registry: &InstitutionRegistry,
        institution: &mut Institution,
        title: String,
        description: String,
        expiry_period: Option<u64>,
        ctx: &mut TxContext
    ) {
        assert!(verify_institution_exists(registry, institution.address), EInstitutionNotFound);
        assert!(institution.address == tx_context::sender(ctx), ENotAuthorized);
        
        let credential = Credential {
            id: object::new(ctx),
            title,
            description,
            issuer: institution.address,
            issue_date: tx_context::epoch(ctx),
            expiry_date: expiry_period,
            metadata: linked_table::new(ctx),
            revoked: false
        };

        linked_table::push_back(&mut institution.credentials, title, credential);
    }


    // Function to check credential expiry
    public fun check_credential_expiry(credential: &Credential, ctx: &mut TxContext) {
        if (option::is_some(&credential.expiry_date)) {
            let expiry = option::borrow(&credential.expiry_date);
            assert!(tx_context::epoch(ctx) <= *expiry, EExpiredCredential);
        }
    }

    // Validate institution exists before operations
    public fun verify_institution_exists(
        registry: &InstitutionRegistry, 
        institution_address: address
    ): bool {
        linked_table::contains(&registry.institutions, institution_address)
    }

    public fun issue_certificate(
        registry: &InstitutionRegistry,
        cert_registry: &mut CertificateRegistry,
        institution: &Institution,
        credential_title: String,
        holder_address: address,
        achievement_data: LinkedTable<String, String>,
        ctx: &mut TxContext
    ) {
        assert!(verify_institution_exists(registry, institution.address), EInstitutionNotFound);
        assert!(institution.address == tx_context::sender(ctx), ENotAuthorized);
        
        let credential = linked_table::borrow(&institution.credentials, credential_title);
        let credential_id = object::id(credential);
        
        let certificate = Certificate {
            id: object::new(ctx),
            credential_id,
            holder: holder_address,
            issued_by: institution.address,
            issue_date: tx_context::epoch(ctx),
            achievement_data
        };

        let cert_id = object::id(&certificate);
        
        // Track certificate in registry
        linked_table::push_back(&mut cert_registry.certificates, cert_id, credential_id);
        
        // Add to holder's certificates
        if (!linked_table::contains(&cert_registry.holders, holder_address)) {
            linked_table::push_back(&mut cert_registry.holders, holder_address, vector::empty());
        };
        let holder_certs = linked_table::borrow_mut(&mut cert_registry.holders, holder_address);
        vector::push_back(holder_certs, cert_id);

        transfer::transfer(certificate, holder_address);
    }

    // Function to look up a certificate
    public fun get_certificate(
        cert_registry: &CertificateRegistry,
        cert_id: ID
    ): ID {
        assert!(linked_table::contains(&cert_registry.certificates, cert_id), ECertificateNotFound);
        *linked_table::borrow(&cert_registry.certificates, cert_id)
    }

    // Function to update institution verification status
    public fun update_institution_verification(
        platform: &Platform,
        registry: &InstitutionRegistry,
        institution: &mut Institution,
        verified: bool,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == platform.admin, ENotAuthorized);
        assert!(verify_institution_exists(registry, institution.address), EInstitutionNotFound);
        institution.verified = verified;
    }

    public fun verify_certificate(
        platform: &mut Platform,
        cert_registry: &CertificateRegistry,
        holder: &mut CredentialHolder,
        certificate: &Certificate,
        notes: String,
        valid_period: u64,
        payment: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let cert_id = object::id(certificate);
        // Verify certificate exists in registry
        assert!(linked_table::contains(&cert_registry.certificates, cert_id), ECertificateNotFound);

        // Check if certificate is already verified
        let verification_id = std::string::utf8(b"verification_");

        assert!(!linked_table::contains(&holder.verifications, verification_id), EAlreadyVerified);
        
        let payment_value = coin::value(&payment);
        assert!(payment_value >= platform.verification_fee, EInvalidCredential);
        assert!(holder.holder == certificate.holder, ENotAuthorized);
        
        let verification = Verification {
            verifier: tx_context::sender(ctx),
            verification_date: tx_context::epoch(ctx),
            valid_until: tx_context::epoch(ctx) + valid_period,
            verification_notes: notes
        };

        let verification_id = std::string::utf8(b"verification_");
        linked_table::push_back(
            &mut holder.verifications, 
            verification_id,
            verification
        );

        let payment_balance = coin::into_balance(payment);
        balance::join(&mut platform.revenue, payment_balance);
    }

    // Function to get all certificates for a holder
    public fun get_holder_certificates(
        cert_registry: &CertificateRegistry,
        holder: address
    ): vector<ID> {
        assert!(linked_table::contains(&cert_registry.holders, holder), ECertificateNotFound);
        *linked_table::borrow(&cert_registry.holders, holder)
    }

    // Function to revoke a certificate
    public fun revoke_certificate(
        cert_registry: &mut CertificateRegistry,
        institution: &Institution,
        cert_id: ID,
        ctx: &mut TxContext
    ) {
        assert!(linked_table::contains(&cert_registry.certificates, cert_id), ECertificateNotFound);
        assert!(institution.address == tx_context::sender(ctx), ENotAuthorized);
        
        // Remove certificate from registry
        linked_table::remove(&mut cert_registry.certificates, cert_id);
    }

    // Gamification functions
    public fun create_skill_tree(ctx: &mut TxContext) {
        let skill_tree = SkillTree {
            id: object::new(ctx),
            skills: linked_table::new(ctx),
            prerequisites: linked_table::new(ctx),
            owner: tx_context::sender(ctx)
        };
        transfer::transfer(skill_tree, tx_context::sender(ctx));
    }

    public fun add_skill(
        skill_tree: &mut SkillTree,
        name: String,
        mastery_threshold: u64,
        prerequisites: vector<String>,
        ctx: &mut TxContext
    ) {
        assert!(skill_tree.owner == tx_context::sender(ctx), ENotAuthorized);
        
        let skill = Skill {
            name: name,
            level: 0,
            experience: 0,
            mastery_threshold,
            endorsements: vector::empty()
        };

        linked_table::push_back(&mut skill_tree.skills, name, skill);
        linked_table::push_back(&mut skill_tree.prerequisites, name, prerequisites);
    }

    // Enhanced skill tree progression with prerequisites check
    public fun level_up_skill(
        skill_tree: &mut SkillTree,
        skill_name: String,
        ctx: &mut TxContext
    ) {
        assert!(skill_tree.owner == tx_context::sender(ctx), ENotAuthorized);
        
        // Check prerequisites
        let prerequisites = linked_table::borrow(&skill_tree.prerequisites, skill_name);
        let mut i = 0;
        let len = vector::length(prerequisites);
        
        while (i < len) {
            let prereq_skill = vector::borrow(prerequisites, i);
            let skill = linked_table::borrow(&skill_tree.skills, *prereq_skill);
            assert!(skill.level > 0, EPrerequisitesNotMet);
            i = i + 1;
        };
        
        // Level up the skill
        let skill = linked_table::borrow_mut(&mut skill_tree.skills, skill_name);
        skill.level = skill.level + 1;
    }

    
    public fun endorse_skill(
        skill_tree: &mut SkillTree,
        skill_name: String,
        weight: u64,
        notes: String,
        ctx: &mut TxContext
    ) {
        let endorser = tx_context::sender(ctx);
        assert!(endorser != skill_tree.owner, EInvalidEndorsement);
        
        let skill = linked_table::borrow_mut(&mut skill_tree.skills, skill_name);
        let endorsement = Endorsement {
            endorser,
            weight,
            timestamp: tx_context::epoch(ctx),
            notes
        };
        vector::push_back(&mut skill.endorsements, endorsement);
    }

    public fun create_learning_path(
        name: String,
        description: String,
        required_credentials: vector<String>,
        completion_reward: u64,
        ctx: &mut TxContext
    ) {
        let learning_path = LearningPath {
            id: object::new(ctx),
            name,
            description,
            required_credentials,
            milestones: linked_table::new(ctx),
            completion_reward,
            participants: vector::empty()
        };
        transfer::share_object(learning_path);
    }

    public fun add_milestone(
        learning_path: &mut LearningPath,
        milestone_number: u64,
        description: String,
        required_skills: vector<String>,
        reward_points: u64,
        _ctx: &mut TxContext
    ) {
        let milestone = Milestone {
            description,
            required_skills,
            reward_points,
            completed_by: vector::empty()
        };
        linked_table::push_back(&mut learning_path.milestones, milestone_number, milestone);
    }

    public fun create_challenge(
        name: String,
        description: String,
        start_time: u64,
        end_time: u64,
        required_credentials: vector<String>,
        reward_points: u64,
        minimum_points: u64,
        ctx: &mut TxContext
    ) {
        let challenge = Challenge {
            id: object::new(ctx),
            name,
            description,
            start_time,
            end_time,
            required_credentials,
            reward_points,
            minimum_points,
            participants: vector::empty(),
            completed_by: vector::empty()
        };
        transfer::share_object(challenge);
    }

    // Enhanced challenge participation function
    public fun participate_in_challenge(
        challenge: &mut Challenge,
        reputation: &ReputationPoints,
        ctx: &mut TxContext
    ) {
    let participant = tx_context::sender(ctx);
    
    // Check if challenge is active
    let current_time = tx_context::epoch(ctx);
    assert!(
        current_time >= challenge.start_time && 
        current_time <= challenge.end_time, 
        EChallengeNotActive
    );
    
    // Check minimum points requirement
    assert!(reputation.total_points >= challenge.minimum_points, EInsufficientPoints);
    
    // Add participant if not already participating
    if (!vector::contains(&challenge.participants, &participant)) {
        vector::push_back(&mut challenge.participants, participant);
    };
}

    public fun add_points(
        reputation: &mut ReputationPoints,
        amount: u64,
        source: vector<u8>,
        ctx: &mut TxContext
    ) {
        reputation.total_points = reputation.total_points + amount;
        reputation.level = calculate_level(reputation.total_points);
        
        let entry = PointEntry {
            amount,
            source: string::utf8(source),
            timestamp: tx_context::epoch(ctx),
            category: string::utf8(b"Achievement")
        };
        
        linked_table::push_back(
            &mut reputation.point_history,
            string::utf8(source),
            entry
        );
    }

    fun calculate_level(points: u64): u64 {
        points / 100 + 1
    }

    public fun award_badge(
        reputation: &mut ReputationPoints,
        name: String,
        category: String,
        level: u8,
        privileges: vector<String>,
        ctx: &mut TxContext
    ) {
        let badge = Badge {
            name,
            category,
            level,
            earned_date: tx_context::epoch(ctx),
            special_privileges: privileges
        };
        vector::push_back(&mut reputation.badges, badge);
    }

    // Enhanced badge verification function
    public fun verify_badge_access(
        reputation: &ReputationPoints,
        required_badge: String,
        required_level: u8
    ) {
        let mut has_badge = false;  // Declare `has_badge` as mutable
        let badges = &reputation.badges;
        
        let mut i = 0;  // Declare `i` as mutable
        let len = vector::length(badges);

        while (i < len) {
            let badge = vector::borrow(badges, i);
            if (badge.name == required_badge && badge.level >= required_level) {
                has_badge = true;
                break
            };
            i = i + 1;
        };

        assert!(has_badge, EBadgeNotEarned);
    }


    public fun progress_learning_path(
        learning_path: &mut LearningPath,
        reputation: &mut ReputationPoints,
        milestone_number: u64,
        ctx: &mut TxContext
    ) {
        let participant = tx_context::sender(ctx);
        let milestone = linked_table::borrow_mut(&mut learning_path.milestones, milestone_number);
        
        vector::push_back(&mut milestone.completed_by, participant);
        add_points(reputation, milestone.reward_points, b"Learning Path Progress", ctx);
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }
}