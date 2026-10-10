> 🌐 **English** · [Español](./GAS-ES.md)

# Gas optimization — Flash Loans & Atomic Arbitrage

Regenerate:

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test --match-contract FlashLoanGasTest --gas-report
forge snapshot --match-contract FlashLoanGasTest
```

**Baseline date:** 2026-09-04 (Phase 8)  
**Snapshot:** `.gas-snapshot` (tests in `test/gas/FlashLoan.gas.t.sol`)

---

## Deploy

| Contract | Deploy cost | Bytecode | Notes |
|----------|--------------|----------|-------|
| `FlashLoanPool` | 876 785 gas · 4 085 B | Runtime | ERC-3156 + Ownable2Step + ReentrancyGuard + SafeERC20 |
| `AtomicArbitrage` | 638 862 gas · 3 031 B | Runtime | Borrower + immutables `flashLender` / `owner` |

---

## Main functions (gas-report, medians)

| Function | Contract | Median | Notes |
|---------|----------|--------|-------|
| `deposit` | Pool | **56 940** | `transferFrom` + event |
| `withdraw` | Pool | **58 171** | Owner only |
| `flashLoan` | Pool | **66 623** | Includes simple repay callback (`RepayingBorrower`) |
| `flashFee` | Pool | **654** | View |
| `maxFlashLoan` | Pool | **5 853** | View (`balanceOf`) |
| `execute` | Arb | **234 684** | Flash loan + 2 MockAMM swaps + profit |

---

## E2E snapshot (`test/gas/FlashLoan.gas.t.sol`)

| Test | Gas |
|------|-----|
| `testGas_deposit` | 40 936 |
| `testGas_withdraw` | 42 055 |
| `testGas_flashLoan_repay` | 52 203 |
| `testGas_maxFlashLoan` | 13 167 |
| `testGas_flashFee` | 7 998 |
| `testGas_execute_arbitrage` | 222 056 |

> The snapshot measures the cost of the full test (partial setup already done in `setUp`); the gas-report measures contract calls. Use both as baselines; don't compare them 1:1.

---

## Optimizations applied (Phase 8)

| Technique | Where | Effect |
|---------|-------|--------|
| `immutable` `token` / `feeBps` | Pool | No SLOAD on fee/maxLoan paths |
| `immutable` `flashLender` / `owner` | Arb | Auth and profit without accumulator storage |
| Profit without SSTORE | `onFlashLoan` | Direct transfer to `owner` |
| Custom errors | Pool + Arb | Lower cost vs `require` strings |
| Exact `forceApprove` | Arb repay / swaps | Avoids residual allowance |
| `BPS_DENOMINATOR` constant | Pool | Fee division without SLOAD |
| `feeBps <= 10_000` cap | Constructor | `FeeBpsTooHigh` (SWC-AUDIT hardening) |
| `optimizer_runs = 200` | `foundry.toml` | Deploy/runtime balance |

---

## Accepted tradeoffs

| Decision | Why |
|----------|---------|
| OZ `SafeERC20` vs custom SafeTransfer | Suite consistency; typed repay with try/catch |
| `minOut = 0` in the arb's swaps | v1; `minProfit` mitigates an insufficient edge (off-chain MEV) |
| Custodial pool (`withdraw` owner) | No LP shares; O(1) gas and a simple model |
| External callback in `flashLoan` | ERC-3156; the borrower's gas is paid by the caller |

---

## Relationship with security

See [`SWC-AUDIT-EN.md`](./SWC-AUDIT-EN.md): SafeERC20 / try-catch cover SWC-104; `nonReentrant` + callback auth cover SWC-107; fuzz/invariant tests validate that the optimizations don't break liquidity accounting.
