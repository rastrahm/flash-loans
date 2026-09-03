# Diagrama de clases — Flash Loans & Atomic Arbitrage

Modelo estructural **to-be** (módulo 08). Contratos, interfaces ERC-3156, mocks y tests.

## 1. Diagrama principal (UML / Mermaid)

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
    MockAMM ..> IERC20 : reservas
```

## 2. Errores y eventos

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

## 3. Tests y actores

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

## 4. Responsabilidades

| Artefacto | Rol |
|-----------|-----|
| `FlashLoanPool` | Custodia liquidez, presta ERC-20, cobra fee, lock anti-reentrada |
| `AtomicArbitrage` | Inicia el préstamo, autentica callback, swaps, repay, profit a owner |
| `ArbitrageMath` | `repayAmount` e `isProfitable` sin estado |
| `ISimpleAMM` / `MockAMM` | Par token0/token1 con reservas seteables para imbalance |
| `ReentrancyGuard` | Impide reentrar `flashLoan` durante el callback |
| `Ownable2Step` | Admin de liquidez del pool (deposit/withdraw v1) |
| `SafeERC20` | Transfers y allowance del token prestado |
| `MaliciousBorrower` | Intenta reentrar o no devolver el préstamo |

## 5. Dependencias (resumen)

```
FlashLoanPool
  ├── hereda     → ReentrancyGuard, Ownable2Step
  ├── implementa → IERC3156FlashLender, IFlashLoanPool
  ├── usa        → SafeERC20
  ├── llama      → IERC3156FlashBorrower.onFlashLoan
  ├── emite      → FlashLoan / LiquidityDeposited / LiquidityWithdrawn
  └── revierte   → UnsupportedToken / AmountExceedsMaxLoan / CallbackFailed /
                    ZeroAmount / LoanRepaymentFailed

AtomicArbitrage
  ├── implementa → IERC3156FlashBorrower, IAtomicArbitrage
  ├── immutables → flashLender, owner
  ├── usa        → ArbitrageMath, SafeERC20, ISimpleAMM (×2)
  ├── llama      → IERC3156FlashLender.flashLoan
  ├── emite      → ArbitrageExecuted
  └── revierte   → InvalidInitiator / UntrustedLender /
                    UnprofitableArbitrage / LoanRepaymentFailed

MockAMM
  ├── implementa → ISimpleAMM
  └── setReserves → crea spread artificial entre AMM A y AMM B
```

## 6. Layout Solidity

### FlashLoanPool

1. Imports / interfaces / libraries  
2. Contract `FlashLoanPool`  
3. Immutables (`token`) + state (`feeBps`)  
4. Events → Errors → Modifiers (`nonReentrant` heredado)  
5. External: `maxFlashLoan`, `flashFee`, `flashLoan`, `deposit`, `withdraw`  
6. Internal: `_chargeRepayment`

### AtomicArbitrage

1. Imports  
2. Immutables (`flashLender`, `owner`) — **sin** mapping de profits  
3. Events → Errors  
4. External: `execute`, `onFlashLoan`  
5. Internal: `_swapRoundTrip`, `_payProfit` (solo `safeTransfer` a owner)

## 7. Relación con módulos 06 y 07

```mermaid
classDiagram
    direction LR

    class TokenSwapPair {
        <<módulo 06>>
        +swap()
        +getReserves()
    }

    class LiquidityPool {
        <<módulo 07>>
        +deposit()
        +withdraw()
    }

    class FlashLoanPool {
        <<módulo 08>>
        +flashLoan()
    }

    class AtomicArbitrage {
        <<módulo 08>>
        +onFlashLoan()
    }

    note for TokenSwapPair "AMM x*y=k\ncontraparte de swap en prod"
    note for FlashLoanPool "Liquidez prestable ERC-3156"
    note for AtomicArbitrage "Zero-capital arb\natómico + fee"

    AtomicArbitrage ..> FlashLoanPool : borrow
    AtomicArbitrage ..> TokenSwapPair : swap futuro via ISimpleAMM
```

En v1 los tests usan `MockAMM`. Una integración posterior puede adaptar `ISimpleAMM` a `TokenSwapPair` del módulo 06. El módulo 07 no es requerido para el flash loan.
