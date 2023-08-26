import json
import os
import subprocess
import sys
import time
from pprint import pprint

import termcolor
import ruamel.yaml
from dotenv import load_dotenv, set_key, dotenv_values

####################
# Global Variables #
####################
L1_CHAIN_ID = "900"
L2_CHAIN_ID = "901"

L1_RPC = "http://localhost:8545"
L2_RPC = "http://localhost:9545"

HIDE_OUTPUT = True  # supress output

# prep directories
SCRIPT_DIR = os.getcwd()
ROOT_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, os.pardir))
ARPA_NODE_DIR = os.path.join(ROOT_DIR, "crates/arpa-node")
ARPA_NODE_CONFIG_DIR = os.path.join(ARPA_NODE_DIR, "test/conf")
CONTRACTS_DIR = os.path.join(ROOT_DIR, "contracts")
ENV_EXAMPLE_PATH = os.path.join(CONTRACTS_DIR, ".env.example")
ENV_PATH = os.path.join(CONTRACTS_DIR, ".env")
OP_CONTROLLER_ORACLE_BROADCAST_PATH = os.path.join(
    CONTRACTS_DIR,
    "broadcast",
    "OPControllerOracleLocalTest.s.sol",
    L2_CHAIN_ID,
    "run-latest.json",
)
CONTROLLER_LOCAL_TEST_BROADCAST_PATH = os.path.join(
    CONTRACTS_DIR,
    "broadcast",
    "ControllerLocalTest.s.sol",
    L1_CHAIN_ID,
    "run-latest.json",
)


def cprint(text: str, color: str = "green"):
    """Prints text in color

    Args:
        text (str): the text to be printed
        color (str): the color to be used
    """
    termcolor.cprint(text, color)


def get_addresses_from_json(path: str) -> dict:
    """
    Given a path to a json file, return a dictionary of contract names to addresses
    """

    # Initialize an empty dictionary
    contracts_dict = {}

    # Open the json file
    with open(path, "r") as read_file:
        data = json.load(read_file)  # Load the json contents
        transactions = data.get(
            "transactions", []
        )  # Get the list of transactions or an empty list if "transactions" key does not exist

        # Loop through each transaction
        for transaction in transactions:
            contract_name = transaction.get("contractName")
            contract_address = transaction.get("contractAddress")

            # If both contractName and contractAddress exists, add to dictionary
            if contract_name and contract_address:
                contracts_dict[contract_name] = contract_address

    return contracts_dict


def run_command(
    cmd: list,
    check=True,
    shell=False,
    cwd=None,
    env=None,
    capture_output=False,  # default to not capturing output (printing directly to stdout).
    # Set to true if you want to suppress output / need to set output to a variable.
    text=False,
):
    """
    Run a command in a subprocess, raising an exception if it fails.
    """
    env = env if env else {}
    return subprocess.run(
        cmd,
        check=check,
        shell=shell,
        env={**os.environ, **env},
        cwd=cwd,
        capture_output=capture_output,
        text=text,
    )


