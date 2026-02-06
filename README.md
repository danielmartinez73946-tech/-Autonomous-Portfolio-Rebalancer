# 📊 Autonomous Portfolio Rebalancer

A smart contract for automated portfolio management on the Stacks blockchain. Set your target allocation across STX, BTC, and stablecoins, and let the contract automatically rebalance your portfolio every quarter.

## 🎯 Features

- **Target Allocation Setting** - Define your ideal portfolio mix (e.g., 40% STX, 30% BTC, 30% stablecoins)
- **Automated Rebalancing** - Execute quarterly rebalances with a single transaction
- **Portfolio Tracking** - Monitor current balances and allocation percentages
- **Rebalance History** - View historical rebalancing events
- **Portfolio Analytics** - Calculate rebalance needs and current allocations

## 🚀 Quick Start

### Initialize Your Portfolio

```clarity
(contract-call? .portfolio-rebalancer initialize-portfolio u40 u30 u30)
```

This creates a portfolio with 40% STX, 30% BTC, and 30% stablecoin targets.

### Deposit Assets

```clarity
(contract-call? .portfolio-rebalancer deposit u1 u1000000)
(contract-call? .portfolio-rebalancer deposit u2 u500000)
(contract-call? .portfolio-rebalancer deposit u3 u500000)
```

Asset types: `u1` = STX, `u2` = BTC, `u3` = Stablecoin

### Execute Rebalancing

```clarity
(contract-call? .portfolio-rebalancer execute-rebalance)
```

Rebalances your portfolio to match target allocations (available quarterly).

## 📋 Core Functions

### Write Functions

| Function | Parameters | Description |
|----------|------------|-------------|
| `initialize-portfolio` | `stx-target`, `btc-target`, `stable-target` | Create new portfolio with target allocations (must sum to 100) |
| `update-targets` | `stx-target`, `btc-target`, `stable-target` | Update target allocation percentages |
| `deposit` | `asset-type`, `amount` | Deposit assets into portfolio |
| `withdraw` | `asset-type`, `amount` | Withdraw assets from portfolio |
| `execute-rebalance` | - | Rebalance portfolio to target allocations |

### Read Functions

| Function | Parameters | Description |
|----------|------------|-------------|
| `get-portfolio` | `user` | Get complete portfolio data for a user |
| `get-total-value` | `user` | Get total portfolio value across all assets |
| `get-current-allocation` | `user` | Get current allocation percentages |
| `can-rebalance` | `user` | Check if rebalancing is available |
| `calculate-rebalance-needs` | `user` | Calculate required swaps to reach target |
| `get-stats` | - | Get global statistics |
| `get-rebalance-history` | `user`, `timestamp` | Get historical rebalance data |

## 💡 Example Usage

### Complete Workflow

```clarity
;; 1. Initialize portfolio (40% STX, 35% BTC, 25% stablecoin)
(contract-call? .portfolio-rebalancer initialize-portfolio u40 u35 u25)

;; 2. Deposit initial assets
(contract-call? .portfolio-rebalancer deposit u1 u4000000)
(contract-call? .portfolio-rebalancer deposit u2 u3500000)
(contract-call? .portfolio-rebalancer deposit u3 u2500000)

;; 3. Check current allocation
(contract-call? .portfolio-rebalancer get-current-allocation tx-sender)

;; 4. After 4320 blocks (approx 1 quarter), rebalance
(contract-call? .portfolio-rebalancer execute-rebalance)

;; 5. View what needs rebalancing
(contract-call? .portfolio-rebalancer calculate-rebalance-needs tx-sender)
```

## 🔧 Technical Details

### Constants

- **Blocks per quarter**: 4320 blocks
- **Precision**: 10000 (for percentage calculations)
- **Max allocation**: 100 (sum of all targets must equal 100)
- **Asset types**: STX (1), BTC (2), Stablecoin (3)

### Rebalancing Logic

The contract calculates target balances based on total portfolio value and target percentages:

```
target_stx = (total_value * stx_target) / 100
target_btc = (total_value * btc_target) / 100
target_stable = (total_value * stable_target) / 100
```

### Time Constraints

Rebalancing can only occur once every 4320 blocks (approximately one quarter). This prevents excessive trading and maintains portfolio stability.

## ⚠️ Error Codes

| Code | Description |
|------|-------------|
| `u100` | Owner-only function |
| `u101` | Invalid allocation (must sum to 100, all > 0) |
| `u102` | Insufficient balance for withdrawal |
| `u103` | Not yet time for rebalancing |
| `u104` | Portfolio not initialized |
| `u105` | Portfolio already initialized |
| `u106` | Zero amount not allowed |
| `u107` | Invalid asset type |

## 🎓 Learning Concepts

This contract demonstrates:

- **Portfolio Mathematics** - Target allocation calculations and rebalancing logic
- **Automated Trading** - Time-based execution triggers
- **Asset Management** - Multi-asset portfolio tracking
- **Algorithmic Execution** - Systematic rebalancing strategies
- **Map Storage** - Efficient data structures for user portfolios
- **Read-Only Functions** - Gas-efficient portfolio queries

## 🛠️ Development

Built with [Clarinet](https://github.com/hirosystems/clarinet) for the Stacks blockchain.

### Testing

```bash
clarinet test
```

### Deployment

```bash
clarinet deploy
```

## 📝 Notes

This is an MVP implementation. In production, you would integrate with:
- Real DEX protocols for asset swaps
- Price oracles for accurate valuations
- More sophisticated rebalancing strategies
- Gas optimization techniques
- Security audits

## 📄 License

MIT

---

**⚡ Built for the Stacks Blockchain** | Made with 💜 by the Clarity community