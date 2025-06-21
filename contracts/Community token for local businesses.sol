// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interface for ERC20 token standard
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// Basic ERC20 implementation
contract ERC20 is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
    }
    
    function name() public view returns (string memory) { return _name; }
    function symbol() public view returns (string memory) { return _symbol; }
    function decimals() public view returns (uint8) { return _decimals; }
    function totalSupply() public view override returns (uint256) { return _totalSupply; }
    function balanceOf(address account) public view override returns (uint256) { return _balances[account]; }
    
    function transfer(address to, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }
    
    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }
    
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _transfer(from, to, amount);
        _approve(from, msg.sender, currentAllowance - amount);
        return true;
    }
    
    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        _balances[from] = fromBalance - amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }
    
    function _mint(address to, uint256 amount) internal {
        require(to != address(0), "ERC20: mint to the zero address");
        _totalSupply += amount;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }
    
    function _burn(address from, uint256 amount) internal {
        require(from != address(0), "ERC20: burn from the zero address");
        uint256 accountBalance = _balances[from];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        _balances[from] = accountBalance - amount;
        _totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }
    
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}

// Simple ownership control
contract Ownable {
    address private _owner;
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    constructor() {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }
    
    function owner() public view returns (address) {
        return _owner;
    }
    
    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }
    
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// Reentrancy protection
contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;
    
    constructor() {
        _status = _NOT_ENTERED;
    }
    
    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

/**
 * @title CommunityToken
 * @dev A token system for local businesses to reward customers and build community engagement
 */
