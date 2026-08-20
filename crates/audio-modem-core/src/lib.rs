//! Deterministic bootstrap codec for an ADLP lossless WAV round trip.
//!
//! This is not yet an over-the-air acoustic PHY. It proves the boundary
//! between the ADLP container and a lossless audio transport. A future DSP
//! profile can replace this simple symbol mapper without changing ADLP bytes.

pub mod acoustic1;
pub mod acoustic2;

use std::fmt;

use adlp_protocol::{ProtocolError, WireObject};

pub const SAMPLE_RATE_HZ: u32 = 48_000;
pub const SAMPLES_PER_BIT: usize = 24;
pub const PREAMBLE_BITS: usize = 64;
pub const SYNC_WORD: u16 = 0xD3A5;
pub const MAX_WIRE_BYTES: usize = adlp_protocol::MAX_PAYLOAD_BYTES + 512;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct DecodedTransfer {
    pub object: WireObject,
    pub sample_rate_hz: u32,
    pub samples_consumed: usize,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum CodecError {
    Protocol(ProtocolError),
    InvalidWav(&'static str),
    TruncatedSignal,
    PreambleMismatch,
    SyncMismatch,
    WireObjectTooLarge,
}

impl fmt::Display for CodecError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Protocol(error) => write!(formatter, "protocol error: {error}"),
            Self::InvalidWav(reason) => write!(formatter, "unsupported WAV: {reason}"),
            Self::TruncatedSignal => write!(formatter, "truncated bootstrap signal"),
            Self::PreambleMismatch => write!(formatter, "bootstrap preamble mismatch"),
            Self::SyncMismatch => write!(formatter, "bootstrap sync word mismatch"),
            Self::WireObjectTooLarge => {
                write!(formatter, "encoded wire object exceeds bootstrap limit")
            }
        }
    }
}

impl std::error::Error for CodecError {}

impl From<ProtocolError> for CodecError {
    fn from(error: ProtocolError) -> Self {
        Self::Protocol(error)
    }
}

pub fn encode_wav(object: &WireObject) -> Result<Vec<u8>, CodecError> {
    let wire = object.encode()?;
    if wire.len() > MAX_WIRE_BYTES {
        return Err(CodecError::WireObjectTooLarge);
    }
    let mut samples =
        Vec::with_capacity((PREAMBLE_BITS + 16 + 32 + wire.len() * 8) * SAMPLES_PER_BIT);
    for index in 0..PREAMBLE_BITS {
        push_bit(&mut samples, index % 2 == 0);
    }
    push_u16(&mut samples, SYNC_WORD);
    push_u32(&mut samples, wire.len() as u32);
    for byte in wire {
        push_byte(&mut samples, byte);
    }
    make_canonical_wav(&samples)
}

pub fn decode_wav(wav: &[u8]) -> Result<DecodedTransfer, CodecError> {
    let (sample_rate_hz, samples) = parse_canonical_wav(wav)?;
    if sample_rate_hz != SAMPLE_RATE_HZ {
        return Err(CodecError::InvalidWav("sample rate must be 48 kHz"));
    }
    let mut cursor = BitCursor::new(&samples);
    for index in 0..PREAMBLE_BITS {
        if cursor.bit()? != (index % 2 == 0) {
            return Err(CodecError::PreambleMismatch);
        }
    }
    if cursor.u16()? != SYNC_WORD {
        return Err(CodecError::SyncMismatch);
    }
    let length = cursor.u32()? as usize;
    if length > MAX_WIRE_BYTES {
        return Err(CodecError::WireObjectTooLarge);
    }
    let mut wire = Vec::with_capacity(length);
    for _ in 0..length {
        wire.push(cursor.byte()?);
    }
    Ok(DecodedTransfer {
        object: WireObject::decode(&wire)?,
        sample_rate_hz,
        samples_consumed: cursor.samples_consumed(),
    })
}

fn push_bit(samples: &mut Vec<i16>, bit: bool) {
    let amplitude = if bit { 18_000 } else { -18_000 };
    samples.resize(samples.len() + SAMPLES_PER_BIT, amplitude);
}

fn push_byte(samples: &mut Vec<i16>, byte: u8) {
    for offset in (0..8).rev() {
        push_bit(samples, byte & (1 << offset) != 0);
    }
}

fn push_u16(samples: &mut Vec<i16>, value: u16) {
    for byte in value.to_be_bytes() {
        push_byte(samples, byte);
    }
}

fn push_u32(samples: &mut Vec<i16>, value: u32) {
    for byte in value.to_be_bytes() {
        push_byte(samples, byte);
    }
}

pub(crate) fn make_canonical_wav(samples: &[i16]) -> Result<Vec<u8>, CodecError> {
    let data_len = samples
        .len()
        .checked_mul(2)
        .ok_or(CodecError::WireObjectTooLarge)?;
    let file_len = 36_usize
        .checked_add(data_len)
        .ok_or(CodecError::WireObjectTooLarge)?;
    if file_len > u32::MAX as usize {
        return Err(CodecError::WireObjectTooLarge);
    }
    let mut wav = Vec::with_capacity(44 + data_len);
    wav.extend_from_slice(b"RIFF");
    wav.extend_from_slice(&(file_len as u32).to_le_bytes());
    wav.extend_from_slice(b"WAVEfmt ");
    wav.extend_from_slice(&16_u32.to_le_bytes());
    wav.extend_from_slice(&1_u16.to_le_bytes());
    wav.extend_from_slice(&1_u16.to_le_bytes());
    wav.extend_from_slice(&SAMPLE_RATE_HZ.to_le_bytes());
    wav.extend_from_slice(&(SAMPLE_RATE_HZ * 2).to_le_bytes());
    wav.extend_from_slice(&2_u16.to_le_bytes());
    wav.extend_from_slice(&16_u16.to_le_bytes());
    wav.extend_from_slice(b"data");
    wav.extend_from_slice(&(data_len as u32).to_le_bytes());
    for sample in samples {
        wav.extend_from_slice(&sample.to_le_bytes());
    }
    Ok(wav)
}

