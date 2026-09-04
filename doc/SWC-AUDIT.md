# Auditoría SWC — Flash Loans & Atomic Arbitrage

Verificación de `FlashLoanPool` y `AtomicArbitrage` contra el [SWC Registry](https://swcregistry.io/) (EIP-1470) y principios del monorepo (custom errors, `ReentrancyGuard`, SafeERC20, ERC-3156, auth de callback).

> **Nota:** El SWC Registry no se mantiene activamente desde ~2020. Complementar con [SCSVS](https://github.com/ComposableSecurity/SCSVS) y [EEA EthTrust](https://entethalliance.org/specs/ethtrust/).

**Contratos auditados:** `src/FlashLoanPool.sol`, `src/AtomicArbitrage.sol`, `src/libraries/ArbitrageMath.sol` (+ interfaces)  
**Mocks (fuera de prod):** `src/mocks/MockAMM.sol`, `src/mocks/MockERC20.sol`  
**Fecha:** 2026-09-04  
**Referencia tests:** `test/FlashLoanPool.t.sol`, `test/AtomicArbitrage.t.sol`, `test/Unauthorized.t.sol`, `test/fuzz/`, `test/invariant/`  
**Estilo:** alineado a [`07-liquidity-pools/doc/SWC-AUDIT.md`](../../07-liquidity-pools/doc/SWC-AUDIT.md)

---

## Resumen ejecutivo

| Estado | Cantidad |
|--------|----------|
| ✅ Mitigado / No aplicable | 33 |
| ⚠️ Informativo (diseño / MEV / trust) | 3 |
| ❌ Vulnerable | 0 |

**Conclusión:** Sin vulnerabilidades SWC explotables en el alcance v1 (ERC-20 único, flash loan ERC-3156, arbitraje atómico entre dos AMMs vía `ISimpleAMM`). Riesgos informativos: MEV/front-run de `execute` (swaps con `minOut = 0`), centralización del `owner` del pool (puede retirar liquidez), y tokens fee-on-transfer / ERC-777 fuera de alcance.

**Principios del suite verificados:**

| Principio | Estado |
|-----------|--------|
| Custom errors (no `require` strings) | ✅ |
| Pragma fijo `0.8.24` | ✅ |
| CEI + `nonReentrant` en `flashLoan` | ✅ + Unauthorized / pool reentrancy |
| Callback auth (`UntrustedLender` / `InvalidInitiator`) | ✅ + `Unauthorized.t.sol` |
| SafeERC20 (SWC-104) en transfers out / deposit | ✅ |
| Atomicidad unprofitable (`UnprofitableArbitrage`) | ✅ + fase 5 |
| Fuzz ≥ 1000 runs | ✅ `foundry.toml` + `test/fuzz/` |
| Invariantes liquidez / fees / maxLoan | ✅ `test/invariant/` |

---

## Matriz completa SWC-100 — SWC-136

| ID | Título | Aplica | Estado | Evidencia en Flash Loans |
|----|--------|--------|--------|---------------------------|
| SWC-100 | Function Default Visibility | Sí | ✅ | Visibilidad explícita en contratos, interfaces y `ArbitrageMath` |
| SWC-101 | Integer Overflow and Underflow | Sí | ✅ | Solidity `0.8.24`; fee `amount * feeBps / 10_000`; fuzz fee/amounts |
| SWC-102 | Outdated Compiler Version | Sí | ✅ | `pragma solidity 0.8.24` + `foundry.toml` `solc = "0.8.24"` |
| SWC-103 | Floating Pragma | Sí | ✅ | Pragma exacto (sin `^`) en todo `src/` |
| SWC-104 | Unchecked Call Return Value | Sí | ✅ | OZ `SafeERC20` en transfer/deposit/profit; repay con try/catch → `LoanRepaymentFailed` |
| SWC-105 | Unprotected Ether Withdrawal | No | N/A | Sin ETH / `payable` / `.call{value}` |
| SWC-106 | Unprotected SELFDESTRUCT | No | N/A | Sin `selfdestruct` |
| SWC-107 | Reentrancy | Sí | ✅ | `nonReentrant` en `flashLoan`; callback no puede reentrar el lender (`Unauthorized` + pool unit) |
| SWC-108 | State Variable Default Visibility | Sí | ✅ | `immutable` / `constant` / `private` explícitos |
| SWC-109 | Uninitialized Storage Pointer | No | N/A | Sin punteros storage legacy |
| SWC-110 | Assert Violation | No | N/A | Sin `assert` de producción |
| SWC-111 | Deprecated Solidity Functions | Sí | ✅ | Sin `suicide` / `throw` / `tx.origin` / `transfer`/`send` ETH |
| SWC-112 | Delegatecall to Untrusted Callee | No | N/A | Sin `delegatecall` |
| SWC-113 | DoS with Failed Call | Parcial | ✅ | Callback/repay fallido → revert completa; pool no pierde liquidez |
| SWC-114 | Transaction Order Dependence | Sí | ⚠️ | Front-run de `execute` / sandwich en swaps (`minOut = 0`); ver riesgos |
| SWC-115 | Authorization through tx.origin | No | N/A | Sin `tx.origin`; auth por `msg.sender` + `initiator` |
| SWC-116 | Block values as a proxy for time | No | N/A | Sin locks temporales on-chain |
| SWC-117 | Signature Malleability | No | N/A | Sin firmas / `ecrecover` / permit |
| SWC-118 | Incorrect Constructor Name | No | N/A | `constructor` 0.8+ |
| SWC-119 | Shadowing State Variables | Sí | ✅ | Sin shadowing de estado |
| SWC-120 | Weak Sources of Randomness | No | N/A | Sin RNG |
| SWC-121 | Missing Protection against Signature Replay | No | N/A | Sin firmas |
| SWC-122 | Lack of Proper Signature Verification | No | N/A | Sin verificación de firmas |
| SWC-123 | Requirement Violation | Sí | ✅ | Custom errors + unit/fuzz/invariant/unauthorized/unprofitable |
| SWC-124 | Write to Arbitrary Storage Location | No | N/A | Sin assembly de storage |
| SWC-125 | Incorrect Inheritance Order | Sí | ✅ | `IERC3156FlashLender, IFlashLoanPool, ReentrancyGuard, Ownable2Step` |
| SWC-126 | Insufficient Gas Griefing | Parcial | ✅ | Callback externo; gas limitado por el bloque/tx del caller; magic value obligatorio |
| SWC-127 | Arbitrary Jump with Function Type Variable | No | N/A | Sin function types dinámicos |
| SWC-128 | DoS With Block Gas Limit | Parcial | ✅ | Sin loops de usuario; `flashLoan` / swaps O(1) |
| SWC-129 | Typographical Error | Sí | ✅ | Revisión + `forge build` / 48 tests PASS |
| SWC-130 | Right-To-Left-Override | No | N/A | ASCII |
| SWC-131 | Presence of unused variables | Sí | ✅ | Sin dead code material en `src/` de producción |
| SWC-132 | Unexpected Ether balance | No | N/A | Contratos no manejan ETH |
| SWC-133 | Hash Collisions (var-length args) | No | N/A | Solo `keccak256` del magic string ERC-3156 (constante) |
| SWC-134 | Message call with hardcoded gas | No | N/A | Sin `{gas: …}` |
| SWC-135 | Code With No Effects | No | N/A | Sin no-ops relevantes |
| SWC-136 | Unencrypted Private Data On-Chain | Parcial | ✅ | Fee, liquidez y params de arb son públicos por diseño |

---

## Riesgos informativos

### SWC-114 — MEV y orden de transacciones

`AtomicArbitrage.execute` es público y los swaps usan `minOut = 0`. Un bot puede:

1. Front-run el `execute` con el mismo path y vaciar el edge.
2. Sandwich los swaps del callback (peor precio → `UnprofitableArbitrage` o profit menor).

**Mitigación de producto (v1):** `minProfit` en `params` fuerza revert si el edge no alcanza el umbral; la atomicidad evita pérdida de capital del pool. Mitigación off-chain: private relay / builder. Mejora futura: `minOut` por hop en `data`.

### Centralización / trust del pool owner

| Tema | Riesgo | Tratamiento v1 |
|------|--------|----------------|
| `withdraw` solo owner | Owner puede drenar liquidez en cualquier momento | `Ownable2Step`; documentar trust en operador del pool |
| `feeBps` immutable | Fee fijado en deploy (puede ser alto) | Sin cap on-chain; elegir fee en deploy |
| `deposit` abierto | Cualquiera aporta liquidez que el owner puede retirar | Modelo “pool custodiado” explícito; no es LP tokenizado |
| Tokens fee-on-transfer / ERC-777 | Accounting / callbacks inesperados | Fuera de alcance v1; solo ERC-20 estándar honestos |

### Callback y superficie ERC-3156

El receptor es un contrato arbitrario en `FlashLoanPool.flashLoan`. Un borrower malicioso puede no pagar → `LoanRepaymentFailed` / `CallbackFailed` y **toda la tx revierte** (liquidez intacta). `AtomicArbitrage` restringe:

- `msg.sender == flashLender` → `UntrustedLender`
- `initiator == address(this)` → `InvalidInitiator` (impide que un tercero inicie el loan “en nombre” del arb)

Cubierto en `test/Unauthorized.t.sol`.

---

## Checklist principios monorepo (+ módulo 08)

| Principio | ¿Cumple? | Notas |
|-----------|----------|--------|
| Custom errors | ✅ | Pool + arb (`UnsupportedToken`, `UntrustedLender`, `UnprofitableArbitrage`, …) |
| ReentrancyGuard (OZ) | ✅ | `flashLoan`; deposit/withdraw sin estado crítico que corromper |
| SafeERC20 | ✅ | Outbound + deposit; repay con try/catch tipado |
| ERC-3156 magic value | ✅ | `CALLBACK_SUCCESS` en lender y borrower |
| Auth callback | ✅ | Lender + initiator |
| Profit sin SSTORE | ✅ | Transfer directo a `owner` immutable |
| NatSpec públicas/externas | ⚠️ | Presente en APIs principales; completar/ pulir en fase 8 |
| Fuzz ≥ 1000 runs | ✅ | `test/fuzz/FlashLoan.fuzz.t.sol` |
| Invariantes liquidez | ✅ | `balance == deposits + fees − withdraws` |
| Gas baseline | ⬜ | Pendiente fase 8 (`doc/GAS.md` + snapshot) |

---

## Hallazgos de verificación (código)

### Mitigaciones confirmadas

1. **`FlashLoanPool.flashLoan`:** checks (receiver/token/amount/max) → transfer → callback → magic → pull `amount+fee` → event. Lock `nonReentrant`.
2. **`_chargeRepayment`:** no usa valor de retorno unchecked a ciegas; try/catch + chequeo de balance delta → `LoanRepaymentFailed` (cubre allowance insuficiente y tokens que retornan `false`).
3. **`AtomicArbitrage.onFlashLoan`:** auth antes de swaps; profit check vía `ArbitrageMath`; approve exacto al lender.
4. **Sin `require` strings / `tx.origin` / ETH `transfer`/`send` / `delegatecall` / `selfdestruct`** en `src/`.

### Observaciones no bloqueantes (fase 8 / v2)

| # | Observación | Severidad | Acción sugerida |
|---|-------------|-----------|-----------------|
| 1 | `deposit` / `withdraw` sin `nonReentrant` | Info | Bajo riesgo (sin máquina de estados); opcional alinear con suite |
| 2 | `feeBps` sin cota superior en constructor | Info | `require(feeBps <= 10_000)` o custom error |
| 3 | Swaps con `minOut = 0` | Info (MEV) | Codificar mínimos por hop en `params` |
| 4 | NatSpec / gas snapshot incompletos | Proceso | Fase 8 del plan |
| 5 | Sin suite `test/attack/` dedicada (estilo 07) | Proceso | Cubierto por `Unauthorized` + reentrancy unit; opcional extraer |

---

## Mapeo SWC → tests

| SWC | Test(s) |
|-----|---------|
| SWC-101 | `testFuzz_flashFee_*`, `testFuzz_flashLoan_poolGainsExactFee`, `testFuzz_execute_*` |
| SWC-103 | Compilador fijo (`forge build`) |
| SWC-104 | Unit deposit/withdraw/flashLoan; `LoanRepaymentFailed` (deadbeat borrower) |
| SWC-107 | `test_flashLoan_revertsOnReentrancy`, `test_flashLoan_reentrancyFromMaliciousBorrower_reverts` |
| SWC-113 | Unprofitable / CallbackFailed / LoanRepaymentFailed → capital intacto |
| SWC-114 | Documental; `minProfit` en fuzz/unit |
| SWC-123 | unit Pool/Arb + Unauthorized + fuzz + invariant |
| Auth callback | `Unauthorized.t.sol` (EOA, fake lender, third-party initiator) |
| Atomicidad | `test_execute_balancedAmms_*`, `test_execute_feeExceedsSpread_*`, `test_execute_wrongDirection_*` |
| Liquidez | `invariant_balanceEqualsGhostAccounting`, `invariant_maxFlashLoanEqualsBalance` |

---

## Resultado de ejecución

```text
forge test --summary
AtomicArbitrageTest    11 PASS
FlashLoanPoolTest      20 PASS
UnauthorizedTest        5 PASS
FlashLoanFuzzTest       8 PASS (1000 runs c/u)
FlashLoanInvariantTest  4 PASS (256 runs)
Total: 48 PASS / 0 FAIL
```

---

## Referencias

- [SWC Registry](https://swcregistry.io/)
- [EIP-1470](https://eips.ethereum.org/EIPS/eip-1470)
- [ERC-3156](https://eips.ethereum.org/EIPS/eip-3156)
- Módulo 07: [`07-liquidity-pools/doc/SWC-AUDIT.md`](../../07-liquidity-pools/doc/SWC-AUDIT.md)
- Plan: [`PLANIFICACION.md`](./PLANIFICACION.md)
