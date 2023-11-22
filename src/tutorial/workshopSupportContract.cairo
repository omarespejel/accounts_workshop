use starknet::ContractAddress;

#[starknet::interface]
trait WorkshopSupportContractTrait<TContractState> {
    // ///////////////////
    // GETTER FUNCTIONS
    // ///////////////////
    fn get_tutorial_erc20_address(self: @TContractState) -> ContractAddress;
    fn get_players_registry(self: @TContractState) -> ContractAddress;
    fn has_validated_exercise(
        self: @TContractState, account: ContractAddress, exercise_id: u128
    ) -> bool;
    fn get_next_rank(self: @TContractState) -> u8;
    fn get_assigned_rank(self: @TContractState, player_address: ContractAddress) -> u8;
    fn is_teacher(self: @TContractState, account: ContractAddress) -> bool;

    // ///////////////////
    // EXTERNAL FUNCTIONS
    // ///////////////////
    fn set_teacher(ref self: TContractState, account: ContractAddress, permission: bool);
    fn set_max_rank(ref self: TContractState, max_rank: u8);
    fn set_random_values(ref self: TContractState, values_len: u8, values: Array<u8>, column: u32);
}

#[starknet::contract]
mod WorkshopSupportContract {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use accounts_workshop::tutorial::IPlayerRegistry::IPlayerRegistryDispatcherTrait;
    use accounts_workshop::tutorial::IPlayerRegistry::IPlayerRegistryDispatcher;
    use accounts_workshop::tutorial::IWorkshopSupportContract::IWorkshopSupportContractDispatcherTrait;
    use accounts_workshop::tutorial::IWorkshopSupportContract::IWorkshopSupportContractDispatcher;

    const ERC20_BASE: u128 = 1000000000000000000;

    //
    // STORAGE VARIABLES
    //
    #[storage]
    struct Storage {
        tutorial_erc20_address: ContractAddress,
        players_registry_address: ContractAddress,
        workshop_id: u8,
        teacher_accounts: LegacyMap::<ContractAddress, bool>,
        max_rank: u8,
        next_rank: u8,
        // TODO: actually get random values
        random_attributes: u8,
        assigned_rank: LegacyMap::<ContractAddress, u8>
    }

    #[external(v0)]
    impl WorkshopSupportContractImpl of super::WorkshopSupportContractTrait<ContractState> {
        // ///////////////////
        // GETTER FUNCTIONS
        // ///////////////////
        fn get_tutorial_erc20_address(self: @ContractState) -> ContractAddress {
            self.tutorial_erc20_address.read()
        }

        fn get_players_registry(self: @ContractState) -> ContractAddress {
            self.players_registry_address.read()
        }

        fn has_validated_exercise(
            self: @ContractState, account: ContractAddress, exercise_id: u128
        ) -> bool {
            let _players_registry = self.players_registry_address.read();
            let _workshop_id = self.workshop_id.read();

            IPlayerRegistryDispatcher { contract_address: _players_registry }
                .has_validated_exercise(account, _workshop_id, exercise_id)
        }

        fn get_next_rank(self: @ContractState) -> u8 {
            self.next_rank.read()
        }

        fn get_assigned_rank(self: @ContractState, player_address: ContractAddress) -> u8 {
            self.assigned_rank.read(player_address)
        }

        fn is_teacher(self: @ContractState, account: ContractAddress) -> bool {
            self.teacher_accounts.read(account) == true
        }

        // ///////////////////
        // EXTERNAL FUNCTIONS
        // ///////////////////
        fn set_teacher(ref self: ContractState, account: ContractAddress, permission: bool) {
            self.only_teacher();
            self.teacher_accounts.write(account, permission);
        }

        fn set_max_rank(ref self: ContractState, max_rank: u8) {
            self.max_rank.write(max_rank);
        }

        fn set_random_values(
            ref self: ContractState, values_len: u8, values: Array<u8>, column: u32
        ) {
            let _max = self.max_rank.read();
            assert(values_len == _max, 'invalid values length');
            self.set_a_random_value(*values.at(column));
        }
    }

    #[generate_trait]
    impl LibraryFunctions of LibraryFunctionsTrait {
        fn ex_initializer(
            ref self: ContractState,
            _erc20_address: ContractAddress,
            _players_registry: ContractAddress,
            _workshop_id: u8
        ) {
            self.tutorial_erc20_address.write(_erc20_address);
            self.players_registry_address.write(_players_registry);
            self.workshop_id.write(_workshop_id);
        }

        fn distribute_points(self: @ContractState, to: ContractAddress, amount: u128) {
            let _points_to_credit: u128 = amount * ERC20_BASE;
            let _erc20_address = self.tutorial_erc20_address.read();
            IWorkshopSupportContractDispatcher { contract_address: _erc20_address }
                .distribute_points(to, _points_to_credit);
        }

        fn validate_exercise(self: @ContractState, account: ContractAddress, exercise_id: u128) {
            let _players_registry = self.players_registry_address.read();
            let _workshop_id = self.workshop_id.read();
            let _has_validated = IPlayerRegistryDispatcher { contract_address: _players_registry }
                .has_validated_exercise(account, _workshop_id, exercise_id);
            assert(_has_validated == false, 'already validated');

            IPlayerRegistryDispatcher { contract_address: _players_registry }
                .validate_exercise(account, _workshop_id, exercise_id);
        }

        fn validate_and_reward(
            self: @ContractState, sender_address: ContractAddress, exercise: u128, points: u128
        ) {
            let _has_validated = self.has_validated_exercise(sender_address, exercise);

            if (_has_validated == false) {
                self.validate_exercise(sender_address, exercise);
                self.distribute_points(sender_address, points);
            }
        }

        fn only_teacher(self: @ContractState) {
            let _caller = get_caller_address();
            let _permission = self.teacher_accounts.read(_caller);
            assert(_permission == true, 'only teacher');
        }

        fn set_a_random_value(ref self: ContractState, value: u8,) {
            self.random_attributes.write(value);
        }

        // TODO: max rank and rank in general
        fn assign_rank_to_player(ref self: ContractState, sender_address: ContractAddress) {
            let _rank = self.next_rank.read();
            self.assigned_rank.write(sender_address, _rank);

            let _new_rank = _rank + 1_u8;
            let _max = self.max_rank.read();

            if (_new_rank == _max) {
                self.next_rank.write(0);
            } else {
                self.next_rank.write(_new_rank);
            }
        }
    }
}
