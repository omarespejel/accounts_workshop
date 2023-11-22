/// @dev Core Library Imports for the Traits outside the Starknet Contract
use starknet::ContractAddress;

/// @dev Trait defining the functions that can be implemented or called by the Starknet Contract
#[starknet::interface]
trait EvaluatorTrait<TContractState> {
    // ///////////////////
    // GETTER FUNCTIONS
    // ///////////////////
    fn get_public(self: @TContractState) -> felt252;
    fn get_random(self: @TContractState) -> u64;
    fn get_multicall_count(self: @TContractState, tx_meta: felt252) -> felt252;

    // ///////////////////
    // EXTERNAL FUNCTIONS
    // ///////////////////
    fn validate_hello(ref self: TContractState, input: u64, address: ContractAddress) -> bool;
    fn validate_signature_1(
        ref self: TContractState, input: felt252, address: ContractAddress
    ) -> bool;
}

/// @dev Starknet Contract allowing three registered voters to vote on a proposal
#[starknet::contract]
mod Evaluator {
    use core::traits::TryInto;
    use core::traits::Into;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::info::{get_tx_info, get_block_number, TxInfo, ExecutionInfo};
    use core::pedersen::pedersen;
    use ecdsa::check_ecdsa_signature;
    use array::{Array, ArrayTrait};
    use integer::Felt252TryIntoU32;
    use starknet::contract_address::ContractAddressIntoFelt252;
    use starknet::eth_signature::verify_eth_signature;
    use starknet::secp256_trait::{Signature, signature_from_vrs};
    use starknet::EthAddress;
    use starknet::syscalls::get_execution_info_syscall;
    use starknet::SyscallResultTrait;

    use starknetpy::tutorial::IWorkshopSupportContract::IWorkshopSupportContractDispatcherTrait;
    use starknetpy::tutorial::IWorkshopSupportContract::IWorkshopSupportContractDispatcher;
    use starknetpy::tutorial::IAccountsInterfaces::{
        IMultiSigDispatcherTrait, IMultiSigDispatcher, IAccountSigDispatcherTrait,
        IAccountSigDispatcher
    };

    // ///////////////////
    // CONSTS
    // ///////////////////
    const WORKSHIP_ID: u8 = 5;
    const HELLO: u128 = 'HELLO';
    const SIGNATURE_1: u128 = 'SIGNATURE_1';
    const SIGNATURE_2: u128 = 'SIGNATURE_2';
    const SIGNATURE_3: u128 = 'SIGNATURE_3';
    const MULTICALL: u128 = 'MULTICALL';
    const MULTISIG: u128 = 'MULTISIG';
    const ABSTRACTION: u128 = 'ABSTRACTION';
    const REWARDS_BASE: u128 = 1000000000000000000;
    const ETHEREUM_ADDRESS: felt252 = 0x1a642f0e3c3af545e7acbd38b07251b3990914f1;

    // ///////////////////
    // STORAGE VARIABLES
    // ///////////////////
    #[storage]
    struct Storage {
        private: u256,
        public: felt252,
        secret_1: felt252,
        secret_2: felt252,
        random: u64,
        // TODO (nonurgent) - eliminat ethereum_address if unnecessary
        ethereum_address: ContractAddress,
        tutorial_erc20_address: ContractAddress,
        multicall_counter: LegacyMap::<felt252, felt252>,
    }

    // ///////////////////
    // CONSTRUCTOR
    // ///////////////////

    /// @dev Initializes the contract
    #[constructor]
    fn constructor(
        ref self: ContractState,
        private: u256,
        public: felt252,
        secret_1: felt252,
        secret_2: felt252,
        _tutorial_erc20_address: ContractAddress,
        _players_registry: ContractAddress,
        _first_teacher: ContractAddress
    ) {
        IWorkshopSupportContractDispatcher { contract_address: _tutorial_erc20_address }
            .ex_initializer(_tutorial_erc20_address, _players_registry, WORKSHIP_ID);
        self.tutorial_erc20_address.write(_tutorial_erc20_address);
        IWorkshopSupportContractDispatcher { contract_address: _tutorial_erc20_address }
            .set_teacher(_first_teacher, true);
        IWorkshopSupportContractDispatcher { contract_address: _tutorial_erc20_address }
            .set_max_rank(100);

        let block_num: u64 = get_block_number();
        self.private.write(private);
        self.public.write(public);
        self.secret_1.write(secret_1);
        self.secret_2.write(secret_2);
        self.random.write(block_num);
    }

