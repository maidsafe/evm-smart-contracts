.PHONY: all remove install build clean update test

all: remove install setup build

remove:
	rm -rf .gitmodules && rm -rf .git/modules && rm -rf lib && touch .gitmodules 

install:
	forge install foundry-rs/forge-std --no-commit && forge install openzeppelin/openzeppelin-contracts --no-commit

setup:
	mkdir -p src script

build:
	forge build

clean:
	forge clean

update:
	forge update

test:
	forge test

audit:
	aderyn && slither .

create:
	@if [ -z "$(name)" ]; then \
		echo "Usage: make create name=<filename>"; \
		exit 1; \
	fi
	@./create.sh "$(name)"

include .env

export $(shell sed 's/=.*//' .env)

deploy-registry:
	forge script script/DeployAppRegistry.s.sol:DeployAppRegistry --rpc-url $(ARBITRUM_RPC_URL) --sender $(SENDER_MAINNET) --etherscan-api-key $(ETHERSCAN_API_KEY) --verify --broadcast

deploy-registry-sim:
	forge script script/DeployAppRegistry.s.sol:DeployAppRegistry --rpc-url $(ARBITRUM_RPC_URL) --sender $(SENDER_MAINNET)

deploy-registry-testnet:
	forge script script/DeployAppRegistry.testnet.s.sol:DeployAppRegistryTestnet --rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) --sender $(SENDER_TESTNET) --etherscan-api-key $(ETHERSCAN_API_KEY) --verify --broadcast

deploy-phase1:
	forge script script/DeployPhase1Voting.s.sol:DeployPhase1Voting --rpc-url $(ARBITRUM_RPC_URL) --sender $(SENDER_MAINNET) --etherscan-api-key $(ETHERSCAN_API_KEY) --verify --broadcast

deploy-phase1-sim:
	forge script script/DeployPhase1Voting.s.sol:DeployPhase1Voting --rpc-url $(ARBITRUM_RPC_URL) --sender $(SENDER_MAINNET)

deploy-phase1-testnet:
	forge script script/DeployPhase1Voting.testnet.s.sol:DeployPhase1VotingTestnet --rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) --sender $(SENDER_TESTNET) --etherscan-api-key $(ETHERSCAN_API_KEY) --verify --broadcast

deploy-phase1-testnet-sim:
	forge script script/DeployPhase1Voting.testnet.s.sol:DeployPhase1VotingTestnet --rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) --sender $(SENDER_TESTNET)

deploy-phase2:
	forge script script/DeployPhase2Voting.s.sol:DeployPhase2Voting --rpc-url $(ARBITRUM_RPC_URL) --sender $(SENDER_MAINNET) --etherscan-api-key $(ETHERSCAN_API_KEY) --verify --broadcast

deploy-phase2-sim:
	forge script script/DeployPhase2Voting.s.sol:DeployPhase2Voting --rpc-url $(ARBITRUM_RPC_URL) --sender $(SENDER_MAINNET)

deploy-phase2-testnet:
	forge script script/DeployPhase2Voting.testnet.s.sol:DeployPhase2VotingTestnet --rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) --sender $(SENDER_TESTNET) --etherscan-api-key $(ETHERSCAN_API_KEY) --verify --broadcast

deploy-phase2-testnet-sim:
	forge script script/DeployPhase2Voting.testnet.s.sol:DeployPhase2VotingTestnet --rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) --sender $(SENDER_TESTNET)

register-apps:
	forge script script/RegisterApps.s.sol:RegisterApps --rpc-url $(ARBITRUM_RPC_URL) --sender $(SENDER_MAINNET) --etherscan-api-key $(ETHERSCAN_API_KEY) --verify --broadcast

register-apps-sim:
	forge script script/RegisterApps.s.sol:RegisterApps --rpc-url $(ARBITRUM_RPC_URL) --sender $(SENDER_MAINNET)