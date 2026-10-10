const I18N = {
  es: {
    'html.lang': 'es',
    'meta.title': 'Flash Loans & Atomic Arbitrage — Rolando Strahm',
    'meta.description':
      'Flash loans ERC-3156 con arbitraje atómico, gas documentado y auditoría SWC. Foundry · Solidity 0.8.24.',

    'nav.overview': 'Proyecto',
    'nav.pillars': 'Pilares',
    'nav.gas': 'Gas',
    'nav.swc': 'SWC',
    'nav.process': 'Proceso',
    'nav.attacks': 'Ataques',
    'nav.repos': 'Repos',
    'nav.close': '← Cerrar',

    'hero.tag': '// MÓDULO 08 · PORTFOLIO WEB3',
    'hero.title': 'FLASH LOANS<br>ATOMIC ARBITRAGE',
    'hero.role': 'Solidity 0.8.24 · Foundry · ERC-3156 · Gas · SWC',
    'hero.sub':
      'Proveedor ERC-3156 + ejecutor de arbitraje atómico: si el trade no cubre principal + fee, toda la tx revierte. Gas documentado y campañas defensivas SWC.',
    'hero.cta1': 'Ver en GitHub',
    'hero.cta2': 'Ver en GitLab',

    'ov.eyebrow': '// 01 — CONTEXTO',
    'ov.title': 'Por qué este proyecto',
    'ov.lead':
      'Después de pools y AMM, construí un <strong>flash loan ERC-3156</strong> y un <strong>arbitraje atómico</strong> entre dos AMMs. El foco no es “pedir prestado”: es <strong>atomicidad</strong> (unprofitable → revert), <strong>auth del callback</strong>, <strong>gas</strong> y <strong>SWC</strong> con tests que demuestran que el ataque falla.',

    'pi.eyebrow': '// 02 — TRES PILARES',
    'pi.title': 'Qué entrega el módulo',
    'p1.num': '// PILAR_01',
    'p1.title': 'ERC-3156 + arbitraje',
    'p1.desc':
      'FlashLoanPool (lender) + AtomicArbitrage (borrower): deposit/withdraw, flashLoan, swaps round-trip, repay + profit al owner sin SSTORE.',
    'p1.l1': 'Auth: UntrustedLender / InvalidInitiator',
    'p1.l2': 'UnprofitableArbitrage → revert atómico',
    'p1.l3': 'CEI + ReentrancyGuard en flashLoan',
    'p2.num': '// PILAR_02',
    'p2.title': 'Optimización de gas',
    'p2.desc':
      'Immutables, profit sin storage, custom errors, forceApprove exacto y snapshot Foundry en doc/GAS-ES.md.',
    'p2.l1': 'token / feeBps / flashLender / owner immutable',
    'p2.l2': 'Profit = transfer directo (0 SSTORE)',
    'p2.l3': '.gas-snapshot + gas-report',
    'p3.num': '// PILAR_03',
    'p3.title': 'Verificación SWC',
    'p3.desc':
      'Matriz SWC-100–136, ReentrancyAttack, CallbackSpoof, LoanDefault, fuzz ≥ 1000 e invariantes de liquidez.',
    'p3.l1': '0 vulnerabilidades explotables',
    'p3.l2': '33 mitigados / N/A · 3 info',
    'p3.l3': '65 tests Foundry PASS',

    'gas.eyebrow': '// 03 — OPTIMIZACIÓN DE GAS',
    'gas.title': 'Hot path barato, tradeoffs claros',
    'gas.lead':
      'Fase 8: baseline en <code>doc/GAS-ES.md</code> y <code>.gas-snapshot</code>. Medianas gas-report: <strong>flashLoan ~67k</strong>, <strong>execute ~235k</strong>, <strong>deposit ~57k</strong>. Cada técnica tiene tradeoff explícito.',
    'gas.th1': 'Optimización',
    'gas.th2': 'Tradeoff / efecto',
    'gas.r1a': 'immutable token + feeBps (pool)',
    'gas.r1b': 'Sin SLOAD en fee / maxFlashLoan / flashLoan path',
    'gas.r2a': 'immutable flashLender + owner (arb)',
    'gas.r2b': 'Auth y destino de profit sin storage de acumulado',
    'gas.r3a': 'Profit sin SSTORE',
    'gas.r3b': 'safeTransfer directo al owner en el callback',
    'gas.r4a': 'forceApprove exacto (repay / swaps)',
    'gas.r4b': 'Evita allowance residual; approve = required',
    'gas.r5a': 'BPS_DENOMINATOR constant + FeeBpsTooHigh',
    'gas.r5b': 'Fee sin SLOAD; cap feeBps ≤ 10_000 en constructor',
    'gas.r6a': 'Custom errors (API externa)',
    'gas.r6b': 'Reverts compactos vs require strings',
    'gas.r7a': 'optimizer_runs = 200',
    'gas.r7b': 'Balance deploy (~877k pool / ~639k arb) vs runtime',

    'swc.eyebrow': '// 04 — VERIFICACIÓN SWC',
    'swc.title': 'SWC Registry · EIP-1470',
    'swc.lead':
      'Matriz <strong>SWC-100 → SWC-136</strong> sobre FlashLoanPool / AtomicArbitrage / ArbitrageMath. Informe: <code>doc/SWC-AUDIT-ES.md</code>. Conclusión: <strong>0 vulnerabilidades explotables</strong> en el alcance v1 (ERC-20 + ERC-3156).',
    'swc.s1': 'Mitigados / N/A',
    'swc.s2': 'Informativos (diseño)',
    'swc.s3': 'Vulnerables',
    'swc.th1': 'SWC clave',
    'swc.th2': 'Mitigación en el contrato',
    'swc.r101': 'Overflow: Solidity 0.8.24; fee amount * feeBps / 10_000',
    'swc.r103': 'Floating pragma: pragma solidity 0.8.24 fijo',
    'swc.r104': 'Unchecked return: SafeERC20 + try/catch → LoanRepaymentFailed',
    'swc.r107': 'Reentrancy: nonReentrant en flashLoan; suite ReentrancyAttack',
    'swc.r114': 'Tx order / MEV: minProfit en params; execute público (doc)',
    'swc.r123': 'Requirements: custom errors + unit/fuzz/invariant/attack',
    'swc.info': 'INFORMATIVO',
    'swc.i1t': 'MEV en execute / swaps',
    'swc.i1d':
      'execute es público y los swaps usan minOut = 0. Mitigación v1: minProfit; mejora v2: minOut por hop.',
    'swc.i2t': 'Trust del pool owner',
    'swc.i2d':
      'withdraw solo owner (Ownable2Step): puede drenar liquidez. Modelo custodiado explícito en v1.',

    'pr.eyebrow': '// 05 — PROCESO',
    'pr.title': 'Fases 0–8 cerradas',
    'pr.lead':
      'TDD por gates: scaffold ERC-3156, tests rojos del lender, FlashLoanPool, mocks AMM, AtomicArbitrage, unprofitable, unauthorized, fuzz/invariant, gas + fork + attack.',
    'ph.02': 'Scaffold + tests lender + FlashLoanPool',
    'ph.34': 'Mocks AMM + AtomicArbitrage',
    'ph.56': 'Unprofitable + unauthorized auth',
    'ph.7': 'Fuzz · invariant · SWC',
    'ph.8': 'Gas · Deploy · fork · FeeBpsTooHigh · attack',
    'st.1': 'Fases',
    'st.2': 'Tests PASS',
    'st.3': 'SWC críticos',
    'st.4': 'Attack suites',
    'term.label': 'rolando@strahm:~/08-flash-loans',
    'term.1': 'forge test',
    'term.2': '[PASS] suite · 65 passed · 2 skipped (fork)',
    'term.3': 'cat doc/SWC-AUDIT-ES.md | head',
    'term.4': 'Vulnerable: 0 · Informativos: 3 · Mitigados/N/A: 33',
    'term.5': 'echo status',
    'term.6': 'MODULE_08_CLOSED · GAS_SWC_ATTACK_CLOSED',

    'at.eyebrow': '// 06 — CAMPAÑAS DE ATAQUE',
    'at.title': 'Defensivo, no ofensivo',
    'at.lead':
      'Suites en test/attack, Unauthorized, fuzz e invariant: el “éxito” del ataque es que revierte y el pool no pierde liquidez. Sin PoCs de exploit.',
    'cA.t': 'Reentrancy',
    'cA.d': 'Reentrar flashLoan (mismo receiver / cómplice) → guard.',
    'cB.t': 'Callback spoof',
    'cB.d': 'EOA / fake lender / initiator tercero → auth errors.',
    'cC.t': 'Loan default',
    'cC.d': 'Impago / magic malo / overborrow → pool intacto.',
    'cD.t': 'Unprofitable',
    'cD.d': 'AMMs equilibrados o fee > spread → revert atómico.',
    'cE.t': 'Fuzz / inv',
    'cE.d': 'balance = deposits + fees − withdraws; maxLoan.',

    're.eyebrow': '// 07 — CÓDIGO ABIERTO',
    're.title': 'Repositorios',
    're.lead':
      'Mismo código en GitHub y GitLab: contratos, tests, GAS-ES.md, SWC-AUDIT-ES.md, diagramas y Deploy.s.sol.',
    're.cta': 'Contactar',
    're.linkedin': 'LinkedIn',

    'ft.left': 'ROLANDO STRAHM — Flash Loans · Portfolio',
    'ft.right': 'FOUNDRY · SOLC 0.8.24 · ERC-3156 · ALL_SYSTEMS_OPERATIONAL',
  },

  en: {
    'html.lang': 'en',
    'meta.title': 'Flash Loans & Atomic Arbitrage — Rolando Strahm',
    'meta.description':
      'ERC-3156 flash loans with atomic arbitrage, documented gas, and SWC audit. Foundry · Solidity 0.8.24.',

    'nav.overview': 'Project',
    'nav.pillars': 'Pillars',
    'nav.gas': 'Gas',
    'nav.swc': 'SWC',
    'nav.process': 'Process',
    'nav.attacks': 'Attacks',
    'nav.repos': 'Repos',
    'nav.close': '← Close',

    'hero.tag': '// MODULE 08 · WEB3 PORTFOLIO',
    'hero.title': 'FLASH LOANS<br>ATOMIC ARBITRAGE',
    'hero.role': 'Solidity 0.8.24 · Foundry · ERC-3156 · Gas · SWC',
    'hero.sub':
      'ERC-3156 lender + atomic arbitrage executor: if the trade cannot cover principal + fee, the whole tx reverts. Documented gas and defensive SWC campaigns.',
    'hero.cta1': 'View on GitHub',
    'hero.cta2': 'View on GitLab',

    'ov.eyebrow': '// 01 — CONTEXT',
    'ov.title': 'Why this project',
    'ov.lead':
      'After pools and the AMM, I built an <strong>ERC-3156 flash loan</strong> and an <strong>atomic arbitrage</strong> path across two AMMs. The point is not “just borrow” — it is <strong>atomicity</strong> (unprofitable → revert), <strong>callback auth</strong>, <strong>gas</strong>, and <strong>SWC</strong> with tests that prove the attack fails.',

    'pi.eyebrow': '// 02 — THREE PILLARS',
    'pi.title': 'What the module ships',
    'p1.num': '// PILLAR_01',
    'p1.title': 'ERC-3156 + arbitrage',
    'p1.desc':
      'FlashLoanPool (lender) + AtomicArbitrage (borrower): deposit/withdraw, flashLoan, round-trip swaps, repay + profit to owner with zero profit SSTORE.',
    'p1.l1': 'Auth: UntrustedLender / InvalidInitiator',
    'p1.l2': 'UnprofitableArbitrage → atomic revert',
    'p1.l3': 'CEI + ReentrancyGuard on flashLoan',
    'p2.num': '// PILLAR_02',
    'p2.title': 'Gas optimization',
    'p2.desc':
      'Immutables, profit without storage, custom errors, exact forceApprove, and a Foundry snapshot in doc/GAS-EN.md.',
    'p2.l1': 'token / feeBps / flashLender / owner immutable',
    'p2.l2': 'Profit = direct transfer (0 SSTORE)',
    'p2.l3': '.gas-snapshot + gas-report',
    'p3.num': '// PILLAR_03',
    'p3.title': 'SWC verification',
    'p3.desc':
      'SWC-100–136 matrix, ReentrancyAttack, CallbackSpoof, LoanDefault, fuzz ≥ 1000, and liquidity invariants.',
    'p3.l1': '0 exploitable vulnerabilities',
    'p3.l2': '33 mitigated / N/A · 3 info',
    'p3.l3': '65 Foundry tests PASS',

    'gas.eyebrow': '// 03 — GAS OPTIMIZATION',
    'gas.title': 'Cheap hot path, clear tradeoffs',
    'gas.lead':
      'Phase 8: baseline in <code>doc/GAS-EN.md</code> and <code>.gas-snapshot</code>. Gas-report medians: <strong>flashLoan ~67k</strong>, <strong>execute ~235k</strong>, <strong>deposit ~57k</strong>. Every technique has an explicit tradeoff.',
    'gas.th1': 'Optimization',
    'gas.th2': 'Tradeoff / effect',
    'gas.r1a': 'immutable token + feeBps (pool)',
    'gas.r1b': 'No SLOAD on fee / maxFlashLoan / flashLoan path',
    'gas.r2a': 'immutable flashLender + owner (arb)',
    'gas.r2b': 'Auth and profit destination without accrued-profit storage',
    'gas.r3a': 'Profit with zero SSTORE',
    'gas.r3b': 'Direct safeTransfer to owner in the callback',
    'gas.r4a': 'Exact forceApprove (repay / swaps)',
    'gas.r4b': 'No residual allowance; approve = required',
    'gas.r5a': 'BPS_DENOMINATOR constant + FeeBpsTooHigh',
    'gas.r5b': 'Fee without SLOAD; feeBps capped ≤ 10_000 at deploy',
    'gas.r6a': 'Custom errors (external API)',
    'gas.r6b': 'Compact reverts vs require strings',
    'gas.r7a': 'optimizer_runs = 200',
    'gas.r7b': 'Balance deploy (~877k pool / ~639k arb) vs runtime',

    'swc.eyebrow': '// 04 — SWC VERIFICATION',
    'swc.title': 'SWC Registry · EIP-1470',
    'swc.lead':
      'Full matrix <strong>SWC-100 → SWC-136</strong> on FlashLoanPool / AtomicArbitrage / ArbitrageMath. Report: <code>doc/SWC-AUDIT-EN.md</code>. Conclusion: <strong>0 exploitable vulnerabilities</strong> in v1 scope (ERC-20 + ERC-3156).',
    'swc.s1': 'Mitigated / N/A',
    'swc.s2': 'Informational (design)',
    'swc.s3': 'Vulnerable',
    'swc.th1': 'Key SWC',
    'swc.th2': 'Mitigation in the contract',
    'swc.r101': 'Overflow: Solidity 0.8.24; fee amount * feeBps / 10_000',
    'swc.r103': 'Floating pragma: fixed pragma solidity 0.8.24',
    'swc.r104': 'Unchecked return: SafeERC20 + try/catch → LoanRepaymentFailed',
    'swc.r107': 'Reentrancy: nonReentrant on flashLoan; ReentrancyAttack suite',
    'swc.r114': 'Tx order / MEV: minProfit in params; public execute (documented)',
    'swc.r123': 'Requirements: custom errors + unit/fuzz/invariant/attack',
    'swc.info': 'INFORMATIONAL',
    'swc.i1t': 'MEV on execute / swaps',
    'swc.i1d':
      'execute is public and swaps use minOut = 0. v1 mitigation: minProfit; v2 improvement: per-hop minOut.',
    'swc.i2t': 'Pool owner trust',
    'swc.i2d':
      'withdraw is owner-only (Ownable2Step): owner can drain liquidity. Explicit custodial model in v1.',

    'pr.eyebrow': '// 05 — PROCESS',
    'pr.title': 'Phases 0–8 closed',
    'pr.lead':
      'Gate-based TDD: ERC-3156 scaffold, red lender tests, FlashLoanPool, AMM mocks, AtomicArbitrage, unprofitable, unauthorized, fuzz/invariant, gas + fork + attack.',
    'ph.02': 'Scaffold + lender tests + FlashLoanPool',
    'ph.34': 'AMM mocks + AtomicArbitrage',
    'ph.56': 'Unprofitable + unauthorized auth',
    'ph.7': 'Fuzz · invariant · SWC',
    'ph.8': 'Gas · Deploy · fork · FeeBpsTooHigh · attack',
    'st.1': 'Phases',
    'st.2': 'Tests PASS',
    'st.3': 'Critical SWC',
    'st.4': 'Attack suites',
    'term.label': 'rolando@strahm:~/08-flash-loans',
    'term.1': 'forge test',
    'term.2': '[PASS] suite · 65 passed · 2 skipped (fork)',
    'term.3': 'cat doc/SWC-AUDIT-EN.md | head',
    'term.4': 'Vulnerable: 0 · Informational: 3 · Mitigated/N/A: 33',
    'term.5': 'echo status',
    'term.6': 'MODULE_08_CLOSED · GAS_SWC_ATTACK_CLOSED',

    'at.eyebrow': '// 06 — ATTACK CAMPAIGNS',
    'at.title': 'Defensive, not offensive',
    'at.lead':
      'Suites under test/attack, Unauthorized, fuzz, and invariant: a successful “attack” means it reverts and the pool keeps its liquidity. No exploit PoCs.',
    'cA.t': 'Reentrancy',
    'cA.d': 'Reenter flashLoan (same receiver / accomplice) → guard.',
    'cB.t': 'Callback spoof',
    'cB.d': 'EOA / fake lender / third-party initiator → auth errors.',
    'cC.t': 'Loan default',
    'cC.d': 'Non-repay / bad magic / overborrow → pool intact.',
    'cD.t': 'Unprofitable',
    'cD.d': 'Balanced AMMs or fee > spread → atomic revert.',
    'cE.t': 'Fuzz / inv',
    'cE.d': 'balance = deposits + fees − withdraws; maxLoan.',

    're.eyebrow': '// 07 — OPEN SOURCE',
    're.title': 'Repositories',
    're.lead':
      'Same codebase on GitHub and GitLab: contracts, tests, GAS-EN.md, SWC-AUDIT-EN.md, diagrams, and Deploy.s.sol.',
    're.cta': 'Contact',
    're.linkedin': 'LinkedIn',

    'ft.left': 'ROLANDO STRAHM — Flash Loans · Portfolio',
    'ft.right': 'FOUNDRY · SOLC 0.8.24 · ERC-3156 · ALL_SYSTEMS_OPERATIONAL',
  },
};

