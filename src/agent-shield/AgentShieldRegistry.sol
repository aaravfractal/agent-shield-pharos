// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title  Agent Shield Registry
/// @notice The on-chain token-trust registry for AI agents on Pharos.
///         Agents screen a token off-chain (GoPlus + heuristics), then record
///         a permanent, public attestation here. Any other agent can read the
///         attestation instead of re-screening - trust becomes shared,
///         composable infrastructure for the Pharos agent economy.
/// @dev    No admin key. No upgradability. No owner.
contract AgentShieldRegistry {
    enum Verdict {
        NONE,   // 0 - no attestation exists
        ALLOW,  // 1 - safe to interact (score >= 70)
        WARN,   // 2 - interact with caution (score 40-69)
        BLOCK   // 3 - do not interact (score < 40)
    }

    struct Attestation {
        address attester;
        uint8   score;
        Verdict verdict;
        string  reasons;
        uint64  timestamp;
        uint32  revision;
    }

    mapping(address => Attestation) private _latest;
    mapping(address => uint256) public bountyOf;
    uint256 public totalAttestations;

    event TokenScreened(
        address indexed token,
        address indexed attester,
        uint8 score,
        Verdict verdict,
        string reasons,
        uint64 timestamp,
        uint32 revision
    );

    event ScreeningFunded(
        address indexed token,
        address indexed sponsor,
        uint256 amount,
        uint256 totalBounty
    );

    event BountyPaid(
        address indexed token,
        address indexed attester,
        uint256 amount
    );

    function attest(
        address token,
        uint8 score,
        Verdict verdict,
        string calldata reasons
    ) external {
        require(token != address(0), "Token address cannot be zero");
        require(score <= 100, "Score must be 0-100");
        require(
            verdict == Verdict.ALLOW ||
            verdict == Verdict.WARN ||
            verdict == Verdict.BLOCK,
            "Verdict must be ALLOW, WARN, or BLOCK"
        );
        require(bytes(reasons).length <= 200, "Reasons too long (max 200 chars)");

        uint32 revision = _latest[token].revision + 1;

        _latest[token] = Attestation({
            attester:  msg.sender,
            score:     score,
            verdict:   verdict,
            reasons:   reasons,
            timestamp: uint64(block.timestamp),
            revision:  revision
        });

        totalAttestations += 1;

        emit TokenScreened(
            token, msg.sender, score, verdict, reasons,
            uint64(block.timestamp), revision
        );

        uint256 bounty = bountyOf[token];
        if (bounty > 0) {
            bountyOf[token] = 0;
            (bool ok, ) = msg.sender.call{value: bounty}("");
            require(ok, "Bounty transfer failed");
            emit BountyPaid(token, msg.sender, bounty);
        }
    }

    function fundScreening(address token) external payable {
        require(token != address(0), "Token address cannot be zero");
        require(msg.value > 0, "Must send PHRS");

        bountyOf[token] += msg.value;

        emit ScreeningFunded(token, msg.sender, msg.value, bountyOf[token]);
    }

    function getAttestation(address token)
        external
        view
        returns (
            address attester,
            uint8 score,
            Verdict verdict,
            string memory reasons,
            uint64 timestamp,
            uint32 revision
        )
    {
        Attestation storage a = _latest[token];
        require(a.verdict != Verdict.NONE, "No attestation for this token");
        return (a.attester, a.score, a.verdict, a.reasons, a.timestamp, a.revision);
    }

    function isSafe(address token) external view returns (bool) {
        return _latest[token].verdict == Verdict.ALLOW;
    }

    function isFlagged(address token) external view returns (bool) {
        return _latest[token].verdict == Verdict.BLOCK;
    }

    function isScreened(address token) external view returns (bool) {
        return _latest[token].verdict != Verdict.NONE;
    }

    function scoreOf(address token) external view returns (uint8) {
        Attestation storage a = _latest[token];
        require(a.verdict != Verdict.NONE, "No attestation for this token");
        return a.score;
    }

    function attestationAge(address token) external view returns (uint256) {
        Attestation storage a = _latest[token];
        require(a.verdict != Verdict.NONE, "No attestation for this token");
        return block.timestamp - a.timestamp;
    }
}
