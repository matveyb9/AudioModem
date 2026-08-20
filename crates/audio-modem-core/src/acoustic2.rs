//! Experimental Acoustic-2 controlled PCM measurement harness.
//!
//! This module applies declared deterministic sample-domain transforms around
//! Acoustic-1 WAV decoding. It does not represent a live audio route, a device,
//! SNR/BER measurement, timing-recovery loop, or acoustic interoperability.

use std::fmt;

use adlp_protocol::TransferProfile;

use crate::{acoustic1, make_canonical_wav, parse_canonical_wav, CodecError, SAMPLE_RATE_HZ};

pub const MAX_LEADING_SILENCE_SAMPLES: usize = acoustic1::MAX_SYNC_OFFSET_SAMPLES;
pub const MAX_NOISE_PEAK: i16 = 1_000;

/// A reproducible integer-domain transform applied to an Acoustic-1 PCM/WAV.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct PcmImpairment {
    pub leading_silence_samples: usize,
    pub gain_per_mille: u16,
    pub noise_peak: i16,
    pub noise_seed: u32,
    pub clip_abs: Option<i16>,
    pub drop_every_nth_sample: Option<usize>,
}

impl Default for PcmImpairment {
    fn default() -> Self {
        Self {
            leading_silence_samples: 0,
            gain_per_mille: 1_000,
            noise_peak: 0,
            noise_seed: 0,
            clip_abs: None,
            drop_every_nth_sample: None,
        }
    }
}

/// Codec-observable output from a named controlled PCM measurement.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Acoustic2Measurement {
    pub sample_rate_hz: u32,
    pub input_samples: usize,
    pub output_samples: usize,
    pub dropped_samples: usize,
    pub leading_silence_samples: usize,
    pub acquisition_offset_samples: usize,
    pub samples_consumed: usize,
    pub profile: TransferProfile,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum Acoustic2Error {
    Codec(CodecError),
    Acoustic1(acoustic1::Acoustic1Error),
    LeadingSilenceOutOfRange,
    GainOutOfRange,
    NoiseOutOfRange,
    ClipOutOfRange,
    DropIntervalOutOfRange,
}

impl fmt::Display for Acoustic2Error {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Codec(error) => write!(formatter, "WAV error: {error}"),
            Self::Acoustic1(error) => write!(formatter, "Acoustic-1 error: {error}"),
            Self::LeadingSilenceOutOfRange => write!(
                formatter,
                "leading silence exceeds Acoustic-1 bounded acquisition window"
            ),
            Self::GainOutOfRange => write!(formatter, "gain must be between 1 and 1,000 per mille"),
            Self::NoiseOutOfRange => write!(formatter, "noise peak must be between 0 and 1,000"),
            Self::ClipOutOfRange => {
                write!(formatter, "clip threshold must be between 1 and 32,767")
            }
            Self::DropIntervalOutOfRange => {
                write!(formatter, "sample drop interval must be at least two")
            }
        }
    }
}

impl std::error::Error for Acoustic2Error {}

impl From<CodecError> for Acoustic2Error {
    fn from(error: CodecError) -> Self {
        Self::Codec(error)
    }
}

impl From<acoustic1::Acoustic1Error> for Acoustic2Error {
    fn from(error: acoustic1::Acoustic1Error) -> Self {
        Self::Acoustic1(error)
    }
}

/// Applies a declared controlled PCM impairment and measures Acoustic-1 decode.
pub fn measure_acoustic1_wav(
    wav: &[u8],
    impairment: &PcmImpairment,
) -> Result<Acoustic2Measurement, Acoustic2Error> {
    validate_impairment(impairment)?;
    let (sample_rate_hz, samples) = parse_canonical_wav(wav)?;
    if sample_rate_hz != SAMPLE_RATE_HZ {
        return Err(Acoustic2Error::Codec(CodecError::InvalidWav(
            "sample rate must be 48 kHz",
        )));
    }
    let (transformed, dropped_samples) = apply_impairment(&samples, impairment);
    let transformed_wav = make_canonical_wav(&transformed)?;
    let decoded = acoustic1::decode_wav(&transformed_wav)?;
    Ok(Acoustic2Measurement {
        sample_rate_hz,
        input_samples: samples.len(),
        output_samples: transformed.len(),
        dropped_samples,
        leading_silence_samples: impairment.leading_silence_samples,
        acquisition_offset_samples: decoded.frame_start_candidate_samples,
        samples_consumed: decoded.samples_consumed,
        profile: decoded.object.manifest.profile,
    })
}

fn validate_impairment(impairment: &PcmImpairment) -> Result<(), Acoustic2Error> {
    if impairment.leading_silence_samples > MAX_LEADING_SILENCE_SAMPLES {
        return Err(Acoustic2Error::LeadingSilenceOutOfRange);
    }
    if impairment.gain_per_mille == 0 || impairment.gain_per_mille > 1_000 {
        return Err(Acoustic2Error::GainOutOfRange);
    }
    if !(0..=MAX_NOISE_PEAK).contains(&impairment.noise_peak) {
        return Err(Acoustic2Error::NoiseOutOfRange);
    }
    if impairment.clip_abs.is_some_and(|clip| clip <= 0) {
        return Err(Acoustic2Error::ClipOutOfRange);
    }
    if impairment
        .drop_every_nth_sample
        .is_some_and(|interval| interval < 2)
    {
        return Err(Acoustic2Error::DropIntervalOutOfRange);
    }
    Ok(())
}

