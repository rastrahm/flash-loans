> 🌐 **English** · [Español](./PLANIFICACION-ES.md)

# Planning — Module 08: Flash Loans & Atomic Arbitrage Execution

**Status:** Phases **0–8** ✅ — module closed (NatSpec + gas + Deploy + optional fork + `FeeBpsTooHigh`).

## 1. Project goal

An **ERC-3156 flash loan** provider and an **atomic arbitrage** executor across two AMMs: detect a price imbalance, borrow with no capital of your own, execute swaps, repay principal + premium and keep the net profit **within the same transaction**. Stack: Foundry and Solidity `0.8.24`.

### Core capabilities

- `FlashLoanPool` pool implementing `IERC3156FlashLender` (ERC-20 liquidity, fixed fee, anti-reentrancy lock).
- `AtomicArbitrage` receiver implementing `IERC3156FlashBorrower` and orchestrating two AMM swaps.
- **Atomic guarantee:** if the trade does not cover `principal + fee`, the transaction **reverts entirely**.
- Strict authentication in `onFlashLoan()`: `msg.sender == flashLender` and `initiator == address(this)`.
- Profit **without intermediate storage**: direct transfer to `owner` / treasury.
- Foundry tests: unit, mocks of two imbalanced AMMs, optional fork, unauthorized callers.

---

## 2. Scope

### Included

| Area | Description |
|------|-------------|
| FlashLoanPool | ERC-3156: `maxFlashLoan`, `flashFee`, `flashLoan`; depositable liquidity |
| AtomicArbitrage | Callback + swaps A→B / B→A; repay + profit to owner |
| Callback auth | `UntrustedLender` / `InvalidInitiator` |
| Atomicity | `UnprofitableArbitrage` if final balance < amount + fee |
| Repay | Approve/transfer to the lender; `LoanRepaymentFailed` if the pull fails |
| Security | `ReentrancyGuard` on `flashLoan`; CEI; custom errors |
| AMM mocks | Two pools with artificially imbalanced reserves |
| Tests | Unit, unprofitable revert, unauthorized callback, amount fuzzing |

### Not included (v1)

- Multi-hop routing (>2 AMMs) or an off-chain path finder in the contract.
- Native ETH flash loans (ERC-20 only; WETH as a token if needed).
- Production Uniswap V3 / concentrated liquidity integration (mocks + minimal interface).
- Chainlink oracles for a “fair price” (the imbalance is simulated in tests).
- Next.js frontend (optional later phase).
- On-chain governance of the lender fee.

---

## 3. Tech stack

| Component | Choice |
|------------|----------|
| Compiler | `pragma solidity 0.8.24;` (exact, no floating pragma) |
| Framework | Foundry (`forge test`, fuzz ≥ 1000, traces, optional fork) |
| Standard | ERC-3156 (`IERC3156FlashLender`, `IERC3156FlashBorrower`) |
| Libraries | OpenZeppelin Contracts v5.x (`ReentrancyGuard`, `Ownable2Step`, `SafeERC20`, IERC3156 where applicable) |
| ETH | If any mock uses ETH: `.call{value: ...}("")` — never `transfer`/`send` |
| Documentation | NatSpec on every public/external API |

---

## 4. Architecture

```
08-flash-loans/
├── doc/
│   ├── README-EN.md
│   ├── PLANIFICACION-EN.md
│   ├── diagrama-clases-EN.md
│   ├── diagrama-flujo-EN.md
│   └── flujograma-EN.md
├── src/
│   ├── FlashLoanPool.sol                 # IERC3156FlashLender + liquidity
│   ├── AtomicArbitrage.sol               # IERC3156FlashBorrower + executor
│   ├── interfaces/
│   │   ├── IERC3156FlashLender.sol
│   │   ├── IERC3156FlashBorrower.sol
│   │   ├── IFlashLoanPool.sol
│   │   ├── IAtomicArbitrage.sol
│   │   └── ISimpleAMM.sol                # minimal swapExactIn for mocks
│   ├── libraries/
│   │   └── ArbitrageMath.sol             # amountOut / profit check (view)
│   └── mocks/
│       ├── MockERC20.sol
│       └── MockAMM.sol                   # simplified x*y=k, settable reserves
├── test/
│   ├── FlashLoanPool.t.sol
│   ├── AtomicArbitrage.t.sol
│   ├── Unauthorized.t.sol
│   ├── fuzz/FlashLoan.fuzz.t.sol
│   └── fork/Arbitrage.fork.t.sol         # optional, skipped if no RPC
├── script/
│   └── Deploy.s.sol
├── foundry.toml
└── remappings.txt
```

