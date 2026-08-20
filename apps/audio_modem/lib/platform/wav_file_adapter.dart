// Local WAV file adapter. It owns only user file dialogs; Rust owns ADLP and WAV validation.

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class SelectedWavFile {
  const SelectedWavFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

class SavedWavFile {
  const SavedWavFile({required this.name, required this.location});

  final String name;
  final Uri location;
}

abstract interface class WavFileAdapter {
  Future<SelectedWavFile?> openWav();

  Future<SavedWavFile?> saveWav({
    required String suggestedName,
    required Uint8List bytes,
  });
}

class PlatformWavFileAdapter implements WavFileAdapter {
  const PlatformWavFileAdapter();

  @override
  Future<SelectedWavFile?> openWav() async {
    final selected = await FilePicker.pickFile(
      dialogTitle: 'Выберите WAV передачу',
      type: FileType.custom,
      allowedExtensions: const ['wav'],
    );
    if (selected == null) {
      return null;
    }
    return SelectedWavFile(
      name: selected.name,
      bytes: await selected.readAsBytes(),
    );
  }

  @override
  Future<SavedWavFile?> saveWav({
    required String suggestedName,
    required Uint8List bytes,
  }) async {
    final location = await FilePicker.saveFile(
      dialogTitle: 'Сохранить WAV передачу',
      fileName: suggestedName,
      bytes: bytes,
      mimeType: 'audio/wav',
      type: FileType.custom,
      allowedExtensions: const ['wav'],
    );
    if (location == null) {
      return null;
    }
    return SavedWavFile(name: suggestedName, location: location);
  }
}
