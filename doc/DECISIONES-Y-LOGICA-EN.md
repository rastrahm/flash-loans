> 🌐 **English** · [Español](./DECISIONES-Y-LOGICA-ES.md)

# Technical decisions, logic and gas — Module 08

A document for studying the design of **Flash Loans & Atomic Arbitrage**: what was decided and why, how the logic flows, and what could be improved in gas without breaking security.

**Contracts:** `FlashLoanPool` · `AtomicArbitrage` · `ArbitrageMath`  
**References:** [PLANIFICACION-EN.md](./PLANIFICACION-EN.md) · [GAS-EN.md](./GAS-EN.md) · [SWC-AUDIT-EN.md](./SWC-AUDIT-EN.md) · [diagrama-flujo-EN.md](./diagrama-flujo-EN.md)

---

## 1. What problem it solves

There are two pieces that work together:

| Contract | Role |
|----------|-----|
| **FlashLoanPool** | Lends an ERC-20 **without collateral** within **a single transaction** (ERC-3156). Charges `amount + fee`. |
| **AtomicArbitrage** | Requests the loan, performs two swaps between AMMs with different prices, repays the debt and keeps the profit. |

Golden rule: if at the end there aren't enough tokens for `principal + fee`, **the whole transaction reverts**. The pool never “half-loses”.

---

## 2. Technical decisions (and why)

### 2.1 ERC-3156 standard (not a made-up callback)

**Decision:** implement `IERC3156FlashLender` / `IERC3156FlashBorrower`.

**Why:**

- Well-known interface (Aave-style / EIP-3156): `maxFlashLoan`, `flashFee`, `flashLoan`, `onFlashLoan`.
- Magic value `keccak256("ERC3156FlashBorrower.onFlashLoan")` → the lender knows the callback “accepted” the protocol.
- Makes testing and comparison with other lenders easier.

**Tradeoff:** the lender calls an external contract (the borrower). That forces `nonReentrant` and repay validation.

---

### 2.2 A single token per pool (`immutable token`)

**Decision:** v1 = one ERC-20 fixed in the constructor.

**Why:**

- Less storage and fewer branches (`UnsupportedToken` is trivial).
- `maxFlashLoan` = `balanceOf(pool)` of the single token.
- Aligned with the suite's “teaching module” approach.

**Tradeoff:** no multi-asset or native WETH in the same contract.

---

### 2.3 Fee in basis points (`feeBps` immutable)

**Decision:** `fee = amount * feeBps / 10_000`, capped at `feeBps <= 10_000` (`FeeBpsTooHigh`).

**Why:**

- Predictable fee, cheap to compute (no oracles).
- Immutable → no on-chain fee governance in v1 (smaller attack surface).
- The cap prevents absurd fees (>100%).

**Tradeoff:** the fee cannot be changed without redeploying.

---

### 2.4 Custodial pool (`withdraw` `owner`-only)

**Decision:** anyone can `deposit`; only the owner (`Ownable2Step`) can `withdraw`.

**Why:**

- Simple model: no LP shares, dilution or the anti-inflation logic from module 07.
- O(1) gas; the module's focus = flash loan + arbitrage, not a vault.

**Tradeoff / risk:** the owner can drain liquidity. This is an explicit **trust model** (documented in the SWC audit as informational), not a hidden bug.

---

### 2.5 Strict auth in `onFlashLoan`

**Decision:**

1. `msg.sender == flashLender` → otherwise `UntrustedLender`
2. `initiator == address(this)` → otherwise `InvalidInitiator`

**Why:**

- Prevents an EOA or a “fake lender” from triggering swaps / token approvals from the arb.
- Prevents a third party from calling `pool.flashLoan(arb, …)` and using the arb as the receiver: the `initiator` would be the third party, not the contract itself.
- Only `execute()` (called so that the initiator is the arb) is a valid path.

**Tradeoff:** `execute` is public (anyone can trigger the arb); the profit always goes to the immutable `owner`. This is intentional (bot / operator).

---

### 2.6 Profit without state variables (zero accumulator SSTOREs)

**Decision:** after the swaps, `profit = balance - (amount + fee)` and `safeTransfer(owner, profit)`.

**Why:**

- Module rule (`.cursorrules`): do not write intermediate profits to storage.
- Less gas in the callback's hot path.
- Less state to audit.

**Tradeoff:** there is no “on-chain treasury” or profit history in the contract (only events).

---

### 2.7 Atomicity of the unprofitable case

**Decision:** if `balance < amount + fee` (or profit `< minProfit`) → `UnprofitableArbitrage` **before** approving the lender.

**Why:**

