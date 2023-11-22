import asyncio

from starknet_py.net.gateway_client import GatewayClient


async def fetch_transaction_receipt(transaction_id: str, network: str = "testnet"):
    client = GatewayClient(network)
    call_result = await client.get_transaction_receipt(transaction_id)
    return call_result


receipt = asyncio.run(
    fetch_transaction_receipt(
        "0x2534e504b48b918088007bc95e8c1b6834f62039f1cc93a991829301c004bfc"
    )
)
print(receipt)
