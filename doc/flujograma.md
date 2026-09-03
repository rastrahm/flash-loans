# Flujograma del proyecto — Flash Loans & Atomic Arbitrage

Flujograma operativo **to-be** (v1): setup → liquidez → execute → callback → repay → seguridad → TDD.

## 1. Flujograma maestro del sistema

```mermaid
flowchart TB
    subgraph SETUP["FASE 0 — Setup"]
        S1[Foundry 0.8.24 + interfaces ERC-3156] --> S2[Deploy FlashLoanPool]
        S2 --> S3[Deploy MockERC20 + MockAMM A/B]
        S3 --> S4[Desbalancear reservas A vs B]
        S4 --> S5[Deploy AtomicArbitrage]
        S5 --> S6[deposit liquidez al pool]
    end

    subgraph EXEC["FASE 1 — Execute"]
        E1[Operador llama execute] --> E2[pool.flashLoan receiver=arb]
        E2 --> E3{Validaciones lender}
        E3 -->|token/amount inválido| Ex1[UnsupportedToken / ZeroAmount / AmountExceedsMaxLoan]
        E3 -->|OK| E4[Transfer principal al arb]
    end

    subgraph CB["FASE 2 — Callback"]
        C1[onFlashLoan] --> C2{msg.sender == lender?}
        C2 -->|No| Cx1[UntrustedLender]
        C2 -->|Sí| C3{initiator == this?}
        C3 -->|No| Cx2[InvalidInitiator]
        C3 -->|Sí| C4[Swap AMM buy + Swap AMM sell]
        C4 --> C5{balance >= amount + fee?}
        C5 -->|No| Cx3[UnprofitableArbitrage]
        C5 -->|Sí| C6[Profit → owner]
        C6 --> C7[Approve repay]
        C7 --> C8[return CALLBACK_SUCCESS]
    end

    subgraph REPAY["FASE 3 — Cierre lender"]
        R1{magic value OK?}
        R1 -->|No| Rx1[CallbackFailed]
        R1 -->|Sí| R2[transferFrom amount+fee]
        R2 -->|Fallo| Rx2[LoanRepaymentFailed]
        R2 -->|OK| R3[Emit FlashLoan]
        R3 --> R4[Unlock nonReentrant]
    end

    SETUP --> EXEC
    EXEC --> CB
    CB --> REPAY
    REPAY --> END1([Pool +fee · owner +profit])
```

## 2. Flujograma detallado de rentabilidad

```mermaid
flowchart TD
    Start([Post-swaps en el callback]) --> B[required = amount + flashFee]
    B --> C[bal = IERC20.balanceOf this]
    C --> D{bal >= required?}
    D -->|No| F1[UnprofitableArbitrage]
    D -->|Sí| E{bal - required >= minProfit?}
    E -->|No| F1
    E -->|Sí| G[profit = bal - required]
    G --> H[Transfer profit a owner]
    H --> I([Aprobar required al lender])
    F1 --> J([Revert — atomicidad])
```

## 3. Flujograma de seguridad (reentrancy + CEI)

```mermaid
flowchart TD
    A[MaliciousBorrower recibe flashLoan] --> B[nonReentrant: ENTERED]
    B --> C[Callback: intenta flashLoan otra vez]
    C --> D{status == ENTERED?}
    D -->|Sí| E[Revert ReentrancyGuard]
    D -->|No| F[No debería ocurrir]
    E --> G([Liquidez del pool intacta])

    H[Callback no aprueba repay] --> I[transferFrom falla]
    I --> J[LoanRepaymentFailed]
    J --> K([Toda la tx revierte])
```

## 4. Flujograma unauthorized callback

```mermaid
flowchart TD
    A([Escenario de ataque]) --> B{Vector}
    B -->|Llamar onFlashLoan desde EOA| C[UntrustedLender]
    B -->|Lender fake con initiator = arb| D[UntrustedLender]
    B -->|flashLoan iniciado por tercero como initiator| E[InvalidInitiator]
    B -->|Receiver distinto que no es el arb| F[El arb no ejecuta swaps; pool exige repay al receiver]
    C --> Z([PASS Unauthorized.t.sol])
    D --> Z
    E --> Z
    F --> Z
```

`initiator` en ERC-3156 es quien llamó `flashLoan`. Si un tercero llama `pool.flashLoan(arb, ...)`, `initiator` sería el tercero y `AtomicArbitrage` revierte `InvalidInitiator`. Solo `execute()` (el propio contrato) es un initiator válido.

## 5. Flujograma del pipeline de desarrollo (TDD)

```mermaid
flowchart LR
    A[.cursorrules] --> B[Docs planificación]
    B --> C[Tests lender rojos]
    C --> D[FlashLoanPool]
    D --> E[Tests arb + mocks AMM rojos]
    E --> F[AtomicArbitrage + auth]
    F --> G[Unprofitable revert]
    G --> H[Unauthorized + reentrancy]
    H --> I[Fuzz + invariant liquidez]
    I --> J[Fork opcional + gas + NatSpec]
    J --> K([Módulo cerrado])
```

## 6. Matriz flujo ↔ función ↔ invariante

| Paso del flujograma | Función | Invariante / postcondición |
|---------------------|---------|----------------------------|
| Deposit liquidez | `FlashLoanPool.deposit` | `balance(pool)` ↑; `maxFlashLoan` ↑ |
| Cap del préstamo | `maxFlashLoan` | `<= IERC20.balanceOf(pool)` |
| Fee | `flashFee` | `amount * feeBps / 10_000` |
| Préstamo | `flashLoan` | Tras éxito: pool ≥ pre + fee |
| Callback auth | `onFlashLoan` | solo lender + initiator = this |
| Round-trip | `_swapRoundTrip` | token prestado vuelve al arb |
| Profit | `_payProfit` | owner ↑; **sin** SSTORE de acumulado |
| No rentable | `onFlashLoan` | revert; balances pre-tx |
| Callback falso | `onFlashLoan` | `UntrustedLender` / `InvalidInitiator` |
| Reentrada | `flashLoan` | segunda llamada revierte |
| Repay | `transferFrom` | `LoanRepaymentFailed` si allowance/balance cortos |

## 7. Flujograma de dos AMMs (imbalance de test)

```mermaid
flowchart TD
    M0[MockAMM A: T cara / tokenB barata] --> M1[MockAMM B: T barata / tokenB cara]
    M1 --> M2[execute amount]
    M2 --> M3[Pedir T al pool]
    M3 --> M4[Comprar tokenB donde rinde más]
    M4 --> M5[Vender tokenB donde T rinde más]
    M5 --> M6{¿T final > amount + fee?}
    M6 -->|Sí| M7[PASS AtomicArbitrage.t.sol]
    M6 -->|No| M8[Ajustar reservas del mock / bajar fee]
```

Las reservas se setean en `setUp()` para que el camino A→B sea **determinísticamente** rentable en el test feliz y **no** rentable en el test de revert.

## 8. Cómo leer estos diagramas

1. **Setup**: pool con liquidez, dos AMMs con precios distintos, arb apuntando al lender.
2. **Execute → flashLoan**: el capital sale del pool solo dentro de una tx que debe cerrar con repay.
3. **Callback**: autenticación primero; swaps después; profit en transfer directo; luego approve.
4. **Cierre**: magic value + `transferFrom`; si algo falla, **todo** revierte (incluido el profit).
5. **TDD**: tests rojos del lender → pool → tests del arb → auth/unprofitable → fuzz → cierre.
