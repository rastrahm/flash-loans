# 08 — Flash Loans & Atomic Arbitrage

Proveedor de flash loans **ERC-3156** y ejecutor de arbitraje atómico entre dos AMMs. Solidity `0.8.24` + Foundry.

**Estado:** Fase **3** ✅ (tests TDD arb en rojo). Fase 4: `onFlashLoan` + swaps + profit.

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

## Estructura (fase 3)

```
src/FlashLoanPool.sol              # 20 PASS
src/AtomicArbitrage.sol            # esqueleto TDD (NotImplemented)
src/mocks/MockERC20.sol
src/mocks/MockAMM.sol              # x*y=k fee 0.3%, reservas seteables
test/FlashLoanPool.t.sol
test/AtomicArbitrage.t.sol         # 5 PASS / 3 FAIL (execute)
test/helpers/FlashBorrowers.sol
doc/
```

Pendiente: lógica de `AtomicArbitrage` (fase 4).
