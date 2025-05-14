include .env

export $(shell sed 's/=.*//' .env)

deploy:
	forge script script/DeployAnt.s.sol:AntDeployer --rpc-url $(ARBITRUM_RPC_URL) --sender $(SENDER) --etherscan-api-key $(ETHERSCAN_API_KEY) --verify --broadcast
	
deploy-sim:
	forge script script/DeployAnt.s.sol:AntDeployer --rpc-url $(ARBITRUM_RPC_URL) --sender $(SENDER)

deploy-testnet:
	forge script script/DeployAnt.s.sol:AntDeployer --rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) --sender $(SENDER) --etherscan-api-key $(ETHERSCAN_API_KEY) --verify --broadcast

deploy-testnet-sim:
	forge script script/DeployAnt.s.sol:AntDeployer --rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) --sender $(SENDER)

deploy-supply:
	forge script script/DeployAntCirculatingSupply.s.sol:AntCirculatingSupplyDeployer --rpc-url $(ARBITRUM_RPC_URL) --sender $(SENDER) --etherscan-api-key $(ETHERSCAN_API_KEY) --verify --broadcast

deploy-supply-sim:
	forge script script/DeployAntCirculatingSupply.s.sol:AntCirculatingSupplyDeployer --rpc-url $(ARBITRUM_RPC_URL) --sender $(SENDER)