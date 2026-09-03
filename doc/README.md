# Documentación — Module 08: Flash Loans & Atomic Arbitrage

Índice de la carpeta `doc/`. Diseño **to-be** previo a la implementación (TDD).

| Documento | Contenido |
|-----------|-----------|
| [PLANIFICACION.md](./PLANIFICACION.md) | Objetivo, alcance, fases TDD, criterios de aceptación |
| [diagrama-clases.md](./diagrama-clases.md) | UML: lender ERC-3156, borrower, mocks AMM, tests |
| [diagrama-flujo.md](./diagrama-flujo.md) | Flujos flash loan, callback, swaps atómicos, reembolsos |
| [flujograma.md](./flujograma.md) | Operativo, seguridad, unprofitable revert, pipeline TDD |

**Estado:** Fase **0** — planificación y diagramas (contratos aún no implementados).

**Contratos previstos:** `FlashLoanPool` · `AtomicArbitrage` · mocks AMM  
**Estándar:** ERC-3156 (`IERC3156FlashLender` / `IERC3156FlashBorrower`)
