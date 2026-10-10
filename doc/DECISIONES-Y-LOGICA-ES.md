> 🌐 [English](./DECISIONES-Y-LOGICA-EN.md) · **Español**

# Decisiones técnicas, lógica y gas — Módulo 08

Documento para estudiar el diseño de **Flash Loans & Atomic Arbitrage**: qué se decidió y por qué, cómo fluye la lógica, y qué se podría mejorar en gas sin romper seguridad.

**Contratos:** `FlashLoanPool` · `AtomicArbitrage` · `ArbitrageMath`  
**Referencias:** [PLANIFICACION-ES.md](./PLANIFICACION-ES.md) · [GAS-ES.md](./GAS-ES.md) · [SWC-AUDIT-ES.md](./SWC-AUDIT-ES.md) · [diagrama-flujo-ES.md](./diagrama-flujo-ES.md)

---

## 1. Qué problema resuelve

Hay dos piezas que trabajan juntas:

| Contrato | Rol |
|----------|-----|
| **FlashLoanPool** | Presta un ERC-20 **sin colateral** dentro de **una sola transacción** (ERC-3156). Cobra `amount + fee`. |
| **AtomicArbitrage** | Pide el préstamo, hace dos swaps entre AMMs con precios distintos, devuelve la deuda y se queda con el profit. |

Regla de oro: si al final no hay tokens suficientes para `principal + fee`, **toda la transacción revierte**. El pool no “pierde a medias”.

---

## 2. Decisiones técnicas (y por qué)

### 2.1 Estándar ERC-3156 (no un callback inventado)

**Decisión:** implementar `IERC3156FlashLender` / `IERC3156FlashBorrower`.

**Por qué:**

- Interfaz conocida (Aave-style / EIP-3156): `maxFlashLoan`, `flashFee`, `flashLoan`, `onFlashLoan`.
- Magic value `keccak256("ERC3156FlashBorrower.onFlashLoan")` → el lender sabe que el callback “aceptó” el protocolo.
- Facilita tests y comparación con otros lenders.

**Tradeoff:** el lender llama a un contrato externo (el borrower). Eso obliga a `nonReentrant` y a validar el repay.

---

### 2.2 Un solo token por pool (`immutable token`)

**Decisión:** v1 = un ERC-20 fijo en el constructor.

**Por qué:**

- Menos storage y menos ramas (`UnsupportedToken` es trivial).
- `maxFlashLoan` = `balanceOf(pool)` del único token.
- Alineado a “módulo didáctico” de la suite.

**Tradeoff:** no hay multi-asset ni WETH nativo en el mismo contrato.

---

### 2.3 Fee en basis points (`feeBps` immutable)

**Decisión:** `fee = amount * feeBps / 10_000`, con tope `feeBps <= 10_000` (`FeeBpsTooHigh`).

**Por qué:**

- Fee predecible y barato de calcular (sin oráculos).
- Immutable → no hay governance on-chain de fee en v1 (menos superficie de ataque).
- Cap evita fees absurdos (>100%).

**Tradeoff:** no se puede cambiar el fee sin redesplegar.

---

### 2.4 Pool custodiado (`withdraw` solo `owner`)

**Decisión:** cualquiera puede `deposit`; solo el owner (`Ownable2Step`) puede `withdraw`.

**Por qué:**

- Modelo simple: no hay LP shares, dilución ni anti-inflation del módulo 07.
- Gas O(1); foco del módulo = flash loan + arbitraje, no vault.

**Tradeoff / riesgo:** el owner puede drenar liquidez. Es un **trust model** explícito (documentado en SWC como informativo), no un bug oculto.

---

### 2.5 Auth estricta en `onFlashLoan`

**Decisión:**

1. `msg.sender == flashLender` → si no, `UntrustedLender`
2. `initiator == address(this)` → si no, `InvalidInitiator`

**Por qué:**

- Impide que un EOA o un “lender falso” dispare swaps / aprueben tokens del arb.
- Impide que un tercero llame `pool.flashLoan(arb, …)` y use el arb como receptor: el `initiator` sería el tercero, no el propio contrato.
- Solo `execute()` (llamado de forma que el initiator sea el arb) es camino válido.

**Tradeoff:** `execute` es público (cualquiera puede disparar el arb); el profit siempre va al `owner` immutable. Eso es intencional (bot / operador).

---

### 2.6 Profit sin variables de estado (cero SSTORE de acumulado)

**Decisión:** tras los swaps, `profit = balance - (amount + fee)` y `safeTransfer(owner, profit)`.

**Por qué:**

- Regla del módulo (`.cursorrules`): no escribir profits intermedios a storage.
- Menos gas en el hot path del callback.
- Menos estado que auditar.

**Tradeoff:** no hay “treasury on-chain” ni historial de profits en el contrato (solo eventos).

---

### 2.7 Atomicidad del unprofitable

**Decisión:** si `balance < amount + fee` (o profit `< minProfit`) → `UnprofitableArbitrage` **antes** del approve al lender.

**Por qué:**

