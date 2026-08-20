//! Experimental Acoustic-1 B-FSK carrier for controlled PCM/WAV tests.
//!
//! It transports an unchanged ADLP v1 wire object. This module deliberately
//! does not claim live-device timing recovery, AGC, or acoustic interoperability.

use std::fmt;

use adlp_protocol::{ProtocolError, TransferProfile, WireObject};

use crate::{make_canonical_wav, parse_canonical_wav, CodecError, SAMPLE_RATE_HZ};

pub const MAX_WIRE_BYTES: usize = 256;
pub const PREAMBLE_BITS: usize = 64;
pub const SYNC_WORD: u16 = 0xD391;
pub const MAX_SYNC_OFFSET_SAMPLES: usize = 480;

const SINE_120: [i16; 48] = [
    0, 16, 31, 46, 60, 73, 85, 95, 104, 111, 116, 119, 120, 119, 116, 111, 104, 95, 85, 73, 60, 46,
    31, 16, 0, -16, -31, -46, -60, -73, -85, -95, -104, -111, -116, -119, -120, -119, -116, -111,
    -104, -95, -85, -73, -60, -46, -31, -16,
];

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct DecodedAcousticTransfer {
    pub object: WireObject,
    pub sample_rate_hz: u32,
    pub frame_start_candidate_samples: usize,
    pub samples_consumed: usize,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum Acoustic1Error {
    Codec(CodecError),
    Protocol(ProtocolError),
    WireObjectTooLarge,
    FrameNotFound,
    TruncatedSignal,
    ProfileMismatch,
}

impl fmt::Display for Acoustic1Error {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Codec(error) => write!(formatter, "WAV error: {error}"),
            Self::Protocol(error) => write!(formatter, "ADLP error: {error}"),
            Self::WireObjectTooLarge => {
                write!(formatter, "Acoustic-1 wire object exceeds 256 bytes")
            }
            Self::FrameNotFound => {
                write!(formatter, "Acoustic-1 preamble or sync word was not found")
            }
            Self::TruncatedSignal => write!(formatter, "truncated Acoustic-1 signal"),
            Self::ProfileMismatch => write!(
                formatter,
                "Acoustic-1 symbol rate does not match ADLP profile"
            ),
        }
    }
}

impl std::error::Error for Acoustic1Error {}

impl From<CodecError> for Acoustic1Error {
    fn from(error: CodecError) -> Self {
        Self::Codec(error)
    }
}

impl From<ProtocolError> for Acoustic1Error {
    fn from(error: ProtocolError) -> Self {
        Self::Protocol(error)
    }
}

#[derive(Clone, Copy)]
struct ProfileConfig {
    profile: TransferProfile,
    samples_per_symbol: usize,
}

const PROFILE_CONFIGS: [ProfileConfig; 4] = [
    ProfileConfig {
        profile: TransferProfile::Reliable,
        samples_per_symbol: 480,
    },
    ProfileConfig {
        profile: TransferProfile::Balanced,
        samples_per_symbol: 240,
    },
    ProfileConfig {
        profile: TransferProfile::Fast,
        samples_per_symbol: 144,
    },
    ProfileConfig {
        profile: TransferProfile::Narrowband,
        samples_per_symbol: 480,
    },
];

pub fn encode_wav(object: &WireObject) -> Result<Vec<u8>, Acoustic1Error> {
    Ok(make_canonical_wav(&encode_samples(object)?)?)
}

pub fn decode_wav(wav: &[u8]) -> Result<DecodedAcousticTransfer, Acoustic1Error> {
    let (sample_rate_hz, samples) = parse_canonical_wav(wav)?;
    if sample_rate_hz != SAMPLE_RATE_HZ {
        return Err(Acoustic1Error::Codec(CodecError::InvalidWav(
            "sample rate must be 48 kHz",
        )));
    }

    for config in PROFILE_CONFIGS {
        let minimum_samples = (PREAMBLE_BITS + 16 + 56) * config.samples_per_symbol;
        if samples.len() < minimum_samples {
            continue;
        }
        let maximum_offset = MAX_SYNC_OFFSET_SAMPLES.min(samples.len() - minimum_samples);
        for offset in 0..=maximum_offset {
            if let Ok(decoded) = decode_candidate(&samples, offset, config) {
                return Ok(decoded);
            }
        }
    }
    Err(Acoustic1Error::FrameNotFound)
}

