upgrade-sim:
	forge script script/DeployVault.s.sol:VaultDeployer --rpc-url https://arbitrum-mainnet.infura.io/v3/e7d05c880a884c5f9b5f1ac06e07022a --sender 0xeeb3e0999D01f0d1Ed465513E414725a357F6ae4

upgrade:
	forge script script/DeployVault.s.sol:VaultDeployer --rpc-url https://arbitrum-mainnet.infura.io/v3/e7d05c880a884c5f9b5f1ac06e07022a --sender 0xeeb3e0999D01f0d1Ed465513E414725a357F6ae4 --etherscan-api-key A8ZB96DESARKHQI3IUJZDY8PW2DN5MJCXU --verify --broadcast

upgrade-testnet:
	forge script script/DeployVault.testnet.s.sol:TestnetVaultDeployer --rpc-url https://arbitrum-sepolia.infura.io/v3/e7d05c880a884c5f9b5f1ac06e07022a --sender 0xeeb3e0999D01f0d1Ed465513E414725a357F6ae4 --etherscan-api-key A8ZB96DESARKHQI3IUJZDY8PW2DN5MJCXU --verify --broadcast

deploy-testnet-sim:
	forge script script/NewDeployVault.testnet.s.sol:NewTestnetVaultDeployer --rpc-url https://arbitrum-sepolia.infura.io/v3/e7d05c880a884c5f9b5f1ac06e07022a --sender 0xeeb3e0999D01f0d1Ed465513E414725a357F6ae4
deploy-testnet:
	forge script script/NewDeployVault.testnet.s.sol:NewTestnetVaultDeployer --rpc-url https://arbitrum-sepolia.infura.io/v3/e7d05c880a884c5f9b5f1ac06e07022a --sender 0xeeb3e0999D01f0d1Ed465513E414725a357F6ae4 --etherscan-api-key A8ZB96DESARKHQI3IUJZDY8PW2DN5MJCXU --verify --broadcast

upgrade-pricing-sim:
	forge script script/UpgradePricing.s.sol:PricingUpgrader --rpc-url https://arbitrum-sepolia.infura.io/v3/e7d05c880a884c5f9b5f1ac06e07022a --sender 0xeeb3e0999D01f0d1Ed465513E414725a357F6ae4

upgrade-pricing:
	forge script script/UpgradePricing.s.sol:PricingUpgrader --rpc-url https://arbitrum-sepolia.infura.io/v3/e7d05c880a884c5f9b5f1ac06e07022a --sender 0xeeb3e0999D01f0d1Ed465513E414725a357F6ae4  --etherscan-api-key A8ZB96DESARKHQI3IUJZDY8PW2DN5MJCXU --verify --broadcast

update-vault-to-pricing:
	forge script script/UpdateVaultPricing.s.sol:TestnetVaultPricingUpdater --rpc-url https://arbitrum-sepolia.infura.io/v3/e7d05c880a884c5f9b5f1ac06e07022a --sender 0xeeb3e0999D01f0d1Ed465513E414725a357F6ae4 --broadcast