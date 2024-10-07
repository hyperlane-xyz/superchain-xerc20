// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../FeesVotingReward.t.sol";

contract DepositIntegrationFuzzTest is FeesVotingRewardTest {
    function test_WhenCallerIsNotTheModuleSetOnTheBridge(address _caller) external {
        // It reverts with {NotAuthorized}
        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;

        vm.assume(_caller != address(leafMessageModule));
        vm.prank(_caller);
        vm.expectRevert(IReward.NotAuthorized.selector);
        leafFVR._deposit({amount: amount, tokenId: tokenId});
    }

    function test_WhenCallerIsTheModuleSetOnTheBridge(uint256 _amount) external {
        // It should update the total supply on the leaf fee voting contract
        // It should update the balance of the token id on the leaf fee voting contract
        // It should emit a {Deposit} event
        _amount = bound(_amount, 1, type(uint256).max);
        uint256 tokenId = 1;

        vm.prank(address(leafMessageModule));
        vm.expectEmit(address(leafFVR));
        emit IReward.Deposit({_amount: _amount, _tokenId: tokenId});
        leafFVR._deposit({amount: _amount, tokenId: tokenId});

        assertEq(leafFVR.totalSupply(), _amount);
        assertEq(leafFVR.balanceOf(tokenId), _amount);
    }
}
