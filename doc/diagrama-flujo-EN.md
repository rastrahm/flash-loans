> 🌐 **English** · [Español](./diagrama-flujo-ES.md)

# Flow diagram — Flash Loans & Atomic Arbitrage

**To-be** business flows (v1). See also [flujograma-EN.md](./flujograma-EN.md) and [PLANIFICACION-EN.md](./PLANIFICACION-EN.md).

## 1. System lifecycle

```mermaid
flowchart TD
    Start([Start]) --> DeployP[Deploy FlashLoanPool token, feeBps]
    DeployP --> Fund[Owner deposits ERC-20 liquidity]
    Fund --> DeployA[Deploy AtomicArbitrage lender, owner]
    DeployA --> Ready[System ready]

    Ready --> Action{Action}
    Action -->|profitable execute| Arb[Flash loan + swaps + profit]
    Action -->|unprofitable execute| Rev[Revert UnprofitableArbitrage]
    Action -->|spoofed callback| Auth[Revert UntrustedLender / InvalidInitiator]

    Arb --> Ready
    Rev --> Ready
    Auth --> Ready
```

## 2. ERC-3156 `flashLoan` flow (lender)

```mermaid
flowchart TD
    A([Borrower or AtomicArbitrage calls flashLoan]) --> B[nonReentrant ON]
    B --> C{token == supported token?}
    C -->|No| E1[Revert UnsupportedToken]
    C -->|Yes| D{amount > 0?}
    D -->|No| E2[Revert ZeroAmount]
    D -->|Yes| F{amount <= maxFlashLoan?}
    F -->|No| E3[Revert AmountExceedsMaxLoan]
    F -->|Yes| G[fee = flashFee token, amount]
    G --> H[Interaction: safeTransfer receiver, amount]
    H --> I[onFlashLoan initiator=msg.sender, token, amount, fee, data]
    I --> J{return == CALLBACK_SUCCESS?}
    J -->|No| E4[Revert CallbackFailed]
    J -->|Yes| K[Interaction: transferFrom receiver, amount+fee]
    K --> L{pull OK?}
    L -->|No| E5[Revert LoanRepaymentFailed]
    L -->|Yes| M[Emit FlashLoan]
    M --> N[nonReentrant OFF]
    N --> O([Pool: liquidity + fee])
```

## 3. `onFlashLoan` flow (AtomicArbitrage)

```mermaid
flowchart TD
    A([Lender invokes onFlashLoan]) --> B{msg.sender == flashLender?}
    B -->|No| E1[Revert UntrustedLender]
    B -->|Yes| C{initiator == address this?}
    C -->|No| E2[Revert InvalidInitiator]
    C -->|Yes| D[Decode data: ammBuy, ammSell, tokenB, minProfit]
    D --> E[Approve + swap on ammBuy: token → tokenB]
    E --> F[Approve + swap on ammSell: tokenB → token]
    F --> G[required = amount + fee]
    G --> H[bal = balanceOf this, token]
    H --> I{bal >= required AND bal - required >= minProfit?}
    I -->|No| E3[Revert UnprofitableArbitrage]
    I -->|Yes| J[profit = bal - required]
    J --> K[safeTransfer token → owner, profit]
    K --> L[approve flashLender, required]
    L --> M[return CALLBACK_SUCCESS]
    M --> N([Lender collects repayment])
```

## 4. Execute flow (operator entry point)

```mermaid
flowchart TD
    A([Owner/operator calls execute amount, params]) --> B[Encode params if needed]
    B --> C[flashLender.flashLoan this, token, amount, params]
    C --> D{Callback and repay OK?}
    D -->|Revert| E([Tx aborted — no loss of pool capital])
    D -->|Yes| F[Emit ArbitrageExecuted]
    F --> G([Owner received profit; pool +fee])
```

`execute` does not store the profit: the callback transfers it to the immutable `owner`.

## 5. Swap flow (round-trip between two AMMs)

```mermaid
flowchart LR
    subgraph P["Loan"]
        T0[Token T in AtomicArbitrage]
    end

    subgraph BUY["Cheap AMM"]
        S1[swap T → tokenB]
    end

    subgraph SELL["Expensive AMM"]
        S2[swap tokenB → T]
    end

    subgraph OUT["Settlement"]
        T1[More T than amount+fee]
        T2[Repay lender]
        T3[Remainder → owner]
    end

    T0 --> S1 --> S2 --> T1 --> T2 --> T3
```

Trade direction (example): the borrowed token is sold where it is **overvalued** and bought back (via an intermediate token) where it is **undervalued**, or the reverse path depending on which reserve is imbalanced. The params in `data` set `ammBuy` / `ammSell`.

## 6. Unprofitable flow (atomic guarantee)

```mermaid
flowchart TD
    A([Insufficient spread or fee > edge]) --> B[Swaps execute in the callback]
    B --> C[bal < amount + fee]
    C --> D[Revert UnprofitableArbitrage]
    D --> E[EVM undoes the callback transfers]
    E --> F[flashLoan does not complete the pull]
    F --> G[The whole tx reverts]
    G --> H([Pool and attacker: same balances as pre-tx])
```

There is no "half loan": either it is repaid with the premium or no effective loan ever happened.

## 7. Authentication flow (unauthorized callers)

```mermaid
flowchart TD
    A([Call to onFlashLoan]) --> B{Who is calling?}
    B -->|Real FlashLoanPool| C{initiator?}
    B -->|EOA / third-party contract| D[Revert UntrustedLender]
    C -->|AtomicArbitrage address| E[Continue swaps]
    C -->|other address| F[Revert InvalidInitiator]
```

A contract cannot ask the pool for a flash loan "on behalf of" `AtomicArbitrage` and expect the callback to credit a different initiator: `initiator` is the `msg.sender` of `flashLoan`, and it must be `address(this)`.

## 8. Pool liquidity flow (deposit / withdraw)

```mermaid
flowchart TD
    A([LP/owner]) --> B{Action}
    B -->|deposit| C[Checks amount > 0]
    C --> D[Effects: no loan effects]
    D --> E[safeTransferFrom → pool]
    E --> F[Emit LiquidityDeposited]
    B -->|withdraw| G[Checks owner + amount <= idle balance]
    G --> H[safeTransfer → owner]
    H --> I[Emit LiquidityWithdrawn]
```

`maxFlashLoan` = current token balance in the pool (v1: no nested loans).

## Legend

| Symbol | Meaning |
|---------|-------------|
| Rectangle | On-chain process / action |
| Diamond | Decision / validation |
| Oval | Start / end |

## CEI order

| Step | `flashLoan` (pool) | `onFlashLoan` (arb) |
|------|--------------------|---------------------|
| **Checks** | token, amount, maxLoan | lender, initiator |
| **Effects** | reentrancy lock | (no profit SSTORE) |
| **Interactions** | transfer out → callback → transferFrom repay | AMM swaps → transfer profit → approve |
| **Final checks** | magic value + pull OK | `bal >= required` |
