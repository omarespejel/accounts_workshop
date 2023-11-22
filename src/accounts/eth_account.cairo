use starknet::account::Call;

// IPublicKey obtained from Open Zeppelin's cairo-contracts/src/account/interface.cairo
#[starknet::interface]
trait IPublicKey<TState> {
    fn get_public_key(self: @TState) -> felt252;
    fn set_public_key(ref self: TState, new_public_key: felt252);
}

// IDeclarer obtained from Open Zeppelin's cairo-contracts/src/account/interface.cairo
#[starknet::interface]
trait IDeclarer<TState> {
    fn __validate_declare__(self: @TState, class_hash: felt252) -> felt252;
}

// IDeployable obtained from Open Zeppelin's cairo-contracts/src/account/interface.cairo
#[starknet::interface]
trait IDeployable<TState> {
    fn __validate_deploy__(
        self: @TState, class_hash: felt252, contract_address_salt: felt252, public_key: felt252
    ) -> felt252;
}

// IERC6 obtained from Open Zeppelin's cairo-contracts/src/account/interface.cairo
#[starknet::interface]
trait ISRC6<TState> {
    fn __execute__(self: @TState, calls: Array<Call>) -> Array<Span<felt252>>;
    fn __validate__(self: @TState, calls: Array<Call>) -> felt252;
    fn is_valid_signature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;
}

#[starknet::contract]
mod EthSignatureAccount {
    use core::traits::TryInto;
    use starknet::account::Call;
    use starknet::get_tx_info;
    use starknet::eth_signature::verify_eth_signature;
    use starknet::secp256_trait::{Signature, signature_from_vrs};
    use starknet::EthAddress;
    use integer::Felt252TryIntoU32;
    use starknet::get_caller_address;


    #[storage]
    struct Storage {
        // the ethereum_address is the last 20 bytes of the hash of the public key
        ethereum_address: felt252,
    }

    #[constructor]
    fn constructor(ref self: ContractState, public_key: felt252) {
        self.ethereum_address.write(public_key);
    }

    #[external(v0)]
    impl PublicKeyImpl of super::IPublicKey<ContractState> {
        fn get_public_key(self: @ContractState) -> felt252 {
            self.ethereum_address.read()
        }
        fn set_public_key(ref self: ContractState, new_public_key: felt252) {
            self.ethereum_address.write(new_public_key);
        }
    }

    #[external(v0)]
    impl DeclarerImpl of super::IDeclarer<ContractState> {
        fn __validate_declare__(self: @ContractState, class_hash: felt252) -> felt252 {
            let tx_info = get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            let signature = tx_info.signature;
            assert(self._is_valid_signature(tx_hash, signature), 'Account: invalid signature');
            starknet::VALIDATED
        }
    }

    #[external(v0)]
    impl DeployableImpl of super::IDeployable<ContractState> {
        fn __validate_deploy__(
            self: @ContractState,
            class_hash: felt252,
            contract_address_salt: felt252,
            public_key: felt252
        ) -> felt252 {
            let tx_info = get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            let signature = tx_info.signature;
            assert(self._is_valid_signature(tx_hash, signature), 'Account: invalid signature');
            starknet::VALIDATED
        }
    }

    #[external(v0)]
    impl ERC6Impl of super::ISRC6<ContractState> {
        fn __execute__(self: @ContractState, calls: Array<Call>) -> Array<Span<felt252>> {
            let sender = get_caller_address();
            assert(sender.is_zero(), 'Account: invalid caller');

            _execute_calls(calls)
        }

        fn __validate__(self: @ContractState, calls: Array<Call>) -> felt252 {
            let tx_info = get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            let signature = tx_info.signature;
            assert(self._is_valid_signature(tx_hash, signature), 'Account: invalid signature');
            starknet::VALIDATED
        }

        fn is_valid_signature(
            self: @ContractState, hash: felt252, signature: Array<felt252>
        ) -> felt252 {
            if self._is_valid_signature(hash, signature.span()) {
                starknet::VALIDATED
            } else {
                0
            }
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _is_valid_signature(
            self: @ContractState, hash: felt252, signature: Span<felt252>
        ) -> bool {
            let sig_v: felt252 = *signature.at(0);
            let sig_r: felt252 = *signature.at(1);
            let sig_s: felt252 = *signature.at(2);

            self
                ._is_valid_eth_signature(
                    message_hash: hash.into(),
                    sig_r: sig_r.into(),
                    sig_s: sig_s.into(),
                    sig_v: sig_v.try_into().unwrap()
                )
        }

        fn _is_valid_eth_signature(
            self: @ContractState,
            message_hash: u256, // Note here a big change from the original code, 
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
                message_hash,
                signature_non_boolean_v,
                // TODO - Confirm this is the correct ethereum address
                EthAddress { address: self.ethereum_address.read() }
            );
            true
        }
    }

    fn _execute_calls(mut calls: Array<Call>) -> Array<Span<felt252>> {
        let mut res = ArrayTrait::new();
        loop {
            match calls.pop_front() {
                Option::Some(call) => {
                    let _res = _execute_single_call(call);
                    res.append(_res);
                },
                Option::None(_) => { break (); },
            };
        };
        res
    }

    fn _execute_single_call(call: Call) -> Span<felt252> {
        let Call{to, selector, calldata } = call;
        starknet::call_contract_syscall(to, selector, calldata.span()).unwrap()
    }
}
