// ドラム用LUTの宣言 [インデックス][0:周波数, 1:強度, 2:衰退時間(Decay)]
//float[][] kickLUT, snareLUT, hihatLUT;











// ==========================================
// 1. キック（Kick）のクラス
// ==========================================
class KickInstrument implements Instrument {
  //Summer mixer;
  ADSR masterEnv;
  
  //Oscil[] tones;
  ADSR[] harmonicEnvs;
  //Line[] pitchSweeps;

  KickInstrument(float masterVol, float velocity) {
    Summer mixer = new Summer();
    
    float[][]kickLUT = utils.GetLUT("Kick");
    
    // フルートと同じく、リリース時のバッファを持たせたマスターエンベロープ
    masterEnv = new ADSR(1.0f, 0.001f, 0.0f, 1.0f, 0.1f);
    mixer.patch(masterEnv);
    
    int numComponents = kickLUT.length;
    Oscil[] tones = new Oscil[numComponents];
    harmonicEnvs = new ADSR[numComponents];
    Line[] pitchSweeps = new Line[numComponents];
    
    float baseAmp = masterVol * velocity * 1.0;

    for (int i = 0; i < numComponents; i++) {
      if (kickLUT[i] == null || kickLUT[i].length < 3) continue;
      
      float freq = kickLUT[i][0];
      float mag = kickLUT[i][1];
      float decayTime = kickLUT[i][2];
      float amp = (baseAmp * mag) / numComponents;
      
      tones[i] = new Oscil(freq, amp, Waves.SINE);
      tones[i].setPhase(random(1.0f)); // 初期位相を散らしてアタックのピーク割れを防ぐ
      
      // 個別の成分のエンベロープ
      harmonicEnvs[i] = new ADSR(1.0f, 0.001f, decayTime * 0.7, 0.0f, 0.1f);
      
      // ピッチスイープ
      pitchSweeps[i] = new Line(0.05f, freq * 1.5f, freq);
      pitchSweeps[i].patch(tones[i].frequency);
      
      // 結線: Oscil -> 個別ADSR -> Mixer
      tones[i].patch(harmonicEnvs[i]);
      harmonicEnvs[i].patch(mixer);
    }
  }

  void noteOn(float duration) {
    masterEnv.noteOn();
    for (int i = 0; i < harmonicEnvs.length; i++) {
      if (harmonicEnvs[i] != null) harmonicEnvs[i].noteOn();
    }
    // グローバルな out に直接パッチ！
    masterEnv.patch(out);
  }

  void noteOff() {
    masterEnv.noteOff();
    for (int i = 0; i < harmonicEnvs.length; i++) {
      if (harmonicEnvs[i] != null) harmonicEnvs[i].noteOff();
    }
    // グローバルな out からアンパッチ！
    masterEnv.unpatchAfterRelease(out);
  }
}

// ==========================================
// 2. スネア（Snare）のクラス
// ==========================================
class SnareInstrument implements Instrument {
  //Summer mixer;
  ADSR masterEnv;
  
  // LUT（胴鳴り・倍音）用
  //Oscil[] tones;
  ADSR[] harmonicEnvs;
  //Line[] pitchSweeps;
  
  // ノイズ（スナッピー）用
  //Noise snareNoise;
  //HighPassSP snareFilter;
  ADSR noiseEnv;

  SnareInstrument(float masterVol, float velocity) {
    Summer mixer = new Summer();
    masterEnv = new ADSR(1.0f, 0.001f, 0.0f, 1.0f, 0.1f);
    mixer.patch(masterEnv);
    
    float baseAmp = masterVol * velocity * 0.2;
    
    float[][]snareLUT = utils.GetLUT("Snare");
    
    // --- 1. 胴鳴りパート (LUTによる加算合成) ---
    int numComponents = snareLUT.length;
    Oscil[] tones = new Oscil[numComponents];
    harmonicEnvs = new ADSR[numComponents];
    Line[] pitchSweeps = new Line[numComponents];

    for (int i = 0; i < numComponents; i++) {
      if (snareLUT[i] == null || snareLUT[i].length < 3) continue;
      
      float freq = snareLUT[i][0];
      float mag = snareLUT[i][1];
      float decayTime = snareLUT[i][2];
      float amp = (baseAmp * mag) / numComponents;
      
      tones[i] = new Oscil(freq, amp, Waves.SINE);
      tones[i].setPhase(random(1.0f)); 
      
      harmonicEnvs[i] = new ADSR(1.0f, 0.001f, decayTime * 0.7, 0.0f, 0.1f);
      
      // スネア特有：低音（胴鳴り）のみピッチスイープ
      if (freq < 1000) {
        pitchSweeps[i] = new Line(0.05f, freq * 1.5f, freq);
        pitchSweeps[i].patch(tones[i].frequency);
      }
      
      tones[i].patch(harmonicEnvs[i]);
      harmonicEnvs[i].patch(mixer);
    }
    
    // --- 2. スナッピーパート (ノイズによる減算合成) ---
    // 以前の解析で導き出した数値をそのまま採用
    float noiseVol = baseAmp * 0.022f; 
    Noise snareNoise = new Noise(noiseVol, Noise.Tint.WHITE);
    HighPassSP snareFilter = new HighPassSP(512, out.sampleRate()); // 7750Hz以上を通す
    noiseEnv = new ADSR(1.0f, 0.003f, 0.15f, 0.0f, 0.1f); // ディケイ0.25秒
    
    // ノイズをフィルターし、エンベロープを通してミキサーへ合流
    snareNoise.patch(snareFilter).patch(noiseEnv).patch(mixer);
  }

