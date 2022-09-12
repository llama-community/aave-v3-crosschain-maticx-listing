# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# deps
update:; forge update

# Build & test
build  :; forge build --sizes
test   :; forge test -vvv

# Deploy L2 proposals
deploy-maticx :; forge script script/DeployPolygonMaticX.s.sol:DeployPolygonMaticX --rpc-url ${POLYGON_RPC_URL} --broadcast --legacy --private-key ${PRIVATE_KEY} --verify --etherscan-api-key ${POLYGONSCAN_API_KEY} -vvvv
verify-maticx :; forge script script/DeployPolygonMaticX.s.sol:DeployPolygonMaticX --rpc-url ${POLYGON_RPC_URL} --legacy --verify --etherscan-api-key ${POLYGONSCAN_API_KEY} -vvvv

# Deploy L1 proposal
deploy-l1-proposal :; forge script script/DeployL1PolygonProposal.s.sol:DeployMaticX --rpc-url ${ETHEREUM_RPC_URL} --broadcast --private-key ${PRIVATE_KEY} -vvvv
