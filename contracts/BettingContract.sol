// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EuroCupBetting {

    event CategoryCreated(uint16 indexed categoryId, string name);
    event MatchCreated(uint256 indexed matchId, uint16 indexed categoryId, string homeTeam, string awayTeam);
    event BetPlaced(address indexed better, uint256 indexed matchId, uint8 prediction, uint256 amount);
    event GameResultSet(uint256 indexed matchId, uint8 result);
    event PrizeDistributed(address indexed winner, uint256 indexed matchId, uint256 amount);


    struct Category {
        uint16 categoryId;
        string name;
        Match[] matches;
    }

    struct Bet {
        uint256 betId;
        uint256 matchId;
        address better;
        uint256 amount;
        uint8 prediction; // 0: Home Win, 1: Draw, 2: Away Win
    }

    struct Match {
        uint256 matchId;
        string homeTeam;
        string awayTeam;
        uint8 result; // 0: Not Declared, 1: Home Win, 2: Draw, 3: Away Win
        bool isResultDeclared;
        uint256 totalBetAmount;
        Bet[] bets;
        mapping(address => uint256) userBetIds;
    }

    mapping(address => bool) public isManager;
    mapping(uint256 => Match) public matches;
    mapping(uint16 => Category) public categories;
    mapping(uint16 => Bet) public bets;
    uint256 public matchCounter;
    uint256 public categoryCounter;
    uint256 public betCounter;

    constructor() {
        isManager[msg.sender] = true;
    }

    modifier onlyManager() {
        require(isManager[msg.sender], "Not manager");
        _;
    }

    function AddManager(address addrs) public onlyManager {
        require(!isManager[addrs], "Already a manager");
        isManager[addrs] = true;
    }


    function createCategory(string memory categoryName) public {
        require(bytes(categoryName).length > 0, "categoryName can not be empty");
        categoryCounter++;
        categories[categoryCounter] = Category({
            categoryId: categoryCounter,
            name: categoryName,
            matches: new Match[](0)
        });
    }

    function createMatch(uint16 memory categoryId, string memory _homeTeam, string memory _awayTeam) public {
        require(categoryId > 0 && categoryId <= categoryCounter, "category does not exist");
        matchCounter++;
        matches[matchCounter] = Match({
            matchId: matchCounter,
            homeTeam: _homeTeam,
            awayTeam: _awayTeam,
            result: 0, // 0 means result not declared
            isResultDeclared: false,
            bets: new Bet[](0)
        });
        categories[categoryId].matches.push(matches[matchCounter]);
    }

    function placeBet(uint256 _matchId, uint8 _prediction) public payable {
        require(_matchId > 0 && _matchId <= matchCounter, "Match does not exist");
        require(msg.value > 0, "Bet amount should be greater than zero");
        require(_prediction <= 3, "Invalid prediction");

        Match storage m = matches[_matchId];
        betCounter++;
        m.bets.push(Bet({
            betId: betCounter,
            matchId: _matchId,
            better: msg.sender,
            amount: msg.value,
            prediction: _prediction
        }));
        m.totalBetAmount += msg.value;
        m.userBetIds[msg.sender] = betCounter;
    }

    function declareResult(uint256 _matchId, uint8 _result) public onlyManager {
        require(_matchId <= matchCounter, "Match does not exist");
        require(_result <= 3, "Invalid result");

        Match storage m = matches[_matchId];
        require(!m.isResultDeclared, "Result already declared");

        m.result = _result;
        m.isResultDeclared = true;

        uint256 totalWinningAmount = 0;

        for (uint256 i = 0; i < m.bets.length; i++) {
            if (m.bets[i].prediction == _result) {
                totalWinningAmount += m.bets[i].amount;
            }
        }
        uint256 totalLosingAmount = m.totalBetAmount - totalWinningAmount;

        for (uint256 i = 0; i < m.bets.length; i++) {
            if (m.bets[i].prediction == _result) {
                //losing money for winner proportionately
                uint256 winAmount = totalLosingAmount * m.bets[i].amount / totalWinningAmount;
                // add with the bet amount
                payable(m.bets[i].better).transfer(m.bets[i].amount + winAmount);
            }
        }
    }
}
