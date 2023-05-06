// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IUniswapV2Router {
    function swapExactTokensForETH(uint amountIn,uint amountOutMin,address[] calldata path,address to,uint deadline) external returns (uint[] memory amounts);
    function getAmountsOut(uint amountIn, address[] memory path) external view returns (uint[] memory amounts);
    function swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut,address[] calldata path,address to,uint deadline) external payable returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin,address[] calldata path,address to,uint deadline) external payable returns (uint[] memory amounts);
}

interface ISushiSwapRouter {
    function swapExactETHForTokens(uint amountOutMin,address[] calldata path,address to,uint deadline) external payable returns (uint[] memory amounts);
    function getAmountsOut(uint amountIn, address[] memory path) external view returns (uint[] memory amounts);
    function swapTokensForExactTokens(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline) external returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn,uint amountOutMin,address[] calldata path,address to,uint deadline) external returns (uint[] memory amounts);
    function swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external returns (uint[] memory amounts);
}

interface IWETH9 {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
    function approve(address guy, uint256 wad) external returns (bool);
    function transfer(address dst, uint256 wad) external returns (bool);
    function transferFrom(address src, address dst, uint256 wad) external returns (bool);
    function totalSupply() external view returns (uint256);
    function balanceOf(address src) external view returns (uint256);
    function allowance(address src, address guy) external view returns (uint256);

    event Approval(address indexed src, address indexed guy, uint256 wad);
    event Transfer(address indexed src, address indexed dst, uint256 wad);
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);
}



contract MyContract {
    address constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant UNISWAP_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant SUSHISWAP_ROUTER_ADDRESS = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
    address constant UNI_TOKEN = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    IUniswapV2Router private uniswapRouter;
    ISushiSwapRouter private sushiswapRouter;

    address private owner;

    constructor() {
        uniswapRouter = IUniswapV2Router(UNISWAP_ROUTER_ADDRESS);
        sushiswapRouter = ISushiSwapRouter(SUSHISWAP_ROUTER_ADDRESS);
        owner = msg.sender;
    }

    function checkArbitrageOpportunity(uint256 _amountIn) public view returns (int256) {
        address[] memory path = new address[](2);
        path[0] = WETH_ADDRESS;
        path[1] = UNI_TOKEN;
        
        // Calculate the amount of UNI tokens you'd get for the given amount of WETH on Uniswap
        uint256[] memory uniswapAmountsOut = uniswapRouter.getAmountsOut(_amountIn, path);
        uint256 uniswapUNIAmount = uniswapAmountsOut[1];
        
        // Calculate the amount of WETH you'd get for the given amount of UNI tokens on SushiSwap
        path[0] = UNI_TOKEN;
        path[1] = WETH_ADDRESS;
        uint256[] memory sushiswapAmountsOut = sushiswapRouter.getAmountsOut(uniswapUNIAmount, path);
        uint256 sushiswapWETHAmount = sushiswapAmountsOut[1];
        
        // Calculate the price difference in percentage
        int256 priceDifference = int256(sushiswapWETHAmount) - int256(_amountIn);
        int256 priceDifferencePercentage = (priceDifference * 10000) / int256(_amountIn); // Multiply by 10000 to get percentage with 2 decimal places
        
        return priceDifferencePercentage;
    }


    function swap(uint256 _amountIn, address inputToken, address outputToken) external {
        IWETH9(WETH_ADDRESS).transferFrom(msg.sender, address(this), _amountIn);
        IWETH9(WETH_ADDRESS).approve(address(UNISWAP_ROUTER_ADDRESS) ,_amountIn); 
        
        address[] memory path = new address[](2);
        path[0] = inputToken;
        path[1] = outputToken;

        uint256[] memory amounts = uniswapRouter.swapExactTokensForTokens(_amountIn, 0, path, address(this), block.timestamp);
        uint256 amountOut = amounts[1];

        IWETH9(outputToken).approve(address(SUSHISWAP_ROUTER_ADDRESS), amountOut); 

        path[0] = outputToken;
        path[1] = inputToken;

        uint256[] memory amounts_1 = sushiswapRouter.swapExactTokensForTokens(amountOut, 0, path, msg.sender, block.timestamp);
        uint256 amountOut_1 = amounts_1[1];
        require(amountOut_1 > _amountIn , "Arbitrage unsuccessful!");
    }

    function withdrawETH() external {
        require(msg.sender == owner, "Only the owner can withdraw");
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function withdrawToken(address tokenAddress) external {
        require(msg.sender == owner, "Only the owner can withdraw");
        uint256 balance = IERC20(tokenAddress).balanceOf(address(this));
        IERC20(tokenAddress).transfer(msg.sender, balance);
    }
}
