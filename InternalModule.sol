pragma solidity >=0.5.0 <0.6.0;

contract InternalModule {

    address[] _authAddress;

    address _contractOwner;

    address _managerAddress;

    constructor() public {
        _contractOwner = msg.sender;
    }

    modifier OwnerOnly() {
        require( _contractOwner == msg.sender ); _;
    }

    modifier ManagerOnly() {
        require(msg.sender == _managerAddress); _;
    }

    modifier APIMethod() {

        bool exist = false;

        for (uint i = 0; i < _authAddress.length; i++) {
            if ( _authAddress[i] == msg.sender ) {
                exist = true;
                break;
            }
        }

        require(exist); _;
    }

    function SetRoundManager(address rmaddr ) external OwnerOnly {
        _managerAddress = rmaddr;
    }

    function AddAuthAddress(address _addr) external ManagerOnly {
        _authAddress.push(_addr);
    }

    function DelAuthAddress(address _addr) external ManagerOnly {

        for (uint i = 0; i < _authAddress.length; i++) {

            if (_authAddress[i] == _addr) {

                for (uint j = 0; j < _authAddress.length - 1; j++) {

                    _authAddress[j] = _authAddress[j+1];

                }

                delete _authAddress[_authAddress.length - 1];
                _authAddress.length--;
            }

        }
    }


}