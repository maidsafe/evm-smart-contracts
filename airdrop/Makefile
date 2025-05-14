include .env

export $(shell sed 's/=.*//' .env)

deploy:
	forge script script/DeployAirdrop.s.sol:AirdropDeployer --rpc-url $(ARBITRUM_RPC_URL) --sender $(SENDER) --etherscan-api-key $(ETHERSCAN_API_KEY) --verify --broadcast

deploy-sim:
	forge script script/DeployAirdrop.s.sol:AirdropDeployer --rpc-url $(ARBITRUM_RPC_URL) --sender $(SENDER)

deploy-batch:
	forge script script/DeployBatchETHTransfer.s.sol:BatchETHTransferDeployer --rpc-url $(ARBITRUM_RPC_URL) --sender $(SENDER) --etherscan-api-key $(ETHERSCAN_API_KEY) --verify --broadcast

deploy-batch-sim:
	forge script script/DeployBatchETHTransfer.s.sol:BatchETHTransferDeployer --rpc-url $(ARBITRUM_RPC_URL) --sender $(SENDER)