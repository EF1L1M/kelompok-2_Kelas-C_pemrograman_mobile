// ============================================================================
// ADVANCE DART: GENERICS & SEALED CLASS (DART 3 PATTERN MATCHING)
// Penanggung Jawab: Anggota 2 (Tabel 1.3 & Bab 2.9)
// Pembungkus generik untuk respons API Open-Source (Frankfurter & OCR API).
// ============================================================================

sealed class ApiResponse<T> {
  const ApiResponse();
}

final class ApiLoading<T> extends ApiResponse<T> {
  final String message;
  const ApiLoading([this.message = 'Memuat data dari API...']);
}

final class ApiSuccess<T> extends ApiResponse<T> {
  final T data;
  final bool isFromFallbackCache;
  final int executionTimeMs;

  const ApiSuccess({
    required this.data,
    this.isFromFallbackCache = false,
    this.executionTimeMs = 0,
  });
}

final class ApiFailure<T> extends ApiResponse<T> {
  final String errorMessage;
  final int? statusCode;
  final T? fallbackData;

  const ApiFailure({
    required this.errorMessage,
    this.statusCode,
    this.fallbackData,
  });
}