### Roles

| Actor | Responsibility |
|-------|-----------------|
| **Liquidity provider** | Deposits ERC-20 into `FlashLoanPool` to enable loans |
| **Operator / owner** | Calls `AtomicArbitrage.execute(...)` when there is a spread |
| **FlashLoanPool** | Transfers principal, invokes callback, collects amount+fee |
| **AtomicArbitrage** | Authenticates callback, swaps on cheap AMM → expensive AMM, repays, sends profit |
| **AMM A / AMM B** | Mock (or fork) pools with different prices for the same pair |
| **Attacker (test)** | Calls `onFlashLoan` directly or reenters the lender → must revert |

---

## 5. Data model

```solidity
// FlashLoanPool (summary)
address public immutable token;          // lendable ERC-20 (v1: a single token)
uint256 public feeBps;                   // e.g. 5 = 0.05% (or fixed fee in wei)
uint256 public constant CALLBACK_SUCCESS =
    keccak256("ERC3156FlashBorrower.onFlashLoan");

// AtomicArbitrage (summary)
address public immutable flashLender;
address public immutable owner;          // profit destination (immutable = 0 storage writes during execution)
// no profits mapping — direct transfer inside the callback
```

### Key formulas

| Operation | Formula |
|-----------|---------|
| ERC-3156 fee | `flashFee = amount * feeBps / 10_000` (or minimum fee; amount=0 does not apply) |
| Debt | `repayAmount = amount + flashFee` |
| Swap (mock AMM) | `amountOut = (amountIn * 997 * reserveOut) / (reserveIn * 1000 + amountIn * 997)` |
| Profit | `balance(token) - repayAmount` after both swaps |
| Atomicity | `profit >= 0` (balance ≥ repayAmount) or `UnprofitableArbitrage` |

Flash loan `data` (ABI-encoded):

| Field | Use |
|-------|-----|
| `ammBuy` | AMM where the borrowed token buys the cheaper intermediate token |
| `ammSell` | AMM where the more expensive intermediate token is sold |
| `tokenB` | Intermediate token of the pair |
| `minProfit` | Minimum-profit slippage guard (optional, wei) |

---

## 6. On-chain API

### FlashLoanPool (`IERC3156FlashLender`)

| Function | Visibility | Description |
|---------|-------------|-------------|
| `maxFlashLoan(address token)` | view | Available liquidity; 0 if token is not supported |
| `flashFee(address token, uint256 amount)` | view | Premium; reverts if token is not supported |
| `flashLoan(receiver, token, amount, data)` | external nonReentrant | Transfers, callback, pulls amount+fee |
| `deposit(uint256 amount)` | external | Adds liquidity to the pool |
| `withdraw(uint256 amount)` | external | Withdraws liquidity (owner only / LPs depending on design; v1: owner) |

### AtomicArbitrage (`IERC3156FlashBorrower`)

| Function | Visibility | Description |
|---------|-------------|-------------|
| `execute(uint256 amount, bytes params)` | external | Starts `flashLoan` towards `address(this)` |
| `onFlashLoan(initiator, token, amount, fee, data)` | external | Auth → swaps → approve repay → CALLBACK_SUCCESS |
| `owner()` | view | Profit recipient |

### Custom errors (mandatory)