function setLanguage(lang) {
  const dict = I18N[lang] || I18N.es;
  document.documentElement.lang = dict['html.lang'];
  document.title = dict['meta.title'];

  const metaDesc = document.querySelector('meta[name="description"]');
  if (metaDesc && dict['meta.description']) {
    metaDesc.setAttribute('content', dict['meta.description']);
  }

  document.querySelectorAll('[data-i18n]').forEach((el) => {
    const key = el.getAttribute('data-i18n');
    const val = dict[key];
    if (val == null) return;
    if (el.hasAttribute('data-i18n-html')) el.innerHTML = val;
    else el.textContent = val;
  });

  document.querySelectorAll('.lang-btn').forEach((btn) => {
    btn.classList.toggle('active', btn.dataset.lang === lang);
  });

  localStorage.setItem('fl-portfolio-lang', lang);

  const url = new URL(window.location.href);
  url.searchParams.set('lang', lang);
  history.replaceState(null, '', url);
}

function initI18n() {
  const params = new URLSearchParams(window.location.search);
  const fromQuery = params.get('lang');
  const saved = localStorage.getItem('fl-portfolio-lang');
  const preferred =
    (fromQuery === 'en' || fromQuery === 'es' ? fromQuery : null) ||
    saved ||
    (navigator.language?.startsWith('en') ? 'en' : 'es');

  setLanguage(preferred);

  document.querySelectorAll('.lang-btn').forEach((btn) => {
    btn.addEventListener('click', () => setLanguage(btn.dataset.lang));
  });
}

document.addEventListener('DOMContentLoaded', initI18n);
