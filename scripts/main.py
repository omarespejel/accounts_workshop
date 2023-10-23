import asyncio
import subprocess
from importlib.metadata import version
from pathlib import Path

import yaml
from starknet_py.common import create_casm_class
from starknet_py.hash.casm_class_hash import compute_casm_class_hash
from starknet_py.net.account.account import Account
from starknet_py.net.full_node_client import FullNodeClient
from starknet_py.net.models.chains import StarknetChainId
from starknet_py.net.signer.stark_curve_signer import KeyPair


def load_config(filename="config.yaml"):
    with open(filename, "r") as f:
        config = yaml.safe_load(f)
    return config


def get_full_node_client_config(config):
    """Return the node_url based on the network configuration."""
    network = config.get("NETWORK", "testnet").lower()
    return config["FULL_NODE_CLIENTS"][network.upper()]["URL"]


async def get_full_node_client(node_url):
    print("Getting full node client...")
    return FullNodeClient(node_url=node_url)


def get_account(client, config):
    """Get the account based on the network configuration."""
    print("Getting account...")

    network = config.get("NETWORK", "testnet").lower()
    account_key = network.upper()
    if network == "devnet":
        chain = StarknetChainId.TESTNET
    else:
        chain = StarknetChainId.TESTNET

    key_pair = KeyPair.from_private_key(config["ACCOUNTS"][account_key]["PRIVATE"])
    account = Account(
        client=client,
        address=config["ACCOUNTS"][account_key]["ADDRESS"],
        key_pair=key_pair,
        chain=chain
    )
    print(f"Account address: {hex(account.address)}")
    return account


def compile_contract(target_dir):
    print("Cleaning compiler output...")
    subprocess.run(
        ["scarb", "clean"],
    )
    print("Compiling contract...")
    output = subprocess.run(
        ["scarb", "build"],
        capture_output=True,
        text=True,
    )
    print("STDOUT:")
    print(output.stdout)
    print("STDERR:")
    print(output.stderr)

    if output.returncode != 0:
        print(f"Compilation failed with return code {output.returncode}")
        raise RuntimeError(f"Compilation failed: {output.stderr}")
    else:
        print("Contract compiled successfully.")

    target_dir = Path(target_dir)
    casm_file, sierra_file = None, None

    for json_file in target_dir.glob("*.json"):
        if json_file.name.endswith(".casm.json"):
            casm_file = json_file
        elif json_file.name.endswith(".sierra.json"):
            sierra_file = json_file

    if casm_file is None or sierra_file is None:
        raise FileNotFoundError(
            "One or both of the compiled files (.casm.json, .sierra.json) were not found."
        )

    return casm_file, sierra_file


async def declare_contract(
    account, casm_compiled_contract, sierra_compiled_contract, max_fee
):
    print("Declaring contract...")

    casm_class = create_casm_class(casm_compiled_contract)
    casm_class_hash = compute_casm_class_hash(casm_class)

    print(f"Casm class hash: {casm_class_hash}")

    declare_v2_transaction = await account.sign_declare_v2_transaction(
        compiled_contract=sierra_compiled_contract,
        compiled_class_hash=casm_class_hash,
        max_fee=max_fee,
    )
    print("Sending transaction...")

    # Send Declare v2 transaction
    resp = await account.client.declare(transaction=declare_v2_transaction)
    print(f"Transaction hash: {hex(resp.transaction_hash)}")
    # ISSUE: THE TRANSACTION IS REJECTED SO THE CODE BELOW KEEPS WAITING FOREVER
    await account.client.wait_for_tx(resp.transaction_hash)

    sierra_class_hash = resp.class_hash
    print(f"Sierra class hash: {sierra_class_hash}")
    print("Contract declared successfully.")


async def main():
    print(f"Starknet py version: {version('starknet_py')}")
    print("Loading configuration...")
    config = load_config()
    node_url = get_full_node_client_config(config)
    full_node_client = await get_full_node_client(node_url)
    max_fee = config["SETTINGS"]["MAX_FEE"]
    target_dir = config["SETTINGS"]["TARGET_DIR"]

    full_node_client = await get_full_node_client(node_url)
    account = get_account(full_node_client, config)
    print(f"Account: {hex(account.address)}")
    print(f"Cairo version: {account.client} ")
    print(f"Supported transaction versions: {account.supported_transaction_version}")

    casm_path, sierra_path = compile_contract(target_dir=target_dir)
    print(f"CASM compiled contract path: {casm_path}")
    print(f"Sierra compiled contract path: {sierra_path}")

    with open(casm_path, "r") as f:
        casm_compiled_contract = f.read()

    with open(sierra_path, "r") as f:
        sierra_compiled_contract = f.read()

    await declare_contract(
        account, casm_compiled_contract, sierra_compiled_contract, max_fee
    )


if __name__ == "__main__":
    asyncio.run(main())
