# Governance

## Maintainer-led, public by default

AudioModem begins as a maintainer-led project. Maintainers make final decisions while recording rationale in public Issues, pull requests, Discussions or RFCs. Protocol decisions are never hidden.

## Roles

Contributors propose code, documents, tests and reports. Reviewers provide technical feedback. Maintainers merge changes, manage releases, triage security reports and preserve compatibility policy. Code ownership identifies paths requiring review.

## RFC process

An RFC is required for changes to the object container, frame format, FEC, PHY profile, cryptographic envelope, identity model, compatibility policy, supported-platform scope or release security workflow. Create a `protocol-rfc` issue or Discussion, explain motivation, alternatives, backwards compatibility, test strategy and migration plan, then add the accepted proposal to `spec/rfcs/` before merge.

## Versioning

Application releases use SemVer. Protocol and PHY profile identifiers have separate immutable versions with `Experimental`, `Stable` and `Deprecated` status. No released identifier is silently redefined.
