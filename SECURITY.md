# Security Policy

## Supported versions

Until the first stable release, only the latest `main` commit and latest published pre-release are supported. Experimental protocol and cryptography APIs may change.

## Reporting a vulnerability

Do **not** open a public issue. Use GitHub's private repository security advisory reporting channel and include a minimal reproduction, affected revision and impact assessment. Do not include private keys, sensitive recordings or personal data.

We will acknowledge, investigate and coordinate a fix privately, then publish an advisory when a remediation or clear mitigation is available.

## Scope

In scope are parser crashes, memory-safety failures, resource exhaustion, malformed WAV/frame handling, dependency supply-chain risks, unintended disclosure, future key-management flaws and workflow vulnerabilities. The current absence of encryption and non-authenticated callsigns are documented behaviour; do not rely on experimental code for confidentiality.