- Si revierte ahí, el EVM deshace transfers del callback → el pool nunca completa el pull → **liquidez intacta**.
- `minProfit` en `params` actúa como slippage de beneficio.

**Tradeoff:** los swaps usan `minOut = 0` → riesgo MEV/sandwich (mitigado parcialmente con `minProfit`, no con minOut por hop).

---

### 2.8 Reentrancy solo en `flashLoan` (no en deposit/withdraw)

**Decisión:** `nonReentrant` en `flashLoan`; deposit/withdraw sin guard.

**Por qué:**

- El peligro real es reentrar el préstamo durante el callback (transfer + call externo).
- deposit/withdraw no tienen máquina de estados compleja (solo mueven tokens).

**Tradeoff:** se podría añadir `nonReentrant` también ahí por simetría (mejora menor de seguridad, coste de gas en paths fríos).

---

### 2.9 Repay con try/catch → `LoanRepaymentFailed`

**Decisión:** no asumir que `transferFrom` “siempre va”; capturar fallo y mapear a error custom.

**Por qué:**

- ERC-20 malos / sin allowance / retorno `false`.
- Tests de `NonRepayingBorrower` y suite `LoanDefaultAttack`.

**Tradeoff:** un poco más de bytecode vs un `safeTransferFrom` que revierte con el error de OZ (menos tipado al caso de negocio).

---

### 2.10 AMMs vía `ISimpleAMM` + mocks

**Decisión:** interfaz mínima `getAmountOut` / `swap`; tests con `MockAMM` (`x*y=k`, fee 0.3%).

**Por qué:**

- El módulo no depende del código del 06 para cerrar TDD.
- Después se puede adaptar `ISimpleAMM` a un par real.

**Tradeoff:** el fork actual despliega mocks en el fork; no arbitra Uniswap mainnet “de verdad” (eso sería integración v2).

---

### 2.11 Stack y estilo de la suite

| Decisión | Motivo |
|----------|--------|
| `pragma solidity 0.8.24` fijo | Suite + overflow checks nativos |
| Custom errors | Gas + claridad vs `require("…")` |
| Foundry TDD (fases 0–8) | Tests primero, fuzz ≥ 1000, invariantes |
| OpenZeppelin v5 | `ReentrancyGuard`, `Ownable2Step`, `SafeERC20` auditados |
| SafeERC20 (OZ) vs SafeTransfer propio del 07 | Consistencia OZ aquí; repay tipado con try/catch |

---

## 3. Lógica que sigue el sistema

### 3.1 Vista mental (una frase)

> El operador llama `execute` → el pool presta tokens al arb → el arb compra barato / vende caro → si sobra, manda profit al owner y aprueba el repay → el pool cobra `amount + fee` → fin. Si en cualquier punto falta plata o falla auth, **todo se deshace**.

### 3.2 Secuencia feliz (paso a paso)

```
1) Alguien llama AtomicArbitrage.execute(amount, params)
      params = abi.encode(ammBuy, ammSell, tokenB, minProfit)

2) Arb lee pool.token() y llama:
      flashLender.flashLoan(address(this), token, amount, params)
      → initiator = address(arb)

3) FlashLoanPool.flashLoan (nonReentrant):
      a. Checks: receiver ≠ 0, token ok, amount > 0, amount ≤ balance
      b. fee = amount * feeBps / 10_000
      c. Transfer amount → receiver (arb)
      d. Llama arb.onFlashLoan(initiator, token, amount, fee, data)
      e. Exige return == CALLBACK_SUCCESS
      f. transferFrom(arb, pool, amount + fee)  // repay
      g. Emit FlashLoan

4) Dentro de onFlashLoan (arb):
      a. Auth: msg.sender == flashLender
      b. Auth: initiator == address(this)
      c. Decode params
      d. Swap 1: token → tokenB en ammBuy
      e. Swap 2: tokenB → token en ammSell
      f. required = amount + fee
      g. Si balance < required o profit < minProfit → UnprofitableArbitrage
      h. Transfer profit → owner
      i. forceApprove(flashLender, required)
      j. return CALLBACK_SUCCESS
```

### 3.3 Caminos de fallo (qué protege cada uno)

| Situación | Error / efecto |
|-----------|----------------|
| Lender falso / EOA llama callback | `UntrustedLender` |
| Tercero inicia `flashLoan(arb, …)` | `InvalidInitiator` |
| Trade no cubre deuda / minProfit | `UnprofitableArbitrage` (tx completa revierte) |
| Borrower no aprueba repay | `LoanRepaymentFailed` |
| Magic value incorrecto | `CallbackFailed` |
| Reentrar `flashLoan` en el callback | `ReentrancyGuardReentrantCall` |
| Amount > liquidez | `AmountExceedsMaxLoan` |

### 3.4 Contabilidad del pool (invariante)

En tests de invariante se rastrea:

```
balance(pool) == ghostDeposited + ghostFeesEarned - ghostWithdrawn
```

- Un flash loan **exitoso** aumenta el balance en exactamente el **fee**.
- Un flash loan que **revierte** no cambia el balance (atomicidad).

