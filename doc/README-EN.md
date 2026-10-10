> 🌐 **English** · [Español](./README-ES.md)

# Documentation — Module 08: Flash Loans & Atomic Arbitrage

Index of the `doc/` folder. **Complete project** (contracts + security + gas).

| Document | Contents |
|-----------|-----------|
| [PLANIFICACION-EN.md](./PLANIFICACION-EN.md) | Goal, scope, TDD phases, criteria |
| [DECISIONES-Y-LOGICA-EN.md](./DECISIONES-Y-LOGICA-EN.md) | Technical decisions, logical flow, gas improvements |
| [SWC-AUDIT-EN.md](./SWC-AUDIT-EN.md) | SWC-100–136 matrix, mapping to tests |
| [GAS-EN.md](./GAS-EN.md) | Gas baseline, optimizations, snapshot |
| [SOCIAL-EN.md](./SOCIAL-EN.md) | LinkedIn / X drafts |
| [diagrama-clases-EN.md](./diagrama-clases-EN.md) | UML: ERC-3156 lender, borrower, AMM mocks, tests |
| [diagrama-flujo-EN.md](./diagrama-flujo-EN.md) | Flash loan / callback / repay flows |
| [flujograma-EN.md](./flujograma-EN.md) | Operational, security, TDD pipeline |

**Portfolio:** [`../portfolio/index.html`](../portfolio/index.html) (ES/EN · gas · SWC)

**Status:** Phases **0–8** ✅ (module closed).

**Contracts:** `FlashLoanPool` · `AtomicArbitrage` · `ArbitrageMath` · mocks  
**Standard:** ERC-3156 · **Tests:** `forge test` → **65 PASS** (+ 2 skipped without RPC) · incl. `test/attack/`
