//! Typed WAV carrier API: user text/file data and callsign in, verified ADLP metadata out.
//! No live device, encryption or identity verification is exposed here.

use adlp_protocol::{ObjectKind, TransferProfile, WireObject};
use audio_modem_core::{
    acoustic1, decode_wav as decode_bootstrap_wav, encode_wav as encode_bootstrap_wav,
    SAMPLE_RATE_HZ,
};

const MAX_BRIDGE_TEXT_BYTES: usize = 8 * 1024;
const MAX_BRIDGE_FILE_BYTES: usize = 8 * 1024;

#[derive(Clone, Debug)]
pub struct EncodedWavTransfer {
    pub session_id: u64,
    pub profile: String,
    pub carrier: String,
    pub sample_rate_hz: u32,
    pub wav_bytes: Vec<u8>,
}

#[derive(Clone, Debug)]
pub struct DecodedTextTransfer {
    pub session_id: u64,
    pub sender_callsign: String,
    pub profile: String,
    pub carrier: String,
    pub text: String,
    pub sample_rate_hz: u32,
    pub samples_consumed: u32,
}

#[derive(Clone, Debug)]
pub struct DecodedFileTransfer {
    pub session_id: u64,
    pub sender_callsign: String,
    pub profile: String,
    pub carrier: String,
    pub file_name: String,
    pub mime_type: String,
    pub payload: Vec<u8>,
    pub sample_rate_hz: u32,
    pub samples_consumed: u32,
}

/// Encodes one text-only ADLP object into a selected canonical 48 kHz WAV carrier.
pub fn encode_text_to_wav(
    session_id: u64,
    sender_callsign: String,
    text: String,
    profile: String,
    carrier: String,
) -> Result<EncodedWavTransfer, String> {
    if session_id == 0 {
        return Err("session_id must be positive".to_owned());
    }
    if text.len() > MAX_BRIDGE_TEXT_BYTES {
        return Err("text exceeds the 8 KiB WAV carrier application limit".to_owned());
    }
    let profile = parse_profile(&profile)?;
    let carrier = parse_carrier(&carrier)?;
    let object = WireObject::text(session_id, sender_callsign, text, profile)
        .map_err(|error| error.to_string())?;
    let wav_bytes = match carrier {
        Carrier::Bootstrap => encode_bootstrap_wav(&object).map_err(|error| error.to_string())?,
        Carrier::Acoustic1 => acoustic1::encode_wav(&object).map_err(|error| error.to_string())?,
    };
    Ok(EncodedWavTransfer {
        session_id,
        profile: profile.as_str().to_owned(),
        carrier: carrier.as_str().to_owned(),
        sample_rate_hz: SAMPLE_RATE_HZ,
        wav_bytes,
    })
}

/// Encodes one bounded file ADLP object into a selected canonical 48 kHz WAV carrier.
pub fn encode_file_to_wav(
    session_id: u64,
    sender_callsign: String,
    file_name: String,
    mime_type: String,
    payload: Vec<u8>,
    profile: String,
    carrier: String,
) -> Result<EncodedWavTransfer, String> {
    if session_id == 0 {
        return Err("session_id must be positive".to_owned());
    }
    if payload.len() > MAX_BRIDGE_FILE_BYTES {
        return Err("file exceeds the 8 KiB WAV carrier application limit".to_owned());
    }
    let profile = parse_profile(&profile)?;
    let carrier = parse_carrier(&carrier)?;
    let object = WireObject::file(
        session_id,
        sender_callsign,
        file_name,
        mime_type,
        payload,
        profile,
    )
    .map_err(|error| error.to_string())?;
    let wav_bytes = match carrier {
        Carrier::Bootstrap => encode_bootstrap_wav(&object).map_err(|error| error.to_string())?,
        Carrier::Acoustic1 => acoustic1::encode_wav(&object).map_err(|error| error.to_string())?,
    };
    Ok(EncodedWavTransfer {
        session_id,
        profile: profile.as_str().to_owned(),
        carrier: carrier.as_str().to_owned(),
        sample_rate_hz: SAMPLE_RATE_HZ,
        wav_bytes,
    })
}

