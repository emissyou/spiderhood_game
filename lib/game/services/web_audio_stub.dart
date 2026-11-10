/// Stub implementation of WebAudioService for non-web platforms (Dart VM, tests).
class WebAudioService {
  static final WebAudioService instance = WebAudioService._();
  WebAudioService._();

  void playBgm(String relativePath, double volume) {}
  void stopBgm() {}
  void pauseBgm() {}
  void resumeBgm() {}
  void setBgmVolume(double volume) {}
  void playSfx(String relativePath, double volume) {}
}
