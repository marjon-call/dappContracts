// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

contract AddressProvider {

    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    struct ContractData {
        uint128 version;
        uint128 lastModified;
        address proxyAddress;
        bool isDeprecated;
        string name;
    }

    mapping(string => ContractData) public contracts;
    uint256 public numberOfContracts;

    address public owner;

    event ContractAdded(address proxy, string name);

    constructor(address _owner) {
        owner = _owner;
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Adds contracts to the address provider that have already been deployed
    /// @dev Only called by the contract owner
    /// @param _proxy the proxy address of the contract we are adding
    /// @param _name the name of the contract for reference
    function addContract(address _proxy, string memory _name) external onlyOwner {
        require(contracts[_name].lastModified == 0, "Contract already exists");
        contracts[_name] = ContractData({
            version: 1,
            lastModified: uint128(block.timestamp),
            proxyAddress: _proxy,
            isDeprecated: false,
            name: _name
        });
        numberOfContracts++;

        emit ContractAdded(_proxy, _name);
    }

    /// @notice Deactivates a contract
    /// @dev Only called by the contract owner
    /// @param _name the contract identifier
    function deactivateContract(string memory _name) external onlyOwner {
        require(contracts[_name].isDeprecated == false, "Contract already deprecated");
        contracts[_name].isDeprecated = true;
    }

    /// @notice Reactivates a contract
    /// @dev Only called by the contract owner
    /// @param _name the contract identifier
    function reactivateContract(string memory _name) external onlyOwner {
        require(contracts[_name].isDeprecated == true, "Contract already active");
        contracts[_name].isDeprecated = false;
    }

    //--------------------------------------------------------------------------------------
    //--------------------------------------  SETTER  --------------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Facilitates the change of ownership
    /// @dev Only called by the contract owner
    /// @param _newOwner the address of the new owner
    function setOwner(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Cannot be zero addr");
        owner = _newOwner;
    }

    //--------------------------------------------------------------------------------------
    //--------------------------------------  GETTER  --------------------------------------
    //--------------------------------------------------------------------------------------

    function getProxyAddress(string memory _name) external view returns (address) {
        return contracts[_name].proxyAddress;
    }

    function getImplementationAddress(string memory _name) external view returns (address) {
        //TODO: Return getImplementation from the proxy contract
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner function");
        _;
    }
}
