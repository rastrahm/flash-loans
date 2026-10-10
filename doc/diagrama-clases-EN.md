> 🌐 **English** · [Español](./diagrama-clases-ES.md)

# Class diagram — Flash Loans & Atomic Arbitrage

**To-be** structural model (module 08). Contracts, ERC-3156 interfaces, mocks, and tests.

## 1. Main diagram (UML / Mermaid)

```mermaid
classDiagram
    direction TB

    class IERC20 {
        <<interface>>
        +balanceOf(address) uint256
        +transfer(address, uint256) bool
        +transferFrom(address, address, uint256) bool
        +approve(address, uint256) bool
        +allowance(address, address) uint256
    }

    class IERC3156FlashLender {
        <<interface ERC-3156>>
        +maxFlashLoan(address token) uint256
        +flashFee(address token, uint256 amount) uint256
        +flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount, bytes data) bool
    }

    class IERC3156FlashBorrower {
        <<interface ERC-3156>>
        +onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes data) bytes32
    }

    class ISimpleAMM {
        <<interface>>
        +token0() address
        +token1() address
        +getAmountOut(uint256 amountIn, address tokenIn) uint256
        +swap(address tokenIn, uint256 amountIn, uint256 minOut, address to) uint256
    }

    class IFlashLoanPool {
        <<interface>>
        +deposit(uint256 amount)
        +withdraw(uint256 amount)
        +token() address
        +feeBps() uint256
    }

    class IAtomicArbitrage {
        <<interface>>
        +execute(uint256 amount, bytes params)
        +flashLender() address
        +owner() address
    }

    class FlashLoanPool {
        +address immutable token
        +uint256 feeBps
        +maxFlashLoan(address) uint256
        +flashFee(address, uint256) uint256
        +flashLoan(receiver, token, amount, data) bool
        +deposit(uint256)
        +withdraw(uint256)
    }

    class AtomicArbitrage {
        +address immutable flashLender
        +address immutable owner
        +execute(uint256 amount, bytes params)
        +onFlashLoan(initiator, token, amount, fee, data) bytes32
        -_swapRoundTrip(bytes data) uint256
        -_payProfit(address token, uint256 profit)
    }

    class ArbitrageMath {
        <<library>>
        +repayAmount(uint256 amount, uint256 fee) uint256
        +isProfitable(uint256 balance, uint256 required, uint256 minProfit) bool
    }

    class MockAMM {
        +address token0
        +address token1
        +uint256 reserve0
        +uint256 reserve1
        +setReserves(uint256, uint256)
        +swap(address, uint256, uint256, address) uint256
        +getAmountOut(uint256, address) uint256
    }

    class ReentrancyGuard {
        <<OZ>>
        #nonReentrant()
    }

    class Ownable2Step {
        <<OZ>>
        +owner() address
        +transferOwnership(address)
    }

    class SafeERC20 {
        <<OZ library>>
        +safeTransfer(IERC20, address, uint256)
        +safeTransferFrom(IERC20, address, address, uint256)
        +safeIncreaseAllowance(IERC20, address, uint256)
    }

    IERC3156FlashLender <|.. FlashLoanPool
    IFlashLoanPool <|.. FlashLoanPool
    ReentrancyGuard <|-- FlashLoanPool
    Ownable2Step <|-- FlashLoanPool

    IERC3156FlashBorrower <|.. AtomicArbitrage
    IAtomicArbitrage <|.. AtomicArbitrage

    FlashLoanPool ..> IERC3156FlashBorrower : onFlashLoan
    FlashLoanPool ..> IERC20 : liquidity token
    FlashLoanPool ..> SafeERC20 : transfer / pull

    AtomicArbitrage ..> IERC3156FlashLender : flashLoan
    AtomicArbitrage ..> ISimpleAMM : swap x2
    AtomicArbitrage ..> ArbitrageMath : profit check
    AtomicArbitrage ..> IERC20
    AtomicArbitrage ..> SafeERC20

    MockAMM ..|> ISimpleAMM
    MockAMM ..> IERC20 : reserves
```

## 2. Errors and events

```mermaid
classDiagram
    direction LR

    class FlashLoanErrors {
        <<errors>>
        UnsupportedToken()
        AmountExceedsMaxLoan()
        CallbackFailed()
        ZeroAmount()
        LoanRepaymentFailed()
    }

    class ArbitrageErrors {
        <<errors>>
        InvalidInitiator()
        UntrustedLender()
        UnprofitableArbitrage()
        LoanRepaymentFailed()
    }

    class FlashLoanEvents {
        <<events>>
        FlashLoan(address indexed, address indexed, uint256, uint256)
        LiquidityDeposited(address indexed, uint256)
        LiquidityWithdrawn(address indexed, uint256)
    }

    class ArbitrageEvents {
        <<events>>
        ArbitrageExecuted(address indexed token, uint256 amount, uint256 profit)
    }

    FlashLoanPool ..> FlashLoanErrors : revert
    FlashLoanPool ..> FlashLoanEvents : emit
    AtomicArbitrage ..> ArbitrageErrors : revert
    AtomicArbitrage ..> ArbitrageEvents : emit
```

