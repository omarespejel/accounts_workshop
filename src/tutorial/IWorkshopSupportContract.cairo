use starknet::ContractAddress;

////////////////////////////////
// IWorkshopSupportContract INTERFACE
////////////////////////////////
#[starknet::interface]
trait IWorkshopSupportContract<TContractState> {
    fn distribute_points(self: @TContractState, to: ContractAddress, amount: u128);
    fn set_teacher(ref self: TContractState, account: ContractAddress, permission: bool);
    fn set_max_rank(ref self: TContractState, max_rank: u8);
    fn ex_initializer(
        ref self: TContractState,
        _erc20_address: ContractAddress,
        _players_registry: ContractAddress,
        _workshop_id: u8
    );
    fn assign_rank_to_player(ref self: TContractState, sender_address: ContractAddress);
    fn validate_and_reward(
        self: @TContractState, sender_address: ContractAddress, exercise: u128, points: u128
    );
}
