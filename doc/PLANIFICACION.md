# Planificación — Module 08: Flash Loans & Atomic Arbitrage Execution

**Estado:** Fase **7** ✅ — fuzz + invariant. Siguiente: fase **8** (fork opcional + gas + NatSpec).

## 1. Objetivo del proyecto

Proveedor de **flash loans ERC-3156** y ejecutor de **arbitraje atómico** entre dos AMMs: identificar un desequilibrio de precios, pedir prestado sin capital propio, ejecutar swaps, devolver principal + prima y retener el beneficio neto **en la misma transacción**. Stack: Foundry y Solidity `0.8.24`.

### Capacidades principales

- Pool `FlashLoanPool` que implementa `IERC3156FlashLender` (liquidez ERC-20, fee fijo, lock anti-reentrada).
- Receptor `AtomicArbitrage` que implementa `IERC3156FlashBorrower` y orquesta dos swaps AMM.
- **Garantía atómica:** si el trade no cubre `principal + fee`, la transacción **revierte por completo**.
- Autenticación estricta en `onFlashLoan()`: `msg.sender == flashLender` e `initiator == address(this)`.
- Beneficio **sin storage intermedio**: transfer directo a `owner` / tesorería.
- Tests Foundry: unit, mocks de dos AMMs desbalanceados, fork opcional, callers no autorizados.

---

## 2. Alcance

### Incluye

| Área | Descripción |
|------|-------------|
| FlashLoanPool | ERC-3156: `maxFlashLoan`, `flashFee`, `flashLoan`; liquidez depositable |
| AtomicArbitrage | Callback + swaps A→B / B→A; repay + profit to owner |
| Auth callback | `UntrustedLender` / `InvalidInitiator` |
| Atomicidad | `UnprofitableArbitrage` si balance final < amount + fee |
| Repay | Approve/transfer al lender; `LoanRepaymentFailed` si el pull falla |
| Seguridad | `ReentrancyGuard` en `flashLoan`; CEI; custom errors |
| Mocks AMM | Dos pools con reservas artificialmente desbalanceadas |
| Tests | Unit, unprofitable revert, unauthorized callback, fuzz de amounts |

### No incluye (v1)

- Routing multi-hop (>2 AMMs) o path finder off-chain en contrato.
- Flash loans de ETH nativo (solo ERC-20; WETH como token si se necesita).
- Integración Uniswap V3 / concentrated liquidity en producción (mocks + interfaz mínima).
- Oráculos Chainlink para “fair price” (el desequilibrio se simula en tests).
- Frontend Next.js (fase posterior opcional).
- Governance on-chain de la fee del lender.

---

## 3. Stack técnico

| Componente | Elección |
|------------|----------|
| Compilador | `pragma solidity 0.8.24;` (exacto, sin pragma flotante) |
| Framework | Foundry (`forge test`, fuzz ≥ 1000, traces, fork opcional) |
| Estándar | ERC-3156 (`IERC3156FlashLender`, `IERC3156FlashBorrower`) |
| Librerías | OpenZeppelin Contracts v5.x (`ReentrancyGuard`, `Ownable2Step`, `SafeERC20`, IERC3156 si aplica) |
| ETH | Si algún mock usa ETH: `.call{value: ...}("")` — nunca `transfer`/`send` |
| Documentación | NatSpec en toda API public/external |

---

## 4. Arquitectura

