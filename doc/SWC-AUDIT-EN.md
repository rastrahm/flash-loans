> 🌐 **English** · [Español](./SWC-AUDIT-ES.md)

# SWC Audit — Flash Loans & Atomic Arbitrage

Verification of `FlashLoanPool` and `AtomicArbitrage` against the [SWC Registry](https://swcregistry.io/) (EIP-1470) and the monorepo principles (custom errors, `ReentrancyGuard`, SafeERC20, ERC-3156, callback auth).

> **Note:** The SWC Registry has not been actively maintained since ~2020. Complement it with [SCSVS](https://github.com/ComposableSecurity/SCSVS) and [EEA EthTrust](https://entethalliance.org/specs/ethtrust/).

**Audited contracts:** `src/FlashLoanPool.sol`, `src/AtomicArbitrage.sol`, `src/libraries/ArbitrageMath.sol` (+ interfaces)  
**Mocks (out of prod scope):** `src/mocks/MockAMM.sol`, `src/mocks/MockERC20.sol`  
**Date:** 2026-09-04  
**Test reference:** `test/FlashLoanPool.t.sol`, `test/AtomicArbitrage.t.sol`, `test/Unauthorized.t.sol`, `test/attack/`, `test/fuzz/`, `test/invariant/`, `test/gas/`, `test/fork/`  
**Style:** aligned with [`07-liquidity-pools/doc/SWC-AUDIT.md`](../../07-liquidity-pools/doc/SWC-AUDIT.md)

---

## Executive summary

| Status | Count |
|--------|----------|
| ✅ Mitigated / Not applicable | 33 |
| ⚠️ Informational (design / MEV / trust) | 3 |
| ❌ Vulnerable | 0 |

**Conclusion:** No exploitable SWC vulnerabilities within the v1 scope (single ERC-20, ERC-3156 flash loan, atomic arbitrage between two AMMs via `ISimpleAMM`). Informational risks: MEV/front-running of `execute` (swaps with `minOut = 0`), centralization of the pool `owner` (can withdraw liquidity), and fee-on-transfer / ERC-777 tokens out of scope.

**Suite principles verified:**

| Principle | Status |
|-----------|--------|
| Custom errors (no `require` strings) | ✅ |
| Fixed pragma `0.8.24` | ✅ |
| CEI + `nonReentrant` on `flashLoan` | ✅ + Unauthorized / pool reentrancy |
| Callback auth (`UntrustedLender` / `InvalidInitiator`) | ✅ + `Unauthorized.t.sol` |
| SafeERC20 (SWC-104) on outbound transfers / deposit | ✅ |
| Unprofitable atomicity (`UnprofitableArbitrage`) | ✅ + phase 5 |
| Fuzz ≥ 1000 runs | ✅ `foundry.toml` + `test/fuzz/` |
| Liquidity / fees / maxLoan invariants | ✅ `test/invariant/` |

---

## Full SWC-100 — SWC-136 matrix

| ID | Title | Applies | Status | Evidence in Flash Loans |
|----|--------|--------|--------|---------------------------|
| SWC-100 | Function Default Visibility | Yes | ✅ | Explicit visibility in contracts, interfaces and `ArbitrageMath` |
| SWC-101 | Integer Overflow and Underflow | Yes | ✅ | Solidity `0.8.24`; fee `amount * feeBps / 10_000`; fee/amount fuzzing |
| SWC-102 | Outdated Compiler Version | Yes | ✅ | `pragma solidity 0.8.24` + `foundry.toml` `solc = "0.8.24"` |
| SWC-103 | Floating Pragma | Yes | ✅ | Exact pragma (no `^`) across all of `src/` |
| SWC-104 | Unchecked Call Return Value | Yes | ✅ | OZ `SafeERC20` on transfer/deposit/profit; repay with try/catch → `LoanRepaymentFailed` |
| SWC-105 | Unprotected Ether Withdrawal | No | N/A | No ETH / `payable` / `.call{value}` |
| SWC-106 | Unprotected SELFDESTRUCT | No | N/A | No `selfdestruct` |
| SWC-107 | Reentrancy | Yes | ✅ | `nonReentrant` on `flashLoan`; callback cannot reenter the lender (`Unauthorized` + pool unit) |
| SWC-108 | State Variable Default Visibility | Yes | ✅ | Explicit `immutable` / `constant` / `private` |
| SWC-109 | Uninitialized Storage Pointer | No | N/A | No legacy storage pointers |
| SWC-110 | Assert Violation | No | N/A | No production `assert` |
| SWC-111 | Deprecated Solidity Functions | Yes | ✅ | No `suicide` / `throw` / `tx.origin` / ETH `transfer`/`send` |
| SWC-112 | Delegatecall to Untrusted Callee | No | N/A | No `delegatecall` |
| SWC-113 | DoS with Failed Call | Partial | ✅ | Failed callback/repay → full revert; pool loses no liquidity |
| SWC-114 | Transaction Order Dependence | Yes | ⚠️ | Front-running of `execute` / sandwiching of swaps (`minOut = 0`); see risks |
| SWC-115 | Authorization through tx.origin | No | N/A | No `tx.origin`; auth via `msg.sender` + `initiator` |
| SWC-116 | Block values as a proxy for time | No | N/A | No on-chain time locks |
| SWC-117 | Signature Malleability | No | N/A | No signatures / `ecrecover` / permit |
| SWC-118 | Incorrect Constructor Name | No | N/A | 0.8+ `constructor` |
| SWC-119 | Shadowing State Variables | Yes | ✅ | No state shadowing |
| SWC-120 | Weak Sources of Randomness | No | N/A | No RNG |
| SWC-121 | Missing Protection against Signature Replay | No | N/A | No signatures |
| SWC-122 | Lack of Proper Signature Verification | No | N/A | No signature verification |
| SWC-123 | Requirement Violation | Yes | ✅ | Custom errors + unit/fuzz/invariant/unauthorized/unprofitable |
| SWC-124 | Write to Arbitrary Storage Location | No | N/A | No storage assembly |
| SWC-125 | Incorrect Inheritance Order | Yes | ✅ | `IERC3156FlashLender, IFlashLoanPool, ReentrancyGuard, Ownable2Step` |
| SWC-126 | Insufficient Gas Griefing | Partial | ✅ | External callback; gas bounded by the caller's block/tx; magic value mandatory |
| SWC-127 | Arbitrary Jump with Function Type Variable | No | N/A | No dynamic function types |
| SWC-128 | DoS With Block Gas Limit | Partial | ✅ | No user-driven loops; `flashLoan` / swaps are O(1) |
| SWC-129 | Typographical Error | Yes | ✅ | Review + `forge build` / 48 tests PASS |
| SWC-130 | Right-To-Left-Override | No | N/A | ASCII |
| SWC-131 | Presence of unused variables | Yes | ✅ | No material dead code in production `src/` |
| SWC-132 | Unexpected Ether balance | No | N/A | Contracts do not handle ETH |
| SWC-133 | Hash Collisions (var-length args) | No | N/A | Only `keccak256` of the ERC-3156 magic string (constant) |
| SWC-134 | Message call with hardcoded gas | No | N/A | No `{gas: …}` |
| SWC-135 | Code With No Effects | No | N/A | No relevant no-ops |
| SWC-136 | Unencrypted Private Data On-Chain | Partial | ✅ | Fee, liquidity and arb params are public by design |

---

## Informational risks

### SWC-114 — MEV and transaction ordering

`AtomicArbitrage.execute` is public and the swaps use `minOut = 0`. A bot can:

1. Front-run `execute` with the same path and drain the edge.
2. Sandwich the callback swaps (worse price → `UnprofitableArbitrage` or lower profit).

**Product-level mitigation (v1):** `minProfit` in `params` forces a revert if the edge does not reach the threshold; atomicity prevents any loss of pool capital. Off-chain mitigation: private relay / builder. Future improvement: per-hop `minOut` in `data`.

### Centralization / pool owner trust

| Topic | Risk | v1 treatment |
|------|--------|----------------|
| `withdraw` owner-only | Owner can drain liquidity at any time | `Ownable2Step`; document trust in the pool operator |
| `feeBps` immutable | Fee fixed at deploy (could be high) | No on-chain cap; choose fee at deploy |
| Open `deposit` | Anyone can provide liquidity that the owner can withdraw | Explicit “custodial pool” model; not a tokenized LP |
| Fee-on-transfer / ERC-777 tokens | Unexpected accounting / callbacks | Out of v1 scope; honest standard ERC-20s only |

### Callback and ERC-3156 surface

The receiver in `FlashLoanPool.flashLoan` is an arbitrary contract. A malicious borrower may not repay → `LoanRepaymentFailed` / `CallbackFailed` and **the whole tx reverts** (liquidity intact). `AtomicArbitrage` enforces:

- `msg.sender == flashLender` → `UntrustedLender`
- `initiator == address(this)` → `InvalidInitiator` (prevents a third party from starting the loan “on behalf of” the arb)

Covered in `test/Unauthorized.t.sol`.

---

## Monorepo principles checklist (+ module 08)

| Principle | Compliant? | Notes |
|-----------|----------|--------|
| Custom errors | ✅ | Pool + arb (`UnsupportedToken`, `UntrustedLender`, `UnprofitableArbitrage`, …) |
| ReentrancyGuard (OZ) | ✅ | `flashLoan`; deposit/withdraw have no critical state to corrupt |
| SafeERC20 | ✅ | Outbound + deposit; repay with typed try/catch |
| ERC-3156 magic value | ✅ | `CALLBACK_SUCCESS` in lender and borrower |
| Callback auth | ✅ | Lender + initiator |
| Profit without SSTORE | ✅ | Direct transfer to immutable `owner` |
| NatSpec on public/external | ✅ | Phase 8 |
| Fuzz ≥ 1000 runs | ✅ | `test/fuzz/FlashLoan.fuzz.t.sol` |
| Liquidity invariants | ✅ | `balance == deposits + fees − withdraws` |
| Gas baseline | ✅ | `doc/GAS-EN.md` + `.gas-snapshot` |
| `feeBps` cap | ✅ | `FeeBpsTooHigh` if `> 10_000` |

---

## Verification findings (code)

### Confirmed mitigations

1. **`FlashLoanPool.flashLoan`:** checks (receiver/token/amount/max) → transfer → callback → magic → pull `amount+fee` → event. `nonReentrant` lock.
2. **`_chargeRepayment`:** does not blindly use an unchecked return value; try/catch + balance-delta check → `LoanRepaymentFailed` (covers insufficient allowance and tokens returning `false`).
3. **`AtomicArbitrage.onFlashLoan`:** auth before swaps; profit check via `ArbitrageMath`; exact approve to the lender.
4. **No `require` strings / `tx.origin` / ETH `transfer`/`send` / `delegatecall` / `selfdestruct`** in `src/`.

### Non-blocking observations (phase 8 / v2)

| # | Observation | Severity | Suggested action |
|---|-------------|-----------|-----------------|
| 1 | `deposit` / `withdraw` without `nonReentrant` | Info | Low risk (no state machine); optionally align with the suite |
| 2 | ~~`feeBps` without upper bound~~ → `FeeBpsTooHigh` | Resolved F8 | `feeBps <= 10_000` |
| 3 | Swaps with `minOut = 0` | Info (MEV) | Encode per-hop minimums in `params` (v2) |
| 4 | ~~Incomplete NatSpec / gas snapshot~~ | Resolved F8 | `GAS-EN.md` + API NatSpec |
| 5 | ~~No dedicated `test/attack/` suite~~ | Resolved | `ReentrancyAttack` · `CallbackSpoofAttack` · `LoanDefaultAttack` |

---

## SWC → tests mapping

| SWC | Test(s) |
|-----|---------|
| SWC-101 | `testFuzz_flashFee_*`, `testFuzz_flashLoan_poolGainsExactFee`, `testFuzz_execute_*` |
| SWC-103 | Fixed compiler (`forge build`) |
| SWC-104 | Unit deposit/withdraw/flashLoan; `LoanRepaymentFailed` (deadbeat borrower) |
| SWC-107 | `test/attack/ReentrancyAttack.t.sol` + unit `test_flashLoan_revertsOnReentrancy` |
| SWC-113 | `test/attack/LoanDefaultAttack.t.sol` + unprofitable AtomicArbitrage |
| SWC-114 | Documentation only; `minProfit` in fuzz/unit |
| SWC-123 | unit Pool/Arb + Unauthorized + attack + fuzz + invariant |
| Callback auth | `test/attack/CallbackSpoofAttack.t.sol` + `Unauthorized.t.sol` |
| Atomicity | `test_execute_balancedAmms_*`, `LoanDefaultAttack`, unprofitable |
| Liquidity | `invariant_balanceEqualsGhostAccounting`, `invariant_maxFlashLoanEqualsBalance` |

---

## Execution results

```text
forge test --summary
AtomicArbitrageTest       11 PASS
FlashLoanPoolTest         22 PASS
UnauthorizedTest           3 PASS
CallbackSpoofAttackTest    4 PASS
LoanDefaultAttackTest      3 PASS
ReentrancyAttackTest       4 PASS
FlashLoanFuzzTest          8 PASS
FlashLoanInvariantTest     4 PASS
FlashLoanGasTest           6 PASS
ArbitrageForkTest          2 SKIP (no MAINNET_RPC_URL)
Total: 65 PASS / 0 FAIL / 2 SKIP
```

---

## References

- [SWC Registry](https://swcregistry.io/)
- [EIP-1470](https://eips.ethereum.org/EIPS/eip-1470)
- [ERC-3156](https://eips.ethereum.org/EIPS/eip-3156)
- Module 07: [`07-liquidity-pools/doc/SWC-AUDIT.md`](../../07-liquidity-pools/doc/SWC-AUDIT.md)
- Plan: [`PLANIFICACION-EN.md`](./PLANIFICACION-EN.md)
