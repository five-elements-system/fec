// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.0;

// import "./library.sol";

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a / b;
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}


contract FECToken {
    
    using SafeMath for uint256;
    
    //代币名称
    string constant public name = "FEC Token";
    //代币符号 
    string constant public symbol = "FEC";
    //精度 
    uint256 public decimals = 18;
    mapping(address => uint256) balances;
    address public owner;
    
    uint256 public totalSupply = 10000000000;
    bool public isStopped;
    
    //版本控制，ture-弃用
    bool public deprecated;
    
    //黑名单mapping
    mapping (address => bool) public isBlackListed;
    
    //授权数据mapping 相当于map包map结构
    mapping (address => mapping (address => uint)) public allowed;
    //2**256就是2的256次方
    uint public constant MAX_UINT = 2**256 - 1;
    
    uint _allowance;
    uint public basisPointsRate = 0;
    uint public maximumFee = 0;//最大燃料费
    
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
        balances[msg.sender] = totalSupply;
    }
    
    function balanceOf(address _owner) public view returns(uint256) {
        require(!isBlackListed[_owner]);
        return balances[_owner];
    }
    
    function transfer(address _to,uint256 _value) public isRunning validAddress isDeprecated returns(bool) {
        require(!isBlackListed[msg.sender]);
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(msg.sender,_to,_value);
    }
    
    function start() public isOwner {
        isStopped = false;
    }
    
    function stop() public isOwner {
        isStopped = true;
    }
    
    //弃用当前版本
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
    
    //销毁黑名单账户 把它的代币清空
    function destroyBlackFunds (address _blackListedUser) public isOwner isRunning isDeprecated {
        require(isBlackListed[_blackListedUser]);
        uint dirtyFunds = balanceOf(_blackListedUser);
        balances[_blackListedUser] = 0;
        totalSupply -= dirtyFunds;
        DestroyedBlackFunds(_blackListedUser, dirtyFunds);
    }
    
    //重写代理交易
    function transferFrom(address _from, address _to, uint _value) public onlyPayloadSize(3 * 32) {
        _allowance = allowed[_from][msg.sender];
        
        require(_allowance >= _value);

        uint fee = (_value.mul(basisPointsRate)).div(10000);
        if (fee > maximumFee) {
            fee = maximumFee;
        }
        if (_allowance < MAX_UINT) {
            allowed[_from][msg.sender] = _allowance.sub(_value);
        }
        uint sendAmount = _value.sub(fee);
        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(sendAmount);
        if (fee > 0) {
            balances[owner] = balances[owner].add(fee);
            emit Transfer(_from, owner, fee);
        }
        emit Transfer(_from, _to, sendAmount);
    }

    //重写授权
    function approve(address _spender, uint _value) public onlyPayloadSize(2 * 32) {

        //如果已经有授权额度了 不能重新授权 必须先授权为0 再重新授权
        require(!((_value != 0) && (allowed[msg.sender][_spender] != 0)));

        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
    }

    //重写授权额度
    function allowance(address _owner, address _spender) public view returns (uint remaining) {
        return allowed[_owner][_spender];
    }
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Deprecate(address addr);
    event AddedBlackList(address addr);
    event RemovedBlackList(address addr);
    event DestroyedBlackFunds(address addr,uint256 balance);
    event Approval(address indexed owner, address indexed spender, uint value);
}