```
08-flash-loans/
├── doc/
│   ├── README.md
│   ├── PLANIFICACION.md
│   ├── diagrama-clases.md
│   ├── diagrama-flujo.md
│   └── flujograma.md
├── src/
│   ├── FlashLoanPool.sol                 # IERC3156FlashLender + liquidez
│   ├── AtomicArbitrage.sol               # IERC3156FlashBorrower + executor
│   ├── interfaces/
│   │   ├── IERC3156FlashLender.sol
│   │   ├── IERC3156FlashBorrower.sol
│   │   ├── IFlashLoanPool.sol
│   │   ├── IAtomicArbitrage.sol
│   │   └── ISimpleAMM.sol                # swapExactIn mínimo para mocks
│   ├── libraries/
│   │   └── ArbitrageMath.sol             # amountOut / profit check (view)
│   └── mocks/
│       ├── MockERC20.sol
│       └── MockAMM.sol                   # x*y=k simplificado, reservas seteables
├── test/
│   ├── FlashLoanPool.t.sol
│   ├── AtomicArbitrage.t.sol
│   ├── Unauthorized.t.sol
│   ├── fuzz/FlashLoan.fuzz.t.sol
│   └── fork/Arbitrage.fork.t.sol         # opcional, skip si no hay RPC
├── script/
│   └── Deploy.s.sol
├── foundry.toml
└── remappings.txt
```

### Roles

| Actor | Responsabilidad |
|-------|-----------------|
| **Liquidez provider** | Deposita ERC-20 en `FlashLoanPool` para habilitar préstamos |
| **Operador / owner** | Llama `AtomicArbitrage.execute(...)` cuando hay spread |
| **FlashLoanPool** | Transfiere principal, invoca callback, cobra amount+fee |
| **AtomicArbitrage** | Autentica callback, swap en AMM barato → AMM caro, repay, envía profit |
| **AMM A / AMM B** | Pools mock (o fork) con precios distintos para el mismo par |
| **Atacante (test)** | Llama `onFlashLoan` directo o reentra el lender → debe revertir |

---

## 5. Modelo de datos

```solidity
// FlashLoanPool (resumen)
address public immutable token;          // ERC-20 prestable (v1: un token)
uint256 public feeBps;                   // p.ej. 5 = 0.05% (o fee fijo wei)
uint256 public constant CALLBACK_SUCCESS =
    keccak256("ERC3156FlashBorrower.onFlashLoan");

// AtomicArbitrage (resumen)
address public immutable flashLender;
address public immutable owner;          // destino de profit (immutable = 0 storage write en ejecución)
// sin mapping de profits — transfer directo en el callback
```

### Fórmulas clave

| Operación | Fórmula |
|-----------|---------|
| Fee ERC-3156 | `flashFee = amount * feeBps / 10_000` (o fee mínimo si amount=0 no aplica) |
| Deuda | `repayAmount = amount + flashFee` |
| Swap (mock AMM) | `amountOut = (amountIn * 997 * reserveOut) / (reserveIn * 1000 + amountIn * 997)` |
| Profit | `balance(token) - repayAmount` tras ambos swaps |
| Atomicidad | `profit >= 0` (balance ≥ repayAmount) o `UnprofitableArbitrage` |

`data` del flash loan (ABI-encoded):

| Campo | Uso |
|-------|-----|
| `ammBuy` | AMM donde el token prestado compra el intermediario más barato |
| `ammSell` | AMM donde se vende el intermediario más caro |
| `tokenB` | Token intermediario del par |
| `minProfit` | Slippage de beneficio mínimo (opcional, wei) |

---

## 6. API on-chain

### FlashLoanPool (`IERC3156FlashLender`)

| Función | Visibilidad | Descripción |
|---------|-------------|-------------|
| `maxFlashLoan(address token)` | view | Liquidez disponible; 0 si token no soportado |
| `flashFee(address token, uint256 amount)` | view | Prima; revert si token no soportado |
| `flashLoan(receiver, token, amount, data)` | external nonReentrant | Transfiere, callback, pull amount+fee |
| `deposit(uint256 amount)` | external | Aporta liquidez al pool |
| `withdraw(uint256 amount)` | external | Retira liquidez (solo owner / LPs según diseño v1: owner) |

### AtomicArbitrage (`IERC3156FlashBorrower`)