fn encode_samples(object: &WireObject) -> Result<Vec<i16>, Acoustic1Error> {
    let wire = object.encode()?;
    if wire.len() > MAX_WIRE_BYTES {
        return Err(Acoustic1Error::WireObjectTooLarge);
    }
    let config = profile_config(object.manifest.profile);
    let mut bits = Vec::with_capacity(PREAMBLE_BITS + 16 + 56 + wire.len() * 14);
    for index in 0..PREAMBLE_BITS {
        bits.push(index % 2 == 0);
    }
    append_raw_u16(&mut bits, SYNC_WORD);
    for byte in (wire.len() as u32).to_be_bytes() {
        append_hamming_byte(&mut bits, byte);
    }
    for byte in wire {
        append_hamming_byte(&mut bits, byte);
    }
    Ok(modulate(&bits, config.samples_per_symbol))
}

fn decode_candidate(
    samples: &[i16],
    offset: usize,
    config: ProfileConfig,
) -> Result<DecodedAcousticTransfer, Acoustic1Error> {
    let mut cursor = SymbolCursor::new(samples, offset, config.samples_per_symbol);
    for index in 0..PREAMBLE_BITS {
        if cursor.bit()? != (index % 2 == 0) {
            return Err(Acoustic1Error::FrameNotFound);
        }
    }
    if cursor.raw_u16()? != SYNC_WORD {
        return Err(Acoustic1Error::FrameNotFound);
    }
    let mut length_bytes = [0_u8; 4];
    for byte in &mut length_bytes {
        *byte = cursor.hamming_byte()?;
    }
    let length = u32::from_be_bytes(length_bytes) as usize;
    if length > MAX_WIRE_BYTES {
        return Err(Acoustic1Error::WireObjectTooLarge);
    }
    let mut wire = Vec::with_capacity(length);
    for _ in 0..length {
        wire.push(cursor.hamming_byte()?);
    }
    let object = WireObject::decode(&wire)?;
    if object.manifest.profile != config.profile {
        return Err(Acoustic1Error::ProfileMismatch);
    }
    Ok(DecodedAcousticTransfer {
        object,
        sample_rate_hz: SAMPLE_RATE_HZ,
        frame_start_candidate_samples: offset,
        samples_consumed: cursor.samples_consumed(),
    })
}

fn profile_config(profile: TransferProfile) -> ProfileConfig {
    PROFILE_CONFIGS
        .iter()
        .copied()
        .find(|config| config.profile == profile)
        .expect("all ADLP transfer profiles have an Acoustic-1 configuration")
}

fn append_raw_u16(bits: &mut Vec<bool>, value: u16) {
    for byte in value.to_be_bytes() {
        append_raw_byte(bits, byte);
    }
}

fn append_raw_byte(bits: &mut Vec<bool>, value: u8) {
    for offset in (0..8).rev() {
        bits.push(value & (1 << offset) != 0);
    }
}

fn append_hamming_byte(bits: &mut Vec<bool>, value: u8) {
    append_hamming_nibble(bits, value >> 4);
    append_hamming_nibble(bits, value & 0x0F);
}

fn append_hamming_nibble(bits: &mut Vec<bool>, value: u8) {
    let d3 = value & 0b1000 != 0;
    let d2 = value & 0b0100 != 0;
    let d1 = value & 0b0010 != 0;
    let d0 = value & 0b0001 != 0;
    bits.extend_from_slice(&[d3 ^ d2 ^ d0, d3 ^ d1 ^ d0, d3, d2 ^ d1 ^ d0, d2, d1, d0]);
}

