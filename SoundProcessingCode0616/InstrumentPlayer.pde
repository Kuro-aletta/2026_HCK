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
      new StringsInstrument(midiNote, duration, startVel, endVel, masterVol));
  }
  
  void PlayPiano(float midiNote, float duration, float velocity, float masterVol) {
    out.playNote(0.0f, duration, 
      new PianoInstrument(midiNote, velocity, masterVol));
  }
   
  // キックを鳴らす関数
  void PlayKick(float masterVol, float velocity) {
    // out.playNote(開始時間, 鳴らす長さ, 音色クラス);
    // ドラムはエンベロープ側で長さを制御するため、第2引数のdurationは適当な値(1.0など)でOKです。
    out.playNote(0, 0.15, new KickInstrument(masterVol, velocity));
  }
  
  // スネアを鳴らす関数
  void PlaySnare(float masterVol, float velocity) {
    out.playNote(0, 0.5, new SnareInstrument(masterVol, velocity));
  }
  
  // スネアver2を鳴らす関数
  void PlaySnare2(float masterVol, float velocity) {
    out.playNote(0, 0.3, new SnareInstrument2(masterVol, velocity));
  }
  
  // クローズハイハットを鳴らす関数
  void PlayHiHat(float masterVol, float velocity) {
    out.playNote(0, 0.2, new HiHatInstrument(masterVol, velocity));
  }
  
  // クローズハイハットver2を鳴らす関数
  void PlayHiHat2(float masterVol, float velocity) {
    out.playNote(0, 0.2, new HiHatInstrument2(masterVol, velocity));
  }
}
