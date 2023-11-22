import asyncio
from importlib.metadata import version

from configs import get_full_node_client, get_full_node_client_config, load_config
from contracts import (
    declare_and_deploy_contract,
    fund_account,
    get_account,
    load_contract_data,
)
from utils import colored_print


async def main():
    # Initialization and Configuration
    colored_print(f"Starknet py version: {version('starknet_py')}", "yellow")
    config = load_config()

    # Setup Client and Account Information
    node_url = get_full_node_client_config(config)
    full_node_client = await get_full_node_client(node_url)
    account = get_account(full_node_client, config)

    # Compile and Load Contract Data
    casm_compiled_contract, sierra_compiled_contract = load_contract_data(
        config["SETTINGS"]["TARGET_DIR"]
    )

    constructor_args = {
        "init_owner": account.address,
    }

    # Declare and Deploy Contract
    await declare_and_deploy_contract(
        account,
        casm_compiled_contract,
        sierra_compiled_contract,
        config["SETTINGS"]["MAX_FEE"],
    )


if __name__ == "__main__":
    asyncio.run(main())
