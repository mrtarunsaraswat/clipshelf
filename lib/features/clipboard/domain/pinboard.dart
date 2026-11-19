class Pinboard {
  const Pinboard({required this.id, required this.name, required this.color});
  factory Pinboard.fromMap(Map<Object?, Object?> data) => Pinboard(
    id: data['id'] as String,
    name: data['name'] as String,
    color: data['color'] as int,
  );
  final String id, name;
  final int color;
}