contract CommunityToken is ERC20, Ownable, ReentrancyGuard {
    
    // Business structure
    struct Business {
        string name;
        address owner;
        bool isVerified;
        uint256 rewardRate; // Tokens per ETH spent
        uint256 totalCustomers;
        bool isActive;
    }
    
    // Customer structure
    struct Customer {
        uint256 totalSpent;
        uint256 tokensEarned;
        uint256 businessesSupported;
        bool isRegistered;
    }
    
    // Mappings
    mapping(address => Business) public businesses;
    mapping(address => Customer) public customers;
    mapping(address => mapping(address => uint256)) public customerBusinessSpending;
    
    // Arrays for tracking
    address[] public businessList;
    address[] public customerList;
    
    // Events
    event BusinessRegistered(address indexed businessAddress, string name);
    event CustomerRegistered(address indexed customerAddress);
    event TokensEarned(address indexed customer, address indexed business, uint256 amount);
    event TokensRedeemed(address indexed customer, address indexed business, uint256 amount);
    event BusinessVerified(address indexed businessAddress);
    
    // Constants
    uint256 public constant INITIAL_REWARD_RATE = 10; // 10 tokens per ETH
    uint256 public constant VERIFICATION_BONUS = 1000 * 10**18; // 1000 tokens bonus for verification
    
    constructor() ERC20("CommunityToken", "COMM") {}
    
    /**
     * @dev Core Function 1: Register a new business in the community
     * @param _name Name of the business
     * @param _rewardRate Number of tokens customers earn per ETH spent
     */
    function registerBusiness(string memory _name, uint256 _rewardRate) external {
        require(bytes(_name).length > 0, "Business name cannot be empty");
        require(_rewardRate > 0, "Reward rate must be greater than 0");
        require(!businesses[msg.sender].isActive, "Business already registered");
        
        businesses[msg.sender] = Business({
            name: _name,
            owner: msg.sender,
            isVerified: false,
            rewardRate: _rewardRate,
            totalCustomers: 0,
            isActive: true
        });
        
        businessList.push(msg.sender);
        
        // Mint initial tokens to business for rewards
        _mint(msg.sender, 10000 * 10**18); // 10,000 initial tokens
        
        emit BusinessRegistered(msg.sender, _name);
    }
    
    /**
     * @dev Core Function 2: Register a customer in the community
     */
    function registerCustomer() external {
        require(!customers[msg.sender].isRegistered, "Customer already registered");
        
        customers[msg.sender] = Customer({
            totalSpent: 0,
            tokensEarned: 0,
            businessesSupported: 0,
            isRegistered: true
        });
        
        customerList.push(msg.sender);
        
        // Welcome bonus for new customers
        _mint(msg.sender, 100 * 10**18); // 100 welcome tokens
        
        emit CustomerRegistered(msg.sender);
    }
    
    /**
     * @dev Core Function 3: Award tokens to customers for purchases
     * @param _customer Address of the customer
     * @param _amountSpent Amount spent by customer (in wei)
     */
    function awardTokensForPurchase(address _customer, uint256 _amountSpent) external {
        require(businesses[msg.sender].isActive, "Business not registered or inactive");
        require(customers[_customer].isRegistered, "Customer not registered");
        require(_amountSpent > 0, "Amount spent must be greater than 0");
        
        Business storage business = businesses[msg.sender];
        Customer storage customer = customers[_customer];
        
        // Calculate tokens to award
        uint256 tokensToAward = (_amountSpent * business.rewardRate) / 1 ether;
        
        // Update customer data
        customer.totalSpent += _amountSpent;
        customer.tokensEarned += tokensToAward;
        
        // Track customer-business relationship
        if (customerBusinessSpending[_customer][msg.sender] == 0) {
            customer.businessesSupported += 1;
            business.totalCustomers += 1;
        }
        customerBusinessSpending[_customer][msg.sender] += _amountSpent;
        
        // Mint tokens to customer
        _mint(_customer, tokensToAward);
        
        emit TokensEarned(_customer, msg.sender, tokensToAward);
    }
    
    /**
     * @dev Core Function 4: Redeem tokens for discounts or rewards at businesses
     * @param _business Address of the business
     * @param _tokenAmount Amount of tokens to redeem
     */
    function redeemTokens(address _business, uint256 _tokenAmount) external nonReentrant {
        require(businesses[_business].isActive, "Business not active");
        require(customers[msg.sender].isRegistered, "Customer not registered");
        require(balanceOf(msg.sender) >= _tokenAmount, "Insufficient token balance");
        require(_tokenAmount > 0, "Token amount must be greater than 0");
        
        // Burn tokens from customer
        _burn(msg.sender, _tokenAmount);
        
        // Mint tokens to business as they're providing the discount/reward
        _mint(_business, _tokenAmount / 2); // Business gets 50% back to encourage participation
        
        emit TokensRedeemed(msg.sender, _business, _tokenAmount);
    }
    
    /**
     * @dev Core Function 5: Verify a business (only owner can verify)
     * @param _businessAddress Address of the business to verify
     */
    function verifyBusiness(address _businessAddress) external onlyOwner {
        require(businesses[_businessAddress].isActive, "Business not registered");
        require(!businesses[_businessAddress].isVerified, "Business already verified");
        
        businesses[_businessAddress].isVerified = true;
        
        // Award verification bonus
        _mint(_businessAddress, VERIFICATION_BONUS);
        
        emit BusinessVerified(_businessAddress);
    }
    
    // View functions
    function getBusinessInfo(address _businessAddress) external view returns (
        string memory name,
        bool isVerified,
        uint256 rewardRate,
        uint256 totalCustomers,
        bool isActive
    ) {
        Business memory business = businesses[_businessAddress];
        return (business.name, business.isVerified, business.rewardRate, business.totalCustomers, business.isActive);
    }
    
    function getCustomerInfo(address _customerAddress) external view returns (
        uint256 totalSpent,
        uint256 tokensEarned,
        uint256 businessesSupported,
        bool isRegistered
    ) {
        Customer memory customer = customers[_customerAddress];
        return (customer.totalSpent, customer.tokensEarned, customer.businessesSupported, customer.isRegistered);
    }
    
    function getTotalBusinesses() external view returns (uint256) {
        return businessList.length;
    }
    
    function getTotalCustomers() external view returns (uint256) {
        return customerList.length;
    }
    
    function getCustomerSpendingAtBusiness(address _customer, address _business) external view returns (uint256) {
        return customerBusinessSpending[_customer][_business];
    }
}