/// Sealed Result type for domain layer operations.
/// Never throw exceptions across layer boundaries — return Result instead.
sealed class Result<T> {
  const Result();
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> extends Result<T> {
  final AppFailure failure;
  const Failure(this.failure);
}

// ---------------------------------------------------------------------------
// Failure hierarchy
// ---------------------------------------------------------------------------

sealed class AppFailure {
  final String messageEn;
  final String messageThai;
  const AppFailure({required this.messageEn, required this.messageThai});
}

class NetworkFailure extends AppFailure {
  const NetworkFailure()
      : super(
          messageEn: 'No internet connection',
          messageThai: 'ไม่มีการเชื่อมต่ออินเทอร์เน็ต',
        );
}

class TimeoutFailure extends AppFailure {
  const TimeoutFailure()
      : super(
          messageEn: 'Request timed out',
          messageThai: 'การเชื่อมต่อใช้เวลานานเกินไป กรุณาลองใหม่',
        );
}

class DatabaseFailure extends AppFailure {
  final String? detail;
  const DatabaseFailure([this.detail])
      : super(
          messageEn: 'Database error',
          messageThai: 'เกิดข้อผิดพลาดในการบันทึกข้อมูล กรุณาลองใหม่',
        );
}

class NotFoundFailure extends AppFailure {
  const NotFoundFailure()
      : super(
          messageEn: 'Resource not found',
          messageThai: 'ไม่พบข้อมูลที่ต้องการ',
        );
}

class AuthFailure extends AppFailure {
  const AuthFailure.invalidCredentials()
      : super(
          messageEn: 'Invalid credentials',
          messageThai: 'อีเมล/เบอร์โทร หรือรหัสผ่านไม่ถูกต้อง',
        );
  const AuthFailure.identifierAlreadyExists()
      : super(
          messageEn: 'Identifier already registered',
          messageThai: 'อีเมลหรือเบอร์โทรศัพท์นี้ถูกใช้งานแล้ว',
        );
  const AuthFailure.weakPassword()
      : super(
          messageEn: 'Password too weak',
          messageThai:
              'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษรและมีตัวเลขอย่างน้อย 1 ตัว',
        );
  const AuthFailure.sessionExpired()
      : super(
          messageEn: 'Session expired',
          messageThai: 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่',
        );
}

class ValidationFailure extends AppFailure {
  final String field;
  const ValidationFailure.required(this.field)
      : super(
          messageEn: 'Required field missing: $field',
          messageThai: 'กรุณากรอกข้อมูลที่จำเป็น',
        );
  const ValidationFailure.areaOutOfRange(this.field)
      : super(
          messageEn: 'Area must be between 0 and 10,000 rai',
          messageThai: 'ขนาดพื้นที่ต้องอยู่ระหว่าง 0 ถึง 10,000 ไร่',
        );
}

class OfflineFailure extends AppFailure {
  const OfflineFailure()
      : super(
          messageEn: 'Device is offline',
          messageThai: 'ฟีเจอร์นี้ต้องการการเชื่อมต่ออินเทอร์เน็ต',
        );
}

class SyncFailure extends AppFailure {
  const SyncFailure()
      : super(
          messageEn: 'Sync failed',
          messageThai:
              'ไม่สามารถซิงค์ข้อมูลได้ ข้อมูลจะถูกส่งเมื่อมีการเชื่อมต่ออีกครั้ง',
        );
}

class AiFailure extends AppFailure {
  const AiFailure()
      : super(
          messageEn: 'AI service unavailable',
          messageThai: 'ไม่สามารถเชื่อมต่อ AI ได้ กรุณาลองใหม่',
        );
}

class DiseaseDetectionFailure extends AppFailure {
  const DiseaseDetectionFailure()
      : super(
          messageEn: 'Could not analyse image',
          messageThai:
              'ไม่สามารถวิเคราะห์ภาพได้ กรุณาถ่ายภาพใหม่ในที่ที่มีแสงสว่างเพียงพอ',
        );
}

class DemoWriteBlockedFailure extends AppFailure {
  const DemoWriteBlockedFailure()
      : super(
          messageEn: 'Write operations disabled in Demo Mode',
          messageThai:
              'ฟีเจอร์นี้ไม่พร้อมใช้งานในโหมดสาธิต กรุณาสมัครสมาชิก',
        );
}

class UnexpectedFailure extends AppFailure {
  final String? detail;
  const UnexpectedFailure([this.detail])
      : super(
          messageEn: 'Unexpected error',
          messageThai:
              'เกิดข้อผิดพลาดที่ไม่คาดคิด กรุณาลองใหม่หรือติดต่อผู้ดูแลระบบ',
        );
}
