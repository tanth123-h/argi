class DeviceCalibration {
  final double moistureOffset;
  final double phOffset;
  final double ecMultiplier;

  const DeviceCalibration({
    this.moistureOffset = 0,
    this.phOffset = 0,
    this.ecMultiplier = 1,
  });

  double? moisture(double? value) =>
      value == null ? null : (value + moistureOffset).clamp(0, 100).toDouble();
  double? ph(double? value) =>
      value == null ? null : (value + phOffset).clamp(0, 14).toDouble();
  double? ec(double? value) => value == null ? null : value * ecMultiplier;
}
