// Config: AgoraConfig
// Gamit: Dito nakalagay ang mga sensitibong keys at tokens para sa Agora Service.
// Siguraduhin na tama ang App ID para gumana ang voice/video call.
// Connected sa: voice_chat_screen.dart (para sa initialization ng engine at joinChannel)
class AgoraConfig {
  // Palitan ito ng iyong App ID mula sa Agora Console
  // Ito ang unique identifier ng project mo sa Agora system.
  static const String appId = '6bd237b746714e7da55fa28a1397f47c';

  // Authentication Token (Iwanang blangko kung App ID only mode o testing mode)
  // Sa production, dapat galing ito sa server para secure.
  static const String token = '';

  // Check if App ID is valid
  static bool get isValidAppId => appId.isNotEmpty && appId.length >= 32;
}
