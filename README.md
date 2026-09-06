# 08 — Flash Loans & Atomic Arbitrage

Proveedor de flash loans **ERC-3156** y ejecutor de arbitraje atómico entre dos AMMs. Solidity `0.8.24` + Foundry.

**Estado:** Fases **0–8** ✅ (módulo cerrado).

---

## Stack

| Capa | Tecnología |
|------|------------|
| Contratos | Solidity `0.8.24` |
| Tooling | Foundry (`forge` / `cast` / `anvil`) |
| Estándar | ERC-3156 (`IERC3156FlashLender` / `IERC3156FlashBorrower`) |
| Librerías | OpenZeppelin Contracts v5.2, forge-std |
| Seguridad | CEI, ReentrancyGuard, custom errors, SafeERC20 |

---

## Documentación

| Doc | Descripción |
|-----|-------------|
| [doc/README.md](./doc/README.md) | Índice de documentación |
| [doc/PLANIFICACION.md](./doc/PLANIFICACION.md) | Plan, fases TDD y criterios de aceptación |
| [doc/SWC-AUDIT.md](./doc/SWC-AUDIT.md) | Auditoría SWC-100–136 y mapeo a tests |
| [doc/GAS.md](./doc/GAS.md) | Gas report baseline y optimizaciones |
| [doc/diagrama-clases.md](./doc/diagrama-clases.md) | UML de contratos |
| [doc/diagrama-flujo.md](./doc/diagrama-flujo.md) | Flujos flash loan / callback / repay |
| [doc/flujograma.md](./doc/flujograma.md) | Flujograma operativo y pipeline TDD |

---

## Setup

```shell
export PATH="$HOME/.foundry/bin:$PATH"

forge install foundry-rs/forge-std@v1.16.2 --no-git
forge install OpenZeppelin/openzeppelin-contracts@v5.2.0 --no-git

forge build
forge test
forge snapshot --match-contract FlashLoanGasTest
```

Fork opcional:

```shell
# En `.env` (copiar desde `.env.example`)
MAINNET_RPC_URL=https://...
forge test --match-path test/fork/
```

---

## Deploy local (Anvil)

```shell
anvil
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

---

## Estructura

```
src/FlashLoanPool.sol
src/AtomicArbitrage.sol
src/libraries/ArbitrageMath.sol
src/mocks/MockERC20.sol
src/mocks/MockAMM.sol
test/FlashLoanPool.t.sol
test/AtomicArbitrage.t.sol
test/Unauthorized.t.sol
test/attack/ReentrancyAttack.t.sol
test/attack/CallbackSpoofAttack.t.sol
test/attack/LoanDefaultAttack.t.sol
test/fuzz/
test/invariant/
test/gas/FlashLoan.gas.t.sol
test/fork/Arbitrage.fork.t.sol
script/Deploy.s.sol
doc/
```

---

## Tests

`forge test` → **65 PASS** · **2 SKIP** (fork sin `MAINNET_RPC_URL`)
