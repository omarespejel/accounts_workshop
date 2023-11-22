import yaml
from starknet_py.net.full_node_client import FullNodeClient
from termcolor import colored


def load_config(filename: str = "config.yaml") -> dict:
    """Load configuration from a file."""
    with open(filename, "r") as f:
        return yaml.safe_load(f)


def get_network_config(config) -> str:
    """Retrieve the network configuration."""
    network = config.get("NETWORK", "testnet").lower()
    print(colored(f"Network configuration retrieved: {network}", "cyan"))
    return network


def get_full_node_client_config(config):
    """Return the node_url based on the network configuration."""
    network = config.get("NETWORK", "testnet").lower()
    node_url = config["FULL_NODE_CLIENTS"][network.upper()]["URL"]
    return node_url


async def get_full_node_client(node_url):
    print(colored("Getting full node client...", "yellow"))
    return FullNodeClient(node_url=node_url)
