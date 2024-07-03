// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract EuroCupBetting {

    event CategoryCreated(uint16 indexed categoryId, string name);
    event MatchCreated(uint256 indexed matchId, uint16 indexed categoryId, string homeTeam, string awayTeam);
    event BetPlaced(address indexed better, uint256 indexed matchId, uint8 prediction, uint256 amount);
    event GameResultSet(uint256 indexed matchId, uint8 result);
    event PrizeDistributed(address indexed winner, uint256 indexed matchId, uint256 amount);

    struct Category {
        uint16 categoryId;
        string name;
        uint256[] matchIds;
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
    uint16 public categoryCounter;
    uint256 public betCounter;

    constructor() {
        isManager[msg.sender] = true;
    }

    modifier onlyManager() {
        require(isManager[msg.sender], "Not manager");
        _;
    }

    function addManager(address addrs) public onlyManager {
        require(!isManager[addrs], "Already a manager");
        isManager[addrs] = true;
    }

    function createCategory(string memory categoryName) public onlyManager {
        require(bytes(categoryName).length > 0, "Category name cannot be empty");
        categoryCounter++;
        Category storage category = categories[categoryCounter];
        category.categoryId = categoryCounter;
        category.name = categoryName;
        emit CategoryCreated(categoryCounter, categoryName);
    }

    function createMatch(uint16 categoryId, string memory homeTeam, string memory awayTeam) public onlyManager {
        require(categoryId > 0 && categoryId <= categoryCounter, "Category does not exist");
        matchCounter++;
        Match storage newMatch = matches[matchCounter];
        newMatch.matchId = matchCounter;
        newMatch.homeTeam = homeTeam;
        newMatch.awayTeam = awayTeam;
        newMatch.result = 0; // 0 means result not declared
        newMatch.isResultDeclared = false;
        newMatch.totalBetAmount = 0;
        categories[categoryId].matchIds.push(matchCounter);
        emit MatchCreated(matchCounter, categoryId, homeTeam, awayTeam);
    }

    function placeBet(uint256 matchId, uint8 prediction) public payable {
        require(matchId > 0 && matchId <= matchCounter, "Match does not exist");
        require(msg.value > 0, "Bet amount should be greater than zero");
        require(prediction <= 3, "Invalid prediction");

        Match storage m = matches[matchId];
        betCounter++;
        m.bets.push(Bet({
            betId: betCounter,
            matchId: matchId,
            better: msg.sender,
            amount: msg.value,
            prediction: prediction
        }));
        m.totalBetAmount += msg.value;
        m.userBetIds[msg.sender] = betCounter;

        emit BetPlaced(msg.sender, matchId, prediction, msg.value);
    }

    function declareResult(uint256 matchId, uint8 result) public onlyManager {
        require(matchId <= matchCounter, "Match does not exist");
        require(result <= 3, "Invalid result");

        Match storage m = matches[matchId];
        require(!m.isResultDeclared, "Result already declared");

        m.result = result;
        m.isResultDeclared = true;

        emit GameResultSet(matchId, result);

        uint256 totalWinningAmount = 0;

        for (uint256 i = 0; i < m.bets.length; i++) {
            if (m.bets[i].prediction == result) {
                totalWinningAmount += m.bets[i].amount;
            }
        }
        uint256 totalLosingAmount = m.totalBetAmount - totalWinningAmount;

        for (uint256 i = 0; i < m.bets.length; i++) {
            if (m.bets[i].prediction == result) {
                // Losing money for winner proportionately
                uint256 winAmount = totalLosingAmount * m.bets[i].amount / totalWinningAmount;
                // Add with the bet amount
                uint256 prizeAmount = m.bets[i].amount + winAmount;
                payable(m.bets[i].better).transfer(prizeAmount);
                emit PrizeDistributed(m.bets[i].better, matchId, prizeAmount);
            }
        }
    }
}
