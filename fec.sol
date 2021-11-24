// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.0;

import "../../openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../../openzeppelin-contracts/contracts/utils/Context.sol";
import "../../openzeppelin-contracts/contracts/utils/math/SafeMath.sol";


contract FECToken is Context, IERC20, IERC20Metadata {
    
    using SafeMath for uint256;
    
    //代币名称
    string constant private _name = "FEC Token";
    //代币符号 
    string constant private _symbol = "FEC";
    //精度 
    uint8 private _decimals = 18;
    mapping(address => uint256) balances;
    address private owner;
    //供应量
    uint256 private _totalSupply = 10000000000 * 10 ** 18;
    //是否停用
    bool private isStopped;
    
    //版本控制，ture-弃用
    bool private deprecated = false;
    
    //黑名单mapping
    mapping (address => bool) public isBlackListed;
    
    //授权数据mapping 相当于map包map结构
    mapping (address => mapping (address => uint)) public _allowances;

    
    modifier isOwner {
        require(owner == msg.sender);
        _;
    }
    
    modifier isRunning {
        require(!isStopped);
        _;
    }
    
    modifier validAddress {
        require(msg.sender != address(0));
        _;
    }
    
    modifier isDeprecated {
        require(!deprecated);
        _;
    }
    
    //修改器 防止短地址攻击
    modifier onlyPayloadSize(uint size) {
        require(!(msg.data.length < size + 4));
        _;
    }
    
    constructor() {
        owner = msg.sender;
        balances[msg.sender] = _totalSupply;
    }
    
    function balanceOf(address _owner) override public view returns(uint256) {
        require(!isBlackListed[_owner],"in blackListed");
        return balances[_owner];
    }
    
    function transfer(address _to,uint256 _value) override public isRunning validAddress isDeprecated returns(bool) {
        require(!isBlackListed[msg.sender]);
        require(!isBlackListed[_to]);
        require(_to != address(0));
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(msg.sender,_to,_value);
        return true;
    }
    
    //开启
    function start() public isOwner isDeprecated {
        isStopped = false;
        emit Start();
    }
    
    //暂停
    function stop() public isOwner isDeprecated {
        isStopped = true;
        emit Stop();
    }
    
    //弃用
    function deprecate() public isOwner isRunning {
        deprecated = true;
        emit Deprecate(msg.sender);
    }
    
    //加入黑名单
    function addBlackList (address _evilUser) public isOwner isRunning isDeprecated {
        isBlackListed[_evilUser] = true;
        emit AddedBlackList(_evilUser);
    }
    
    //取消黑名单
    function removeBlackList (address _clearedUser) public isOwner isRunning isDeprecated {
        isBlackListed[_clearedUser] = false;
        emit RemovedBlackList(_clearedUser);
    }
    
    //重写代理交易
    function transferFrom(address _from, address _to, uint _value) override public isRunning isDeprecated onlyPayloadSize(3 * 32) returns(bool) {
        uint _allowance = _allowances[_from][msg.sender];
        require(_allowance >= _value);
        
        require(!isBlackListed[_from]);
        require(!isBlackListed[_to]);
        require(!isBlackListed[msg.sender]);

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(_from, _to, _value);
        return true;
    }

    //重写授权
    function approve(address _spender, uint _value) override public onlyPayloadSize(2 * 32) returns(bool) {

        //如果已经有授权额度了 不能重新授权 必须先授权为0 再重新授权
        require(!((_value != 0) && (_allowances[msg.sender][_spender] != 0)));

        _allowances[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    //重写授权额度
    function allowance(address _owner, address _spender) override public view returns (uint remaining) {
        return _allowances[_owner][_spender];
    }
    
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() override public view virtual returns (string memory) {
        return _symbol;
    }
    
    function decimals() override public view virtual returns (uint8) {
        return _decimals;
    }
    
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }
    
    // event Transfer(address indexed from, address indexed to, uint256 value);
    event Deprecate(address addr);
    event AddedBlackList(address addr);
    event RemovedBlackList(address addr);
    // event Approval(address indexed owner, address indexed spender, uint value);
    event Start();
    event Stop();
}