fn apply_impairment(samples: &[i16], impairment: &PcmImpairment) -> (Vec<i16>, usize) {
    let mut state = impairment.noise_seed;
    let mut transformed = Vec::with_capacity(samples.len() + impairment.leading_silence_samples);
    let mut dropped_samples = 0;
    for (index, sample) in samples.iter().enumerate() {
        let mut value = (i32::from(*sample) * i32::from(impairment.gain_per_mille)) / 1_000;
        state = state.wrapping_mul(1_664_525).wrapping_add(1_013_904_223);
        if impairment.noise_peak != 0 {
            let span = u32::try_from(i32::from(impairment.noise_peak) * 2 + 1)
                .expect("validated noise span fits u32");
            value += i32::try_from(state % span).expect("noise sample fits i32")
                - i32::from(impairment.noise_peak);
        }
        if let Some(clip) = impairment.clip_abs {
            value = value.clamp(-i32::from(clip), i32::from(clip));
        }
        if impairment
            .drop_every_nth_sample
            .is_some_and(|interval| (index + 1) % interval == 0)
        {
            dropped_samples += 1;
            continue;
        }
        transformed.push(value.clamp(i32::from(i16::MIN), i32::from(i16::MAX)) as i16);
    }
    if impairment.leading_silence_samples != 0 {
        let mut with_silence = vec![0; impairment.leading_silence_samples];
        with_silence.extend(transformed);
        return (with_silence, dropped_samples);
    }
    (transformed, dropped_samples)
}

#[cfg(test)]
mod tests {
    use super::*;
    use adlp_protocol::WireObject;

    const ACOUSTIC1_GOLDEN_WAV: &[u8] =
        include_bytes!("../tests/fixtures/acoustic-1-v1-text-balanced.wav");

    fn test_wav() -> Vec<u8> {
        let object = WireObject::text(
            91,
            "AC2",
            "Acoustic-2 measurement",
            TransferProfile::Balanced,
        )
        .unwrap();
        acoustic1::encode_wav(&object).unwrap()
    }

    #[test]
    fn baseline_reports_acoustic1_observables() {
        let measurement = measure_acoustic1_wav(&test_wav(), &PcmImpairment::default()).unwrap();
        assert_eq!(measurement.sample_rate_hz, SAMPLE_RATE_HZ);
        assert_eq!(measurement.acquisition_offset_samples, 0);
        assert_eq!(measurement.dropped_samples, 0);
        assert_eq!(measurement.profile, TransferProfile::Balanced);
        assert!(measurement.samples_consumed > 0);
    }

    #[test]
    fn bounded_silence_attenuation_and_seeded_noise_are_measured() {
        let impairment = PcmImpairment {
            leading_silence_samples: 137,
            gain_per_mille: 500,
            noise_peak: 200,
            noise_seed: 0xAC02_0001,
            clip_abs: Some(8_000),
            drop_every_nth_sample: None,
        };
        let measurement = measure_acoustic1_wav(&test_wav(), &impairment).unwrap();
        assert_eq!(measurement.leading_silence_samples, 137);
        assert!(measurement.acquisition_offset_samples <= 137);
        assert_eq!(measurement.profile, TransferProfile::Balanced);
    }

    #[test]
    fn periodic_sample_deletion_is_rejected_in_the_declared_vector() {
        let impairment = PcmImpairment {
            drop_every_nth_sample: Some(113),
            ..PcmImpairment::default()
        };
        assert!(measure_acoustic1_wav(&test_wav(), &impairment).is_err());
    }

    #[test]
    fn bounds_are_rejected_before_wav_transforms() {
        let leading = PcmImpairment {
            leading_silence_samples: MAX_LEADING_SILENCE_SAMPLES + 1,
            ..PcmImpairment::default()
        };
        assert_eq!(
            measure_acoustic1_wav(&test_wav(), &leading).unwrap_err(),
            Acoustic2Error::LeadingSilenceOutOfRange
        );
        let invalid_drop = PcmImpairment {
            drop_every_nth_sample: Some(1),
            ..PcmImpairment::default()
        };
        assert_eq!(
            measure_acoustic1_wav(&test_wav(), &invalid_drop).unwrap_err(),
            Acoustic2Error::DropIntervalOutOfRange
        );
    }

    #[test]
    fn seeded_transform_is_byte_deterministic() {
        let (_, source_samples) = parse_canonical_wav(&test_wav()).unwrap();
        let impairment = PcmImpairment {
            noise_peak: 200,
            noise_seed: 42,
            clip_abs: Some(9_000),
            ..PcmImpairment::default()
        };
        assert_eq!(
            apply_impairment(&source_samples, &impairment),
            apply_impairment(&source_samples, &impairment)
        );
    }

    #[test]
    fn golden_measurement_matches_acoustic1_fixture_contract() {
        let impairment = PcmImpairment {
            leading_silence_samples: 137,
            gain_per_mille: 500,
            noise_peak: 200,
            noise_seed: 2_885_812_225,
            clip_abs: Some(8_000),
            drop_every_nth_sample: None,
        };
        let measurement = measure_acoustic1_wav(ACOUSTIC1_GOLDEN_WAV, &impairment).unwrap();
        assert_eq!(measurement.sample_rate_hz, SAMPLE_RATE_HZ);
        assert_eq!(measurement.input_samples, 358_560);
        assert_eq!(measurement.output_samples, 358_697);
        assert_eq!(measurement.dropped_samples, 0);
        assert_eq!(measurement.leading_silence_samples, 137);
        assert_eq!(measurement.acquisition_offset_samples, 21);
        assert_eq!(measurement.samples_consumed, 358_581);
        assert_eq!(measurement.profile, TransferProfile::Balanced);
    }
}
