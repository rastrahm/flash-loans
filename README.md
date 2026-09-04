# 08 — Flash Loans & Atomic Arbitrage

Proveedor de flash loans **ERC-3156** y ejecutor de arbitraje atómico entre dos AMMs. Solidity `0.8.24` + Foundry.

**Estado:** Fase **7** ✅ (fuzz + invariant). Fase 8: fork opcional + gas snapshot + NatSpec.

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
```

---

## Estructura (fase 7)

```
src/FlashLoanPool.sol
src/AtomicArbitrage.sol
test/FlashLoanPool.t.sol
test/AtomicArbitrage.t.sol
test/Unauthorized.t.sol
test/fuzz/FlashLoan.fuzz.t.sol           # 8 PASS (1000 runs)
test/invariant/FlashLoanHandler.sol
test/invariant/FlashLoan.invariant.t.sol # 4 PASS (256 runs)
doc/
```

Pendiente: fork / gas / NatSpec (fase 8).
