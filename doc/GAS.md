# Optimización de gas — Flash Loans & Atomic Arbitrage

Regenerar:

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test --match-contract FlashLoanGasTest --gas-report
forge snapshot --match-contract FlashLoanGasTest
```

**Fecha baseline:** 2026-09-04 (Fase 8)  
**Snapshot:** `.gas-snapshot` (tests en `test/gas/FlashLoan.gas.t.sol`)

---

## Deploy

| Contrato | Coste deploy | Bytecode | Notas |
|----------|--------------|----------|-------|
| `FlashLoanPool` | 876 785 gas · 4 085 B | Runtime | ERC-3156 + Ownable2Step + ReentrancyGuard + SafeERC20 |
| `AtomicArbitrage` | 638 862 gas · 3 031 B | Runtime | Borrower + immutables `flashLender` / `owner` |

---

## Funciones principales (gas-report, medianas)

| Función | Contrato | Median | Notas |
|---------|----------|--------|-------|
| `deposit` | Pool | **56 940** | `transferFrom` + event |
| `withdraw` | Pool | **58 171** | Solo owner |
| `flashLoan` | Pool | **66 623** | Incluye callback repay simple (`RepayingBorrower`) |
| `flashFee` | Pool | **654** | View |
| `maxFlashLoan` | Pool | **5 853** | View (`balanceOf`) |
| `execute` | Arb | **234 684** | Flash loan + 2 swaps MockAMM + profit |

---

## Snapshot e2e (`test/gas/FlashLoan.gas.t.sol`)

| Test | Gas |
|------|-----|
| `testGas_deposit` | 40 936 |
| `testGas_withdraw` | 42 055 |
| `testGas_flashLoan_repay` | 52 203 |
| `testGas_maxFlashLoan` | 13 167 |
| `testGas_flashFee` | 7 998 |
| `testGas_execute_arbitrage` | 222 056 |

> El snapshot mide el coste del test completo (setup parcial ya hecho en `setUp`); el gas-report mide llamadas al contrato. Usar ambos como baseline, no comparar 1:1.

---

## Optimizaciones aplicadas (Fase 8)

| Técnica | Dónde | Efecto |
|---------|-------|--------|
| `immutable` `token` / `feeBps` | Pool | Sin SLOAD en fee/maxLoan paths |
| `immutable` `flashLender` / `owner` | Arb | Auth y profit sin storage de acumulado |
| Profit sin SSTORE | `onFlashLoan` | Transfer directo a `owner` |
| Custom errors | Pool + Arb | Menor coste vs `require` strings |
| `forceApprove` exacto | Arb repay / swaps | Evita allowance residual |
| `BPS_DENOMINATOR` constant | Pool | División fee sin SLOAD |
| Cap `feeBps <= 10_000` | Constructor | `FeeBpsTooHigh` (hardening SWC-AUDIT) |
| `optimizer_runs = 200` | `foundry.toml` | Balance deploy/runtime |

---

## Tradeoffs aceptados

| Decisión | Por qué |
|----------|---------|
| OZ `SafeERC20` vs SafeTransfer propio | Consistencia suite; repay tipado con try/catch |
| `minOut = 0` en swaps del arb | v1; `minProfit` mitiga edge insuficiente (MEV off-chain) |
| Pool custodiado (`withdraw` owner) | Sin LP shares; gas O(1) y modelo simple |
| Callback externo en `flashLoan` | ERC-3156; gas del borrower a cargo del caller |

---

## Relación con seguridad

Ver [`SWC-AUDIT.md`](./SWC-AUDIT.md): SafeERC20 / try-catch cubren SWC-104; `nonReentrant` + auth callback cubren SWC-107; fuzz/invariant validan que las opts no rompen la contabilidad de liquidez.
