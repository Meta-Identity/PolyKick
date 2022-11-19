// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./PolyKick_Launchpad.sol";


contract PolyKick_Factory{

    PolyKick_Launchpad public pkLaunchpad;

    uint256 constant months = 30 days;
    uint256 projectsCount;
    address public _factory;


    event launchpadCreated(address pkLaunchpad);


    function startLaunchpad(
        address _polyKick,
        ERC20 _token, 
        uint256 _tokenAmount, 
        ERC20 _currency, 
        uint256 _price, 
        uint256 _priceDecimals, 
        uint256 _target,
        uint256 _months
        ) external returns(address){
        require(_token.balanceOf(msg.sender) >= _tokenAmount,"Not enough tokens");
        require(_target >= (_tokenAmount/2), "Target is less than 50%");
        _factory = address(this);
        _months = _months * months;
        uint256 _duration = _months + block.timestamp;
        pkLaunchpad = new PolyKick_Launchpad(msg.sender, _polyKick, _factory, _token, _tokenAmount, _currency, _price, _priceDecimals, _target, _duration);
        _token.transferFrom(msg.sender, address(pkLaunchpad), _tokenAmount);
        emit launchpadCreated(address(pkLaunchpad));
        projectsCount++;
        return(address(pkLaunchpad));
    }
}

               /*********************************************************
                  Proudly Developed by MetaIdentity ltd. Copyright 2022
               **********************************************************/