fn modulate(bits: &[bool], samples_per_symbol: usize) -> Vec<i16> {
    let mut samples = Vec::with_capacity(bits.len() * samples_per_symbol);
    for bit in bits {
        let frequency_multiple = if *bit { 1 } else { 2 };
        for index in 0..samples_per_symbol {
            let phase = (index * frequency_multiple) % SINE_120.len();
            samples.push(SINE_120[phase] * 100);
        }
    }
    samples
}

fn symbol_energy(samples: &[i16], frequency_multiple: usize) -> i64 {
    let mut in_phase = 0_i64;
    let mut quadrature = 0_i64;
    for (index, sample) in samples.iter().enumerate() {
        let normalized = i64::from(*sample) / 100;
        let phase = (index * frequency_multiple) % SINE_120.len();
        in_phase += normalized * i64::from(SINE_120[phase]);
        quadrature += normalized * i64::from(SINE_120[(phase + 12) % SINE_120.len()]);
    }
    in_phase * in_phase + quadrature * quadrature
}

struct SymbolCursor<'a> {
    samples: &'a [i16],
    offset: usize,
    samples_per_symbol: usize,
}

impl<'a> SymbolCursor<'a> {
    fn new(samples: &'a [i16], offset: usize, samples_per_symbol: usize) -> Self {
        Self {
            samples,
            offset,
            samples_per_symbol,
        }
    }

    fn bit(&mut self) -> Result<bool, Acoustic1Error> {
        let end = self
            .offset
            .checked_add(self.samples_per_symbol)
            .ok_or(Acoustic1Error::TruncatedSignal)?;
        let symbol = self
            .samples
            .get(self.offset..end)
            .ok_or(Acoustic1Error::TruncatedSignal)?;
        self.offset = end;
        Ok(symbol_energy(symbol, 1) > symbol_energy(symbol, 2))
    }

    fn raw_u16(&mut self) -> Result<u16, Acoustic1Error> {
        let mut value = 0_u16;
        for _ in 0..16 {
            value = (value << 1) | u16::from(self.bit()?);
        }
        Ok(value)
    }

    fn hamming_byte(&mut self) -> Result<u8, Acoustic1Error> {
        Ok((self.hamming_nibble()? << 4) | self.hamming_nibble()?)
    }

    fn hamming_nibble(&mut self) -> Result<u8, Acoustic1Error> {
        let mut codeword = [false; 7];
        for bit in &mut codeword {
            *bit = self.bit()?;
        }
        let syndrome = usize::from(codeword[0] ^ codeword[2] ^ codeword[4] ^ codeword[6])
            | (usize::from(codeword[1] ^ codeword[2] ^ codeword[5] ^ codeword[6]) << 1)
            | (usize::from(codeword[3] ^ codeword[4] ^ codeword[5] ^ codeword[6]) << 2);
        if syndrome != 0 {
            codeword[syndrome - 1] = !codeword[syndrome - 1];
        }
        Ok((u8::from(codeword[2]) << 3)
            | (u8::from(codeword[4]) << 2)
            | (u8::from(codeword[5]) << 1)
            | u8::from(codeword[6]))
    }

