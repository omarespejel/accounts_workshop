#[starknet::interface]
trait IMultiSig<TContractState> {
    fn get_confirmations(self: @TContractState, tx_index: felt252) -> felt252;
    fn get_num_owners(self: @TContractState) -> u8;
    fn get_owners(self: @TContractState) -> Array<felt252>;
    fn get_owner_confirmed(self: @TContractState, tx_index: felt252, owner: felt252) -> felt252;
}

#[starknet::interface]
trait IAccountSig<TContractState> {
    fn get_public_key(self: @TContractState) -> felt252;
    fn is_valid_signature(
        self: @TContractState, message_hash: felt252, signature: Array<felt252>
    ) -> felt252;
}
