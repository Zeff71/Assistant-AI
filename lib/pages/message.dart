import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String from;
  final String text;
  final DateTime timestamp;

  Message({
    required this.id,
    required this.from,
    required this.text,
    required this.timestamp,
  });

  factory Message.fromMap(String id, Map<String, dynamic> data) {
    return Message(
      id: id,
      from: data['from'] ?? 'user',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'from': from, 'text': text, 'timestamp': timestamp};
  }
}
