
extension ListExtension<T> on List<T> {
  int getWrappedIndex(int currentIndexValue) {
    final totalLength = length;
    if (totalLength == 0) {
      return 0;
    } else if (currentIndexValue < 0) {
      currentIndexValue = totalLength + currentIndexValue;
      if (currentIndexValue < 0) {
        currentIndexValue = 0;
      }
    } else if (currentIndexValue >= totalLength) {
      currentIndexValue = currentIndexValue - totalLength;
      if (currentIndexValue >= totalLength) {
        currentIndexValue = totalLength - 1;
      }
    }
    return currentIndexValue;
  }
}