### 3.5 Dónde vive cada pieza de lógica

| Pieza | Archivo |
|-------|---------|
| Prestar / cobrar / liquidez | `src/FlashLoanPool.sol` |
| Auth + swaps + profit | `src/AtomicArbitrage.sol` |
| `repayAmount` / `isProfitable` | `src/libraries/ArbitrageMath.sol` |
| AMM de prueba | `src/mocks/MockAMM.sol` |
| Diagramas de flujo | `doc/diagrama-flujo-ES.md`, `doc/flujograma-ES.md` |

---

## 4. ¿Se puede mejorar el gas de lo que existe?

**Sí**, pero hay que separar: (A) mejoras reales en **nuestros** contratos, (B) coste que viene de **AMMs externos** (casi todo el `execute` ~235k).

Baseline actual (medianas gas-report): `flashLoan` ~67k · `execute` ~235k · `deposit` ~57k. Detalle en [GAS-ES.md](./GAS-ES.md).

### 4.1 Ya aplicado (no “falta”; es el piso actual)

- `immutable` en pool y arb  
- Profit sin SSTORE  
- Custom errors  
- `BPS_DENOMINATOR` constant  
- `forceApprove` exacto  
- `optimizer_runs = 200`

### 4.2 Mejoras posibles (impacto vs riesgo)

| Idea | Ahorro esperado | Riesgo / tradeoff | ¿Vale la pena en v1? |
|------|-----------------|-------------------|----------------------|
| Cachear `token` local en `flashLoan` (ya se hace en parte) | Bajo | Ninguno | Ya razonable |
| `unchecked` en `amount + fee` tras checks | Muy bajo | Hay que probar overflow imposible | Opcional |
| SafeTransfer propio (estilo módulo 07) en vez de OZ SafeERC20 | Bajo–medio en paths | Cambia semántica de revert; reescribir tests | Solo si unificás la suite |
| Empaquetar `feeBps` en un slot con otro dato | Bajo en deploy | Hoy casi todo es immutable | Bajo interés |
| Quitar `Ownable2Step` → `Ownable` simple | Deploy más barato | Menos seguridad en transfer de ownership | No recomendado |
| `minOut` por hop en `params` | **Más** gas (checks + calldata) | Mejor MEV, peor gas | Seguridad > gas |
| `nonReentrant` en deposit/withdraw | **Más** gas en esos paths | Defensa extra | Opcional |
| Assembly en auth / decode | Bajo–medio | Legibilidad y auditoría | No prioritario en módulo didáctico |
| Permitir `transfer` directo del repay (pull pattern ya es estándar) | — | ERC-3156 espera pull del lender | Mantener pull |
| Integrar router real (Uniswap) | El gas lo domina el AMM | No es “opt del pool” | Fuera de alcance v1 |

### 4.3 Dónde está el “grueso” del gas

En `execute`, la mayor parte **no** es el pool: son **2 swaps + approves + transfers ERC-20**. Optimizar el pool ahorra kilogas; optimizar el path de arbitraje en producción es:

- menos hops,
- routers eficientes,
- calldata corta,
- y a veces private mempool (MEV), no micro-opts de Solidity.

### 4.4 Recomendación práctica

Para este módulo, el gas ya está en un buen punto **didáctico + seguro**.

Si mañana querés una mejora concreta y medible:

1. Snapshot actual (`forge snapshot --match-contract FlashLoanGasTest`).  
2. Aplicar **una** opt (ej. `unchecked` en `amount + fee` o cache extras).  
3. Volver a snapshot y anotar delta en `GAS-ES.md`.  
4. No tocar auth ni el orden “profit check → approve → pull”.

---

## 5. Mapa rápido “decisión → archivo → test”

| Decisión | Dónde se ve | Cómo se prueba |
|----------|-------------|----------------|
| ERC-3156 | `FlashLoanPool` / interfaces | `FlashLoanPool.t.sol` |
| Auth callback | `AtomicArbitrage.onFlashLoan` | `Unauthorized` + `CallbackSpoofAttack` |
| Atomic unprofitable | check + revert | `AtomicArbitrage.t.sol` fase 5 |
| Reentrancy | `nonReentrant` | `ReentrancyAttack.t.sol` |
| Impago | `_chargeRepayment` | `LoanDefaultAttack.t.sol` |
| Contabilidad liquidez | balance del pool | `test/invariant/` |
| Gas baseline | immutables / sin SSTORE profit | `doc/GAS-ES.md` + `test/gas/` |

---

## 6. Cómo leer el código (orden sugerido)

1. `doc/diagrama-flujo-ES.md` — foto mental del flujo.  
2. `FlashLoanPool.flashLoan` — lender.  
3. `AtomicArbitrage.execute` + `onFlashLoan` — borrower.  
4. `ArbitrageMath` — 10 líneas de deuda/profit.  
5. Un test feliz + un attack (`test_Attack_*`) — qué pasa cuando algo falla.

Si algo de este doc choca con el código, **manda el código** y actualizá este archivo.
