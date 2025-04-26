<div align="center">
  <img src="https://github.com/user-attachments/assets/f2d35488-b990-4b36-8b8b-6ce23deb652e" alt="text" width="500"/>
</div>

## Contracts

- **Competition.sol**: Main contract that handles the competition logic
  - `startRound` is the key function: it deploys a new token, distributes USDM to participants, and seeds initial liquidity on Uniswap v2.
  - After starting a round, there is a 1-minute grace period where only the AI market maker can trade.
  - Once trading opens, players can buy and sell the token on Uniswap.
  - At the end of each round, all unsold participant tokens are automatically sold for USDM, and trading is paused.

- **Periphery.sol**: Helper functions for the UI

- **MockToken.sol** & **MockUSD.sol**: Mock tokens with special properties for the competition

## Related Repositories

- **Frontend UI:** [crypto-trading-competition-ui](https://github.com/Jun1on/crypto-trading-competition-ui/)
- **Backend Server:** [crypto-trading-competition-backend](https://github.com/Jun1on/crypto-trading-competition-backend)