def wait_command(
    cmd: list,
    shell=False,
    env=None,
    cwd=None,
    wait_time=1,
    max_attempts=1,
    fail_value=None,
    success_value=None,
) -> str:
    """Checks for the success of a command after a set interval.
        Returns the stdout if successful or None if it fails.

    Args:
        cmd (List[str]): the command to be run
        wait_time (int): the time to wait between attempts
        max_attempts (int): the maximum number of attempts
        shell (bool): whether to use shell or not
        env (dict): the environment variables dictionary
        cwd (str): the current working directory
        fail_value (str): value that when provided, must not match the output in order to succeed
        success_value (str): value that when provided, must match the output in order to succeed

    Returns:
        str: stdout if the command finishes successfully, None otherwise
    """
    fail_counter = 0

    while True:
        command_output = run_command(
            cmd,
            shell=shell,
            env=env,
            check=False,
            cwd=cwd,
            capture_output=True,  # ALWAYS TRUE as output is needed to check for success
            text=True,
        )
        # If command_output.stdout is not None, strip it
        stdout = command_output.stdout.strip() if command_output.stdout else None

        # # Debugging
        # print("command_output.returncode: ", command_output.returncode)
        # print("command_output.stdout: ", command_output.stdout)
        # print("stdout: ", stdout)
        # print("fail_value: ", fail_value)
        # print("success_value: ", success_value)

        # Judge whether the command is successful
        if (
            command_output.returncode == 0  # If the command is successful
            and stdout is not None  # If stdout is not None
        ):
            # If neither success_value or fail_value is set, return stdout
            if success_value is None and fail_value is None:
                return stdout
            # If success_value is set, but fail_value is not, return stdout if stdout == success_value
            if success_value is not None and fail_value is None:
                if stdout == success_value:
                    return stdout
            # If fail_value is set, but success_value is not, return stdout if stdout != fail_value
            if success_value is None and fail_value is not None:
                if stdout != fail_value:
                    return stdout
            # If both success_value and fail_value are set, return stdout if stdout == success_value and stdout != fail_value
            if success_value is not None and fail_value is not None:
                if (stdout == success_value) and (stdout != fail_value):
                    return stdout

        # If the command fails, print a dot and increment the fail_counter
        print(".", end="", flush=True)
        fail_counter += 1

        # If the command fails for max_attempts consecutive times, return None
        if fail_counter >= max_attempts:
            print(
                f"\nError: Command did not finish after {wait_time*max_attempts} seconds. Exiting..."
            )
            return None
            # sys.exit(1)

        # Wait for wait_time seconds before trying again
        time.sleep(wait_time)