| Error | Condition |
|-------|-----------|
| `InvalidInitiator()` | `initiator != address(this)` in the callback |
| `UntrustedLender()` | `msg.sender != flashLender` in the callback |
| `UnprofitableArbitrage()` | `balance < amount + fee` (or profit < minProfit) |
| `LoanRepaymentFailed()` | The lender cannot collect amount+fee |

Additional pool errors (recommended, consistent with the suite):

| Error | Condition |
|-------|-----------|
| `UnsupportedToken()` | Token different from the `immutable token` |
| `AmountExceedsMaxLoan()` | `amount > maxFlashLoan` |
| `CallbackFailed()` | Return value different from `CALLBACK_SUCCESS` |
| `ZeroAmount()` | amount 0 |

### Events

`FlashLoan` (borrower, token, amount, fee) · `ArbitrageExecuted` (token, amount, profit) · `LiquidityDeposited` · `LiquidityWithdrawn`

ERC-3156 magic value:

```solidity
bytes32 constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");
```

---

## 7. flashLoan + callback logic (CEI)

### Lender `flashLoan`

1. **Checks:** supported token, `amount > 0`, `amount <= maxFlashLoan`, receiver ≠ 0.
2. Compute `fee = flashFee(token, amount)`.
3. **Effects:** `nonReentrant` lock (status ENTERED).
4. **Interactions:** `SafeERC20.safeTransfer(receiver, amount)`.
5. `bytes32 rc = IERC3156FlashBorrower(receiver).onFlashLoan(msg.sender, token, amount, fee, data)`.
6. **Checks:** `rc == CALLBACK_SUCCESS`.
7. **Interactions:** `safeTransferFrom(receiver, address(this), amount + fee)` → otherwise `LoanRepaymentFailed`.
8. Emit `FlashLoan`. Unlock.

The pool balance at the end must be ≥ initial balance + fee (liquidity not drained).

### Borrower `onFlashLoan`

1. **Checks:** `msg.sender == flashLender` → otherwise `UntrustedLender`.
2. **Checks:** `initiator == address(this)` → otherwise `InvalidInitiator`.
3. Decode `data` (ammBuy, ammSell, tokenB, minProfit).
4. Approve/swap on the buy AMM; swap on the sell AMM (the borrowed token comes back).
5. `required = amount + fee`; `bal = IERC20(token).balanceOf(address(this))`.
6. If `bal < required` or `bal - required < minProfit` → `UnprofitableArbitrage`.
7. `profit = bal - required`; `safeTransfer(token, owner, profit)` (zero profit writes).
8. `safeIncreaseAllowance(flashLender, required)` (or exact approve).
9. Return `CALLBACK_SUCCESS`.

---

## 8. Implementation phases (TDD)

| Phase | Deliverable | Status |
|------|------------|--------|
| **0** | Docs (`doc/`) + Foundry scaffold + ERC-3156 interfaces | ✅ |
| **1** | Failing tests: `flashLoan`, fee, maxLoan, reverts | ✅ |
| **2** | Minimal `FlashLoanPool` (deposit + flashLoan without arbitrage) | ✅ |
| **3** | Failing `AtomicArbitrage` tests + imbalanced AMM mocks | ✅ |
| **4** | `onFlashLoan` auth + swaps + repay + profit to owner | ✅ |
| **5** | Unprofitable revert (balanced AMMs / fee > spread) | ✅ |
| **6** | Unauthorized: direct callback, fake initiator, reentrancy | ✅ |
| **7** | Amount fuzzing + pool liquidity invariant ≥ pre + net fees | ✅ |
| **8** | Optional fork + gas snapshot + NatSpec (+ Deploy + `FeeBpsTooHigh`) | ✅ |

---

## 9. Test plan