- If it reverts there, the EVM undoes the callback's transfers → the pool never completes the pull → **liquidity intact**.
- `minProfit` in `params` acts as profit slippage protection.

**Tradeoff:** the swaps use `minOut = 0` → MEV/sandwich risk (partially mitigated by `minProfit`, not by a per-hop minOut).

---

### 2.8 Reentrancy guard only on `flashLoan` (not on deposit/withdraw)

**Decision:** `nonReentrant` on `flashLoan`; deposit/withdraw without a guard.

**Why:**

- The real danger is reentering the loan during the callback (transfer + external call).
- deposit/withdraw have no complex state machine (they only move tokens).

**Tradeoff:** `nonReentrant` could also be added there for symmetry (minor security improvement, gas cost on cold paths).

---

### 2.9 Repay with try/catch → `LoanRepaymentFailed`

**Decision:** do not assume `transferFrom` “always works”; catch the failure and map it to a custom error.

**Why:**

- Bad ERC-20s / missing allowance / `false` return value.
- `NonRepayingBorrower` tests and the `LoanDefaultAttack` suite.

**Tradeoff:** slightly more bytecode vs a `safeTransferFrom` that reverts with the OZ error (less tailored to the business case).

---

### 2.10 AMMs via `ISimpleAMM` + mocks

**Decision:** minimal `getAmountOut` / `swap` interface; tests with `MockAMM` (`x*y=k`, 0.3% fee).

**Why:**

- The module doesn't depend on module 06's code to complete TDD.
- `ISimpleAMM` can later be adapted to a real pair.

**Tradeoff:** the current fork test deploys mocks on the fork; it doesn't arbitrage mainnet Uniswap “for real” (that would be a v2 integration).

---

### 2.11 Suite stack and style

| Decision | Reason |
|----------|--------|
| Fixed `pragma solidity 0.8.24` | Suite + native overflow checks |
| Custom errors | Gas + clarity vs `require("…")` |
| Foundry TDD (phases 0–8) | Tests first, fuzz ≥ 1000, invariants |
| OpenZeppelin v5 | Audited `ReentrancyGuard`, `Ownable2Step`, `SafeERC20` |
| SafeERC20 (OZ) vs module 07's custom SafeTransfer | OZ consistency here; typed repay with try/catch |

---

## 3. Logic the system follows

### 3.1 Mental model (one sentence)

> The operator calls `execute` → the pool lends tokens to the arb → the arb buys low / sells high → if there's a surplus, it sends the profit to the owner and approves the repay → the pool collects `amount + fee` → done. If at any point funds are short or auth fails, **everything is undone**.

### 3.2 Happy path (step by step)

```
1) Someone calls AtomicArbitrage.execute(amount, params)
      params = abi.encode(ammBuy, ammSell, tokenB, minProfit)

2) Arb reads pool.token() and calls:
      flashLender.flashLoan(address(this), token, amount, params)
      → initiator = address(arb)

3) FlashLoanPool.flashLoan (nonReentrant):
      a. Checks: receiver ≠ 0, token ok, amount > 0, amount ≤ balance
      b. fee = amount * feeBps / 10_000
      c. Transfer amount → receiver (arb)
      d. Calls arb.onFlashLoan(initiator, token, amount, fee, data)
      e. Requires return == CALLBACK_SUCCESS
      f. transferFrom(arb, pool, amount + fee)  // repay
      g. Emit FlashLoan

4) Inside onFlashLoan (arb):
      a. Auth: msg.sender == flashLender
      b. Auth: initiator == address(this)
      c. Decode params
      d. Swap 1: token → tokenB on ammBuy
      e. Swap 2: tokenB → token on ammSell
      f. required = amount + fee
      g. If balance < required or profit < minProfit → UnprofitableArbitrage
      h. Transfer profit → owner
      i. forceApprove(flashLender, required)
      j. return CALLBACK_SUCCESS
```

### 3.3 Failure paths (what each one protects)

| Situation | Error / effect |
|-----------|----------------|
| Fake lender / EOA calls the callback | `UntrustedLender` |
| Third party initiates `flashLoan(arb, …)` | `InvalidInitiator` |
| Trade doesn't cover the debt / minProfit | `UnprofitableArbitrage` (the whole tx reverts) |
| Borrower doesn't approve the repay | `LoanRepaymentFailed` |
| Wrong magic value | `CallbackFailed` |
| Reentering `flashLoan` in the callback | `ReentrancyGuardReentrantCall` |
| Amount > liquidity | `AmountExceedsMaxLoan` |

### 3.4 Pool accounting (invariant)

The invariant tests track:

```
balance(pool) == ghostDeposited + ghostFeesEarned - ghostWithdrawn
```

- A **successful** flash loan increases the balance by exactly the **fee**.
- A flash loan that **reverts** doesn't change the balance (atomicity).

