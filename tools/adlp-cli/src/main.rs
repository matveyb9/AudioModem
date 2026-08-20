use std::{env, error::Error, fs, process};

use adlp_protocol::{ObjectKind, TransferProfile, WireObject};
use audio_modem_core::{acoustic1, decode_wav, encode_wav};

fn main() {
    if let Err(error) = run() {
        eprintln!("error: {error}\n\n{}", usage());
        process::exit(1);
    }
}

fn run() -> Result<(), Box<dyn Error>> {
    let args: Vec<String> = env::args().collect();
    match args.get(1).map(String::as_str) {
        Some("encode-text") => encode_text(&args, false),
        Some("encode-acoustic1-text") => encode_text(&args, true),
        Some("decode") => decode(&args, false),
        Some("decode-acoustic1") => decode(&args, true),
        _ => Err("unknown command".into()),
    }
}

fn encode_text(args: &[String], acoustic1_carrier: bool) -> Result<(), Box<dyn Error>> {
    let output = args.get(2).ok_or("missing output WAV path")?;
    let callsign = args.get(3).ok_or("missing callsign")?;
    let text = args.get(4).ok_or("missing text")?;
    let profile = args
        .get(5)
        .map(|value| parse_profile(value))
        .transpose()?
        .unwrap_or(TransferProfile::Balanced);
    let object = WireObject::text(1, callsign, text, profile)?;
    let carrier = if acoustic1_carrier {
        "Acoustic-1"
    } else {
        "bootstrap"
    };
    let wav = if acoustic1_carrier {
        acoustic1::encode_wav(&object)?
    } else {
        encode_wav(&object)?
    };
    fs::write(output, wav)?;
    println!(
        "encoded {} bytes as {} {} WAV transfer",
        object.payload.len(),
        profile.as_str(),
        carrier
    );
    Ok(())
}

fn decode(args: &[String], acoustic1_carrier: bool) -> Result<(), Box<dyn Error>> {
    let input = args.get(2).ok_or("missing input WAV path")?;
    let (object, samples_consumed) = if acoustic1_carrier {
        let decoded = acoustic1::decode_wav(&fs::read(input)?)?;
        (decoded.object, decoded.samples_consumed)
    } else {
        let decoded = decode_wav(&fs::read(input)?)?;
        (decoded.object, decoded.samples_consumed)
    };
    let manifest = object.manifest;
    println!(
        "carrier: {}",
        if acoustic1_carrier {
            "acoustic1"
        } else {
            "bootstrap"
        }
    );
    println!("protocol: ADLP/{}", manifest.protocol_version);
    println!("profile: {}", manifest.profile.as_str());
    println!("session: {}", manifest.session_id);
    println!("callsign: {}", manifest.sender_callsign);
    println!("samples: {samples_consumed}");
    match manifest.object_kind {
        ObjectKind::Text => println!("text: {}", String::from_utf8(object.payload)?),
        ObjectKind::File => println!("file payload: {} bytes", object.payload.len()),
    }
    Ok(())
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
    "Usage:\n  adlp-cli encode-text <output.wav> <callsign> <text> [reliable|balanced|fast|narrowband]\n  adlp-cli decode <input.wav>\n  adlp-cli encode-acoustic1-text <output.wav> <callsign> <text> [reliable|balanced|fast|narrowband]\n  adlp-cli decode-acoustic1 <input.wav>"
}
