# Device-acceptance report validator

`validate-report.mjs` checks the repository's narrow v1 intake contract. It validates a template or measurement sidecar; it does not calculate acoustic quality, verify hardware, read a WAV, attest a result, or grant route support.

```bash
node tools/device-acceptance/validate-report.mjs \
  tools/device-acceptance/fixtures/report-template-v1.json
```

The committed template is deliberately unexecuted. Do not copy it into an issue as a real device result. See [the device-acceptance protocol](../../docs/operations/device-acceptance.md) for evidence and privacy requirements.
