import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class StreamExtractionService {
  /// Extracts the best audio stream URL using YoutubeExplode with Android VR client
  static Future<String?> getStreamUrl(String videoId) async {
    final yt = YoutubeExplode();
    try {
      debugPrint('FastExtraction: Extracting stream for $videoId');
      final manifest = await yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [YoutubeApiClient.androidVr],
      );

      final audioStreams = manifest.audioOnly;
      if (audioStreams.isNotEmpty) {
        final bestAudio = audioStreams.withHighestBitrate();
        debugPrint('FastExtraction: Found stream - ${bestAudio.url}');
        return bestAudio.url.toString();
      } else {
        debugPrint('FastExtraction: No audio streams found via YoutubeExplode.');
      }
    } catch (e) {
      debugPrint("FastExtraction Error (YoutubeExplode): $e");
    } finally {
      yt.close();
    }

    debugPrint('FastExtraction: Extraction failed — returning null.');
    return null;
  }
}
