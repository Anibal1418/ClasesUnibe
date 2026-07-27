class DataServiceException implements Exception {
  const DataServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
