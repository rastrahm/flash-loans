> 🌐 **English** · [Español](./SOCIAL-ES.md)

# Social media drafts — Flash Loans & Atomic Arbitrage (module 08)

Links:

- **GitHub:** https://github.com/rastrahm/flash-loans  
- **GitLab:** https://gitlab.com/rastrahm/flash-loans  

> If you publish a long-form article (Medium/Hashnode/Mirror), use that URL as the main link and leave the repos as “code”.

---

## LinkedIn (human tone)

About 5 minutes of my time — here's Flash Loans.

I just wrapped up module 08 of my smart contracts suite: **ERC-3156 flash loans + atomic arbitrage** in Solidity 0.8.24 and Foundry.

The goal wasn't just "borrow and done". I wanted a flow where, if the trade doesn't cover principal + fee, **the whole transaction reverts** and the pool doesn't lose a single wei.

What's inside:

- `IERC3156FlashLender` pool with a bps fee and depositable liquidity  
- `IERC3156FlashBorrower` executor: swap across two AMMs, repay, and send profit to the owner (no SSTORE for accumulated profit)  
- Strict callback auth (`UntrustedLender` / `InvalidInitiator`)  
- CEI + `ReentrancyGuard` on the loan  
- Unit, fuzz (1000 runs), liquidity invariants, gas snapshot… and a dedicated `test/attack/` suite (reentrancy, callback spoofing, loan default)

I also included diagrams, planning, an SWC audit, and `doc/GAS-EN.md` so the design can be studied without guesswork.

Code (same project on both):

GitHub → https://github.com/rastrahm/flash-loans  
GitLab → https://gitlab.com/rastrahm/flash-loans  

If you're interested, what would you like me to dig into next: the ERC-3156 callback, atomicity on unprofitable trades, or how I built the attack tests?

\#Solidity \#Foundry \#Web3 \#FlashLoans \#ERC3156 \#SmartContracts \#Ethereum \#DeFi \#OpenZeppelin

---

## X / Twitter — short version (1 post)

Wrapped up ERC-3156 flash loans + atomic arbitrage (Solidity 0.8.24 / Foundry).

If the trade doesn't cover principal + fee, everything reverts. Callback auth, reentrancy guard, fuzzing + an attack suite.

GitHub: https://github.com/rastrahm/flash-loans  
GitLab: https://gitlab.com/rastrahm/flash-loans  

\#Solidity \#Foundry \#FlashLoans \#DeFi

---

## X — thread (optional, more personal)

**1/**  
Finished module 08 of my suite: flash loans + atomic arbitrage.

I didn't want a demo that "works on the happy path". I wanted the ugly case (a losing trade) to not leave the pool stripped bare.

**2/**  
Stack: Solidity 0.8.24, Foundry, OZ v5, ERC-3156 standard.

Flow: `execute` → `flashLoan` → swaps on two AMMs → repay + fee → profit to the owner. No state variables piling up profit along the way.

**3/**  
Security I cared about:

- only the configured lender can call the callback  
- the initiator has to be the contract itself  
- reentering `flashLoan` from the borrower → blocked  
- no repayment / bad magic value → revert, liquidity intact  

**4/**  
Tests: unit + unauthorized + fuzz 1000 + invariants + gas, plus a dedicated `test/attack/` (reentrancy, spoofing, default).

Docs: plan, diagrams, SWC-AUDIT and GAS.

**5/**  
Repo (mirrored):

https://github.com/rastrahm/flash-loans  
https://gitlab.com/rastrahm/flash-loans  

If you run it locally: `forge test` and, with Anvil, `Deploy.s.sol`.

---

## Publishing notes

1. Paste both links (GitHub + GitLab); plenty of people only check one or the other.  
2. On LinkedIn, one image helps: a screenshot of `forge test --summary` or a Mermaid diagram exported from `doc/`.  
3. On X, the short version lands better; use the thread if you want to tell the "why".  
4. This module doesn't need a UI: the hook is security + atomicity, not screens.
