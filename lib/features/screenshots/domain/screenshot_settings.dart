class ScreenshotSettings {
  const ScreenshotSettings({
    this.enabled = true,
    this.folder = '',
    this.message = 'Automatic screenshot copying is starting.',
    this.watching = false,
  });
  factory ScreenshotSettings.fromMap(Map<Object?, Object?> data) =>
      ScreenshotSettings(
        enabled: data['screenshotsEnabled'] != false,
        folder: data['screenshotsFolder'] as String? ?? '',
        message:
            data['screenshotsStatus'] as String? ??
            'Automatic screenshot copying is starting.',
        watching: data['screenshotsWatching'] == true,
      );
  final bool enabled, watching;
  final String folder, message;
}
