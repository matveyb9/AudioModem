// Local payload-file seam. Flutter selects/saves bytes while Rust owns ADLP object validation and WAV codecs.

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class SelectedPayloadFile {
  const SelectedPayloadFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

class SavedPayloadFile {
  const SavedPayloadFile({required this.name, required this.location});

  final String name;
  final Uri location;
}

abstract interface class PayloadFileAdapter {
  Future<SelectedPayloadFile?> openPayload();

  Future<SavedPayloadFile?> savePayload({
    required String suggestedName,
    required Uint8List bytes,
  });
}

class PlatformPayloadFileAdapter implements PayloadFileAdapter {
  const PlatformPayloadFileAdapter();

  @override
  Future<SelectedPayloadFile?> openPayload() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Выберите файл для ADLP передачи',
    );
    if (file == null) {
      return null;
    }
    return SelectedPayloadFile(
      name: file.name,
      bytes: await file.readAsBytes(),
    );
  }

  @override
  Future<SavedPayloadFile?> savePayload({
    required String suggestedName,
    required Uint8List bytes,
  }) async {
    final location = await FilePicker.saveFile(
      dialogTitle: 'Save decoded AudioModem file',
      fileName: suggestedName,
      bytes: bytes,
    );
    if (location == null) {
      return null;
    }
    return SavedPayloadFile(name: suggestedName, location: location);
  }
}
