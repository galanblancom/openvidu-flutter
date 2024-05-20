class JsonConstants {
  // RPC incoming methods
  static const String participantJoined = 'participantJoined';
  static const String participantLeft = 'participantLeft';
  static const String participantPublished = 'participantPublished';
  static const String iceCandidate = 'iceCandidate';
  static const String participantUnpublished = 'participantUnpublished';
  static const String participantEvicted = 'participantEvicted';
  static const String recordingStarted = 'recordingStarted';
  static const String recordingStopped = 'recordingStopped';
  static const String sendMessage = 'sendMessage';
  static const String streamPropertyChanged = 'streamPropertyChanged';
  static const String filterEventDispatched = 'filterEventDispatched';
  static const String mediaError = 'mediaError';

  // RPC outgoing methods
  static const String pingMethod = 'ping';
  static const String joinRoomMethod = 'joinRoom';
  static const String leaveRoomMethod = 'leaveRoom';
  static const String publishVideoMethod = 'publishVideo';
  static const String onIceCandidateMethod = 'onIceCandidate';
  static const String prepareReceiveVideoMethod = 'prepareReceiveVideoFrom';
  static const String receiveVideoMethod = 'receiveVideoFrom';
  static const String unsubscribeFromVideoMethod = 'unsubscribeFromVideo';
  static const String sendMessageRoomMethod = 'sendMessage';
  static const String unpublishVideoMethod = 'unpublishVideo';
  static const String streamPropertyChangedMethod = 'streamPropertyChanged';
  static const String networkQualityLevelChangedMethod =
      'networkQualityLevelChanged';
  static const String forceDisconnectMethod = 'forceDisconnect';
  static const String forceUnpublishMethod = 'forceUnpublish';
  static const String applyFilterMethod = 'applyFilter';
  static const String execFilterMethodMethod = 'execFilterMethod';
  static const String removeFilterMethod = 'removeFilter';
  static const String addFilterEventListenerMethod = 'addFilterEventListener';
  static const String removeFilterEventListenerMethod =
      'removeFilterEventListener';

  static const String jsonRpcVersion = '2.0';

  static const String value = 'value';
  static const String params = 'params';
  static const String method = 'method';
  static const String id = 'id';
  static const String result = 'result';
  static const String error = 'error';
  static const String mediaServer = 'mediaServer';

  static const String sessionId = 'sessionId';
  static const String sdpAnswer = 'sdpAnswer';
  static const String metadata = 'metadata';

  static const String iceServers = 'customIceServers';
}
