//! Versioned transfer container for the Audio Data Link Protocol (ADLP).
//!
//! The protocol crate deliberately knows nothing about audio devices, WAV
//! files or Flutter. It validates exactly the bytes a modem transports.

use std::fmt;

pub const MAGIC: [u8; 4] = *b"ADLP";
pub const PROTOCOL_VERSION: u8 = 1;
pub const MAX_PAYLOAD_BYTES: usize = 16 * 1024 * 1024;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
#[repr(u8)]
pub enum TransferProfile {
    Reliable = 1,
    Balanced = 2,
    Fast = 3,
    Narrowband = 4,
}

impl TransferProfile {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Reliable => "reliable",
            Self::Balanced => "balanced",
            Self::Fast => "fast",
            Self::Narrowband => "narrowband",
        }
    }

    pub fn from_byte(value: u8) -> Result<Self, ProtocolError> {
        match value {
            1 => Ok(Self::Reliable),
            2 => Ok(Self::Balanced),
            3 => Ok(Self::Fast),
            4 => Ok(Self::Narrowband),
            _ => Err(ProtocolError::UnsupportedProfile(value)),
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
#[repr(u8)]
pub enum ObjectKind {
    Text = 1,
    File = 2,
}

impl ObjectKind {
    fn from_byte(value: u8) -> Result<Self, ProtocolError> {
        match value {
            1 => Ok(Self::Text),
            2 => Ok(Self::File),
            _ => Err(ProtocolError::UnsupportedObjectKind(value)),
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TransferManifest {
    pub protocol_version: u8,
    pub profile: TransferProfile,
    pub session_id: u64,
    pub object_kind: ObjectKind,
    pub sender_callsign: String,
    pub mime_type: String,
    pub file_name: String,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct WireObject {
    pub manifest: TransferManifest,
    pub payload: Vec<u8>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum ProtocolError {
    Truncated,
    InvalidMagic,
    UnsupportedVersion(u8),
    UnsupportedProfile(u8),
    UnsupportedObjectKind(u8),
    InvalidUtf8,
    FieldTooLong(&'static str),
    PayloadTooLarge,
    IntegrityMismatch,
}

impl fmt::Display for ProtocolError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Truncated => write!(formatter, "truncated ADLP object"),
            Self::InvalidMagic => write!(formatter, "invalid ADLP magic"),
            Self::UnsupportedVersion(version) => {
                write!(formatter, "unsupported protocol version {version}")
            }
            Self::UnsupportedProfile(profile) => {
                write!(formatter, "unsupported transfer profile {profile}")
            }
            Self::UnsupportedObjectKind(kind) => {
                write!(formatter, "unsupported object kind {kind}")
            }
            Self::InvalidUtf8 => write!(formatter, "invalid UTF-8 manifest field"),
            Self::FieldTooLong(field) => {
                write!(formatter, "manifest field {field} exceeds its limit")
            }
            Self::PayloadTooLarge => write!(formatter, "payload exceeds the protocol limit"),
            Self::IntegrityMismatch => write!(formatter, "ADLP integrity check failed"),
        }
    }
}

impl std::error::Error for ProtocolError {}

impl WireObject {
    pub fn text(
        session_id: u64,
        callsign: impl Into<String>,
        text: impl Into<String>,
        profile: TransferProfile,
    ) -> Result<Self, ProtocolError> {
        let object = Self {
            manifest: TransferManifest {
                protocol_version: PROTOCOL_VERSION,
                profile,
                session_id,
                object_kind: ObjectKind::Text,
                sender_callsign: callsign.into(),
                mime_type: "text/plain; charset=utf-8".to_owned(),
                file_name: String::new(),
            },
            payload: text.into().into_bytes(),
        };
        object.validate()?;
        Ok(object)
    }

    pub fn encode(&self) -> Result<Vec<u8>, ProtocolError> {
        self.validate()?;
        let manifest = &self.manifest;
        let mut bytes = Vec::with_capacity(64 + self.payload.len());
        bytes.extend_from_slice(&MAGIC);
        bytes.push(manifest.protocol_version);
        bytes.push(manifest.profile as u8);
        bytes.push(manifest.object_kind as u8);
        bytes.extend_from_slice(&manifest.session_id.to_be_bytes());
        push_string(&mut bytes, "sender_callsign", &manifest.sender_callsign, 32)?;
        push_string(&mut bytes, "mime_type", &manifest.mime_type, 96)?;
        push_string(&mut bytes, "file_name", &manifest.file_name, 160)?;
        bytes.extend_from_slice(&(self.payload.len() as u32).to_be_bytes());
        bytes.extend_from_slice(&self.payload);
        bytes.extend_from_slice(&crc32c(&bytes).to_be_bytes());
        Ok(bytes)
    }

    pub fn decode(bytes: &[u8]) -> Result<Self, ProtocolError> {
        if bytes.len() < 26 {
            return Err(ProtocolError::Truncated);
        }
        let checksum_offset = bytes.len() - 4;
        let expected = u32::from_be_bytes(
            bytes[checksum_offset..]
                .try_into()
                .map_err(|_| ProtocolError::Truncated)?,
        );
        if crc32c(&bytes[..checksum_offset]) != expected {
            return Err(ProtocolError::IntegrityMismatch);
        }
        let mut cursor = Cursor::new(&bytes[..checksum_offset]);
        if cursor.take(4)? != MAGIC {
            return Err(ProtocolError::InvalidMagic);
        }
        let protocol_version = cursor.byte()?;
        if protocol_version != PROTOCOL_VERSION {
            return Err(ProtocolError::UnsupportedVersion(protocol_version));
        }
        let profile = TransferProfile::from_byte(cursor.byte()?)?;
        let object_kind = ObjectKind::from_byte(cursor.byte()?)?;
        let session_id = u64::from_be_bytes(
            cursor
                .take(8)?
                .try_into()
                .map_err(|_| ProtocolError::Truncated)?,
        );
        let sender_callsign = cursor.string(32)?;
        let mime_type = cursor.string(96)?;
        let file_name = cursor.string(160)?;
        let length = u32::from_be_bytes(
            cursor
                .take(4)?
                .try_into()
                .map_err(|_| ProtocolError::Truncated)?,
        ) as usize;
        if length > MAX_PAYLOAD_BYTES {
            return Err(ProtocolError::PayloadTooLarge);
        }
        let payload = cursor.take(length)?.to_vec();
        if !cursor.is_empty() {
            return Err(ProtocolError::Truncated);
        }
        let object = Self {
            manifest: TransferManifest {
                protocol_version,
                profile,
                session_id,
                object_kind,
                sender_callsign,
                mime_type,
                file_name,
            },
            payload,
        };
        object.validate()?;
        Ok(object)
    }

    fn validate(&self) -> Result<(), ProtocolError> {
        if self.manifest.protocol_version != PROTOCOL_VERSION {
            return Err(ProtocolError::UnsupportedVersion(
                self.manifest.protocol_version,
            ));
        }
        validate_string("sender_callsign", &self.manifest.sender_callsign, 32)?;
        validate_string("mime_type", &self.manifest.mime_type, 96)?;
        validate_string("file_name", &self.manifest.file_name, 160)?;
        if self.payload.len() > MAX_PAYLOAD_BYTES {
            return Err(ProtocolError::PayloadTooLarge);
        }
        Ok(())
    }
}

fn validate_string(
    field: &'static str,
    value: &str,
    max_bytes: usize,
) -> Result<(), ProtocolError> {
    if value.len() > max_bytes || value.len() > u8::MAX as usize {
        return Err(ProtocolError::FieldTooLong(field));
    }
    Ok(())
}

fn push_string(
    target: &mut Vec<u8>,
    field: &'static str,
    value: &str,
    max_bytes: usize,
) -> Result<(), ProtocolError> {
    validate_string(field, value, max_bytes)?;
    target.push(value.len() as u8);
    target.extend_from_slice(value.as_bytes());
    Ok(())
}

struct Cursor<'a> {
    bytes: &'a [u8],
    offset: usize,
}

impl<'a> Cursor<'a> {
    fn new(bytes: &'a [u8]) -> Self {
        Self { bytes, offset: 0 }
    }
    fn take(&mut self, length: usize) -> Result<&'a [u8], ProtocolError> {
        let end = self
            .offset
            .checked_add(length)
            .ok_or(ProtocolError::Truncated)?;
        let value = self
            .bytes
            .get(self.offset..end)
            .ok_or(ProtocolError::Truncated)?;
        self.offset = end;
        Ok(value)
    }
    fn byte(&mut self) -> Result<u8, ProtocolError> {
        Ok(self.take(1)?[0])
    }
    fn string(&mut self, max_bytes: usize) -> Result<String, ProtocolError> {
        let length = self.byte()? as usize;
        if length > max_bytes {
            return Err(ProtocolError::FieldTooLong("decoded_manifest_field"));
        }
        String::from_utf8(self.take(length)?.to_vec()).map_err(|_| ProtocolError::InvalidUtf8)
    }
    fn is_empty(&self) -> bool {
        self.offset == self.bytes.len()
    }
}

/// CRC-32C (Castagnoli), implemented locally to keep the bootstrap codec dependency-free.
pub fn crc32c(bytes: &[u8]) -> u32 {
    let mut value = !0_u32;
    for byte in bytes {
        value ^= u32::from(*byte);
        for _ in 0..8 {
            value = if value & 1 == 1 {
                (value >> 1) ^ 0x82F6_3B78
            } else {
                value >> 1
            };
        }
    }
    !value
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn text_round_trip_preserves_manifest_and_payload() {
        let object =
            WireObject::text(42, "N1", "Привет, AudioModem", TransferProfile::Balanced).unwrap();
        assert_eq!(
            WireObject::decode(&object.encode().unwrap()).unwrap(),
            object
        );
    }

    #[test]
    fn tampering_is_detected() {
        let object = WireObject::text(1, "N1", "hello", TransferProfile::Reliable).unwrap();
        let mut bytes = object.encode().unwrap();
        bytes[12] ^= 0x10;
        assert_eq!(
            WireObject::decode(&bytes),
            Err(ProtocolError::IntegrityMismatch)
        );
    }
}
