// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SportsBetting {

    event CategoryCreated(uint16 indexed categoryId, string name);
    event MatchCreated(uint256 indexed matchId, uint16 indexed categoryId, string homeTeam, string awayTeam);
    event BetPlaced(address indexed better, uint256 indexed matchId, MatchResult prediction, uint256 amount);
    event GameResultSet(uint256 indexed matchId, MatchResult result);
    event PrizeDistributed(address indexed winner, uint256 indexed matchId, uint256 amount);

    struct Category {
        uint16 categoryId;
        string name;
        uint256[] matchIds;
    }

    enum MatchResult {
        Not_DECLARED, HOME_WIN, DRAW, AWAY_WIN
    }

    struct Bet {
        uint256 betId;
        uint256 matchId;
        address better;
        uint256 amount;
        MatchResult prediction;
    }

    struct Match {
        uint256 matchId;
        string homeTeam;
        string awayTeam;
        MatchResult result;
        bool isResultDeclared;
        uint256 totalBetAmount;
        Bet[] bets;
        mapping(address => uint256) userBetIds;
    }

    //use MatchData for frontend
    struct MatchData {
        uint256 matchId;
        string homeTeam;
        string awayTeam;
        MatchResult result;
        MatchResult userBet;
        bool isResultDeclared;
        uint256 totalBetAmount;
    }

    mapping(address => bool) public isManager;
    mapping(uint256 => Match) public matches;
    mapping(uint16 => Category) public categories;
    mapping(uint256 => Bet) public bets;
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
        newMatch.result = MatchResult.Not_DECLARED;
        newMatch.isResultDeclared = false;
        newMatch.totalBetAmount = 0;
        categories[categoryId].matchIds.push(matchCounter);
        emit MatchCreated(matchCounter, categoryId, homeTeam, awayTeam);
    }

    function placeBet(uint256 matchId, MatchResult prediction) public payable {
        require(matchId > 0 && matchId <= matchCounter, "Match does not exist");
        require(msg.value > 0, "Bet amount should be greater than zero");

        //create user bet
        betCounter++;
        Bet memory bet = Bet({
            betId: betCounter,
            matchId: matchId,
            better: msg.sender,
            amount: msg.value,
            prediction: prediction
        });
        // add user bet in match
        Match storage m = matches[matchId];
        m.bets.push(bet);
        bets[betCounter] = bet;
        m.userBetIds[msg.sender] = betCounter;
        m.totalBetAmount += msg.value;

        emit BetPlaced(msg.sender, matchId, prediction, msg.value);
    }

    //for frontend,show all data in match bet page
    function matchesInCategory(uint16 categoryId) public view returns (MatchData[] memory) {
        uint256[] memory matchIds = categories[categoryId].matchIds;
        MatchData[] memory res = new MatchData[](matchIds.length);
        for (uint i = 0; i < matchIds.length; i++) {
            //find match
            Match storage m = matches[matchIds[i]];
            //find userBet in match
            Bet memory userBet = bets[m.userBetIds[msg.sender]];
            //to data for frontend
            res[i] = toMatchData(matchIds[i], userBet.prediction);
        }
        return res;
    }

    //show user bet in specific match
    function userBetInMatch(uint256 matchId) public view returns (Bet memory) {
        Match storage m = matches[matchId];
        require(m.matchId > 0, "match not exist");
        // test it, what will return if user have not bet
        return bets[m.userBetIds[msg.sender]];
    }

    //use Chainlink Keepers to invoke this function when match result is declared
    function declareResult(uint256 matchId, MatchResult result) public onlyManager {
        require(matchId <= matchCounter, "Match does not exist");

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

    //transfer match to frontend data
    function toMatchData(uint256 matchId, MatchResult userBet) private view returns (MatchData memory) {
        Match storage m = matches[matchId];
        return MatchData({
            matchId: m.matchId,
            homeTeam: m.homeTeam,
            awayTeam: m.awayTeam,
            userBet: userBet,
            result: m.result,
            isResultDeclared: m.isResultDeclared,
            totalBetAmount: m.totalBetAmount
        });
    }
}