  void noteOn(float duration) {
    masterEnv.noteOn();
    for (int i = 0; i < harmonicEnvs.length; i++) {
      if (harmonicEnvs[i] != null) harmonicEnvs[i].noteOn();
    }
    noiseEnv.noteOn();
    masterEnv.patch(out);
  }

  void noteOff() {
    masterEnv.noteOff();
    for (int i = 0; i < harmonicEnvs.length; i++) {
      if (harmonicEnvs[i] != null) harmonicEnvs[i].noteOff();
    }
    noiseEnv.noteOff();
    masterEnv.unpatchAfterRelease(out);
  }
}

// ==========================================
// 3. クローズハイハット（Closed Hi-Hat）のクラス
// ==========================================
class HiHatInstrument implements Instrument {
  //Summer mixer;
  ADSR masterEnv;
  
  //Oscil[] tones;
  ADSR[] harmonicEnvs;
  
  //Noise hatNoise;
  //HighPassSP hatFilter;
  ADSR noiseEnv;

  HiHatInstrument(float masterVol, float velocity) {
    Summer mixer = new Summer();
    // ハイハットは余韻が非常に短いため、マスターのリリースも極短に
    masterEnv = new ADSR(1.0f, 0.001f, 0.0f, 1.0f, 0.05f);
    mixer.patch(masterEnv);
    
    float baseAmp = masterVol * velocity * 0.3;
    
    float[][]hihatLUT = utils.GetLUT("HiHat");
    
    // --- 1. 金属共鳴パート (LUTによる加算合成) ---
    int numComponents = hihatLUT.length;
    Oscil[] tones = new Oscil[numComponents];
    harmonicEnvs = new ADSR[numComponents];

    for (int i = 0; i < numComponents; i++) {
      if (hihatLUT[i] == null || hihatLUT[i].length < 3) continue;
      
      float freq = hihatLUT[i][0];
      float mag = hihatLUT[i][1];
      float decayTime = hihatLUT[i][2];
      float amp = (baseAmp * mag) / numComponents;
      
      tones[i] = new Oscil(freq, amp, Waves.SINE);
      tones[i].setPhase(random(1.0f));
      
      harmonicEnvs[i] = new ADSR(1.0f, 0.001f, decayTime, 0.0f, 0.05f);
      
      tones[i].patch(harmonicEnvs[i]);
      harmonicEnvs[i].patch(mixer);
    }
    
    // --- 2. 打撃摩擦パート (ノイズによる減算合成) ---
    float noiseVol = baseAmp * 0.042f;
    Noise hatNoise = new Noise(noiseVol, Noise.Tint.WHITE);
    HighPassSP hatFilter = new HighPassSP(10250, out.sampleRate()); // 10000Hz以上の超高音のみ
    noiseEnv = new ADSR(1.0f, 0.001f, 0.06f, 0.0f, 0.05f); // 0.06秒でスパッと消える
    
    hatNoise.patch(hatFilter).patch(noiseEnv).patch(mixer);
  }

  void noteOn(float duration) {
    masterEnv.noteOn();
    for (int i = 0; i < harmonicEnvs.length; i++) {
      if (harmonicEnvs[i] != null) harmonicEnvs[i].noteOn();
    }
    noiseEnv.noteOn();
    masterEnv.patch(out);
  }

  void noteOff() {
    masterEnv.noteOff();
    for (int i = 0; i < harmonicEnvs.length; i++) {
      if (harmonicEnvs[i] != null) harmonicEnvs[i].noteOff();
    }
    noiseEnv.noteOff();
    masterEnv.unpatchAfterRelease(out);
  }
}
