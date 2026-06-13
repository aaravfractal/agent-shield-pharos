<img width="937" height="852" alt="Screenshot 2026-06-14 000556" src="https://github.com/user-attachments/assets/5d2c01e4-cbf3-4ec8-b07d-86304309235d" />

# 🛡️ Agent Shield — The Token- Trust Layer for Pharos Agents

> **The first on-chain token-trust registry for AI agents on Pharos.**
> Agents screen tokens before touching them. Verdicts are recorded on-chain as permanent, public attestations. Trust becomes shared, composable infrastructure.

**Contract:** `0x5ad1d58B95bb0FaF03499beF303788c73ba8aCe7` · **Chain:** Atlantic Testnet (688689) · **Status:** ✅ Verified · [Pharos Scan](https://atlantic.pharosscan.xyz/address/0x5ad1d58B95bb0FaF03499beF303788c73ba8aCe7) · [Demo Video]((video link coming))

<img width="937" ... src="...5d2c01e4..." />

# 🛡 Agent Shield — The Token-Trust Layer for Pharos Agents

> **The first on-chain token-trust registry...**

---

## The Problem

Pharos's thesis is agents as **on-chain economic actors** — holding assets, invoking tools, transacting autonomously. But an autonomous agent cannot smell a scam. A honeypot token looks identical to a legitimate one until the sell fails. An agent economy without a trust layer is an agent economy that gets drained.

## The Solution

Agent Shield gives every agent on Pharos a pre-flight safety check — and makes the result **verifiable and reusable** by every other agent:

1. **Screen** — composite risk engine: GoPlus security intel + on-chain heuristics (code existence, ownership, supply concentration)
2. **Score** — deterministic 0-100 rubric → verdict: `ALLOW` / `WARN` / `BLOCK`
3. **Attest** — the verdict is written to the `AgentShieldRegistry` on Pharos: permanent, public, queryable by anyone
4. **Reuse** — any other agent calls one free view function (`isSafe`, `isFlagged`) instead of re-screening. Unknown ≠ safe: unscreened tokens are treated as unverified.
5. **Incentivize** — anyone can escrow a PHRS bounty to request a screening; the next attester is paid automatically. Work requested → work performed → value transferred. The agent economy, in one loop.

```
 user/agent ──"is token X safe?"──▶ AGENT (reads SKILL.md → agent-shield.md)
                                      │
                     ┌────────────────┼─────────────────┐
                     ▼                ▼                 ▼
              GoPlus API      cast heuristics     registry lookup
              (off-chain)      (on-chain)         (already screened?)
                     └────────────────┬─────────────────┘
                                      ▼
                          score 0-100 → verdict
                                      │
                                      ▼
                     cast send attest() ──▶ AgentShieldRegistry
                                              │  TokenScreened event
                                              ▼
                            permanent on-chain attestation
                            readable by every agent on Pharos
```

## ⚡ For Judges — Test It in 60 Seconds

No clone, no install. The registry is live and verified on Atlantic testnet:

```bash
export RPC=https://atlantic.dplabs-internal.com
export REGISTRY=0x5ad1d58B95bb0FaF03499beF303788c73ba8aCe7

# 1. Has this token been screened? (a token we screened in the demo)
cast call $REGISTRY "isScreened(address)(bool)" 0x1Fc0Bf04e9531B905037E49B65f96De25435D5E2 --rpc-url $RPC

# 2. Is it flagged as dangerous?
cast call $REGISTRY "isFlagged(address)(bool)" 0x1Fc0Bf04e9531B905037E49B65f96De25435D5E2 --rpc-url $RPC

# 3. Full attestation — attester, score, verdict, reasons, timestamp
cast call $REGISTRY "getAttestation(address)(address,uint8,uint8,string,uint64,uint32)" 0x1Fc0Bf04e9531B905037E49B65f96De25435D5E2 --rpc-url $RPC
```

## Skill Engine Integration

This skill follows the Pharos Skill Engine publishing spec end-to-end:

| Deliverable | Location |
|---|---|
| Contract (source of truth) | `assets/agent-shield/AgentShieldRegistry.sol` + `src/agent-shield/` |
| Reference file | `references/agent-shield.md` — command templates, parameter tables, output parsing, error tables with exact revert strings, agent guidelines |
| Capability Index | rows registered in `SKILL.md` with natural-language intents |
| Deployed + verified | Atlantic testnet, green badge on Pharos Scan |

**Integrate in one line** — any agent, any skill, any Phase 2 project:

```bash
cast call <REGISTRY> "isSafe(address)(bool)" <token> --rpc-url https://atlantic.dplabs-internal.com
```

If it returns `false`, check `isScreened` — unknown tokens should be screened before interaction, dangerous ones refused.

## Scoring Rubric (deterministic)

Start at 100, deduct per signal, clamp 0-100. Honeypot or no-code → instant BLOCK. Full table in [`references/agent-shield.md`](references/agent-shield.md). Verdicts: **≥70 ALLOW · 40-69 WARN · <40 BLOCK**. Risk categories map to the threat classes used by GoPlus and CertiK Skynet: honeypot behavior, malicious taxation, ownership/upgradability risk, holder concentration, source opacity.

## Trust Model (v1 → v2)

v1 is **permissionless with recorded attesters** — every attestation carries its attester's address on-chain, so consumers can filter by attesters they trust. v2 roadmap: attester reputation weighting (accuracy track record), staked attestations, and freshness-based re-screening policies. The registry needs no changes for consumers to apply their own attester allowlists today.

## Built For

Agent Shield — a token-trust layer for autonomous AI agents, built for the Agentic & Autonomous Systems theme. AI agents trade tokens on their own but can't detect scams; Agent Shield lets an agent screen any token, get a 0-100 safety score, and read/write an ALLOW/WARN/BLOCK verdict on-chain in one free call — so it refuses honeypots by itself, no human in the loop. Deployed & verified on Pharos Atlantic. Live demo + working registry included.

---

*No admin key. No owner. No upgradability. Public infrastructure for the agent economy.*
