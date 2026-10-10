> 🌐 **English** · [Español](./README-ES.md)

# 08 — Flash Loans & Atomic Arbitrage

**ERC-3156** flash loan provider and atomic arbitrage executor across two AMMs. Solidity `0.8.24` + Foundry.

**Status:** Phases **0–8** ✅ (module closed).

---

## Stack

| Layer | Technology |
|------|------------|
| Contracts | Solidity `0.8.24` |
| Tooling | Foundry (`forge` / `cast` / `anvil`) |
| Standard | ERC-3156 (`IERC3156FlashLender` / `IERC3156FlashBorrower`) |
| Libraries | OpenZeppelin Contracts v5.2, forge-std |
| Security | CEI, ReentrancyGuard, custom errors, SafeERC20 |

---

## Documentation

| Doc | Description |
|-----|-------------|
| [doc/README-EN.md](./doc/README-EN.md) | Documentation index |
| [doc/PLANIFICACION-EN.md](./doc/PLANIFICACION-EN.md) | Plan, TDD phases and acceptance criteria |
| [doc/SWC-AUDIT-EN.md](./doc/SWC-AUDIT-EN.md) | SWC-100–136 audit and mapping to tests |
| [doc/GAS-EN.md](./doc/GAS-EN.md) | Baseline gas report and optimizations |
| [doc/diagrama-clases-EN.md](./doc/diagrama-clases-EN.md) | Contract UML |
| [doc/diagrama-flujo-EN.md](./doc/diagrama-flujo-EN.md) | Flash loan / callback / repay flows |
| [doc/flujograma-EN.md](./doc/flujograma-EN.md) | Operational flowchart and TDD pipeline |

---

## Setup

```shell
export PATH="$HOME/.foundry/bin:$PATH"

forge install foundry-rs/forge-std@v1.16.2 --no-git
forge install OpenZeppelin/openzeppelin-contracts@v5.2.0 --no-git

forge build
forge test
forge snapshot --match-contract FlashLoanGasTest
```

Optional fork:

```shell
# In `.env` (copy from `.env.example`)
MAINNET_RPC_URL=https://...
forge test --match-path test/fork/
```

---

## Local deploy (Anvil)

```shell
anvil
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

---

## Structure

```
src/FlashLoanPool.sol
src/AtomicArbitrage.sol
src/libraries/ArbitrageMath.sol
src/mocks/MockERC20.sol
src/mocks/MockAMM.sol
test/FlashLoanPool.t.sol
test/AtomicArbitrage.t.sol
test/Unauthorized.t.sol
test/attack/ReentrancyAttack.t.sol
test/attack/CallbackSpoofAttack.t.sol
test/attack/LoanDefaultAttack.t.sol
test/fuzz/
test/invariant/
test/gas/FlashLoan.gas.t.sol
test/fork/Arbitrage.fork.t.sol
script/Deploy.s.sol
doc/
```

---

## Tests

`forge test` → **65 PASS** · **2 SKIP** (fork without `MAINNET_RPC_URL`)
