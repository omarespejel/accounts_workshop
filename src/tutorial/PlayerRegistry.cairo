////////////////////////////////
// PlayersRegistry
// A contract to record all addresses who participated, and which exercises and workshops they completed
////////////////////////////////

use starknet::ContractAddress;

#[starknet::interface]
trait PlayersRegistryTrait<TContractState> {
    // ///////////////////
    // GETTER FUNCTIONS
    // ///////////////////
    fn has_validated_exercise(
        self: @TContractState, account: ContractAddress, workshop: u128, exercise: u128
    ) -> bool;
    fn is_exercise_or_admin(self: @TContractState, account: ContractAddress) -> bool;
    fn get_next_player_rank(self: @TContractState) -> u128;
    fn get_players_registry(self: @TContractState, rank: u128) -> ContractAddress;
    fn players_ranks(self: @TContractState, account: ContractAddress) -> u128;

    // ///////////////////
    // EXTERNAL FUNCTIONS
    // ///////////////////
    fn set_exercise_or_admin(ref self: TContractState, account: ContractAddress, permission: bool);
    fn set_exercises_or_admins(
        ref self: TContractState, accounts: Array::<ContractAddress>, permissions: Array::<bool>
    );
    fn update_class_hash_by_admin(ref self: TContractState, class_hash_in_felt: felt252);
    fn validate_exercise(
        ref self: TContractState, account: ContractAddress, workshop: u128, exercise: u128
    );
}

#[starknet::contract]
mod PlayersRegistry {
    // Core Library Imports
    use starknet::get_caller_address;
    use zeroable::Zeroable;
    use starknet::ContractAddress;
    // use starknet::ContractAddressZeroable;
    use traits::Into;
    use traits::TryInto;
    use array::ArrayTrait;
    use option::OptionTrait;
    use starknet::ClassHash;
    use starknet::syscalls::replace_class_syscall;
    use starknet::class_hash::Felt252TryIntoClassHash;

    // Internal Imports
    // use starknet_cairo_101::utils::Iplayers_registry::Iplayers_registryDispatcherTrait;
    // use starknet_cairo_101::utils::Iplayers_registry::Iplayers_registryDispatcher;
    // use starknet_cairo_101::token::ITDERC20::ITDERC20DispatcherTrait;
    // use starknet_cairo_101::token::ITDERC20::ITDERC20Dispatcher;
    // use core::hash::TupleSize3LegacyHash;
    use starknetpy::tutorial::helper;

    ////////////////////////////////
    // STORAGE
    ////////////////////////////////
    #[storage]
    struct Storage {
        has_validated_exercise_storage: LegacyMap::<(ContractAddress, u128, u128), bool>,
        exercises_and_admins_accounts: LegacyMap::<ContractAddress, bool>,
        next_player_rank: u128,
        players_registry: LegacyMap::<u128, ContractAddress>,
        players_ranks_storage: LegacyMap::<ContractAddress, u128>,
    }

    #[external(v0)]
    impl PlayersRegistryImpl of super::PlayersRegistryTrait<ContractState> {
        ////////////////////////////////
        // View Functions
        ////////////////////////////////
        fn has_validated_exercise(
            self: @ContractState, account: ContractAddress, workshop: u128, exercise: u128
        ) -> bool {
            self.has_validated_exercise_storage.read((account, workshop, exercise))
        }

        fn is_exercise_or_admin(self: @ContractState, account: ContractAddress) -> bool {
            self.exercises_and_admins_accounts.read(account)
        }

        fn get_next_player_rank(self: @ContractState) -> u128 {
            self.next_player_rank.read()
        }

        fn get_players_registry(self: @ContractState, rank: u128) -> ContractAddress {
            self.players_registry.read(rank)
        }

        fn players_ranks(self: @ContractState, account: ContractAddress) -> u128 {
            self.players_ranks_storage.read(account)
        }

        ////////////////////////////////
        // External Functions
        ////////////////////////////////

        fn set_exercise_or_admin(
            ref self: ContractState, account: ContractAddress, permission: bool
        ) {
            // self.only_exercise_or_admin();
            self.exercises_and_admins_accounts.write(account, permission);
        // self.Modificate_Exercise_Or_Admin(account, permission);
        }

        fn set_exercises_or_admins(
            ref self: ContractState, accounts: Array::<ContractAddress>, permissions: Array::<bool>
        ) { // self.only_exercise_or_admin();
        // self.set_single_exercise_or_admin(accounts, permissions);
        }

        fn update_class_hash_by_admin(ref self: ContractState, class_hash_in_felt: felt252) {
            // self.only_exercise_or_admin();
            let class_hash: ClassHash = class_hash_in_felt.try_into().unwrap();
            replace_class_syscall(class_hash);
        }

        fn validate_exercise(
            ref self: ContractState, account: ContractAddress, workshop: u128, exercise: u128
        ) {
            // self.only_exercise_or_admin();
            // Checking if the user already validated this exercise
            let is_validated = self
                .has_validated_exercise_storage
                .read((account, workshop, exercise));

            assert(is_validated == false, 'USER_VALIDATED');

            // Marking the exercise as completed
            self.has_validated_exercise_storage.write((account, workshop, exercise), true);
            // self.New_Validation(account, workshop, exercise);

            // Recording player if he is not yet recorded
            let player_rank = self.players_ranks_storage.read(account);

            if player_rank == 0_u128 {
                // Player is not yet record, let's record
                let next_player_rank = self.next_player_rank.read();
                self.players_registry.write(next_player_rank, account);
                self.players_ranks_storage.write(account, next_player_rank);

                let next_player_rank_plus_one = next_player_rank + 1_u128;
                self.next_player_rank.write(next_player_rank_plus_one);
            // self.New_Player(account, next_player_rank);
            }
        }
    }

    ////////////////////////////////
    // Internal Functions
    ////////////////////////////////
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn only_exercise_or_admin(self: @ContractState) {
            let caller: ContractAddress = get_caller_address();
            let permission: bool = self.exercises_and_admins_accounts.read(caller);
            assert(permission == true, 'You dont have permission.');
        }

        fn set_single_exercise_or_admin(
            ref self: ContractState,
            mut accounts: Array::<ContractAddress>,
            mut permissions: Array::<bool>
        ) {
            helper::check_gas();
            if !accounts.is_empty() {
                self
                    .exercises_and_admins_accounts
                    .write(accounts.pop_front().unwrap(), permissions.pop_front().unwrap());
                self.set_single_exercise_or_admin(accounts, permissions);
            }
        }
    }

    ////////////////////////////////
    // Constructor
    ////////////////////////////////
    #[constructor]
    fn constructor(ref self: ContractState, first_admin: ContractAddress) {
        self.exercises_and_admins_accounts.write(first_admin, true);
        // self.Modificate_Exercise_Or_Admin(first_admin, true);
        self.next_player_rank.write(1_u128);
    }

    ////////////////////////////////
    // Events
    ////////////////////////////////
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Modificate_Exercise_Or_Admin: Modificate_Exercise_Or_Admin,
        New_Player: New_Player,
        New_Validation: New_Validation
    }

    #[derive(Drop, starknet::Event)]
    struct Modificate_Exercise_Or_Admin {
        account: ContractAddress,
        permission: bool
    }

    #[derive(Drop, starknet::Event)]
    struct New_Player {
        account: ContractAddress,
        rank: u128
    }

    #[derive(Drop, starknet::Event)]
    struct New_Validation {
        account: ContractAddress,
        workshop: u128,
        exercise: u128
    }
}
