use std::{env, error::Error, fs, process};

use adlp_protocol::{ObjectKind, TransferProfile, WireObject};
use audio_modem_core::{decode_wav, encode_wav};

fn main() {
    if let Err(error) = run() {
        eprintln!("error: {error}\n\n{}", usage());
        process::exit(1);
    }
}

fn run() -> Result<(), Box<dyn Error>> {
    let args: Vec<String> = env::args().collect();
    match args.get(1).map(String::as_str) {
        Some("encode-text") => {
            let output = args.get(2).ok_or("missing output WAV path")?;
            let callsign = args.get(3).ok_or("missing callsign")?;
            let text = args.get(4).ok_or("missing text")?;
            let profile = args
                .get(5)
                .map(|value| parse_profile(value))
                .transpose()?
                .unwrap_or(TransferProfile::Balanced);
            let object = WireObject::text(1, callsign, text, profile)?;
            fs::write(output, encode_wav(&object)?)?;
            println!(
                "encoded {} bytes as {} WAV transfer",
                object.payload.len(),
                profile.as_str()
            );
            Ok(())
        }
        Some("decode") => {
            let input = args.get(2).ok_or("missing input WAV path")?;
            let decoded = decode_wav(&fs::read(input)?)?;
            let manifest = decoded.object.manifest;
            println!("protocol: ADLP/{}", manifest.protocol_version);
            println!("profile: {}", manifest.profile.as_str());
            println!("session: {}", manifest.session_id);
            println!("callsign: {}", manifest.sender_callsign);
            println!("samples: {}", decoded.samples_consumed);
            match manifest.object_kind {
                ObjectKind::Text => {
                    println!("text: {}", String::from_utf8(decoded.object.payload)?)
                }
                ObjectKind::File => {
                    println!("file payload: {} bytes", decoded.object.payload.len())
                }
            }
            Ok(())
        }
        _ => Err("unknown command".into()),
    }
}

fn parse_profile(value: &str) -> Result<TransferProfile, Box<dyn Error>> {
    match value {
        "reliable" => Ok(TransferProfile::Reliable),
        "balanced" => Ok(TransferProfile::Balanced),
        "fast" => Ok(TransferProfile::Fast),
        "narrowband" => Ok(TransferProfile::Narrowband),
        _ => Err(format!("unknown profile {value:?}").into()),
    }
}

fn usage() -> &'static str {
    "Usage:\n  adlp-cli encode-text <output.wav> <callsign> <text> [reliable|balanced|fast|narrowband]\n  adlp-cli decode <input.wav>"
}
