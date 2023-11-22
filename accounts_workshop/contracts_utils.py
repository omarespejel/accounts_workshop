import json
import subprocess
from pathlib import Path
from typing import Union

from starknet_py.common import (create_casm_class,
                                create_sierra_compiled_contract)
from starknet_py.contract import Contract
from starknet_py.hash.casm_class_hash import compute_casm_class_hash
from starknet_py.hash.selector import get_selector_from_name
from starknet_py.hash.sierra_class_hash import compute_sierra_class_hash
from starknet_py.net.account.account import Account
from starknet_py.net.account.base_account import BaseAccount
from starknet_py.net.client import Client
from starknet_py.net.client_models import Call
from starknet_py.net.models.chains import StarknetChainId
from starknet_py.net.signer.stark_curve_signer import KeyPair

from accounts_workshop.configs import get_network_config
from accounts_workshop.utils import colored_print, int_to_uint256


def compile_contract(contract_name, contract_dir, target_dir):
    colored_print("Cleaning compiler output...", "yellow")
    subprocess.run(["scarb", "clean"])

    colored_print("Compiling contract...", "yellow")
    output = subprocess.run(
        ["scarb", "build"],
        capture_output=True,
        text=True,
    )
    colored_print("STDOUT:", "green")
    print(output.stdout)
    colored_print("STDERR:", "red")
    print(output.stderr)

    if output.returncode != 0:
        colored_print(f"Compilation failed with return code {output.returncode}", "red")
        raise RuntimeError(f"Compilation failed: {output.stderr}")
    else:
        colored_print("Contract compiled successfully.", "green")

    contract_dir = Path(contract_dir)
    target_dir = Path(target_dir)
    casm_file, sierra_file = None, None

    for json_file in target_dir.glob("*.json"):
        if json_file.name.endswith(f"{contract_name}.compiled_contract_class.json"):
            casm_file = json_file
        elif json_file.name.endswith(f"{contract_name}.contract_class.json"):
            sierra_file = json_file

    if casm_file is None or sierra_file is None:
        raise FileNotFoundError(
            f"For contract {contract_name}: One or both of the compiled files (for casm code: compiled_contract_class, for sierra code: contract_class.json) were not found."
        )

    colored_print(f"{contract_name}: CASM compiled contract path: {casm_file}", "green")
    colored_print(
        f"{contract_name}: Sierra compiled contract path: {sierra_file}", "green"
    )

    with open(casm_file, "r") as casm_file:
        casm_compiled_contract = casm_file.read()

    with open(sierra_file, "r") as sierra_file:
        sierra_compiled_contract = sierra_file.read()

    return casm_compiled_contract, sierra_compiled_contract, casm_file, sierra_file


async def deploy_contract(
    account, sierra_compiled_contract_str, class_hash, max_fee, constructor_args: dict
):
    colored_print("Deploying contract...", "yellow")
    sierra_compiled_contract = create_sierra_compiled_contract(
        sierra_compiled_contract_str
    )
    abi = sierra_compiled_contract.abi

    deploy_result = await Contract.deploy_contract(
        account=account,
        class_hash=class_hash,
        abi=json.loads(abi),
        constructor_args=constructor_args,
        max_fee=max_fee,
        cairo_version=1,
    )

    await deploy_result.wait_for_acceptance()
    contract = deploy_result.deployed_contract
    colored_print(
        f"Contract deployed successfully at address: {hex(contract.address)}", "green"
    )


def get_account(client, config):
    colored_print("Getting account...", "yellow")
    network = get_network_config(config)
    account_key = network.upper()
    chain = StarknetChainId.TESTNET

    key_pair = KeyPair.from_private_key(config["ACCOUNTS"][account_key]["PRIVATE"])
    account = Account(
        client=client,
        address=config["ACCOUNTS"][account_key]["ADDRESS"],
        key_pair=key_pair,
        chain=chain,
    )
    colored_print(f"Account address: {hex(account.address)}", "green")
    return account


def get_account_0_private_key(client, config):
    colored_print("Getting account...", "yellow")
    chain = StarknetChainId.TESTNET

    key_pair = KeyPair(private_key=0, public_key=0)
    account = Account(
        client=client,
        address=0x017C1C83FEB4E8E4559BE027F94121837A3B7A0564E14B9861A7CD4765EF1F05,
        key_pair=key_pair,
        chain=chain,
    )
    colored_print(f"Account address: {hex(account.address)}", "green")
    return account


def get_sierra_class_hash(compiled_contract_str: str) -> int:
    sierra_compiled_contract = create_sierra_compiled_contract(compiled_contract_str)
    return compute_sierra_class_hash(sierra_compiled_contract)


