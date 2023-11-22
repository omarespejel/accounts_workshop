use starknet::ContractAddress;

#[starknet::interface]
trait TDERC20Trait<TContractState> {
    // VIEW FUNCTIONS
    fn name_td(self: @TContractState) -> felt252;
    fn symbol_td(self: @TContractState) -> felt252;
    fn decimals_td(self: @TContractState) -> u8;
    fn totalSupply_td(self: @TContractState) -> u256;
    fn balanceOf_td(self: @TContractState, account: ContractAddress) -> u256;
    fn allowance_td(
        self: @TContractState, owner: ContractAddress, spender: ContractAddress
    ) -> u256;
    fn is_teacher_or_exercise_td(self: @TContractState, account: ContractAddress) -> bool;

    // EXTERNAL FUNCTIONS
    fn transfer_td(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn transferFrom_td(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
    fn approve_td(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
    fn increaseAllowance_td(
        ref self: TContractState, spender: ContractAddress, added_value: u256
    ) -> bool;
    fn decreaseAllowance_td(
        ref self: TContractState, spender: ContractAddress, subtracted_value: u256
    ) -> bool;
    fn distribute_points_td(ref self: TContractState, to: ContractAddress, amount: u256);
    fn remove_points_td(ref self: TContractState, to: ContractAddress, amount: u256);
    fn set_teacher_td(ref self: TContractState, account: ContractAddress, permission: bool);
}

#[starknet::contract]
mod tderc20 {
    use starknet::get_caller_address;
    use starknet::ContractAddress;
    use openzeppelin::token::erc20::erc20::ERC20Component;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20MetadataImpl = ERC20Component::ERC20MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl SafeAllowanceImpl = ERC20Component::SafeAllowanceImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    const INITIAL_SUPPLY: u128 = 1000000000000000000; // 1e18 for example

    //
    // STORAGE VARIABLES
    //
    #[storage]
    struct Storage {
        is_transferable_storage: bool,
        teachers_and_exercises_accounts: LegacyMap<ContractAddress, bool>,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
    }

    ////////////////////////////////
    // Events
    ////////////////////////////////
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: TransferEvent,
        Approval: ApprovalEvent,
        ERC20Event: ERC20Component::Event
    }

    #[derive(Drop, starknet::Event)]
    struct TransferEvent {
        from: ContractAddress,
        to: ContractAddress,
        value: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct ApprovalEvent {
        owner: ContractAddress,
        spender: ContractAddress,
        value: u256,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name_: felt252,
        symbol_: felt252,
        decimals_: u8,
        initial_supply: u256,
        recipient: ContractAddress,
        owner: ContractAddress
    ) {
        self.erc20.initializer(name_, symbol_);
        self.teachers_and_exercises_accounts.write(owner, true);
    }

    #[external(v0)]
    impl TDERC20Impl of super::TDERC20Trait<ContractState> {
        //
        // GETTERS
        //

        fn name_td(self: @ContractState) -> felt252 {
            self.erc20.name()
        }

        fn symbol_td(self: @ContractState) -> felt252 {
            self.erc20.symbol()
        }

        fn decimals_td(self: @ContractState) -> u8 {
            self.erc20.decimals()
        }

        fn totalSupply_td(self: @ContractState) -> u256 {
            self.erc20.total_supply()
        }

        fn balanceOf_td(self: @ContractState, account: ContractAddress) -> u256 {
            self.erc20.balance_of(account)
        }

        fn allowance_td(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress
        ) -> u256 {
            self.erc20.allowance(owner, spender)
        }

        fn is_teacher_or_exercise_td(self: @ContractState, account: ContractAddress) -> bool {
            self.teachers_and_exercises_accounts.read(account)
        }

        //
        // EXTERNAL FUNCTIONS
        //

        fn transfer_td(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            self.erc20.transfer(recipient, amount)
        }

        fn transferFrom_td(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            self.erc20.transfer_from(sender, recipient, amount)
        }

        fn approve_td(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            self.erc20.approve(spender, amount)
        }

        fn increaseAllowance_td(
            ref self: ContractState, spender: ContractAddress, added_value: u256
        ) -> bool {
            self.erc20.increase_allowance(spender, added_value)
        }

        fn decreaseAllowance_td(
            ref self: ContractState, spender: ContractAddress, subtracted_value: u256
        ) -> bool {
            self.erc20.decrease_allowance(spender, subtracted_value)
        }

        fn distribute_points_td(ref self: ContractState, to: ContractAddress, amount: u256) {
            self.erc20._mint(to, amount);
        }

        fn remove_points_td(ref self: ContractState, to: ContractAddress, amount: u256) {
            self.erc20._burn(to, amount);
        }

        // TODO (non-urgent) - finish set_teachers function (currently not working)
        // fn set_teachers(ref self: ContractState, accounts: Array<ContractAddress>, permissions: Array<bool>) {
        //     only_teacher_or_exercise();
        //     _set_teacher(accounts.len(), accounts, permissions);
        // }

        fn set_teacher_td(ref self: ContractState, account: ContractAddress, permission: bool) {
            self.only_teacher_or_exercise();
            self.teachers_and_exercises_accounts.write(account, permission);
        }
    }

    //
    // INTERNAL FUNCTIONS
    //
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn only_teacher_or_exercise(self: @ContractState) {
            let caller = get_caller_address();
            let permission = self.teachers_and_exercises_accounts.read(caller);
            assert(permission == true, 'Only teachers or exercises');
        }
    // TODO (non-urgent) - consider adding a function _set_teacher to set multiple teachers at once
    // as it is done in the original contract
    }
}
