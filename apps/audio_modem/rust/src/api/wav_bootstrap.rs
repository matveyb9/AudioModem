//! Typed WAV bootstrap API: user text and callsign in, verified ADLP metadata out.
//! No live device, encryption, identity verification or file-object workflow is exposed here.

use adlp_protocol::{ObjectKind, TransferProfile, WireObject};
use audio_modem_core::{decode_wav, encode_wav, SAMPLE_RATE_HZ};

const MAX_BRIDGE_TEXT_BYTES: usize = 8 * 1024;

#[derive(Clone, Debug)]
pub struct EncodedWavTransfer {
    pub session_id: u64,
    pub profile: String,
    pub sample_rate_hz: u32,
    pub wav_bytes: Vec<u8>,
}

#[derive(Clone, Debug)]
pub struct DecodedTextTransfer {
    pub session_id: u64,
    pub sender_callsign: String,
    pub profile: String,
    pub text: String,
    pub sample_rate_hz: u32,
    pub samples_consumed: u32,
}

/// Encodes one text-only ADLP object into canonical 48 kHz mono 16-bit PCM WAV bytes.
pub fn encode_text_to_wav(
    session_id: u64,
    sender_callsign: String,
    text: String,
    profile: String,
) -> Result<EncodedWavTransfer, String> {
    if session_id == 0 {
        return Err("session_id must be positive".to_owned());
    }
    if text.len() > MAX_BRIDGE_TEXT_BYTES {
        return Err("text exceeds the 8 KiB WAV bootstrap application limit".to_owned());
    }
    let profile = parse_profile(&profile)?;
    let object = WireObject::text(session_id, sender_callsign, text, profile)
        .map_err(|error| error.to_string())?;
    let wav_bytes = encode_wav(&object).map_err(|error| error.to_string())?;
    Ok(EncodedWavTransfer {
        session_id,
        profile: profile.as_str().to_owned(),
        sample_rate_hz: SAMPLE_RATE_HZ,
        wav_bytes,
    })
}

/// Decodes and verifies canonical WAV bytes before exposing text metadata to Flutter.
pub fn decode_wav_text(wav_bytes: Vec<u8>) -> Result<DecodedTextTransfer, String> {
    let decoded = decode_wav(&wav_bytes).map_err(|error| error.to_string())?;
    if decoded.object.manifest.object_kind != ObjectKind::Text {
        return Err("the WAV contains a non-text ADLP object".to_owned());
    }
    let text = String::from_utf8(decoded.object.payload)
        .map_err(|_| "the ADLP text payload is not valid UTF-8".to_owned())?;
    let samples_consumed = u32::try_from(decoded.samples_consumed)
        .map_err(|_| "decoded sample count exceeds bridge return range".to_owned())?;
    Ok(DecodedTextTransfer {
        session_id: decoded.object.manifest.session_id,
        sender_callsign: decoded.object.manifest.sender_callsign,
        profile: decoded.object.manifest.profile.as_str().to_owned(),
        text,
        sample_rate_hz: decoded.sample_rate_hz,
        samples_consumed,
    })
}

fn parse_profile(value: &str) -> Result<TransferProfile, String> {
    match value {
        "reliable" => Ok(TransferProfile::Reliable),
        "balanced" => Ok(TransferProfile::Balanced),
        "fast" => Ok(TransferProfile::Fast),
        "narrowband" => Ok(TransferProfile::Narrowband),
        _ => Err("profile must be reliable, balanced, fast or narrowband".to_owned()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bridge_round_trip_preserves_text_metadata() {
        let encoded = encode_text_to_wav(
            7,
            "N1".to_owned(),
            "Hello from Flutter".to_owned(),
            "balanced".to_owned(),
        )
        .unwrap();
        let decoded = decode_wav_text(encoded.wav_bytes).unwrap();
        assert_eq!(decoded.session_id, 7);
        assert_eq!(decoded.sender_callsign, "N1");
        assert_eq!(decoded.profile, "balanced");
        assert_eq!(decoded.text, "Hello from Flutter");
        assert_eq!(decoded.sample_rate_hz, SAMPLE_RATE_HZ);
    }

    #[test]
    fn bridge_rejects_zero_session_and_unknown_profile() {
        assert!(
            encode_text_to_wav(0, "N1".to_owned(), "x".to_owned(), "balanced".to_owned()).is_err()
        );
        assert!(
            encode_text_to_wav(1, "N1".to_owned(), "x".to_owned(), "turbo".to_owned()).is_err()
        );
    }
}
