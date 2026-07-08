class InstrumentPlayer {
  AudioOutput out;

  InstrumentPlayer(AudioOutput out) {
    this.out = out; // Mainから渡された出力を保持する
  }

  void PlayFlute(float midiNote, float duration, float startVel, float endVel, float masterVol) {
    out.playNote(0.0f, duration, 
      new FluteInstrument(midiNote, duration, startVel, endVel, masterVol));
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
    //out.playNote(0, 0.1, new KickInstrument(masterVol, velocity));
    out.playNote(0, 0.1, new KickInstrument(masterVol, velocity));
  }
  
  // スネアを鳴らす関数
  void PlaySnareOld(float masterVol, float velocity) {
    out.playNote(0, 0.5, new SnareInstrumentOld(masterVol, velocity));
  }
  
  // スネアver2を鳴らす関数
  void PlaySnare(float masterVol, float velocity, float sinAmp) {
    out.playNote(0, 0.3, new SnareInstrument(masterVol, velocity, sinAmp));
  }
  
  // クローズハイハットを鳴らす関数
  void PlayHiHatOld(float masterVol, float velocity) {
    out.playNote(0, 0.2, new HiHatInstrumentOld(masterVol, velocity));
  }
  
  // クローズハイハットver2を鳴らす関数
  void PlayHiHat(float masterVol, float velocity) {
    out.playNote(0, 0.15, new HiHatInstrument(masterVol, velocity));
  }
  
  
  
  
  
  
  
  void PlayHorn(float midiNote, float duration, float startVel, float endVel, float masterVol) {
    out.playNote(0.0f, duration, 
      new HornInstrument(midiNote, duration, startVel, endVel, masterVol));
  }
  void PlayTrumpet(float midiNote, float duration, float startVel, float endVel, float masterVol) {
    out.playNote(0.0f, duration, 
      new TrumpetInstrument(midiNote, duration, startVel, endVel, masterVol));
  }
  
  //void PlayCymbal(float masterVol, float velocity) {
  //  out.playNote(0, 0.2, new CymbalInstrument(masterVol, velocity));
  //}
}
