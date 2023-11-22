 ####
# Tutorial Deployment:
# - deploy 'player_registry'
# - deploy 'TDERC20'
# - deploy 'evaluator'
 ####
import asyncio
from importlib.metadata import version

from configs import (get_full_node_client, get_full_node_client_config,
                     load_config)
from contracts import (compile_contract, declare_and_deploy_contract,
                       fund_account, get_account, get_account_0_private_key)
from utils import colored_print


async def main():
    # Initialization and Configuration
    colored_print(f"Starknet py version: {version('starknet_py')}", "yellow")
    config = load_config()

    # funding_amount = (
    #     config["SETTINGS"]["FUNDING_AMOUNT"] / 1e18
    # )  # fetching from config.yaml
    # to_address = config["ACCOUNTS"]["TESTNET"]["ADDRESS"]

    # Setup Client and Account Information
    node_url = get_full_node_client_config(config)
    full_node_client = await get_full_node_client(node_url)
    # account = get_account(full_node_client, config)
    account = get_account_0_private_key(full_node_client, config)

    # Fund Account
    # await fund_account(full_node_client, funding_amount, to_address, config)

    # Compile and Load Contract Data
    (
        casm_compiled_contract,
        sierra_compiled_contract,
        _,
        _,
    ) = compile_contract(config["SETTINGS"]["TARGET_DIR"])

    # constructor_args = {
    #     "init_owner": account.address,
    # }

    # Contructor without arguments
    constructor_args = {}

    # Declare and Deploy Contract
    await declare_and_deploy_contract(
        account,
        casm_compiled_contract,
        sierra_compiled_contract,
        config["SETTINGS"]["MAX_FEE"],
        constructor_args,
    )


if __name__ == "__main__":
    asyncio.run(main())