pub(crate) fn parse_canonical_wav(wav: &[u8]) -> Result<(u32, Vec<i16>), CodecError> {
    if wav.len() < 44 || &wav[0..4] != b"RIFF" || &wav[8..12] != b"WAVE" {
        return Err(CodecError::InvalidWav("expected RIFF/WAVE header"));
    }
    if &wav[12..16] != b"fmt " || le_u32(&wav[16..20])? != 16 {
        return Err(CodecError::InvalidWav("expected canonical PCM fmt chunk"));
    }
    if le_u16(&wav[20..22])? != 1 || le_u16(&wav[22..24])? != 1 || le_u16(&wav[34..36])? != 16 {
        return Err(CodecError::InvalidWav("expected mono 16-bit PCM"));
    }
    if &wav[36..40] != b"data" {
        return Err(CodecError::InvalidWav("expected data chunk"));
    }
    let length = le_u32(&wav[40..44])? as usize;
    let end = 44_usize
        .checked_add(length)
        .ok_or(CodecError::TruncatedSignal)?;
    if length & 1 != 0 || end > wav.len() {
        return Err(CodecError::TruncatedSignal);
    }
    let samples = wav[44..end]
        .chunks_exact(2)
        .map(|chunk| i16::from_le_bytes([chunk[0], chunk[1]]))
        .collect();
    Ok((le_u32(&wav[24..28])?, samples))
}

fn le_u16(bytes: &[u8]) -> Result<u16, CodecError> {
    let pair: [u8; 2] = bytes.try_into().map_err(|_| CodecError::TruncatedSignal)?;
    Ok(u16::from_le_bytes(pair))
}

fn le_u32(bytes: &[u8]) -> Result<u32, CodecError> {
    let quad: [u8; 4] = bytes.try_into().map_err(|_| CodecError::TruncatedSignal)?;
    Ok(u32::from_le_bytes(quad))
}

struct BitCursor<'a> {
    samples: &'a [i16],
    offset: usize,
}

impl<'a> BitCursor<'a> {
    fn new(samples: &'a [i16]) -> Self {
        Self { samples, offset: 0 }
    }
    fn bit(&mut self) -> Result<bool, CodecError> {
        let end = self
            .offset
            .checked_add(SAMPLES_PER_BIT)
            .ok_or(CodecError::TruncatedSignal)?;
        let window = self
            .samples
            .get(self.offset..end)
            .ok_or(CodecError::TruncatedSignal)?;
        self.offset = end;
        Ok(window.iter().map(|sample| i64::from(*sample)).sum::<i64>() >= 0)
    }
    fn byte(&mut self) -> Result<u8, CodecError> {
        let mut value = 0_u8;
        for _ in 0..8 {
            value = (value << 1) | u8::from(self.bit()?);
        }
        Ok(value)
    }
    fn u16(&mut self) -> Result<u16, CodecError> {
        Ok(u16::from_be_bytes([self.byte()?, self.byte()?]))
    }
    fn u32(&mut self) -> Result<u32, CodecError> {
        Ok(u32::from_be_bytes([
            self.byte()?,
            self.byte()?,
            self.byte()?,
            self.byte()?,
        ]))
    }
    fn samples_consumed(&self) -> usize {
        self.offset
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use adlp_protocol::TransferProfile;

    const GOLDEN_WAV: &[u8] = include_bytes!("../tests/fixtures/adlp-v1-text-balanced.wav");

    #[test]
    fn wav_round_trip_preserves_adlp_object() {
        let object =
            WireObject::text(7, "N1", "WAV is a transport", TransferProfile::Reliable).unwrap();
        let decoded = decode_wav(&encode_wav(&object).unwrap()).unwrap();
        assert_eq!(decoded.object, object);
        assert_eq!(decoded.sample_rate_hz, SAMPLE_RATE_HZ);
    }

    #[test]
    fn damaged_wav_does_not_decode() {
        let object = WireObject::text(7, "N1", "integrity", TransferProfile::Fast).unwrap();
        let mut wav = encode_wav(&object).unwrap();
        let first_wire_symbol = 44 + (PREAMBLE_BITS + 16 + 32) * SAMPLES_PER_BIT * 2;
        wav[first_wire_symbol..first_wire_symbol + SAMPLES_PER_BIT * 2].fill(0);
        assert!(decode_wav(&wav).is_err());
    }

    #[test]
    fn golden_wav_fixture_decodes_and_matches_deterministic_encoder() {
        let expected = WireObject::text(
            1,
            "GOLDEN1",
            "AudioModem ADLP golden fixture v1",
            TransferProfile::Balanced,
        )
        .unwrap();
        let decoded = decode_wav(GOLDEN_WAV).unwrap();

        assert_eq!(decoded.object, expected);
        assert_eq!(decoded.sample_rate_hz, SAMPLE_RATE_HZ);
        assert_eq!(decoded.samples_consumed, 20_160);
        assert_eq!(encode_wav(&expected).unwrap(), GOLDEN_WAV);
    }
}
