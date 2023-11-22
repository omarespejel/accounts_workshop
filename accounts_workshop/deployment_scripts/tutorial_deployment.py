####
# Tutorial Deployment:
# - deploy 'player_registry'
# - deploy 'TDERC20'
# - deploy 'evaluator'
####
import asyncio
from importlib.metadata import version

from accounts_workshop.configs import (get_full_node_client,
                                       get_full_node_client_config,
                                       load_config)
from accounts_workshop.contracts_utils import (compile_contract,
                                               declare_and_deploy_contract,
                                               fund_account, get_account,
                                               get_account_0_private_key)
from accounts_workshop.utils import colored_print


async def main():
    # Initialization and Configuration
    colored_print(f"Deploying Evaluator contract", "yellow")
    config = load_config()

    # Setup Client and Account Information
    node_url = get_full_node_client_config(config)
    full_node_client = await get_full_node_client(node_url)
    account = get_account(full_node_client, config)

    # Compile and Load Contract Data
    (casm_compiled_contract, sierra_compiled_contract, _, _,) = compile_contract(
        config["CAIRO_CONTRACTS_PATHS"]["EVALUATOR"]["NAME"],
        config["CAIRO_CONTRACTS_PATHS"]["EVALUATOR"]["PATH"],
        config["SETTINGS"]["TARGET_DIR"],
    )

    # # constructor_args = {
    # #     "init_owner": account.address,
    # # }

    # # Contructor without arguments
    # constructor_args = {}

    # # Declare and Deploy Contract
    # await declare_and_deploy_contract(
    #     account,
    #     casm_compiled_contract,
    #     sierra_compiled_contract,
    #     config["SETTINGS"]["MAX_FEE"],
    #     constructor_args,
    # )


if __name__ == "__main__":
    asyncio.run(main())
