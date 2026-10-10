> 🌐 **English** · [Español](./flujograma-ES.md)

# Project flowchart — Flash Loans & Atomic Arbitrage

Operational **to-be** flowchart (v1): setup → liquidity → execute → callback → repay → security → TDD.

## 1. Master system flowchart

```mermaid
flowchart TB
    subgraph SETUP["PHASE 0 — Setup"]
        S1[Foundry 0.8.24 + ERC-3156 interfaces] --> S2[Deploy FlashLoanPool]
        S2 --> S3[Deploy MockERC20 + MockAMM A/B]
        S3 --> S4[Imbalance reserves A vs B]
        S4 --> S5[Deploy AtomicArbitrage]
        S5 --> S6[deposit liquidity into the pool]
    end

    subgraph EXEC["PHASE 1 — Execute"]
        E1[Operator calls execute] --> E2[pool.flashLoan receiver=arb]
        E2 --> E3{Lender validations}
        E3 -->|invalid token/amount| Ex1[UnsupportedToken / ZeroAmount / AmountExceedsMaxLoan]
        E3 -->|OK| E4[Transfer principal to the arb]
    end

    subgraph CB["PHASE 2 — Callback"]
        C1[onFlashLoan] --> C2{msg.sender == lender?}
        C2 -->|No| Cx1[UntrustedLender]
        C2 -->|Yes| C3{initiator == this?}
        C3 -->|No| Cx2[InvalidInitiator]
        C3 -->|Yes| C4[Swap AMM buy + Swap AMM sell]
        C4 --> C5{balance >= amount + fee?}
        C5 -->|No| Cx3[UnprofitableArbitrage]
        C5 -->|Yes| C6[Profit → owner]
        C6 --> C7[Approve repay]
        C7 --> C8[return CALLBACK_SUCCESS]
    end

    subgraph REPAY["PHASE 3 — Lender settlement"]
        R1{magic value OK?}
        R1 -->|No| Rx1[CallbackFailed]
        R1 -->|Yes| R2[transferFrom amount+fee]
        R2 -->|Failure| Rx2[LoanRepaymentFailed]
        R2 -->|OK| R3[Emit FlashLoan]
        R3 --> R4[Unlock nonReentrant]
    end

    SETUP --> EXEC
    EXEC --> CB
    CB --> REPAY
    REPAY --> END1([Pool +fee · owner +profit])
```

## 2. Detailed profitability flowchart

```mermaid
flowchart TD
    Start([Post-swaps in the callback]) --> B[required = amount + flashFee]
    B --> C[bal = IERC20.balanceOf this]
    C --> D{bal >= required?}
    D -->|No| F1[UnprofitableArbitrage]
    D -->|Yes| E{bal - required >= minProfit?}
    E -->|No| F1
    E -->|Yes| G[profit = bal - required]
    G --> H[Transfer profit to owner]
    H --> I([Approve required to the lender])
    F1 --> J([Revert — atomicity])
```

## 3. Security flowchart (reentrancy + CEI)

```mermaid
flowchart TD
    A[MaliciousBorrower receives flashLoan] --> B[nonReentrant: ENTERED]
    B --> C[Callback: tries flashLoan again]
    C --> D{status == ENTERED?}
    D -->|Yes| E[Revert ReentrancyGuard]
    D -->|No| F[Should never happen]
    E --> G([Pool liquidity intact])

    H[Callback does not approve repay] --> I[transferFrom fails]
    I --> J[LoanRepaymentFailed]
    J --> K([The whole tx reverts])
```

## 4. Unauthorized callback flowchart

```mermaid
flowchart TD
    A([Attack scenario]) --> B{Vector}
    B -->|Call onFlashLoan from an EOA| C[UntrustedLender]
    B -->|Fake lender with initiator = arb| D[UntrustedLender]
    B -->|flashLoan started by a third party as initiator| E[InvalidInitiator]
    B -->|Different receiver that is not the arb| F["The arb runs no swaps; the pool demands repay from the receiver"]
    C --> Z([PASS Unauthorized.t.sol])
    D --> Z
    E --> Z
    F --> Z
```

In ERC-3156, `initiator` is whoever called `flashLoan`. If a third party calls `pool.flashLoan(arb, ...)`, `initiator` would be that third party and `AtomicArbitrage` reverts with `InvalidInitiator`. Only `execute()` (the contract itself) is a valid initiator.

## 5. Development pipeline flowchart (TDD)

```mermaid
flowchart LR
    A[.cursorrules] --> B[Planning docs]
    B --> C[Red lender tests]
    C --> D[FlashLoanPool]
    D --> E[Red arb + AMM mock tests]
    E --> F[AtomicArbitrage + auth]
    F --> G[Unprofitable revert]
    G --> H[Unauthorized + reentrancy]
    H --> I[Fuzz + liquidity invariant]
    I --> J[Optional fork + gas + NatSpec]
    J --> K([Module closed])
```

## 6. Flow ↔ function ↔ invariant matrix

| Flowchart step | Function | Invariant / postcondition |
|---------------------|---------|----------------------------|
| Deposit liquidity | `FlashLoanPool.deposit` | `balance(pool)` ↑; `maxFlashLoan` ↑ |
| Loan cap | `maxFlashLoan` | `<= IERC20.balanceOf(pool)` |
| Fee | `flashFee` | `amount * feeBps / 10_000` |
| Loan | `flashLoan` | On success: pool ≥ pre + fee |
| Callback auth | `onFlashLoan` | only lender + initiator = this |
| Round-trip | `_swapRoundTrip` | borrowed token returns to the arb |
| Profit | `_payProfit` | owner ↑; **no** SSTORE of accumulated profit |
| Unprofitable | `onFlashLoan` | revert; pre-tx balances |
| Fake callback | `onFlashLoan` | `UntrustedLender` / `InvalidInitiator` |
| Reentrancy | `flashLoan` | second call reverts |
| Repay | `transferFrom` | `LoanRepaymentFailed` if allowance/balance is short |

## 7. Two-AMM flowchart (test imbalance)

```mermaid
flowchart TD
    M0[MockAMM A: T expensive / tokenB cheap] --> M1[MockAMM B: T cheap / tokenB expensive]
    M1 --> M2[execute amount]
    M2 --> M3[Borrow T from the pool]
    M3 --> M4[Buy tokenB where it yields more]
    M4 --> M5[Sell tokenB where T yields more]
    M5 --> M6{Final T > amount + fee?}
    M6 -->|Yes| M7[PASS AtomicArbitrage.t.sol]
    M6 -->|No| M8[Adjust mock reserves / lower fee]
```

Reserves are set in `setUp()` so that the A→B path is **deterministically** profitable in the happy-path test and **not** profitable in the revert test.

## 8. How to read these diagrams

1. **Setup**: pool with liquidity, two AMMs with different prices, arb pointing to the lender.
2. **Execute → flashLoan**: capital leaves the pool only inside a tx that must close with a repay.
3. **Callback**: authentication first; swaps next; profit via direct transfer; then approve.
4. **Settlement**: magic value + `transferFrom`; if anything fails, **everything** reverts (including the profit).
5. **TDD**: red lender tests → pool → arb tests → auth/unprofitable → fuzz → close-out.
