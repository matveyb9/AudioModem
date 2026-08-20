# Acoustic-2 measurement research notes

**Last reviewed:** 2026-08-20 · **English (canonical)**

Acoustic-2 is a repository-only controlled PCM measurement milestone. It will not represent a microphone, speaker, room, operating system audio stack, radio or Bluetooth path. Its purpose is to make the effects of declared sample-domain transforms reproducible before a separate device-acceptance effort begins.

| Source | Relevant finding | Consequence for this milestone |
| --- | --- | --- |
| Sanchez, *FSK Demodulation and Bit String Extraction* | Timing recovery aligns sampling instants with symbol boundaries, improves extraction in the presence of timing offset/jitter, and carries added complexity.[1] | Measure acquisition offset and provide a deterministic bounded offset transform; do not claim a general timing-recovery loop. |
| NCC Group, *Developing an FSK receiver step-by-step* | A preamble marks data start and helps synchronize a receiver; receiver development benefits from recorded signals, filtering and explicit clock-recovery stages.[2] | Keep preamble acquisition inspectable and expose measurement results for a known WAV input. |
| Chaudhari, *FSK Demodulation in GNU Radio* | FSK timing synchronization requires a receiver strategy appropriate to the actual waveform and operating conditions; generic timing blocks are not a universal production solution.[3] | Treat controlled acquisition as an experiment with declared bounds, not as device interoperability evidence. |

## Measurement boundary

The first harness may apply deterministic leading silence, gain scaling, hard clipping, integer-domain additive noise and fixed sample drops. It will report whether a generated WAV is accepted plus codec-observable values such as selected acquisition offset and samples consumed. It will not manufacture BER, SNR, range, room-noise, clock-drift or device-compatibility claims from synthetic data.

## References

[1]: https://arxiv.org/html/2402.17777v1 "FSK Demodulation and Bit String Extraction: A Python-Centric Approach in SDR Systems"
[2]: https://nccgroup.github.io/RFTM/fsk_receiver.html "RF Testing Methodology: Developing an FSK receiver step-by-step"
[3]: https://wirelesspi.com/fsk-demodulation-in-gnu-radio/ "FSK Demodulation in GNU Radio"