/// Decodes and verifies selected-carrier WAV bytes before exposing text metadata to Flutter.
pub fn decode_wav_text(wav_bytes: Vec<u8>, carrier: String) -> Result<DecodedTextTransfer, String> {
    let carrier = parse_carrier(&carrier)?;
    let (object, sample_rate_hz, samples_consumed) = decode_selected_wav(&wav_bytes, carrier)?;
    if object.manifest.object_kind != ObjectKind::Text {
        return Err("the WAV contains a non-text ADLP object".to_owned());
    }
    let text = String::from_utf8(object.payload)
        .map_err(|_| "the ADLP text payload is not valid UTF-8".to_owned())?;
    let samples_consumed = u32::try_from(samples_consumed)
        .map_err(|_| "decoded sample count exceeds bridge return range".to_owned())?;
    Ok(DecodedTextTransfer {
        session_id: object.manifest.session_id,
        sender_callsign: object.manifest.sender_callsign,
        profile: object.manifest.profile.as_str().to_owned(),
        carrier: carrier.as_str().to_owned(),
        text,
        sample_rate_hz,
        samples_consumed,
    })
}

/// Decodes and verifies selected-carrier WAV bytes before exposing file metadata and bytes to Flutter.
pub fn decode_wav_file(wav_bytes: Vec<u8>, carrier: String) -> Result<DecodedFileTransfer, String> {
    let carrier = parse_carrier(&carrier)?;
    let (object, sample_rate_hz, samples_consumed) = decode_selected_wav(&wav_bytes, carrier)?;
    if object.manifest.object_kind != ObjectKind::File {
        return Err("the WAV contains a non-file ADLP object".to_owned());
    }
    let samples_consumed = u32::try_from(samples_consumed)
        .map_err(|_| "decoded sample count exceeds bridge return range".to_owned())?;
    Ok(DecodedFileTransfer {
        session_id: object.manifest.session_id,
        sender_callsign: object.manifest.sender_callsign,
        profile: object.manifest.profile.as_str().to_owned(),
        carrier: carrier.as_str().to_owned(),
        file_name: object.manifest.file_name,
        mime_type: object.manifest.mime_type,
        payload: object.payload,
        sample_rate_hz,
        samples_consumed,
    })
}

fn decode_selected_wav(
    wav_bytes: &[u8],
    carrier: Carrier,
) -> Result<(WireObject, u32, usize), String> {
    match carrier {
        Carrier::Bootstrap => {
            let decoded = decode_bootstrap_wav(wav_bytes).map_err(|error| error.to_string())?;
            Ok((
                decoded.object,
                decoded.sample_rate_hz,
                decoded.samples_consumed,
            ))
        }
        Carrier::Acoustic1 => {
            let decoded = acoustic1::decode_wav(wav_bytes).map_err(|error| error.to_string())?;
            Ok((
                decoded.object,
                decoded.sample_rate_hz,
                decoded.samples_consumed,
            ))
        }
    }
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

#[derive(Clone, Copy)]
enum Carrier {
    Bootstrap,
    Acoustic1,
}

impl Carrier {
    fn as_str(self) -> &'static str {
        match self {
            Self::Bootstrap => "bootstrap",
            Self::Acoustic1 => "acoustic1",
        }
    }
}

