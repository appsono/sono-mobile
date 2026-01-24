import 'package:on_audio_query/on_audio_query.dart';

class UnifiedAudioModel {
  final int id;
  final String title;
  final String? artist;
  final String? album;
  final int? duration;
  final String? artworkPath;
  final String audioPath;
  final bool isRemote;
  final Map<String, dynamic>? remoteData;

  UnifiedAudioModel({
    required this.id,
    required this.title,
    this.artist,
    this.album,
    this.duration,
    this.artworkPath,
    required this.audioPath,
    required this.isRemote,
    this.remoteData,
  });

  factory UnifiedAudioModel.fromLocal(SongModel song) {
    return UnifiedAudioModel(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.duration,
      artworkPath: null,
      audioPath: song.uri ?? '',
      isRemote: false,
    );
  }

  factory UnifiedAudioModel.fromRemote(Map<String, dynamic> audioFile) {
    return UnifiedAudioModel(
      id: audioFile['id'],
      title: audioFile['title'] ?? audioFile['original_filename'] ?? 'Unknown',
      artist: audioFile['artist'] ?? 'Unknown Artist',
      album: audioFile['album'],
      duration: audioFile['duration'],
      artworkPath: null,
      audioPath: audioFile['file_url'],
      isRemote: true,
      remoteData: audioFile,
    );
  }

  SongModel? toSongModel() {
    if (isRemote) return null;

    return SongModel({
      '_id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'duration': duration,
      'uri': audioPath,
    });
  }
}