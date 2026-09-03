# Diagrama de flujo — Flash Loans & Atomic Arbitrage

Flujos de negocio **to-be** (v1). Ver también [flujograma.md](./flujograma.md) y [PLANIFICACION.md](./PLANIFICACION.md).

## 1. Ciclo de vida del sistema

```mermaid
flowchart TD
    Start([Inicio]) --> DeployP[Deploy FlashLoanPool token, feeBps]
    DeployP --> Fund[Owner deposita liquidez ERC-20]
    Fund --> DeployA[Deploy AtomicArbitrage lender, owner]
    DeployA --> Ready[Sistema listo]

    Ready --> Action{Acción}
    Action -->|execute rentable| Arb[Flash loan + swaps + profit]
    Action -->|execute no rentable| Rev[Revert UnprofitableArbitrage]
    Action -->|callback spoof| Auth[Revert UntrustedLender / InvalidInitiator]

    Arb --> Ready
    Rev --> Ready
    Auth --> Ready
```

## 2. Flujo ERC-3156 `flashLoan` (lender)

```mermaid
flowchart TD
    A([Borrower o AtomicArbitrage llama flashLoan]) --> B[nonReentrant ON]
    B --> C{token == token soportado?}
    C -->|No| E1[Revert UnsupportedToken]
    C -->|Sí| D{amount > 0?}
    D -->|No| E2[Revert ZeroAmount]
    D -->|Sí| F{amount <= maxFlashLoan?}
    F -->|No| E3[Revert AmountExceedsMaxLoan]
    F -->|Sí| G[fee = flashFee token, amount]
    G --> H[Interaction: safeTransfer receiver, amount]
    H --> I[onFlashLoan initiator=msg.sender, token, amount, fee, data]
    I --> J{return == CALLBACK_SUCCESS?}
    J -->|No| E4[Revert CallbackFailed]
    J -->|Sí| K[Interaction: transferFrom receiver, amount+fee]
    K --> L{pull OK?}
    L -->|No| E5[Revert LoanRepaymentFailed]
    L -->|Sí| M[Emit FlashLoan]
    M --> N[nonReentrant OFF]
    N --> O([Pool: liquidez + fee])
```

## 3. Flujo `onFlashLoan` (AtomicArbitrage)

```mermaid
flowchart TD
    A([Lender invoca onFlashLoan]) --> B{msg.sender == flashLender?}
    B -->|No| E1[Revert UntrustedLender]
    B -->|Sí| C{initiator == address this?}
    C -->|No| E2[Revert InvalidInitiator]
    C -->|Sí| D[Decode data: ammBuy, ammSell, tokenB, minProfit]
    D --> E[Approve + swap en ammBuy: token → tokenB]
    E --> F[Approve + swap en ammSell: tokenB → token]
    F --> G[required = amount + fee]
    G --> H[bal = balanceOf this, token]
    H --> I{bal >= required AND bal - required >= minProfit?}
    I -->|No| E3[Revert UnprofitableArbitrage]
    I -->|Sí| J[profit = bal - required]
    J --> K[safeTransfer token → owner, profit]
    K --> L[approve flashLender, required]
    L --> M[return CALLBACK_SUCCESS]
    M --> N([Lender cobra repay])
```

## 4. Flujo de execute (entrada del operador)

```mermaid
flowchart TD
    A([Owner/operador llama execute amount, params]) --> B[Codifica params si hace falta]
    B --> C[flashLender.flashLoan this, token, amount, params]
    C --> D{¿Callback y repay OK?}
    D -->|Revert| E([Tx abortada — sin pérdida de capital del pool])
    D -->|Sí| F[Emit ArbitrageExecuted]
    F --> G([Owner recibió profit; pool +fee])
```

`execute` no guarda el profit: el callback transfiere al `owner` immutable.

## 5. Flujo de swaps (round-trip entre dos AMMs)

```mermaid
flowchart LR
    subgraph P["Préstamo"]
        T0[Token T en AtomicArbitrage]
    end

    subgraph BUY["AMM barato"]
        S1[swap T → tokenB]
    end

    subgraph SELL["AMM caro"]
        S2[swap tokenB → T]
    end

    subgraph OUT["Cierre"]
        T1[Más T que amount+fee]
        T2[Repay lender]
        T3[Resto → owner]
    end

    T0 --> S1 --> S2 --> T1 --> T2 --> T3
```

Dirección del trade (ejemplo): el token prestado se vende donde está **sobrevalorado** y se recompra (vía intermediario) donde está **infravalorado**, o el camino inverso según qué reserva esté desbalanceada. Los params en `data` fijan `ammBuy` / `ammSell`.

## 6. Flujo unprofitable (garantía atómica)

```mermaid
flowchart TD
    A([Spread insuficiente o fee > edge]) --> B[Swaps se ejecutan en el callback]
    B --> C[bal < amount + fee]
    C --> D[Revert UnprofitableArbitrage]
    D --> E[EVM deshace transfers del callback]
    E --> F[flashLoan no completa el pull]
    F --> G[Toda la tx revierte]
    G --> H([Pool y attacker: mismos balances pre-tx])
```

No hay “préstamo a medias”: o se reembolsa con prima o no hubo préstamo efectivo.

## 7. Flujo de autenticación (callers no autorizados)

```mermaid
flowchart TD
    A([Llamada a onFlashLoan]) --> B{¿Quién llama?}
    B -->|FlashLoanPool real| C{initiator?}
    B -->|EOA / contrato tercero| D[Revert UntrustedLender]
    C -->|address AtomicArbitrage| E[Continúa swaps]
    C -->|otra address| F[Revert InvalidInitiator]
```

Un contrato no puede pedirle al pool un flash loan “en nombre” de `AtomicArbitrage` y esperar que el callback acredite a un initiator distinto: `initiator` es `msg.sender` del `flashLoan`, y debe ser `address(this)`.

## 8. Flujo de liquidez del pool (deposit / withdraw)

```mermaid
flowchart TD
    A([LP/owner]) --> B{Acción}
    B -->|deposit| C[Checks amount > 0]
    C --> D[Effects: ninguno de préstamo]
    D --> E[safeTransferFrom → pool]
    E --> F[Emit LiquidityDeposited]
    B -->|withdraw| G[Checks owner + amount <= balance ocioso]
    G --> H[safeTransfer → owner]
    H --> I[Emit LiquidityWithdrawn]
```

`maxFlashLoan` = balance actual del token en el pool (v1: no hay loans anidados).

## Leyenda

| Símbolo | Significado |
|---------|-------------|
| Rectángulo | Proceso / acción on-chain |
| Diamante | Decisión / validación |
| Óvalo | Inicio / fin |

## Orden CEI

| Paso | `flashLoan` (pool) | `onFlashLoan` (arb) |
|------|--------------------|---------------------|
| **Checks** | token, amount, maxLoan | lender, initiator |
| **Effects** | lock reentrancy | (sin SSTORE de profit) |
| **Interactions** | transfer out → callback → transferFrom repay | swaps AMM → transfer profit → approve |
| **Checks finales** | magic value + pull OK | `bal >= required` |