| Suite | Location | Coverage |
|-------|-----------|-----------|
| Lender unit | `test/FlashLoanPool.t.sol` | maxLoan, fee, repay, unsupported token |
| Arb unit | `test/AtomicArbitrage.t.sol` | Artificial spread → profit to owner |
| Unprofitable | same | AMMs without spread / excessive fee → revert, pool intact |
| Unauthorized | `test/Unauthorized.t.sol` | Auth unit (`UntrustedLender` / `InvalidInitiator`) |
| Attack | `test/attack/` | Reentrancy, callback spoof, loan default |
| Reentrancy (unit) | `test/FlashLoanPool.t.sol` | Malicious receiver reenters `flashLoan` |
| Fuzz | `test/fuzz/FlashLoan.fuzz.t.sol` | `bound(amount)` vs liquidity and fee |
| Fork | `test/fork/Arbitrage.fork.t.sol` | Skipped without `MAINNET_RPC_URL` |
| Invariant | `test/invariant/` | `balance(pool) >= deposits + feesAcumulados - withdraws` |

Capital invariant: a flash loan that reverts does **not** change pool or attacker balances (except gas).

---

## 10. Acceptance criteria

- [x] Foundry scaffold (`0.8.24`, fuzz ≥ 1000)
- [x] `FlashLoanPool` implements `IERC3156FlashLender`
- [x] `AtomicArbitrage` implements `IERC3156FlashBorrower`
- [x] Callback: `msg.sender == flashLender` and `initiator == address(this)`
- [x] Mandatory custom errors (the module's four)
- [x] Unprofitable trade → atomic revert; pool liquidity intact
- [x] Profit transferred to `owner` with no accumulator state variables
- [x] `ReentrancyGuard` on `flashLoan`
- [x] Third parties cannot successfully invoke the callback
- [x] Mocks of two imbalanced AMMs verify atomic execution
- [x] `vm.expectRevert` on every failure path
- [x] NatSpec on public/external functions
- [x] CEI + SafeERC20; no ETH `transfer`/`send`
- [x] Gas baseline (`doc/GAS-EN.md` + `.gas-snapshot`)
- [x] `FeeBpsTooHigh` if `feeBps > 10_000`
- [x] Fork suite skipped without `MAINNET_RPC_URL`
- [x] `script/Deploy.s.sol` for Anvil

---

## 11. Related documents

| Document | Contents |
|-----------|-----------|
| [diagrama-clases-EN.md](./diagrama-clases-EN.md) | Contract UML, ERC-3156 interfaces, tests |
| [diagrama-flujo-EN.md](./diagrama-flujo-EN.md) | Flash loan → swaps → repay sequence |
| [flujograma-EN.md](./flujograma-EN.md) | Operational, security, TDD |
| [SWC-AUDIT-EN.md](./SWC-AUDIT-EN.md) | SWC-100–136 matrix + mapping to tests |
| [GAS-EN.md](./GAS-EN.md) | Gas baseline, optimizations, snapshot |
| [DECISIONES-Y-LOGICA-EN.md](./DECISIONES-Y-LOGICA-EN.md) | Technical decisions, flow, gas improvements |

---

## 12. Risks and mitigations

| Risk | Mitigation |
|--------|------------|
| Callback spoofing | `UntrustedLender` + `InvalidInitiator` |
| Reentrancy into the lender during callback | `nonReentrant` on `flashLoan` |
| Trade that does not cover the fee | `UnprofitableArbitrage` before the approve |
| Residual infinite approve | Exact approve of `required` (or 0 after the pull) |
| Fee-on-transfer token | v1: standard tokens only; tests with a simple mock |
| Read-only reentrancy / stale price | Controlled mocks; on fork, execute within a single block |
| Front-running of execute | Out of on-chain scope; private relay in prod |
| Pool liquidity drain | Pull amount+fee post-callback; balance check |

---

## 13. Conventions (suite + Solidity rules)

- Fixed pragma `0.8.24`; layout: Interfaces → Libraries → Contracts → State → Events → Errors → Modifiers → Functions (External → Public → Internal → Private).
- NatSpec `@notice` / `@dev` / `@param` / `@return` on the public API.
- Tests first (TDD); `vm.expectRevert` on failure paths.
- Gas: `immutable`/`constant`, custom errors, profit without SSTORE.
- Relationship with modules 06/07: the real AMMs live there; this module **lends and arbitrages** against an `ISimpleAMM` interface (mocks in tests, module 06 pairs in a future integration).