fn parse_carrier(value: &str) -> Result<Carrier, String> {
    match value {
        "bootstrap" => Ok(Carrier::Bootstrap),
        "acoustic1" => Ok(Carrier::Acoustic1),
        _ => Err("carrier must be bootstrap or acoustic1".to_owned()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bridge_round_trip_preserves_bootstrap_text_metadata() {
        let encoded = encode_text_to_wav(
            7,
            "N1".to_owned(),
            "Hello from Flutter".to_owned(),
            "balanced".to_owned(),
            "bootstrap".to_owned(),
        )
        .unwrap();
        let decoded = decode_wav_text(encoded.wav_bytes, "bootstrap".to_owned()).unwrap();
        assert_eq!(decoded.session_id, 7);
        assert_eq!(decoded.sender_callsign, "N1");
        assert_eq!(decoded.profile, "balanced");
        assert_eq!(decoded.carrier, "bootstrap");
        assert_eq!(decoded.text, "Hello from Flutter");
        assert_eq!(decoded.sample_rate_hz, SAMPLE_RATE_HZ);
    }

    #[test]
    fn bridge_rejects_zero_session_and_unknown_profile() {
        assert!(encode_text_to_wav(
            0,
            "N1".to_owned(),
            "x".to_owned(),
            "balanced".to_owned(),
            "bootstrap".to_owned(),
        )
        .is_err());
        assert!(encode_text_to_wav(
            1,
            "N1".to_owned(),
            "x".to_owned(),
            "turbo".to_owned(),
            "bootstrap".to_owned(),
        )
        .is_err());
    }

    #[test]
    fn bridge_round_trips_experimental_acoustic1_metadata() {
        let encoded = encode_text_to_wav(
            8,
            "AC1".to_owned(),
            "Controlled carrier".to_owned(),
            "fast".to_owned(),
            "acoustic1".to_owned(),
        )
        .unwrap();
        let decoded = decode_wav_text(encoded.wav_bytes, "acoustic1".to_owned()).unwrap();
        assert_eq!(decoded.session_id, 8);
        assert_eq!(decoded.profile, "fast");
        assert_eq!(decoded.carrier, "acoustic1");
    }

    #[test]
    fn bridge_rejects_an_acoustic1_wav_with_bootstrap_decoder() {
        let encoded = encode_text_to_wav(
            9,
            "AC1".to_owned(),
            "Carrier contract".to_owned(),
            "balanced".to_owned(),
            "acoustic1".to_owned(),
        )
        .unwrap();
        assert!(decode_wav_text(encoded.wav_bytes, "bootstrap".to_owned()).is_err());
    }

    #[test]
    fn bridge_round_trips_bounded_file_metadata_and_payload() {
        let encoded = encode_file_to_wav(
            10,
            "FILE".to_owned(),
            "sample.bin".to_owned(),
            "application/octet-stream".to_owned(),
            vec![0, 1, 2, 255],
            "balanced".to_owned(),
            "bootstrap".to_owned(),
        )
        .unwrap();
        let decoded = decode_wav_file(encoded.wav_bytes, "bootstrap".to_owned()).unwrap();
        assert_eq!(decoded.session_id, 10);
        assert_eq!(decoded.sender_callsign, "FILE");
        assert_eq!(decoded.file_name, "sample.bin");
        assert_eq!(decoded.mime_type, "application/octet-stream");
        assert_eq!(decoded.payload, vec![0, 1, 2, 255]);
    }

    #[test]
    fn bridge_rejects_file_from_text_decoder_and_oversized_file() {
        let encoded = encode_file_to_wav(
            11,
            "FILE".to_owned(),
            "sample.bin".to_owned(),
            "application/octet-stream".to_owned(),
            vec![1],
            "balanced".to_owned(),
            "bootstrap".to_owned(),
        )
        .unwrap();
        assert!(decode_wav_text(encoded.wav_bytes, "bootstrap".to_owned()).is_err());
        assert!(encode_file_to_wav(
            12,
            "FILE".to_owned(),
            "oversized.bin".to_owned(),
            "application/octet-stream".to_owned(),
            vec![0; MAX_BRIDGE_FILE_BYTES + 1],
            "balanced".to_owned(),
            "bootstrap".to_owned(),
        )
        .is_err());
    }
}
