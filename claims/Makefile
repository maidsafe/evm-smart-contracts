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

deploy-nft-sim:
	forge script script/DeployAutonomiNFT.s.sol:DeployAutonomiNFT --rpc-url $(ARBITRUM_RPC_URL) --sender $(SENDER)

deploy-nft:
	forge script script/DeployAutonomiNFT.s.sol:DeployAutonomiNFT --rpc-url $(ARBITRUM_RPC_URL) --sender $(SENDER) --etherscan-api-key $(ETHERSCAN_API_KEY) --verify --broadcast

deploy-claims-sim:
	forge script script/DeployClaims.s.sol:DeployClaims --rpc-url $(ARBITRUM_RPC_URL) --sender $(SENDER)

deploy-claims:
	forge script script/DeployClaims.s.sol:DeployClaims --rpc-url $(ARBITRUM_RPC_URL) --sender $(SENDER) --etherscan-api-key $(ETHERSCAN_API_KEY) --verify --broadcast

deploy-foundation-emissions-sim:
	forge script script/DeployFoundationEmissions.s.sol:DeployFoundationEmissions --rpc-url $(ARBITRUM_RPC_URL) --sender $(SENDER)

deploy-foundation-emissions:
	forge script script/DeployFoundationEmissions.s.sol:DeployFoundationEmissions --rpc-url $(ARBITRUM_RPC_URL) --sender $(SENDER) --etherscan-api-key $(ETHERSCAN_API_KEY) --verify --broadcast
