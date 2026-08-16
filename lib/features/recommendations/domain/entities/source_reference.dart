import 'package:equatable/equatable.dart';

class SourceReference extends Equatable {
  final String title;
  final String publisher;
  final Uri url;
  final String topic;
  final DateTime reviewedAt;

  const SourceReference({
    required this.title,
    required this.publisher,
    required this.url,
    required this.topic,
    required this.reviewedAt,
  });

  @override
  List<Object?> get props => [title, publisher, url, topic, reviewedAt];
}
