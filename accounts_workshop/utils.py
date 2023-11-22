from termcolor import colored


def colored_print(message: str, color: str) -> None:
    print(colored(message, color))


def int_to_uint256(value: int) -> dict:
    low = value & ((1 << 128) - 1)
    high = value >> 128
    return {"low": low, "high": high}
