pragma solidity ^0.7.5;

import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/ISplitFormula.sol";
import "./interfaces/ITreasury.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Fetch is Ownable {

  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  address public WETH;

  address public dexRouter;

  ISplitFormula public splitFormula;

  address public token;

  address public STABLE_COIN;

  address public treasury;

  /**
  * @dev constructor
  *
  * @param _WETH                  address of Wrapped Ethereum token
  * @param _dexRouter             address of Corader DEX
  * @param _token                 address of token token
  * @param _splitFormula          address of split formula
  */
  constructor(
    address _WETH,
    address _dexRouter,
    address _token,
    address _splitFormula,
    address _STABLE_COIN,
    address _treasury
    )
    public
  {
    WETH = _WETH;
    dexRouter = _dexRouter;
    token = _token;
    splitFormula = ISplitFormula(_splitFormula);
    STABLE_COIN = _STABLE_COIN;
    treasury = _treasury;
  }

  function convert() external payable {
    _convertFor(msg.sender);
  }

  function convertFor(address receiver) external payable {
    _convertFor(receiver);
  }

  /**
  * @dev spit ETH input with DEX and SALE
  */
  function _convertFor(address receiver) internal {
    require(msg.value > 0, "zerro eth");
    // swap ETH
    swapETHInput(msg.value);
    // send tokens back
    uint256 tokenReceived = IERC20(token).balanceOf(address(this));
    require(tokenReceived > 0, "not swapped");
    IERC20(token).transfer(receiver, tokenReceived);
  }


 /**
 * @dev swap ETH to token via DEX and Sale
 */
 function swapETHInput(uint256 input) internal {
  (uint256 ethTodex,
   uint256 ethToSale) = calculateToSplit(input);

  // SPLIT SALE with dex and Sale
  if(ethTodex > 0)
    swapETHViaDEX(dexRouter, token, ethTodex);

  if(ethToSale > 0)
    swapETHViaTreasury(ethToSale);
 }

 // helper for swap ETH to token
 function swapETHViaDEX(address routerDEX, address toToken, uint256 amount) internal {
   // SWAP split % of ETH input to token
   address[] memory path = new address[](2);
   path[0] = WETH;
   path[1] = toToken;

   IUniswapV2Router02(routerDEX).swapExactETHForTokens{value:amount}(
     1,
     path,
     address(this),
     block.timestamp + 1800
   );
 }

 function swapETHViaTreasury(uint256 amount) internal {
    swapETHViaDEX(dexRouter, STABLE_COIN, amount);

    uint256 stableCoinAmount = IERC20(STABLE_COIN).balanceOf(address(this));
    IERC20(STABLE_COIN).approve(address(treasury), stableCoinAmount);
    ITreasury(treasury).deposit( stableCoinAmount, STABLE_COIN, 0);

    uint256 tokenAmount = IERC20(token).balanceOf(address(this));
    require(tokenAmount > 0, "Zerro token from treasury");
 }

 /**
 * @dev return split % amount of input
 */
 function calculateToSplit(uint256 ethInput)
   public
   view
   returns(uint256 ethTodex, uint256 ethToSale)
 {
   (uint256 ethPercentTodex,
    uint256 ethPercentToSale) = splitFormula.calculateToSplit(ethInput);

   ethTodex = ethInput.div(100).mul(ethPercentTodex);
   ethToSale = ethInput.div(100).mul(ethPercentToSale);
 }

 /**
 * @dev allow owner update splitFormula
 */
 function updateSplitFormula(address _splitFormula) external onlyOwner {
   splitFormula = ISplitFormula(_splitFormula);
 }
}