def deploy_contracts():
    ##################################
    ###### Contract Deployment #######
    ##################################

    # 1. Copy .env.example to .env, and load .env file for editing
    run_command(["cp", ENV_EXAMPLE_PATH, ENV_PATH])

    # 2. Deploy L2 OPControllerOracleLocalTest contracts (ControllerOracle, Adapter, Arpa)
    # # forge script script/OPControllerOracleLocalTest.s.sol:OPControllerOracleLocalTestScript --fork-url http://localhost:9545 --broadcast
    print("Running Solidity Script: OPControllerOracleLocalTest on L1...")
    cmd = f"forge script script/OPControllerOracleLocalTest.s.sol:OPControllerOracleLocalTestScript --fork-url {L2_RPC} --broadcast"
    cprint(cmd)
    run_command(
        [cmd], env={}, cwd=CONTRACTS_DIR, capture_output=HIDE_OUTPUT, shell=True
    )
    # get L2 contract addresses from broadcast and update .env file
    l2_addresses = get_addresses_from_json(OP_CONTROLLER_ORACLE_BROADCAST_PATH)
    set_key(ENV_PATH, "OP_ADAPTER_ADDRESS", l2_addresses["ERC1967Proxy"])
    set_key(ENV_PATH, "OP_ARPA_ADDRESS", l2_addresses["Arpa"])
    set_key(ENV_PATH, "OP_CONTROLLER_ORACLE_ADDRESS", l2_addresses["ControllerOracle"])

    # 3. Deploy L1 ControllerLocalTest contracts
    #     (Controller, Controller Relayer, OPChainMessenger, Adapter, Arpa, Staking)
    # forge script script/ControllerLocalTest.s.sol:ControllerLocalTestScript --fork-url http://localhost:8545 --broadcast
    print("Running Solidity Script: ControllerLocalTest on L1...")
    cmd = f"forge script script/ControllerLocalTest.s.sol:ControllerLocalTestScript --fork-url {L1_RPC} --broadcast"
    cprint(cmd)
    run_command(
        [cmd],
        env={},
        cwd=CONTRACTS_DIR,
        capture_output=HIDE_OUTPUT,
        shell=True,
    )

    # get L1 contract addresses from broadcast and update .env file
    l1_addresses = get_addresses_from_json(CONTROLLER_LOCAL_TEST_BROADCAST_PATH)
    set_key(ENV_PATH, "ARPA_ADDRESS", l1_addresses["Arpa"])
    set_key(ENV_PATH, "STAKING_ADDRESS", l1_addresses["Staking"])
    set_key(ENV_PATH, "CONTROLLER_ADDRESS", l1_addresses["Controller"])
    set_key(ENV_PATH, "ADAPTER_ADDRESS", l1_addresses["ERC1967Proxy"])

    # 4. deploy remaining contracts (Controller Oracle Init, StakeNodeLocalTest)
    # forge script script/OPControllerOracleInitializationLocalTest.s.sol:OPControllerOracleInitializationLocalTestScript --fork-url http://localhost:9545 --broadcast
    print(
        "Running Solidity Script: OPControllerOracleInitializationLocalTestScript on L2..."
    )
    cmd = f"forge script script/OPControllerOracleInitializationLocalTest.s.sol:OPControllerOracleInitializationLocalTestScript --fork-url {L2_RPC} --broadcast"
    cprint(cmd)
    run_command(
        [cmd],
        env={
            "OP_ADAPTER_ADDRESS": l2_addresses["ERC1967Proxy"],
            "OP_ARPA_ADDRESS": l2_addresses["Arpa"],
            "OP_CONTROLLER_ORACLE_ADDRESS": l2_addresses["ControllerOracle"],
        },
        cwd=CONTRACTS_DIR,
        capture_output=HIDE_OUTPUT,
        shell=True,
    )

    # forge script script/InitStakingLocalTest.s.sol:InitStakingLocalTestScript --fork-url http://localhost:8545 --broadcast -g 15
    print("Running Solidity Script: InitStakingLocalTestScript on L1...")
    cmd = f"forge script script/InitStakingLocalTest.s.sol:InitStakingLocalTestScript --fork-url {L1_RPC} --broadcast -g 150"
    cprint(cmd)
    run_command(
        [cmd],
        env={
            "ARPA_ADDRESS": l1_addresses["Arpa"],
            "STAKING_ADDRESS": l1_addresses["Staking"],
        },
        cwd=CONTRACTS_DIR,
        capture_output=HIDE_OUTPUT,
        shell=True,
    )

    # forge script script/StakeNodeLocalTest.s.sol:StakeNodeLocalTestScript --fork-url http://localhost:8545 --broadcast
    print("Running Solidity Script: StakeNodeLocalTestScript on L1...")
    cmd = f"forge script script/StakeNodeLocalTest.s.sol:StakeNodeLocalTestScript --fork-url {L1_RPC} --broadcast -g 150"
    cprint(cmd)
    run_command(
        [cmd],
        env={
            "ARPA_ADDRESS": l1_addresses["Arpa"],
            "STAKING_ADDRESS": l1_addresses["Staking"],
            "ADAPTER_ADDRESS": l1_addresses["ERC1967Proxy"],
        },
        cwd=CONTRACTS_DIR,
        capture_output=HIDE_OUTPUT,
        shell=True,
    )