| Función | Visibilidad | Descripción |
|---------|-------------|-------------|
| `execute(uint256 amount, bytes params)` | external | Inicia `flashLoan` hacia `address(this)` |
| `onFlashLoan(initiator, token, amount, fee, data)` | external | Auth → swaps → approve repay → CALLBACK_SUCCESS |
| `owner()` | view | Destinatario de beneficios |

### Errores custom (obligatorios)

| Error | Condición |
|-------|-----------|
| `InvalidInitiator()` | `initiator != address(this)` en el callback |
| `UntrustedLender()` | `msg.sender != flashLender` en el callback |
| `UnprofitableArbitrage()` | `balance < amount + fee` (o profit < minProfit) |
| `LoanRepaymentFailed()` | El lender no puede cobrar amount+fee |

Errores adicionales del pool (recomendados, consistentes con la suite):

| Error | Condición |
|-------|-----------|
| `UnsupportedToken()` | Token distinto al `immutable token` |
| `AmountExceedsMaxLoan()` | `amount > maxFlashLoan` |
| `CallbackFailed()` | Return distinto a `CALLBACK_SUCCESS` |
| `ZeroAmount()` | amount 0 |

### Eventos

`FlashLoan` (borrower, token, amount, fee) · `ArbitrageExecuted` (token, amount, profit) · `LiquidityDeposited` · `LiquidityWithdrawn`

Magic value ERC-3156:

```solidity
bytes32 constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");
```

---

## 7. Lógica flashLoan + callback (CEI)

### Lender `flashLoan`

1. **Checks:** token soportado, `amount > 0`, `amount <= maxFlashLoan`, receiver ≠ 0.
2. Calcular `fee = flashFee(token, amount)`.
3. **Effects:** lock `nonReentrant` (status ENTERED).
4. **Interactions:** `SafeERC20.safeTransfer(receiver, amount)`.
5. `bytes32 rc = IERC3156FlashBorrower(receiver).onFlashLoan(msg.sender, token, amount, fee, data)`.
6. **Checks:** `rc == CALLBACK_SUCCESS`.
7. **Interactions:** `safeTransferFrom(receiver, address(this), amount + fee)` → sino `LoanRepaymentFailed`.
8. Emit `FlashLoan`. Unlock.

El balance del pool al final debe ser ≥ balance inicial + fee (liquidez no drenada).

### Borrower `onFlashLoan`

1. **Checks:** `msg.sender == flashLender` → sino `UntrustedLender`.
2. **Checks:** `initiator == address(this)` → sino `InvalidInitiator`.
3. Decode `data` (ammBuy, ammSell, tokenB, minProfit).
4. Approve/swap en AMM buy; swap en AMM sell (vuelve el token prestado).
5. `required = amount + fee`; `bal = IERC20(token).balanceOf(address(this))`.
6. Si `bal < required` o `bal - required < minProfit` → `UnprofitableArbitrage`.
7. `profit = bal - required`; `safeTransfer(token, owner, profit)` (cero writes de profit).
8. `safeIncreaseAllowance(flashLender, required)` (o approve exacto).
9. Return `CALLBACK_SUCCESS`.

---

## 8. Fases de implementación (TDD)

| Fase | Entregable | Estado |
|------|------------|--------|
| **0** | Docs (`doc/`) + scaffold Foundry + interfaces ERC-3156 | ✅ |
| **1** | Tests failing: `flashLoan`, fee, maxLoan, reverts | ✅ |
| **2** | `FlashLoanPool` mínimo (deposit + flashLoan sin arbitraje) | ✅ |
| **3** | Tests failing `AtomicArbitrage` + mocks AMM desbalanceados | ✅ |
| **4** | `onFlashLoan` auth + swaps + repay + profit to owner | ✅ |
| **5** | Unprofitable revert (AMMs equilibrados / fee > spread) | ✅ |
| **6** | Unauthorized: callback directo, initiator falso, reentrancy | ✅ |
| **7** | Fuzz amounts + invariant liquidez pool ≥ pre + fees netas | ✅ |
| **8** | Fork opcional + gas snapshot + NatSpec | ⬜ |

