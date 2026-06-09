class InstrumentPlayer {
  AudioOutput out;

  InstrumentPlayer(AudioOutput out) {
    this.out = out; // Mainから渡された出力を保持する
  }

  void PlayFlute(float midiNote, float duration, float startVel, float endVel, float masterVol) {
    out.playNote(0.0f, duration, 
      new FluteInstrument(midiNote, startVel, endVel, masterVol));
  }
  
  void PlayStrings(float midiNote, float duration, float startVel, float endVel, float masterVol) {
    out.playNote(0.0f, duration, 
      new StringsInstrument(midiNote, startVel, endVel, masterVol));
  }
  
  void PlayPiano(float midiNote, float duration, float velocity, float masterVol) {
    out.playNote(0.0f, duration, 
      new PianoInstrument(midiNote, velocity, masterVol));
  }
   
  // キックを鳴らす関数
  void PlayKick(float masterVol, float velocity) {
    // out.playNote(開始時間, 鳴らす長さ, 音色クラス);
    // ドラムはエンベロープ側で長さを制御するため、第2引数のdurationは適当な値(1.0など)でOKです。
    out.playNote(0, 0.5, new KickInstrument(masterVol, velocity));
  }
  
  // スネアを鳴らす関数
  void PlaySnare(float masterVol, float velocity) {
    out.playNote(0, 0.6, new SnareInstrument(masterVol, velocity));
  }
  
  // クローズハイハットを鳴らす関数
  void PlayHiHat(float masterVol, float velocity) {
    out.playNote(0, 0.4, new HiHatInstrument(masterVol, velocity));
  }
}