async def check_if_already_declared(account, sierra_class_hash):
    colored_print("Checking if contract is already declared...", "yellow")
    try:
        await account.client.get_class_by_hash(sierra_class_hash)
        colored_print("Contract already declared.", "green")
        return True
    except Exception:
        colored_print("Contract not declared yet.", "red")
        return False


async def declare_contract(
    account, casm_compiled_contract, sierra_compiled_contract, max_fee
):
    colored_print("Declaring contract...", "yellow")
    casm_class = create_casm_class(casm_compiled_contract)
    casm_class_hash = compute_casm_class_hash(casm_class)

    colored_print(f"Casm class hash: {hex(casm_class_hash)}", "green")

    sierra_class_hash = get_sierra_class_hash(sierra_compiled_contract)
    if await check_if_already_declared(account, sierra_class_hash):
        colored_print("Contract was already declared. No declaration needed.", "green")
        return

    colored_print("Sending transaction...", "yellow")
    declare_v2_transaction = await account.sign_declare_v2_transaction(
        compiled_contract=sierra_compiled_contract,
        compiled_class_hash=casm_class_hash,
        max_fee=max_fee,
    )

    resp = await account.client.declare(transaction=declare_v2_transaction)
    colored_print(f"Transaction hash: {hex(resp.transaction_hash)}", "green")
    await account.client.wait_for_tx(resp.transaction_hash)
    colored_print("Transaction accepted.", "green")

    colored_print(f"Sierra class hash: {hex(sierra_class_hash)}", "green")
    colored_print("Contract declared successfully.", "green")


async def declare_and_deploy_contract(
    account,
    casm_compiled_contract,
    sierra_compiled_contract,
    max_fee,
    constructor_args: dict,
):
    await declare_contract(
        account, casm_compiled_contract, sierra_compiled_contract, max_fee
    )
    sierra_class_hash = get_sierra_class_hash(sierra_compiled_contract)
    await deploy_contract(
        account, sierra_compiled_contract, sierra_class_hash, max_fee, constructor_args
    )


def starkgate_eth_token_contract(
    client: Union[BaseAccount | Client], config: dict
) -> Contract:
    colored_print("Loading Ethereum Contract...", "blue")
    paying_account = get_account(client, config)
    abi_path = Path("accounts_workshop") / "data" / "ERC20Contract_ABI.json"
    with open(abi_path, "r") as f:
        abi_data = json.load(f)
    colored_print(f"Loaded ABI from {abi_path}", "green")
    contract = Contract(
        abi=abi_data["abi"],
        address=config["ACCOUNTS"]["TESTNET"]["ETH_TOKEN_ADDRESS"]["ADDRESS"],
        provider=paying_account,
        cairo_version=0,
    )
    colored_print(
        f"Contract retrieved successfully for address {hex(contract.address)}", "green"
    )
    return contract


async def fund_account(
    client: Client,
    amount: float,
    to_address: Union[int, str],
    config: dict,
) -> None:
    current_account = get_account(client, config)

    to_address = int(to_address, 16) if isinstance(to_address, str) else to_address
    transfer_amount = amount * 1e18

    eth_contract = starkgate_eth_token_contract(client, config)
    balance_resp = await client.call_contract(
        Call(
            to_addr=eth_contract.address,
            selector=get_selector_from_name("balanceOf"),
            calldata=[current_account.address],
        )
    )
    balance = balance_resp[0]
    colored_print(
        f"Balance of funding account {hex(current_account.address)}: {balance / 1e18} ETH",
        "green",
    )

    if balance < transfer_amount:
        raise ValueError(
            f"Insufficient balance: {balance / 1e18} ETH. Required: {transfer_amount / 1e18} ETH"
        )

    colored_print(f"Initiating transfer of {transfer_amount / 1e18} ETH...", "yellow")
    transaction_data = eth_contract.functions["transfer"].prepare(
        to_address, int_to_uint256(int(transfer_amount))
    )
    transaction = await transaction_data.invoke(max_fee=config["SETTINGS"]["MAX_FEE"])

    colored_print(f"Funding transaction hash: {hex(transaction.hash)}", "green")
    await client.wait_for_tx(transaction.hash)
    status_response = await client.get_transaction_receipt(tx_hash=transaction.hash)

    colored_print(
        f"Funding transaction finality status: {status_response.finality_status}",
        "green",
    )
    colored_print(
        f"Funding transaction execution status: {status_response.execution_status=}",
        "green",
    )
    colored_print(
        f"{transfer_amount / 1e18} ETH sent from {hex(eth_contract.address)} to {hex(to_address)}",
        "green",
    )

    new_balance_resp = await client.call_contract(
        Call(
            to_addr=eth_contract.address,
            selector=get_selector_from_name("balanceOf"),
            calldata=[to_address],
        )
    )
    new_balance = new_balance_resp[0]
    colored_print(
        f"New Balance of {hex(to_address)}: {new_balance / 1e18} ETH", "green"
    )
