import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Para sa kIsWeb check
import 'package:agora_rtc_engine/agora_rtc_engine.dart'; // Agora SDK para sa voice/video functionality
import 'package:permission_handler/permission_handler.dart'; // Para sa paghingi ng mic/cam permission sa device
import 'package:firebase_auth/firebase_auth.dart'; // Para makuha ang current user details
import 'package:cloud_firestore/cloud_firestore.dart'; // Para sa database ng participants (syncing state)
import '../config/agora_config.dart'; // Configuration file para sa App ID at Token

// Widget: VoiceChatScreen (already well-commented)
// Gamit: Voice/video call screen with participants grid, mute/video toggle, Agora + Firestore sync.
// Connected sa: agora_config.dart (AppID/token), server_screen.dart (navigation).
class VoiceChatScreen extends StatefulWidget {
  // Ang unique ID ng channel na sasalihan
  final String channelId;
  // Ang pangalan ng channel na idi-display sa taas
  final String channelName;

  const VoiceChatScreen({
    super.key,
    required this.channelId,
    required this.channelName,
  });

  @override
  State<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen> {
  // Mga Variables para sa State ng Call
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  // State variables para sa UI at logic
  bool _isMuted = false; // Status kung naka-mute ang mic ng local user
  bool _isConnected =
      false; // Status kung successful nang nakapasok sa Agora channel
  bool _isVideoEnabled = false; // Status kung naka-on ang camera ng local user
  Set<int> _activeSpeakers = {}; // Listahan ng mga UIDs na nagsasalita ngayon
  RtcEngine?
  _engine; // Ang main object ng Agora SDK na nagma-manage ng media connection

  @override
  void initState() {
    super.initState();
    // Sa pagsimula ng screen, automatic na tatawagin ang _joinChannel para pumasok sa call.
    _joinChannel();
  }

  // Function: _joinChannel
  // Gamit: I-initialize ang Agora, humingi ng permissions, at pumasok sa channel.
  // Connected sa: Agora SDK at Firestore (para i-announce na sumali ka).
  Future<void> _joinChannel() async {
    // Siguraduhing may user na naka-login bago tumuloy
    if (_currentUser == null) return;

    // Check if Agora App ID is valid
    if (!AgoraConfig.isValidAppId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Invalid Agora App ID. Please check agora_config.dart',
            ),
          ),
        );
        setState(() => _isConnected = false);
      }
      return;
    }

    try {
      // Step 1: Humingi ng permission para sa Microphone at Camera (kung hindi Web)
      // Importante ito para payagan ng OS na gamitin ang hardware resources.
      if (!kIsWeb) {
        await [
          Permission.microphone,
          Permission.camera,
          Permission.bluetoothConnect, // Required for Android 12+ to use headsets/bluetooth
        ].request();
      } else {
        // Sa Web: Kung 'granted' na dati, hindi na lalabas ang popup. 
        // Mag-print tayo para confirm na dumaan dito.
        var statuses = await [Permission.microphone, Permission.camera].request();
        debugPrint('Web Permissions Status: $statuses');
      }

      // Step 2: Gumawa ng Agora Engine instance gamit ang App ID
      // Dito nagsisimula ang connection sa Agora servers.
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(
        RtcEngineContext(
          appId: AgoraConfig.appId,
          channelProfile: ChannelProfileType
              .channelProfileCommunication, // Mode para sa 1-on-1 o group call
        ),
      );

      // Step 3: I-enable ang Audio at Video features ng engine
      await _engine!.enableAudio(); // Buksan ang audio module
      await _engine!.enableVideo(); // Buksan ang video module
      await _engine!.enableLocalVideo(
        false,
      ); // Start na naka-off ang video by default
      await _engine!.setEnableSpeakerphone(
        true,
      ); // Gamitin ang speakerphone (loudspeaker)

      // Step 4: I-enable ang volume indicator para malaman kung sino ang nagsasalita
      // interval: 200ms (kung gaano kadalas mag-check), smooth: 3 (sensitivity)
      await _engine!.enableAudioVolumeIndication(
        interval: 200,
        smooth: 3,
        reportVad: true,
      );

      // Step 5: Mag-register ng Event Handler para makinig sa mga pangyayari sa call
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          // Kapag may error sa Agora SDK
          onError: (ErrorCodeType err, String msg) {
            debugPrint('[Agora Error] $err: $msg');
          },
          // Event: Kapag may nagsasalita (Volume Indication)
          // Ginagamit ito para magpakita ng visual feedback (green border) kapag may nagsasalita.
          onAudioVolumeIndication:
              (
                RtcConnection connection,
                List<AudioVolumeInfo> speakers,
                int speakerNumber,
                int totalVolume,
              ) {
                // I-update ang listahan ng mga nagsasalita
                Set<int> currentSpeakers = {};
                for (final speaker in speakers) {
                  // Volume > 5 threshold para iwas background noise trigger
                  if ((speaker.volume ?? 0) > 5) {
                    currentSpeakers.add(speaker.uid ?? 0);
                  }
                }
                if (mounted) {
                  setState(() => _activeSpeakers = currentSpeakers);
                }
              },
          // Event: Kapag successful na nakapasok sa channel ang local user
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint("local user ${connection.localUid} joined");
            if (mounted) {
              // I-update ang Firestore document ng user. Ilagay ang 'agoraUid' na binigay ng Agora.
              // Mahalaga ito para ma-link ang Firebase User profile sa Agora Video Stream.
              FirebaseFirestore.instance
                  .collection('channels')
                  .doc(widget.channelId)
                  .collection('voice_participants')
                  .doc(_currentUser!.uid)
                  .set({
                    'agoraUid': connection.localUid,
                  }, SetOptions(merge: true));

              // I-update ang state para mawala ang loading spinner at ipakita ang grid
              setState(() {
                _isConnected = true;
              });
            }
          },
          // Event: Kapag may ibang user na sumali (remote user)
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint("remote user $remoteUid joined");
            // Pwede magdagdag ng logic dito kung kailangan i-handle ang pagpasok ng iba (e.g. notification)
          },
          // Event: Kapag may user na nawala o nag-disconnect
          onUserOffline:
              (
                RtcConnection connection,
                int remoteUid,
                UserOfflineReasonType reason,
              ) {
                debugPrint("remote user $remoteUid left channel");
                // Ang Firestore stream ang bahala mag-update ng UI grid, kaya okay lang na log lang dito
              },
        ),
      );

      // Step 6: Pumasok sa Channel gamit ang Token at Channel ID
      await _engine!.joinChannel(
        token: AgoraConfig.token,
        channelId: widget.channelId,
        uid:
            0, // 0 lets Agora assign a UID automatically (mas safe kaysa manual assignment)
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType
              .clientRoleBroadcaster, // Broadcaster para makapagsalita at mag-send ng video
          publishMicrophoneTrack: true, // I-send ang mic audio
          publishCameraTrack:
              true, // I-send ang camera video (kung naka-enable)
          autoSubscribeVideo: true, // Automatic panuorin ang video ng iba
          autoSubscribeAudio: true, // Automatic pakinggan ang audio ng iba
        ),
      );

      // Step 7: Idagdag ang sarili sa Firestore 'voice_participants' collection.
      // Ito ang magpapakita sa UI ng lahat na ikaw ay nasa call.
      // Connected sa StreamBuilder sa build method.
      await FirebaseFirestore.instance
          .collection('channels')
          .doc(widget.channelId)
          .collection('voice_participants')
          .doc(_currentUser!.uid)
          .set({
            'uid': _currentUser!.uid,
            'displayName': _currentUser.displayName ?? 'Unknown',
            'photoURL': _currentUser!.photoURL,
            'isMuted': _isMuted,
            'isVideoOn': _isVideoEnabled,
            'agoraUid': 0, // Placeholder, updated in onJoinChannelSuccess
            'joinedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      // Error handling kung hindi makapasok sa channel
      debugPrint("Error joining channel: $e");
      
      String errorMessage = 'Failed to join: $e';
      // Check specific Web SDK error
      if (e.toString().contains('createIrisApiEngine')) {
        errorMessage = 'Agora Web Script not loaded. Please hard refresh the browser.';
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Agora Engine Error'),
            content: Text(errorMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        setState(() => _isConnected = false);
      }
    }
  }

  // Function: _leaveChannel
  // Gamit: Linisin ang resources pag-alis sa call.
  // Connected sa: Dispose method at 'End Call' button.
  Future<void> _leaveChannel() async {
    if (_currentUser == null) return;
    try {
      // 1. Umalis sa Agora Channel at sirain ang Engine instance para hindi kumain ng resources
      if (_engine != null) {
        await _engine!.leaveChannel();
        await _engine!.release();
      }

      // 2. Tanggalin ang sarili sa Firestore list para mawala sa UI ng ibang participants
      await FirebaseFirestore.instance
          .collection('channels')
          .doc(widget.channelId)
          .collection('voice_participants')
          .doc(_currentUser!.uid)
          .delete();
    } catch (_) {}
  }

  // Function: _toggleMute
  // Gamit: I-on o i-off ang microphone.
  Future<void> _toggleMute() async {
    setState(() => _isMuted = !_isMuted);
    // Sabihan ang Agora engine na i-mute/unmute ang audio stream
    if (_engine != null) await _engine!.muteLocalAudioStream(_isMuted);
    // I-update ang Firestore para makita ng iba na naka-mute ka (red mic icon)
    if (_currentUser != null) {
      await FirebaseFirestore.instance
          .collection('channels')
          .doc(widget.channelId)
          .collection('voice_participants')
          .doc(_currentUser!.uid)
          .update({'isMuted': _isMuted});
    }
  }

  // Function: _toggleVideo
  // Gamit: I-on o i-off ang camera/video.
  Future<void> _toggleVideo() async {
    setState(() => _isVideoEnabled = !_isVideoEnabled);

    if (_engine != null) {
      // 1. I-enable/disable ang video module sa Agora
      await _engine!.enableLocalVideo(_isVideoEnabled);
      // 2. Mute/Unmute ang video stream (para huminto o tumuloy ang pag-send ng frames)
      await _engine!.muteLocalVideoStream(!_isVideoEnabled);

      // 3. Start/Stop preview para makita mo ang sarili mo sa screen
      if (_isVideoEnabled) {
        await _engine!.startPreview();
      } else {
        await _engine!.stopPreview();
      }
    }

    // 4. I-update ang Firestore para alam ng iba kung naka-video ka o hindi (sync state)
    if (_currentUser != null) {
      await FirebaseFirestore.instance
          .collection('channels')
          .doc(widget.channelId)
          .collection('voice_participants')
          .doc(_currentUser!.uid)
          .update({'isVideoOn': _isVideoEnabled});
    }
  }

  // Function: _switchCamera
  // Gamit: I-switch ang camera (Front/Back)
  Future<void> _switchCamera() async {
    if (_engine != null) {
      await _engine!.switchCamera();
    }
  }

  @override
  void dispose() {
    // Siguraduhing umalis sa channel at linisin ang resources kapag sinara ang screen
    _leaveChannel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF18191A), // Dark background color
      appBar: AppBar(
        backgroundColor:
            Colors.transparent, // Transparent para sa overlay effect
        elevation: 0,
        // Button para i-minimize o isara ang screen
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        // Title ng call na may status "Voice Connected"
        title: Column(
          children: [
            const Text(
              'Voice Connected',
              style: TextStyle(fontSize: 12, color: Colors.greenAccent),
            ),
            Text(
              widget.channelName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Main Content Area: Grid ng mga participants
          Expanded(
            child: !_isConnected
                ? const Center(
                    child: CircularProgressIndicator(),
                  ) // Loading indicator habang kumoconnect sa Agora
                // StreamBuilder: Nakikinig sa Firestore 'voice_participants' collection real-time
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('channels')
                        .doc(widget.channelId)
                        .collection('voice_participants')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const Center(child: CircularProgressIndicator());

                      // Kunin ang tunay na participants at i-convert sa List
                      final docs = snapshot.data!.docs;
                      final participants = docs
                          .map((d) => d.data() as Map<String, dynamic>)
                          .toList();

                      // I-display ang participants sa isang Grid
                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        // 3 items per row, with spacing
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                        itemCount: participants.length,
                        itemBuilder: (context, index) {
                          final data = participants[index];
                          final uid = data['uid'] as String?;
                          final isMe = uid == _currentUser?.uid;
                          final agoraUid = data['agoraUid'] as int? ?? 0;
                          
                          // Determine kung nagsasalita (Green border effect)
                          // Local user is 0 in Agora callbacks, Remote uses their agoraUid
                          final checkUid = isMe ? 0 : agoraUid;
                          final isTalking = _activeSpeakers.contains(checkUid);

                          // Custom widget para sa bawat participant
                          return _ParticipantItem(
                            data: data,
                            isMe: isMe,
                            isTalking: isTalking,
                            engine: _engine,
                            channelId: widget.channelId,
                          );
                        },
                      );
                    },
                  ),
          ),
          // Control Panel: Mute, Video, End Call buttons sa ilalim
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF242526),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Mute/Unmute Button
                IconButton(
                  icon: Icon(_isMuted ? Icons.mic_off : Icons.mic),
                  color: _isMuted ? Colors.red : Colors.white,
                  iconSize: 32,
                  onPressed: _toggleMute,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF3A3B3C),
                  ),
                ),
                // Video/No-Video Button
                IconButton(
                  icon: Icon(
                    _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                  ),
                  color: _isVideoEnabled ? Colors.white : Colors.red,
                  iconSize: 32,
                  onPressed: _toggleVideo,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF3A3B3C),
                  ),
                ),
                // Switch Camera Button (Visible only if video is enabled)
                if (_isVideoEnabled)
                  IconButton(
                    icon: const Icon(Icons.cameraswitch),
                    color: Colors.white,
                    iconSize: 32,
                    onPressed: _switchCamera,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF3A3B3C),
                    ),
                  ),
                // End Call Button (Red background)
                IconButton(
                  icon: const Icon(Icons.call_end),
                  color: Colors.white,
                  iconSize: 32,
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Widget: _ParticipantItem
// Gamit: Nagpapakita ng isang user sa grid (Avatar or Video feed).
// Tumatanggap ng data ng user, status kung ikaw ba ito, kung nagsasalita, at reference sa engine.
class _ParticipantItem extends StatelessWidget {
  final Map<String, dynamic>
  data; // Data mula sa Firestore (uid, displayName, photoURL, isMuted, isVideoOn, agoraUid)
  final bool isMe; // True kung ang item na ito ay ang local user
  final bool isTalking; // True kung may audio activity
  final RtcEngine? engine; // Reference sa Agora engine para sa video rendering
  final String channelId; // Kailangan para sa remote video connection

  const _ParticipantItem({
    required this.data,
    required this.isMe,
    required this.isTalking,
    required this.engine,
    required this.channelId,
  });

  @override
  Widget build(BuildContext context) {
    // Kunin ang status ng user mula sa data
    final isMuted = data['isMuted'] ?? false;
    final isVideoOn = data['isVideoOn'] ?? false;
    final agoraUid = data['agoraUid'] as int? ?? 0;

    // Unique key para sa video view para hindi mag-refresh kapag nag-update ang UI (e.g. speaking border)
    final videoKey = ValueKey(isMe ? 'local_video' : 'remote_video_$agoraUid');

    return Column(
      children: [
        Stack(
          children: [
            // Container para sa Avatar/Video na may border indicator
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  // Kulay ng border: Red pag muted, Green Accent pag nagsasalita, Green pag normal (idle)
                  color: isMuted
                      ? Colors.red
                      : (isTalking ? Colors.greenAccent : Colors.green),
                  width: isTalking ? 4 : 2,
                ),
              ),
              child: isVideoOn && (agoraUid != 0 || isMe) && engine != null
                  // Kung naka-on ang video, ipakita ang AgoraVideoView
                  ? ClipOval(
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: AgoraVideoView(
                          key: videoKey,
                          // Kung ikaw, gamitin ang local camera (Mirror Effect)
                          controller: isMe
                              ? VideoViewController(
                                  rtcEngine: engine!,
                                  canvas: const VideoCanvas(uid: 0),
                                )
                              // Kung ibang user, gamitin ang remote video controller gamit ang Agora UID
                              : VideoViewController.remote(
                                  rtcEngine: engine!,
                                  canvas: VideoCanvas(uid: agoraUid),
                                  connection: RtcConnection(
                                    channelId: channelId,
                                  ),
                                ),
                        ),
                      ),
                    )
                  // Kung walang video, ipakita ang Profile Picture o default icon
                  : CircleAvatar(
                      radius: 32,
                      backgroundImage: data['photoURL'] != null
                          ? NetworkImage(data['photoURL'])
                          : null,
                      child: data['photoURL'] == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
            ),
            // Mic off icon overlay kung naka-mute (maliit na icon sa gilid)
            if (isMuted)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mic_off,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Display name ng user sa ilalim ng avatar
        Text(
          data['displayName'] ?? 'User',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
