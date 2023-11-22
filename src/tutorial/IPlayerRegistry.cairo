use starknet::ContractAddress;

////////////////////////////////
// IPlayerRegistry INTERFACE
////////////////////////////////
#[starknet::interface]
trait IPlayerRegistry<TContractState> {
    fn has_validated_exercise(
        self: @TContractState, account: ContractAddress, workshop: u8, exercise: u128
    ) -> bool;
    fn is_exercise_or_admin(self: @TContractState, account: ContractAddress) -> bool;
    fn next_player_rank(self: @TContractState) -> u8;
    fn players_registry(self: @TContractState, rank: u8) -> ContractAddress;
    fn player_ranks(self: @TContractState, account: ContractAddress) -> u8;
    fn set_exercise_or_admin(ref self: TContractState, account: ContractAddress, permission: bool);
    fn set_exercises_or_admins(ref self: TContractState, accounts: Array::<u8>);
    fn validate_exercise(
        ref self: TContractState, account: ContractAddress, workshop: u8, exercise: u128
    );
}
