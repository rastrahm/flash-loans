# Documentación — Module 08: Flash Loans & Atomic Arbitrage

Índice de la carpeta `doc/`. **Proyecto completo** (contratos + seguridad + gas).

| Documento | Contenido |
|-----------|-----------|
| [PLANIFICACION.md](./PLANIFICACION.md) | Objetivo, alcance, fases TDD, criterios |
| [SWC-AUDIT.md](./SWC-AUDIT.md) | Matriz SWC-100–136, mapeo a tests |
| [GAS.md](./GAS.md) | Baseline gas, optimizaciones, snapshot |
| [diagrama-clases.md](./diagrama-clases.md) | UML: lender ERC-3156, borrower, mocks AMM, tests |
| [diagrama-flujo.md](./diagrama-flujo.md) | Flujos flash loan / callback / repay |
| [flujograma.md](./flujograma.md) | Operativo, seguridad, pipeline TDD |

**Estado:** Fases **0–8** ✅ (módulo cerrado).

**Contratos:** `FlashLoanPool` · `AtomicArbitrage` · `ArbitrageMath` · mocks  
**Estándar:** ERC-3156 · **Tests:** `forge test` → **56 PASS** (+ 2 skip sin RPC)