def deploy_nodes():  # ! Deploy Nodes
    l1_addresses = get_addresses_from_json(CONTROLLER_LOCAL_TEST_BROADCAST_PATH)
    l2_addresses = get_addresses_from_json(OP_CONTROLLER_ORACLE_BROADCAST_PATH)

    ######################################
    ###### ARPA Network Deployment #######
    ######################################

    # update config.yml files with correect L1 controller and adapter addresses
    config_files = ["config_1.yml", "config_2.yml", "config_3.yml"]
    yaml = ruamel.yaml.YAML()
    yaml.preserve_quotes = True  # preserves quotes
    yaml.indent(sequence=4, offset=2)  # set indentation

    for file in config_files:
        file_path = os.path.join(ARPA_NODE_CONFIG_DIR, file)
        with open(file_path, "r") as f:
            data = yaml.load(f)
        # L1
        data["adapter_address"] = l1_addresses["ERC1967Proxy"]
        data["controller_address"] = l1_addresses["Controller"]
        data["controller_relayer_address"] = l1_addresses["ControllerRelayer"]
        # L2
        data["relayed_chains"][0]["controller_oracle_address"] = l2_addresses[
            "ControllerOracle"
        ]
        data["relayed_chains"][0]["adapter_address"] = l2_addresses["ERC1967Proxy"]

        # # update rpc endpoints # Todo: Looks like this breaks things... we need to use 127.0.0.1 for the node config???
        data["provider_endpoint"] = L1_RPC
        data["relayed_chains"][0]["provider_endpoint"] = L2_RPC

        with open(file_path, "w") as f:
            yaml.dump(data, f)

    # start randcast nodes
    print("Starting randcast nodes...")
    print("Starting Node 1!")
    cmd = f"cargo run --bin node-client -- -c {ARPA_NODE_CONFIG_DIR}/config_1.yml > /dev/null 2>&1 &"
    cprint(cmd)

    run_command(
        [cmd],
        cwd=ARPA_NODE_DIR,
        shell=True,
    )

    print("Starting Node 2!")
    cmd = f"cargo run --bin node-client -- -c {ARPA_NODE_CONFIG_DIR}/config_2.yml > /dev/null 2>&1 &"
    cprint(cmd)
    run_command(
        [cmd],
        cwd=ARPA_NODE_DIR,
        shell=True,
    )

    print("Starting Node 3!")
    cmd = f"cargo run --bin node-client -- -c {ARPA_NODE_CONFIG_DIR}/config_3.yml > /dev/null 2>&1 &"
    cprint(cmd)
    run_command(
        [cmd],
        cwd=ARPA_NODE_DIR,
        shell=True,
    )

    # wait for succesful grouping (fail after 1m without grouping)
    print("Waiting for nodes to group... ")
    time.sleep(5)  # wait for node.log file to be created
    cmd = f"cat {ARPA_NODE_DIR}/log/1/node.log | grep 'available'"
    cprint(cmd)
    nodes_grouped = wait_command(
        [cmd],
        wait_time=10,
        max_attempts=12,
        shell=True,
    )

    if nodes_grouped:
        print("\nNodes grouped succesfully!")
        print("Output:\n", nodes_grouped, "\n")
    else:
        print("Nodes failed to group!")
        # print out logs
        run_command(
            [
                f"cat {ARPA_NODE_DIR}/log/1/node.log | tail",
            ],
            shell=True,
        )
        print("Quitting...")
        sys.exit(1)

    # Wait for DKG Proccess to Finish
    print(
        "Waiting for DKG Proccess to complete (group 0 coordinator should zero out)..."
    )
    # call controller.getCoordinator(). If it returns 0, we know dkg proccess finished and post proccess dkg has been called
    # function getCoordinator(uint256 groupIndex) public view override(IController) returns (address) {
    #     return _coordinators[groupIndex];
    # }
    cmd = f"cast call {l1_addresses['Controller']} 'getCoordinator(uint256)' 0 --rpc-url {L1_RPC}"
    cprint(cmd)

    coordinator = wait_command(
        [cmd],
        wait_time=10,
        max_attempts=12,
        shell=True,
        success_value="0x0000000000000000000000000000000000000000000000000000000000000000",
    )
    print("\nDKG Proccess Completed Succesfully!")
    print(f"Coordinator Value: {coordinator}\n")

    time.sleep(10)  # wait for group info to propogate from L1 to L2


def get_last_randomness(address: str, rpc: str) -> str:
    last_randomness_l1 = wait_command(
        [f'cast call {address} "getLastRandomness()(uint256)" --rpc-url {rpc}'],
        wait_time=1,
        max_attempts=1,
        shell=True,
    ).strip()
    return last_randomness_l1


