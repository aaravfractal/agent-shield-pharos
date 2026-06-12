# Agent Shield Operation Instructions

> Network Configuration: `<rpc>` is read from `assets/networks.json` (Atlantic Testnet: `https://atlantic.dplabs-internal.com`, chain ID `688689`).
> Private Key: Pass explicitly via `--private-key $PRIVATE_KEY`.
> Registry Contract (Atlantic Testnet): `0x5ad1d58B95bb0FaF03499beF303788c73ba8aCe7` (verified)

Agent Shield is the token-trust layer for Pharos agents. Before any agent interacts with an unknown token, it screens the token (off-chain risk intel + on-chain heuristics), records a permanent attestation in the AgentShieldRegistry, and other agents read that attestation instead of re-screening.

---

## Screen a Token (composite workflow)

### Overview
The primary Agent Shield operation. Given a token address, gather risk data, compute a composite safety score (0-100), derive a verdict (ALLOW / WARN / BLOCK), and record the attestation on-chain. This is the operation to run when a user or agent asks "is this token safe?", "scam check", "honeypot check", or "should I buy this?".

### Command Template

```bash
# Step 1 — off-chain risk intel (GoPlus, free API; use the token's origin chain ID, e.g. 1 = Ethereum, 56 = BSC)
curl -s "https://api.gopluslabs.io/api/v1/token_security/<origin_chain_id>?contract_addresses=<token>" | jq '.result'

# Step 2 — on-chain heuristics on Pharos (free view calls)
cast code <token> --rpc-url $RPC                                          # contract exists?
cast call <token> "totalSupply()(uint256)" --rpc-url $RPC                  # supply
cast call <token> "owner()(address)" --rpc-url $RPC                        # owner / renounced?

# Step 3 — compute score per the Scoring Rubric below, then record the attestation
cast send 0x5ad1d58B95bb0FaF03499beF303788c73ba8aCe7 "attest(address,uint8,uint8,string)" \
  <token> <score> <verdict_uint> "<reason_codes>" \
  --private-key $PRIVATE_KEY --rpc-url $RPC
```

### Scoring Rubric
Start at 100 and apply deductions. Clamp to 0-100.

| Signal (source) | Deduction |
|---|---|
| `is_honeypot = 1` (GoPlus) | set score to 5, verdict BLOCK |
| `cast code` returns `0x` (no contract) | set score to 0, verdict BLOCK, reason `NO_CODE` |
| sell tax > 50% (GoPlus) | -60 |
| sell tax 10-50% (GoPlus) | -30 |
| `can_take_back_ownership = 1` or `hidden_owner = 1` (GoPlus) | -25 |
| mintable and owner not renounced | -20 |
| top-1 holder > 50% of supply (GoPlus `holders`) | -20 |
| top-10 holders > 80% of supply | -15 |
| `is_open_source = 0` (GoPlus) | -15 |
| token unscreenable by GoPlus (Pharos-native, no origin-chain data) | -10, append reason `NATIVE_LIMITED_INTEL` |

Verdict mapping: score >= 70 → ALLOW (1) · 40-69 → WARN (2) · < 40 → BLOCK (3).
Reason codes: comma-separated, uppercase, max 200 chars. Examples: `HONEYPOT`, `SELL_TAX_100`, `OWNER_NOT_RENOUNCED`, `TOP1_HOLDER_62PCT`, `NO_CODE`, `CLEAN`.

### Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| token | address | Yes | The token / contract being screened |
| score | uint8 | Yes | Composite safety score 0-100 (higher = safer) |
| verdict_uint | uint8 | Yes | 1 = ALLOW, 2 = WARN, 3 = BLOCK |
| reason_codes | string | Yes | Comma-separated uppercase codes, <= 200 chars |

### Output Parsing
| Field | Description |
|-------|-------------|
| transactionHash | The attestation receipt — show with explorer link `https://atlantic.pharosscan.xyz/tx/<hash>` |
| status | `1 (success)` means the attestation is recorded |

