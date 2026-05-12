import 'package:xml/xml.dart';

class Track {
  final String id;
  final String title;
  final String artist;
  final String coverArt;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.coverArt,
  });

  factory Track.fromXml(XmlElement element) {
    return Track(
      id: element.getAttribute('id') ?? '',
      title: element.getAttribute('title') ?? '',
      artist: element.getAttribute('artist') ?? '',
      coverArt: element.getAttribute('coverArt') ?? '',
    );
  }
}
