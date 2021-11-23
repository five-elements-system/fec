// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.0;

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
    //供应量
    uint256 public totalSupply = 10000000000 * 10 ** 18;
    //是否停用
    bool public isStopped;
    
    //版本控制，ture-弃用
    bool public deprecated = false;
    
    //黑名单mapping
    mapping (address => bool) public isBlackListed;
    
    //授权数据mapping 相当于map包map结构
    mapping (address => mapping (address => uint)) public allowed;

    
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
        require(!isBlackListed[_owner],"in blackListed");
        return balances[_owner];
    }
    
    function transfer(address _to,uint256 _value) public isRunning validAddress isDeprecated returns(bool) {
        require(!isBlackListed[msg.sender]);
        require(!isBlackListed[_to]);
        require(_to != address(0));
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(msg.sender,_to,_value);
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
    function transferFrom(address _from, address _to, uint _value) public isRunning isDeprecated onlyPayloadSize(3 * 32) {
        uint _allowance = allowed[_from][msg.sender];
        require(_allowance >= _value);
        
        require(!isBlackListed[_from]);
        require(!isBlackListed[_to]);
        require(!isBlackListed[msg.sender]);

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(_from, _to, _value);
    }

    //重写授权
    function approve(address _spender, uint _value) public onlyPayloadSize(2 * 32) returns(bool) {

        //如果已经有授权额度了 不能重新授权 必须先授权为0 再重新授权
        require(!((_value != 0) && (allowed[msg.sender][_spender] != 0)));

        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    //重写授权额度
    function allowance(address _owner, address _spender) public view returns (uint remaining) {
        return allowed[_owner][_spender];
    }
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Deprecate(address addr);
    event AddedBlackList(address addr);
    event RemovedBlackList(address addr);
    event Approval(address indexed owner, address indexed spender, uint value);
    event Start();
    event Stop();
}