    // ///////////////////
    // EVENTS
    // ///////////////////
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Payday: Payday,
    }

    #[derive(Drop, starknet::Event)]
    struct Payday {
        address: ContractAddress,
        contract: u128
    }

    #[external(v0)]
    impl EvaluatorImpl of super::EvaluatorTrait<ContractState> {
        // ///////////////////
        // GETTER FUNCTIONS
        // ///////////////////
        fn get_public(self: @ContractState) -> felt252 {
            self.public.read()
        }
        fn get_random(self: @ContractState) -> u64 {
            self.random.read()
        }
        fn get_multicall_count(self: @ContractState, tx_meta: felt252) -> felt252 {
            self.multicall_counter.read(tx_meta)
        }

        // ///////////////////
        // EXTERNAL FUNCTIONS
        // ///////////////////
        fn validate_hello(ref self: ContractState, input: u64, address: ContractAddress) -> bool {
            let caller: ContractAddress = get_caller_address();
            assert(caller.is_non_zero(), 'caller is zero');

            let tx_info: TxInfo = get_tx_info().unbox();
            // let execution_info : ExecutionInfo = get_execution_info_syscall().unwrap_syscall().unbox();
            // The account contract from which this transaction originates must be the same as the caller.
            assert(caller == tx_info.account_contract_address, 'invalid caller');
            assert(tx_info.signature.len() == 0, 'invalid signature');

            assert(input == self.random.read(), 'fetched incorrect value');

            // TODO (nonurgent) - Confirm HELLO is actually a contract address and change the value in the event
            self.emit(Payday { address: address, contract: HELLO });
            let _tutorial_erc20_address = self.tutorial_erc20_address.read();
            IWorkshopSupportContractDispatcher { contract_address: _tutorial_erc20_address }
                .assign_rank_to_player(address);
            IWorkshopSupportContractDispatcher { contract_address: _tutorial_erc20_address }
                .validate_and_reward(address, HELLO, 100);
            true
        }

        fn validate_signature_1(
            ref self: ContractState, input: felt252, address: ContractAddress
        ) -> bool {
            let caller = get_caller_address();
            assert(caller.is_non_zero(), 'caller is zero');

            let tx_info: TxInfo = get_tx_info().unbox();
            // The account contract from which this transaction originates must be the same as the caller.
            assert(caller == tx_info.account_contract_address, 'invalid caller');
            assert(tx_info.signature.len() == 0, 'invalid signature');

            let pub = self.public.read();
            let s1 = self.secret_1.read();
            let s2 = self.secret_2.read();

            // TODO (nonurgent) - Look for something like from starkware.cairo.common.hash import hash2
            // to make let (hash) = hash2{hash_ptr=pedersen_ptr}(s1, s2);
            // In this case we are using a pedersen hash
            let hash: felt252 = pedersen(s1, s2);
            assert(hash == input, 'hashes do not match');

            let hash_final: felt252 = pedersen(hash, tx_info.account_contract_address.into());
            assert(
                check_ecdsa_signature(
                    hash_final, pub, *tx_info.signature.at(0), *tx_info.signature.at(1),
                ),
                'could not validate custom hash'
            );
            self.emit(Payday { address: address, contract: SIGNATURE_1 });
            let _tutorial_erc20_address = self.tutorial_erc20_address.read();
            IWorkshopSupportContractDispatcher { contract_address: _tutorial_erc20_address }
                .validate_and_reward(address, SIGNATURE_1, 100);
            true
        }
    }

    // ///////////////////
    // INTERNAL FUNCTIONS
    // ///////////////////
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _is_valid_signature(
            self: @ContractState, message_hash: felt252, signature: Array<felt252>
        ) {
            let _public_key = self.public.read();
            let sig_r = *signature.at(0);
            let sig_s = *signature.at(1);
            check_ecdsa_signature(message_hash, _public_key, sig_r, sig_s);
        }

        fn _is_valid_signature_full(
            self: @ContractState,
            message_hash: felt252,
            pub: felt252,
            sig_r: felt252,
            sig_s: felt252
        ) {
            let _public_key = self.public.read();
            assert(pub != _public_key, 'invalid public key');

            check_ecdsa_signature(message_hash, _public_key, sig_r, sig_s);
        }

        fn _is_valid_eth_signature(
            self: @ContractState,
            message_hash: u256, // Note here a big change from the original code, 
            // we are using a Starknet Signature instead of a an array or *felt
            sig_r: u256,
            sig_s: u256,
            sig_v: u32,
        ) -> bool {
            // `y_parity` == true means that the y coordinate is odd.
            // Some places use non boolean v instead of y_parity.
            // In that case, `signature_from_vrs` should be used.
            let signature_y_parity: Signature = Signature { r: sig_r, s: sig_s, y_parity: true };
            // Creates an ECDSA signature from the `v`, `r` and `s` values.
            // `v` is the sum of an odd number and the parity of the y coordinate of the ec point whose x
            // coordinate is `r`.
            // See https://eips.ethereum.org/EIPS/eip-155 for more details.
            let signature_non_boolean_v: Signature = signature_from_vrs(
                v: sig_v, r: sig_r, s: sig_s
            );
            // Use either `signature_y_parity` or `signature_non_boolean_v`.
            verify_eth_signature(
                message_hash, signature_non_boolean_v, EthAddress { address: ETHEREUM_ADDRESS }
            );
            true
        }
    // TODO (nonurgent) - Add _validate_signer_count function
    // fn _validate_signer_count(
    //     self : @ContractState,
    //     multisig_contract_address: ContractAddress,
    //     tx_index: felt252,
    //     index: felt252,
    //     signers: Array<felt252>
    // ) -> felt252 {
    //     if (index == signers.len().into()) {
    //         return 0;
    //     }

    //     let rest = self._validate_signer_count(
    //         multisig_contract_address, 
    //         tx_index, 
    //         index + 1, 
    //         signers);

    //     let index_u32 : u32 = index.try_into().unwrap();

    //     let confirmed = IMultiSigDispatcher{contract_address: multisig_contract_address}
    //         .get_owner_confirmed(
    //             tx_index: tx_index, owner: *signers.at(index_u32)
    //     );

    //     return confirmed + rest;
    // }

    }
}

