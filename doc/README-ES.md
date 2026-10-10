> 🌐 [English](./README-EN.md) · **Español**

# Documentación — Module 08: Flash Loans & Atomic Arbitrage

Índice de la carpeta `doc/`. **Proyecto completo** (contratos + seguridad + gas).

| Documento | Contenido |
|-----------|-----------|
| [PLANIFICACION-ES.md](./PLANIFICACION-ES.md) | Objetivo, alcance, fases TDD, criterios |
| [DECISIONES-Y-LOGICA-ES.md](./DECISIONES-Y-LOGICA-ES.md) | Decisiones técnicas, flujo lógico, mejoras de gas |
| [SWC-AUDIT-ES.md](./SWC-AUDIT-ES.md) | Matriz SWC-100–136, mapeo a tests |
| [GAS-ES.md](./GAS-ES.md) | Baseline gas, optimizaciones, snapshot |
| [SOCIAL-ES.md](./SOCIAL-ES.md) | Borradores LinkedIn / X |
| [diagrama-clases-ES.md](./diagrama-clases-ES.md) | UML: lender ERC-3156, borrower, mocks AMM, tests |
| [diagrama-flujo-ES.md](./diagrama-flujo-ES.md) | Flujos flash loan / callback / repay |
| [flujograma-ES.md](./flujograma-ES.md) | Operativo, seguridad, pipeline TDD |

**Portfolio:** [`../portfolio/index.html`](../portfolio/index.html) (ES/EN · gas · SWC)

**Estado:** Fases **0–8** ✅ (módulo cerrado).

**Contratos:** `FlashLoanPool` · `AtomicArbitrage` · `ArbitrageMath` · mocks  
**Estándar:** ERC-3156 · **Tests:** `forge test` → **65 PASS** (+ 2 skip sin RPC) · incl. `test/attack/`