def test_request_randomness():  # ! Integration Testing
    l1_addresses = get_addresses_from_json(CONTROLLER_LOCAL_TEST_BROADCAST_PATH)
    l2_addresses = get_addresses_from_json(OP_CONTROLLER_ORACLE_BROADCAST_PATH)
    # pprint(l1_addresses)
    # pprint(l2_addresses)

    # Check group state
    print("L1 Group Info:")
    cmd = f"cast call {l1_addresses['Controller']} \"getGroup(uint256)\" 0 --rpc-url {L1_RPC}"
    l1_group_into = run_command(
        [cmd],
        shell=True,
    )
    # print(l1_group_into)

    print("L2 Group Info:")
    cmd = f"cast call {l2_addresses['ControllerOracle']} \"getGroup(uint256)\" 0 --rpc-url {L2_RPC}"
    cprint(cmd)
    l2_group_into = run_command(
        [cmd],
        shell=True,
    )
    # print(l2_group_into)

    ############################################
    ###### L1 Request Randomness Testing #######
    ############################################

    # 1. Get last randomness

    # get L1 previous randomness
    l1_prev_randomness = get_last_randomness(l1_addresses["ERC1967Proxy"], L1_RPC)

    # 2. Deploy L1 user contract and request randomness
    print("Deploying L1 user contract and requesting randomness...")
    cmd = f"forge script script/GetRandomNumberLocalTest.s.sol:GetRandomNumberLocalTestScript --fork-url {L1_RPC} --broadcast"
    cprint(cmd)
    run_command(
        [cmd],
        env={
            "ADAPTER_ADDRESS": l1_addresses["ERC1967Proxy"],
        },
        cwd=CONTRACTS_DIR,
        capture_output=HIDE_OUTPUT,
        shell=True,
    )
    l1_cur_randomness = get_last_randomness(l1_addresses["ERC1967Proxy"], L1_RPC)

    # 3. Check if randomness is updated

    print("Waiting for randomness to be updated...")
    cmd = f'cast call {l1_addresses["ERC1967Proxy"]} "getLastRandomness()(uint256)" --rpc-url {L1_RPC}'
    cprint(cmd)
    l1_cur_randomness = wait_command(
        [cmd],
        wait_time=5,
        max_attempts=10,
        fail_value=l1_prev_randomness,
        shell=True,
    )
    print(f"\nOld L1 randomness: {l1_prev_randomness}")
    print(f"New L1 randomness: {l1_cur_randomness}")
    print("L1 Requested Randomness succesfully!\n")

    ############################################
    ###### L2 Request Randomness Testing #######
    ############################################

    # 1. Get last randomness
    # get l2 previous randomness
    l2_prev_randomness = get_last_randomness(l2_addresses["ERC1967Proxy"], L2_RPC)

    # 2. Deploy l2 user contract and request randomness
    print("Deploying l2 user contract and requesting randomness...")

    # forge script script/OPGetRandomNumberLocalTest.s.sol:OPGetRandomNumberLocalTestScript --fork-url http://localhost:9545 --broadcast
    cmd = f"forge script script/OPGetRandomNumberLocalTest.s.sol:OPGetRandomNumberLocalTestScript --fork-url {L2_RPC} --broadcast"
    cprint(cmd)
    run_command(
        [cmd],
        env={
            "OP_ADAPTER_ADDRESS": l2_addresses["ERC1967Proxy"],
        },
        cwd=CONTRACTS_DIR,
        capture_output=HIDE_OUTPUT,
        shell=True,
    )
    l2_cur_randomness = get_last_randomness(l2_addresses["ERC1967Proxy"], L2_RPC)

    # 3. Check if randomness is updated

    print("Waiting for randomness to be updated...")
    cmd = f'cast call {l2_addresses["ERC1967Proxy"]} "getLastRandomness()(uint256)" --rpc-url {L2_RPC}'
    cprint(cmd)
    l2_cur_randomness = wait_command(
        [cmd],
        wait_time=5,
        max_attempts=10,
        fail_value=l2_prev_randomness,
        shell=True,
    )
    print(f"\nOld L2 randomness: {l2_prev_randomness}")
    print(f"New L2 randomness: {l2_cur_randomness}")
    print("L2 Requested Randomness succesfully!\n")


def print_addresses():
    l1_addresses = get_addresses_from_json(CONTROLLER_LOCAL_TEST_BROADCAST_PATH)
    l2_addresses = get_addresses_from_json(OP_CONTROLLER_ORACLE_BROADCAST_PATH)
    print("L1 Addresses:")
    pprint(l1_addresses)
    print("L2 Addresses:")
    pprint(l2_addresses)


def main():
    deploy_contracts()
    deploy_nodes()
    test_request_randomness()

    # print_addresses()

    # if testnet.. comment out the following


if __name__ == "__main__":
    main()