---

## 9. Plan de pruebas

| Suite | Ubicación | Cobertura |
|-------|-----------|-----------|
| Unit lender | `test/FlashLoanPool.t.sol` | maxLoan, fee, repay, unsupported token |
| Unit arb | `test/AtomicArbitrage.t.sol` | Spread artificial → profit a owner |
| Unprofitable | mismo | AMMs sin spread / fee excesiva → revert, pool intacto |
| Unauthorized | `test/Unauthorized.t.sol` | `onFlashLoan` desde EOA / lender falso |
| Reentrancy | `test/FlashLoanPool.t.sol` | Receiver malicioso reentra `flashLoan` |
| Fuzz | `test/fuzz/FlashLoan.fuzz.t.sol` | `bound(amount)` vs liquidez y fee |
| Fork | `test/fork/Arbitrage.fork.t.sol` | Skip sin `MAINNET_RPC_URL` |
| Invariant | `test/invariant/` | `balance(pool) >= deposits + feesAcumulados - withdraws` |

Invariante de capital: un flash loan que revierte **no** cambia balances de pool ni de attacker (salvo gas).

---

## 10. Criterios de aceptación

- [x] Scaffold Foundry (`0.8.24`, fuzz ≥ 1000)
- [x] `FlashLoanPool` implementa `IERC3156FlashLender`
- [x] `AtomicArbitrage` implementa `IERC3156FlashBorrower`
- [x] Callback: `msg.sender == flashLender` e `initiator == address(this)`
- [x] Custom errors obligatorios (los cuatro del módulo)
- [x] Trade no rentable → revert atómico; liquidez del pool intacta
- [x] Profit transferido a `owner` sin variables de estado de acumulado
- [x] `ReentrancyGuard` en `flashLoan`
- [x] Terceros no pueden invocar el callback con éxito
- [x] Mocks de dos AMMs con imbalance verifican ejecución atómica
- [x] `vm.expectRevert` en todos los caminos de fallo
- [ ] NatSpec en funciones public/external
- [x] CEI + SafeERC20; sin `transfer`/`send` de ETH

---

## 11. Documentos relacionados

| Documento | Contenido |
|-----------|-----------|
| [diagrama-clases.md](./diagrama-clases.md) | UML contratos, interfaces ERC-3156, tests |
| [diagrama-flujo.md](./diagrama-flujo.md) | Secuencia flash loan → swaps → repay |
| [flujograma.md](./flujograma.md) | Operativo, seguridad, TDD |

---

## 12. Riesgos y mitigaciones

| Riesgo | Mitigación |
|--------|------------|
| Callback spoofing | `UntrustedLender` + `InvalidInitiator` |
| Reentrada al lender durante callback | `nonReentrant` en `flashLoan` |
| Trade que no cubre fee | `UnprofitableArbitrage` antes del approve |
| Approve infinito residual | Approve exacto `required` (o 0 luego del pull) |
| Token fee-on-transfer | v1: solo tokens estándar; tests con mock simple |
| Read-only reentrancy / precio stale | Mocks controlados; en fork, ejecutar en un bloque |
| Front-running del execute | Fuera de alcance on-chain; private relay en prod |
| Drenaje de liquidez del pool | Pull amount+fee post-callback; check de balance |

---

## 13. Convenciones (suite + Solidity rules)

- Pragma fijo `0.8.24`; layout: Interfaces → Libraries → Contracts → State → Events → Errors → Modifiers → Functions (External → Public → Internal → Private).
- NatSpec `@notice` / `@dev` / `@param` / `@return` en API pública.
- Tests primero (TDD); `vm.expectRevert` en caminos de fallo.
- Gas: `immutable`/`constant`, custom errors, profit sin SSTORE.
- Relación con módulos 06/07: los AMMs reales viven allí; este módulo **presta y arbitra** contra una interfaz `ISimpleAMM` (mocks en tests, pares 06 en integración futura).