## 3. Tests and actors

```mermaid
classDiagram
    direction LR

    class FlashLoanPool
    class AtomicArbitrage
    class MockERC20
    class MockAMM
    class FlashLoanPoolTest
    class AtomicArbitrageTest
    class UnauthorizedTest
    class FlashLoanFuzzTest
    class MaliciousBorrower {
        <<attack>>
        +onFlashLoan() bytes32
        +reenterLender()
    }
    class FakeInitiator {
        <<attack>>
        +onFlashLoan() bytes32
    }

    MockERC20 ..|> IERC20
    FlashLoanPoolTest --> FlashLoanPool
    FlashLoanPoolTest --> MockERC20
    AtomicArbitrageTest --> AtomicArbitrage
    AtomicArbitrageTest --> FlashLoanPool
    AtomicArbitrageTest --> MockAMM
    UnauthorizedTest --> AtomicArbitrage
    UnauthorizedTest --> FakeInitiator
    FlashLoanFuzzTest --> FlashLoanPool
    MaliciousBorrower --> FlashLoanPool
```

## 4. Responsibilities

| Artifact | Role |
|-----------|-----|
| `FlashLoanPool` | Holds liquidity, lends ERC-20, charges the fee, anti-reentrancy lock |
| `AtomicArbitrage` | Initiates the loan, authenticates the callback, swaps, repays, sends profit to owner |
| `ArbitrageMath` | Stateless `repayAmount` and `isProfitable` |
| `ISimpleAMM` / `MockAMM` | token0/token1 pair with settable reserves to create an imbalance |
| `ReentrancyGuard` | Prevents reentering `flashLoan` during the callback |
| `Ownable2Step` | Pool liquidity admin (deposit/withdraw v1) |
| `SafeERC20` | Transfers and allowance for the borrowed token |
| `MaliciousBorrower` | Attempts to reenter or not repay the loan |

## 5. Dependencies (summary)

```
FlashLoanPool
  ├── inherits   → ReentrancyGuard, Ownable2Step
  ├── implements → IERC3156FlashLender, IFlashLoanPool
  ├── uses       → SafeERC20
  ├── calls      → IERC3156FlashBorrower.onFlashLoan
  ├── emits      → FlashLoan / LiquidityDeposited / LiquidityWithdrawn
  └── reverts    → UnsupportedToken / AmountExceedsMaxLoan / CallbackFailed /
                    ZeroAmount / LoanRepaymentFailed

AtomicArbitrage
  ├── implements → IERC3156FlashBorrower, IAtomicArbitrage
  ├── immutables → flashLender, owner
  ├── uses       → ArbitrageMath, SafeERC20, ISimpleAMM (×2)
  ├── calls      → IERC3156FlashLender.flashLoan
  ├── emits      → ArbitrageExecuted
  └── reverts    → InvalidInitiator / UntrustedLender /
                    UnprofitableArbitrage / LoanRepaymentFailed

MockAMM
  ├── implements → ISimpleAMM
  └── setReserves → creates an artificial spread between AMM A and AMM B
```

## 6. Solidity layout

### FlashLoanPool

1. Imports / interfaces / libraries  
2. Contract `FlashLoanPool`  
3. Immutables (`token`) + state (`feeBps`)  
4. Events → Errors → Modifiers (inherited `nonReentrant`)  
5. External: `maxFlashLoan`, `flashFee`, `flashLoan`, `deposit`, `withdraw`  
6. Internal: `_chargeRepayment`

### AtomicArbitrage

1. Imports  
2. Immutables (`flashLender`, `owner`) — **no** profits mapping  
3. Events → Errors  
4. External: `execute`, `onFlashLoan`  
5. Internal: `_swapRoundTrip`, `_payProfit` (only `safeTransfer` to owner)

## 7. Relationship with modules 06 and 07

```mermaid
classDiagram
    direction LR

    class TokenSwapPair {
        <<module 06>>
        +swap()
        +getReserves()
    }

    class LiquidityPool {
        <<module 07>>
        +deposit()
        +withdraw()
    }

    class FlashLoanPool {
        <<module 08>>
        +flashLoan()
    }

    class AtomicArbitrage {
        <<module 08>>
        +onFlashLoan()
    }

    note for TokenSwapPair "AMM x*y=k\nswap counterparty in prod"
    note for FlashLoanPool "ERC-3156 lendable liquidity"
    note for AtomicArbitrage "Zero-capital arb\natomic + fee"

    AtomicArbitrage ..> FlashLoanPool : borrow
    AtomicArbitrage ..> TokenSwapPair : future swap via ISimpleAMM
```

In v1 the tests use `MockAMM`. A later integration can adapt `ISimpleAMM` to module 06's `TokenSwapPair`. Module 07 is not required for the flash loan.