    fn samples_consumed(&self) -> usize {
        self.offset
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn test_object(profile: TransferProfile) -> WireObject {
        WireObject::text(73, "AC1", "Acoustic-1 test", profile).unwrap()
    }

    fn samples_with_single_symbol_flipped(
        object: &WireObject,
        symbol_index: usize,
        extra_symbols: &[usize],
    ) -> Vec<i16> {
        let config = profile_config(object.manifest.profile);
        let mut samples = encode_samples(object).unwrap();
        let original_bits = frame_bits(object).unwrap();
        for index in std::iter::once(symbol_index).chain(extra_symbols.iter().copied()) {
            let start = index * config.samples_per_symbol;
            let end = start + config.samples_per_symbol;
            let replacement = modulate(&[!original_bits[index]], config.samples_per_symbol);
            samples[start..end].copy_from_slice(&replacement);
        }
        samples
    }

    fn frame_bits(object: &WireObject) -> Result<Vec<bool>, Acoustic1Error> {
        let wire = object.encode()?;
        let mut bits = Vec::new();
        for index in 0..PREAMBLE_BITS {
            bits.push(index % 2 == 0);
        }
        append_raw_u16(&mut bits, SYNC_WORD);
        for byte in (wire.len() as u32).to_be_bytes() {
            append_hamming_byte(&mut bits, byte);
        }
        for byte in wire {
            append_hamming_byte(&mut bits, byte);
        }
        Ok(bits)
    }

    #[test]
    fn every_profile_round_trips_through_acoustic1_wav() {
        for config in PROFILE_CONFIGS {
            let object = test_object(config.profile);
            let decoded = decode_wav(&encode_wav(&object).unwrap()).unwrap();
            assert_eq!(decoded.object, object);
            assert_eq!(decoded.sample_rate_hz, SAMPLE_RATE_HZ);
            assert_eq!(decoded.frame_start_candidate_samples, 0);
        }
    }

    #[test]
    fn golden_acoustic1_fixture_decodes_and_matches_deterministic_encoder() {
        let fixture = include_bytes!("../tests/fixtures/acoustic-1-v1-text-balanced.wav");
        let expected = WireObject::text(
            1,
            "AC1GOLD",
            "AudioModem Acoustic-1 golden fixture v1",
            TransferProfile::Balanced,
        )
        .unwrap();
        let decoded = decode_wav(fixture).unwrap();
        assert_eq!(decoded.object, expected);
        assert_eq!(decoded.sample_rate_hz, SAMPLE_RATE_HZ);
        assert_eq!(decoded.samples_consumed, 358_560);
        assert_eq!(encode_wav(&expected).unwrap().as_slice(), fixture);
    }

    #[test]
    fn bounded_leading_silence_is_recovered() {
        let object = test_object(TransferProfile::Balanced);
        let mut samples = vec![0; 137];
        samples.extend(encode_samples(&object).unwrap());
        let decoded = decode_wav(&make_canonical_wav(&samples).unwrap()).unwrap();
        assert_eq!(decoded.object, object);
        assert!(decoded.frame_start_candidate_samples <= 137);
    }

    #[test]
    fn hamming_corrects_a_single_symbol_error_in_adlp_wire_data() {
        let object = test_object(TransferProfile::Balanced);
        let first_wire_codeword_symbol = PREAMBLE_BITS + 16 + 56;
        let samples = samples_with_single_symbol_flipped(&object, first_wire_codeword_symbol, &[]);
        let decoded = decode_wav(&make_canonical_wav(&samples).unwrap()).unwrap();
        assert_eq!(decoded.object, object);
    }

    #[test]
    fn double_symbol_error_is_rejected_by_adlp_integrity() {
        let object = test_object(TransferProfile::Balanced);
        let first_wire_codeword_symbol = PREAMBLE_BITS + 16 + 56;
        let samples = samples_with_single_symbol_flipped(
            &object,
            first_wire_codeword_symbol,
            &[first_wire_codeword_symbol + 1],
        );
        assert!(decode_wav(&make_canonical_wav(&samples).unwrap()).is_err());
    }

    #[test]
    fn bounded_additive_noise_preserves_frame() {
        let object = test_object(TransferProfile::Fast);
        let mut samples = encode_samples(&object).unwrap();
        for (index, sample) in samples.iter_mut().enumerate() {
            let noise = ((index.wrapping_mul(17).wrapping_add(23) % 401) as i16) - 200;
            *sample = sample.saturating_add(noise);
        }
        let decoded = decode_wav(&make_canonical_wav(&samples).unwrap()).unwrap();
        assert_eq!(decoded.object, object);
    }
}