### Error Handling
| Error Signature | Cause | Suggested Action |
|----------------|-------|------------------|
| `Token address cannot be zero` | token param was 0x0 | Confirm the token address with the user |
| `Score must be 0-100` | score out of range | Re-check rubric arithmetic, clamp to 0-100 |
| `Verdict must be ALLOW, WARN, or BLOCK` | verdict_uint was 0 or > 3 | Map verdict to 1, 2, or 3 |
| `Reasons too long (max 200 chars)` | reason string > 200 chars | Truncate to the most important codes |
| GoPlus returns empty `result` | token not indexed on that chain | Apply `NATIVE_LIMITED_INTEL` path: heuristics only, -10 |

> **Agent Guidelines**:
> 1. Complete Write Operation Pre-checks (see SKILL.md)
> 2. Run Step 1 and Step 2 data gathering; never skip both — at minimum run `cast code`
> 3. Compute score strictly per the Scoring Rubric; do not invent deductions
> 4. Map verdict from score; send the attestation; wait for receipt
> 5. Report to the user: verdict, score, reasons, and the pharosscan link to the attestation

---

## Check a Token Before Interacting (read-only pre-flight)

### Overview
The cheap path. Before swapping, approving, or transferring an unknown token, an agent first checks whether a recent attestation already exists. All calls are free view functions. Run this when the user asks "has this token been checked?", "is it safe?" (and an attestation may already exist), or before any token interaction as a pre-flight.

### Command Template

```bash
cast call 0x5ad1d58B95bb0FaF03499beF303788c73ba8aCe7 "isScreened(address)(bool)" <token> --rpc-url $RPC
cast call 0x5ad1d58B95bb0FaF03499beF303788c73ba8aCe7 "isSafe(address)(bool)" <token> --rpc-url $RPC
cast call 0x5ad1d58B95bb0FaF03499beF303788c73ba8aCe7 "isFlagged(address)(bool)" <token> --rpc-url $RPC
cast call 0x5ad1d58B95bb0FaF03499beF303788c73ba8aCe7 "getAttestation(address)(address,uint8,uint8,string,uint64,uint32)" <token> --rpc-url $RPC
cast call 0x5ad1d58B95bb0FaF03499beF303788c73ba8aCe7 "attestationAge(address)(uint256)" <token> --rpc-url $RPC
```

### Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| token | address | Yes | The token to look up |

### Output Parsing
| Field | Description |
|-------|-------------|
| isScreened → false | Never screened. Unknown is NOT safe — run the Screen a Token workflow |
| isSafe → true | Latest verdict is ALLOW; proceed |
| isFlagged → true | Latest verdict is BLOCK; refuse the interaction and tell the user why (read `getAttestation` reasons) |
| getAttestation tuple | (attester, score, verdict 1/2/3, reasons, timestamp, revision) |
| attestationAge | Seconds since screening; if > 86400 (24h), recommend re-screening |

### Error Handling
| Error Signature | Cause | Suggested Action |
|----------------|-------|------------------|
| `No attestation for this token` | `getAttestation`/`scoreOf`/`attestationAge` called on an unscreened token | Call `isScreened` first, or run the Screen a Token workflow |
| Empty return value | Wrong REGISTRY address or wrong network | Confirm registry address and `--rpc-url $RPC` |

> **Agent Guidelines**:
> 1. Always call `isScreened` first — it never reverts
> 2. Treat unscreened as unsafe; offer to run a full screening
> 3. On BLOCK: refuse the interaction, surface the reason codes to the user
> 4. On stale attestation (> 24h): proceed only with a warning, or re-screen

---

## Fund a Screening Bounty

### Overview
Anyone — a user, an agent, a protocol — can escrow PHRS as a bounty to request that a token be screened. The next attester for that token automatically receives the bounty. This is the agent-economy loop: work requested, work performed, value transferred on-chain.

### Command Template

```bash
# Escrow 0.05 PHRS to have <token> screened
cast send 0x5ad1d58B95bb0FaF03499beF303788c73ba8aCe7 "fundScreening(address)" <token> \
  --value 0.05ether --private-key $PRIVATE_KEY --rpc-url $RPC

# Check the current bounty on a token (free)
cast call 0x5ad1d58B95bb0FaF03499beF303788c73ba8aCe7 "bountyOf(address)(uint256)" <token> --rpc-url $RPC
```

### Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| token | address | Yes | The token you want screened |
| --value | PHRS amount | Yes | Bounty amount; must be > 0 |

### Output Parsing
| Field | Description |
|-------|-------------|
| transactionHash | Funding receipt |
| bountyOf | Total PHRS (in wei) currently escrowed for the token |

### Error Handling
| Error Signature | Cause | Suggested Action |
|----------------|-------|------------------|
| `Token address cannot be zero` | token param was 0x0 | Confirm the token address |
| `Must send PHRS` | `--value` missing or 0 | Include `--value <amount>ether` |
| `insufficient funds` | Wallet balance too low | `cast balance $DEPLOYER --rpc-url $RPC --ether`, top up from faucet |

> **Agent Guidelines**:
> 1. Complete Write Operation Pre-checks (see SKILL.md)
> 2. Confirm the bounty amount with the user before sending
> 3. After funding, show `bountyOf` so the user sees the escrowed total

---

## Query Screening Events

### Overview
Read the full screening history — all attestations, fundings, and bounty payouts — directly from chain logs. Useful for "show recent screenings", "screening history of token X", or building a live feed.

### Command Template

```bash
# All screenings of a specific token
cast logs --from-block 0 --address 0x5ad1d58B95bb0FaF03499beF303788c73ba8aCe7 \
  "TokenScreened(address,address,uint8,uint8,string,uint64,uint32)" \
  --rpc-url $RPC

# All bounty fundings
cast logs --from-block 0 --address 0x5ad1d58B95bb0FaF03499beF303788c73ba8aCe7 \
  "ScreeningFunded(address,address,uint256,uint256)" --rpc-url $RPC
```

### Output Parsing
| Field | Description |
|-------|-------------|
| topics[1] | indexed token address |
| topics[2] | indexed attester / sponsor address |
| data | score, verdict, reasons, timestamp, revision (decode per event signature) |

### Error Handling
| Error Signature | Cause | Suggested Action |
|----------------|-------|------------------|
| Empty result | No events yet, or wrong address | Confirm REGISTRY address; check `totalAttestations` via cast call |

> **Agent Guidelines**:
> 1. Prefer `getAttestation` for a single token (cheaper); use logs for history/feeds
> 2. Show timestamps in human-readable form

---

## Deploy AgentShieldRegistry

### Overview
One-time deployment of the registry contract. No constructor arguments, no admin key, no owner — the registry is immutable public infrastructure.

### Command Template

```bash
# 1. Pre-checks
cast wallet address --private-key $PRIVATE_KEY
cast balance $DEPLOYER --rpc-url $RPC --ether

# 2. Deploy
forge create src/agent-shield/AgentShieldRegistry.sol:AgentShieldRegistry \
  --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast

# 3. Wait for the indexer, then verify
sleep 10
forge verify-contract <deployed_address> src/agent-shield/AgentShieldRegistry.sol:AgentShieldRegistry \
  --chain-id 688689 \
  --verifier-url https://api.socialscan.io/pharos-atlantic-testnet/v1/explorer/command_api/contract \
  --verifier blockscout
```

### Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| (none) | — | — | Constructor takes no arguments |

### Output Parsing
| Field | Description |
|-------|-------------|
| Deployed to | The registry address — record it as `0x5ad1d58B95bb0FaF03499beF303788c73ba8aCe7` in this file and in SKILL.md |
| Transaction hash | Deployment receipt for the README |

### Error Handling
| Error Signature | Cause | Suggested Action |
|----------------|-------|------------------|
| `insufficient funds` | No testnet PHRS | Request from faucet / Telegram, retry |
| Verification fails immediately | Indexer delay | `sleep 10` and retry the verify command |

> **Agent Guidelines**:
> 1. Complete Write Operation Pre-checks (see SKILL.md)
> 2. Record the deployed address and update references
> 3. Confirm the green verified badge on `https://atlantic.pharosscan.xyz/address/<deployed_address>`
