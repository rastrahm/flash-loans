> 🌐 [English](./SOCIAL-EN.md) · **Español**

# Borradores redes — Flash Loans & Atomic Arbitrage (módulo 08)

Links:

- **GitHub:** https://github.com/rastrahm/flash-loans  
- **GitLab:** https://gitlab.com/rastrahm/flash-loans  

> Si publicás un artículo largo (Medium/Hashnode/Mirror), poné esa URL como link principal y dejá los repos como “código”.

---

## LinkedIn (tono humano)

Cerré el módulo 08 de mi suite de smart contracts: **flash loans ERC-3156 + arbitraje atómico** en Solidity 0.8.24 y Foundry.

La idea no era “pedir prestado y listo”. Quería un flujo donde, si el trade no cubre principal + fee, **toda la transacción revierte** y el pool no pierde un wei.

Qué quedó adentro:

- Pool `IERC3156FlashLender` con fee en bps y liquidez depositable  
- Ejecutor `IERC3156FlashBorrower`: swap entre dos AMMs, repay y profit al owner (sin SSTORE de acumulado)  
- Auth estricta en el callback (`UntrustedLender` / `InvalidInitiator`)  
- CEI + `ReentrancyGuard` en el préstamo  
- Unit, fuzz (1000), invariantes de liquidez, gas snapshot… y una suite `test/attack/` (reentrancy, spoof del callback, impago)

También dejé diagramas, planificación, auditoría SWC y `doc/GAS-ES.md` para poder estudiar el diseño sin adivinar.

Código (mismo proyecto en ambos lados):

GitHub → https://github.com/rastrahm/flash-loans  
GitLab → https://gitlab.com/rastrahm/flash-loans  

Si te interesa, ¿qué preferís que desarrolle en un próximo post: el callback ERC-3156, la atomicidad del unprofitable, o cómo arme los ataques?

\#Solidity \#Foundry \#Web3 \#FlashLoans \#ERC3156 \#SmartContracts \#Ethereum \#DeFi \#OpenZeppelin

---

## X / Twitter — versión corta (1 post)

Cerré flash loans ERC-3156 + arbitraje atómico (Solidity 0.8.24 / Foundry).

Si el trade no cubre principal + fee, revierte todo. Auth en el callback, reentrancy guard, fuzz + suite de ataques.

GitHub: https://github.com/rastrahm/flash-loans  
GitLab: https://gitlab.com/rastrahm/flash-loans  

\#Solidity \#Foundry \#FlashLoans \#DeFi

---

## X — hilo (opcional, más humano)

**1/**  
Terminé el módulo 08 de mi suite: flash loans + arbitraje atómico.

No quería un demo que “funciona en el happy path”. Quería que el caso feo (trade en rojo) no deje al pool en pelotas.

**2/**  
Stack: Solidity 0.8.24, Foundry, OZ v5, estándar ERC-3156.

Flujo: `execute` → `flashLoan` → swaps en dos AMMs → repay + fee → profit al owner. Sin variables de estado para ir acumulando ganancia.

**3/**  
Seguridad que me importaba:

- solo el lender configurado puede llamar el callback  
- el initiator tiene que ser el propio contrato  
- reentrar el `flashLoan` desde el borrower → bloqueado  
- no pagar / magic value malo → revert y liquidez intacta  

**4/**  
Tests: unit + unauthorized + fuzz 1000 + invariantes + gas, y `test/attack/` dedicada (reentrancy, spoof, default).

Docs: plan, diagramas, SWC-AUDIT y GAS.

**5/**  
Repo (espejo):

https://github.com/rastrahm/flash-loans  
https://gitlab.com/rastrahm/flash-loans  

Si lo corrés en local: `forge test` y, con Anvil, el `Deploy.s.sol`.

---

## Notas para publicar

1. Pegá los dos links (GitHub + GitLab); mucha gente mira uno u otro.  
2. En LinkedIn, 1 imagen ayuda: captura de `forge test --summary` o un diagrama Mermaid exportado desde `doc/`.  
3. En X, la versión corta entra mejor; el hilo si querés contar el “por qué”.  
4. No hace falta UI para este módulo: el gancho es seguridad + atomicidad, no pantallas.