### 3.5 Where each piece of logic lives

| Piece | File |
|-------|---------|
| Lending / collecting / liquidity | `src/FlashLoanPool.sol` |
| Auth + swaps + profit | `src/AtomicArbitrage.sol` |
| `repayAmount` / `isProfitable` | `src/libraries/ArbitrageMath.sol` |
| Test AMM | `src/mocks/MockAMM.sol` |
| Flow diagrams | `doc/diagrama-flujo-EN.md`, `doc/flujograma-EN.md` |

---

## 4. Can the gas of what exists be improved?

**Yes**, but we need to separate: (A) real improvements in **our** contracts, (B) cost coming from **external AMMs** (almost all of `execute`'s ~235k).

Current baseline (gas-report medians): `flashLoan` ~67k · `execute` ~235k · `deposit` ~57k. Details in [GAS-EN.md](./GAS-EN.md).

### 4.1 Already applied (not “missing”; this is the current floor)

- `immutable` in pool and arb  
- Profit without SSTORE  
- Custom errors  
- `BPS_DENOMINATOR` constant  
- Exact `forceApprove`  
- `optimizer_runs = 200`

### 4.2 Possible improvements (impact vs risk)

| Idea | Expected savings | Risk / tradeoff | Worth it in v1? |
|------|-----------------|-------------------|----------------------|
| Cache `token` locally in `flashLoan` (already partly done) | Low | None | Already reasonable |
| `unchecked` on `amount + fee` after checks | Very low | Must prove overflow is impossible | Optional |
| Custom SafeTransfer (module 07 style) instead of OZ SafeERC20 | Low–medium on paths | Changes revert semantics; tests must be rewritten | Only if you unify the suite |
| Pack `feeBps` into a slot with other data | Low on deploy | Almost everything is already immutable | Low interest |
| Drop `Ownable2Step` → plain `Ownable` | Cheaper deploy | Less safety on ownership transfer | Not recommended |
| Per-hop `minOut` in `params` | **More** gas (checks + calldata) | Better MEV protection, worse gas | Security > gas |
| `nonReentrant` on deposit/withdraw | **More** gas on those paths | Extra defense | Optional |
| Assembly in auth / decode | Low–medium | Readability and auditability | Not a priority in a teaching module |
| Allow a direct repay `transfer` (pull pattern is already standard) | — | ERC-3156 expects a pull by the lender | Keep pull |
| Integrate a real router (Uniswap) | Gas is dominated by the AMM | Not a “pool optimization” | Out of scope for v1 |

### 4.3 Where the “bulk” of the gas is

In `execute`, most of it is **not** the pool: it's the **2 swaps + approves + ERC-20 transfers**. Optimizing the pool saves kilogas; optimizing the arbitrage path in production means:

- fewer hops,
- efficient routers,
- short calldata,
- and sometimes a private mempool (MEV), not Solidity micro-optimizations.

### 4.4 Practical recommendation

For this module, gas is already at a good **teaching + secure** point.

If you want a concrete, measurable improvement tomorrow:

1. Current snapshot (`forge snapshot --match-contract FlashLoanGasTest`).  
2. Apply **one** optimization (e.g. `unchecked` on `amount + fee` or extra caching).  
3. Snapshot again and record the delta in `GAS-EN.md`.  
4. Don't touch auth or the “profit check → approve → pull” order.

---

## 5. Quick map “decision → file → test”

| Decision | Where to see it | How it's tested |
|----------|-------------|----------------|
| ERC-3156 | `FlashLoanPool` / interfaces | `FlashLoanPool.t.sol` |
| Callback auth | `AtomicArbitrage.onFlashLoan` | `Unauthorized` + `CallbackSpoofAttack` |
| Atomic unprofitable | check + revert | `AtomicArbitrage.t.sol` phase 5 |
| Reentrancy | `nonReentrant` | `ReentrancyAttack.t.sol` |
| Default | `_chargeRepayment` | `LoanDefaultAttack.t.sol` |
| Liquidity accounting | pool balance | `test/invariant/` |
| Gas baseline | immutables / no profit SSTORE | `doc/GAS-EN.md` + `test/gas/` |

---

## 6. How to read the code (suggested order)

1. `doc/diagrama-flujo-EN.md` — mental picture of the flow.  
2. `FlashLoanPool.flashLoan` — lender.  
3. `AtomicArbitrage.execute` + `onFlashLoan` — borrower.  
4. `ArbitrageMath` — 10 lines of debt/profit.  
5. One happy-path test + one attack (`test_Attack_*`) — what happens when something fails.

If anything in this doc conflicts with the code, **the code wins** — update this file.
