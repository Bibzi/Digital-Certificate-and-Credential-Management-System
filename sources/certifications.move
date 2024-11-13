module credentials::certifications {
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::linked_table::{Self, LinkedTable};
    use std::string::String;
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use std::vector;
    use std::option::{Self, Option};

    // Additional error codes
    const EInsufficientPoints: u64 = 6;
    const EBadgeNotEarned: u64 = 7;
    const EChallengeNotActive: u64 = 8;
    const EPrerequisitesNotMet: u64 = 9;
    const EInvalidEndorsement: u64 = 10;

    // Existing structs remain...
    // Adding new structs for gamification

    struct SkillTree has key {
        id: UID,
        skills: LinkedTable<String, Skill>,
        prerequisites: LinkedTable<String, vector<String>>,
        owner: address
    }

    struct Skill has store {
        name: String,
        level: u64,
        experience: u64,
        mastery_threshold: u64,
        endorsements: vector<Endorsement>
    }

    struct Endorsement has store {
        endorser: address,
        weight: u64,
        timestamp: u64,
        notes: String
    }

    struct Achievement has key, store {
        id: UID,
        name: String,
        description: String,
        points: u64,
        rarity: u8, // 1: Common, 2: Rare, 3: Epic, 4: Legendary
        requirements: vector<String>,
        holders: vector<address>
    }

    struct Challenge has key {
        id: UID,
        name: String,
        description: String,
        start_time: u64,
        end_time: u64,
        required_credentials: vector<String>,
        reward_points: u64,
        participants: vector<address>,
        completed_by: vector<address>
    }

    struct ReputationPoints has key {
        id: UID,
        holder: address,
        total_points: u64,
        point_history: LinkedTable<String, PointEntry>,
        level: u64,
        badges: vector<Badge>
    }

    struct PointEntry has store {
        amount: u64,
        source: String,
        timestamp: u64,
        category: String
    }

    struct Badge has store {
        name: String,
        category: String,
        level: u8,
        earned_date: u64,
        special_privileges: vector<String>
    }

    struct LearningPath has key {
        id: UID,
        name: String,
        description: String,
        required_credentials: vector<String>,
        milestones: LinkedTable<u64, Milestone>,
        completion_reward: u64,
        participants: vector<address>
    }

    struct Milestone has store {
        description: String,
        required_skills: vector<String>,
        reward_points: u64,
        completed_by: vector<address>
    }

    // New functions for enhanced features

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
        ctx: &mut TxContext
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
            participants: vector::empty(),
            completed_by: vector::empty()
        };
        transfer::share_object(challenge);
    }

    public fun join_challenge(
        challenge: &mut Challenge,
        holder: &CredentialHolder,
        ctx: &mut TxContext
    ) {
        let participant = tx_context::sender(ctx);
        assert!(tx_context::epoch(ctx) >= challenge.start_time, EChallengeNotActive);
        assert!(tx_context::epoch(ctx) <= challenge.end_time, EChallengeNotActive);
        
        // Verify required credentials
        // (Implementation would check credentials against requirements)
        
        vector::push_back(&mut challenge.participants, participant);
    }

    public fun complete_challenge(
        challenge: &mut Challenge,
        reputation: &mut ReputationPoints,
        ctx: &mut TxContext
    ) {
        let participant = tx_context::sender(ctx);
        assert!(vector::contains(&challenge.participants, &participant), ENotAuthorized);
        assert!(!vector::contains(&challenge.completed_by, &participant), EAlreadyVerified);
        
        // Add points to reputation
        add_points(reputation, challenge.reward_points, b"Challenge Completion", ctx);
        vector::push_back(&mut challenge.completed_by, participant);
    }

    public fun add_points(
        reputation: &mut ReputationPoints,
        amount: u64,
        source: vector<u8>,
        ctx: &mut TxContext
    ) {
        reputation.total_points = reputation.total_points + amount;
        
        // Update level based on points
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
        // Example level calculation: level = sqrt(points/100)
        // Simplified version:
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

    // Function to progress in learning path
    public fun progress_learning_path(
        learning_path: &mut LearningPath,
        reputation: &mut ReputationPoints,
        milestone_number: u64,
        ctx: &mut TxContext
    ) {
        let participant = tx_context::sender(ctx);
        let milestone = linked_table::borrow_mut(&mut learning_path.milestones, milestone_number);
        
        // Verify milestone requirements are met
        // (Implementation would check skills and other requirements)
        
        vector::push_back(&mut milestone.completed_by, participant);
        add_points(reputation, milestone.reward_points, b"Learning Path Progress", ctx);
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }
}