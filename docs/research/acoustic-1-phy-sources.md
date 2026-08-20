# Acoustic-1 PHY research notes

**Last reviewed:** 2026-08-20 · **English (canonical)**

The first Acoustic-1 profile will use binary FSK as a deliberately small, inspectable baseline. This is a repository design decision, not a claim of acoustic interoperability. The required future acceptance evidence remains speaker-to-microphone measurements on declared device classes.

| Source | Relevant finding | Design consequence for Acoustic-1 |
| --- | --- | --- |
| Tiny Tapeout FSK modem | The reference design frames `preamble → sync → payload → CRC`, uses one frequency per binary state, then compares two parallel Goertzel filters before validating integrity.[1] | Keep a versioned framing sequence, a distinctive synchronisation word, and explicit final integrity validation. |
| Sanchez, *FSK Demodulation and Bit String Extraction* | FSK maps binary states to discrete mark/space frequencies; non-coherent demodulation avoids a carrier-phase requirement, while thresholding discriminates the recovered symbols.[2] | Use energy comparison over a fixed symbol window rather than phase-coherent recovery in the first codec. |
| liquid-dsp FEC documentation | Hamming block codes use parity bits to correct one bit error in a block; an additional parity bit adds limited error detection while preserving one-bit correction.[3] | Use explicit Hamming(7,4) codewords only for an inspectable first FEC layer, and retain ADLP CRC-32C as final object-level integrity validation. |

The cited hardware modem explicitly documents that free-running symbol blocks need phase alignment near symbol boundaries.[1] Acoustic-1 must therefore specify its timing assumption and test its receiver against bounded leading-sample offsets. A production receiver will later require a more robust timing-recovery mechanism; that is outside the first implementation.

## References

[1]: https://tinytapeout.com/chips/ttgf26a/tt_um_hydrocomms "FSK Modem — Tiny Tapeout"
[2]: https://arxiv.org/html/2402.17777v1 "FSK Demodulation and Bit String Extraction: A Python-Centric Approach in SDR Systems"
[3]: https://liquidsdr.org/doc/fec/ "liquid-dsp forward error-correction documentation"
