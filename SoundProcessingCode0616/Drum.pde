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
    
    //int numComponents = kickLUT.length;
    int numComponents = 100;
    Oscil[] tones = new Oscil[numComponents];
    harmonicEnvs = new ADSR[numComponents];
    Line[] pitchSweeps = new Line[numComponents];
    
    float baseAmp = masterVol * velocity * 0.5;

    for (int i = 0; i < numComponents; i++) {
      if (kickLUT[i] == null || kickLUT[i].length < 3) continue;
      
      float freq = kickLUT[i][0];
      float mag = kickLUT[i][1];
      float decayTime = kickLUT[i][2];
      float amp = (baseAmp * mag) / numComponents;
      
      tones[i] = new Oscil(freq, amp, Waves.SINE);
      //tones[i].setPhase(random(1.0f)); // 初期位相を散らしてアタックのピーク割れを防ぐ
      
      // 個別の成分のエンベロープ
      harmonicEnvs[i] = new ADSR(1.0f, 0.001f, decayTime * 0.05, 0.0f, 0.1f);
      
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
    masterEnv.patch(shortOut);
  }

  void noteOff() {
    masterEnv.noteOff();
    for (int i = 0; i < harmonicEnvs.length; i++) {
      if (harmonicEnvs[i] != null) harmonicEnvs[i].noteOff();
    }
    // グローバルな out からアンパッチ！
    masterEnv.unpatchAfterRelease(shortOut);
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
    masterEnv.patch(shortOut);
  }

  void noteOff() {
    masterEnv.noteOff();
    for (int i = 0; i < harmonicEnvs.length; i++) {
      if (harmonicEnvs[i] != null) harmonicEnvs[i].noteOff();
    }
    noiseEnv.noteOff();
    masterEnv.unpatchAfterRelease(shortOut);
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
    masterEnv.patch(shortOut);
  }

  void noteOff() {
    masterEnv.noteOff();
    for (int i = 0; i < harmonicEnvs.length; i++) {
      if (harmonicEnvs[i] != null) harmonicEnvs[i].noteOff();
    }
    noiseEnv.noteOff();
    masterEnv.unpatchAfterRelease(shortOut);
  }
}









// ==========================================
// 2. 新・スネア（Snare）のクラス (シンセサイズ方式)
// ==========================================
class SnareInstrument2 implements Instrument {
  ADSR masterEnv;
  
  // 1. 胴鳴り（Body）パート用
  Oscil bodyOsc;
  Line  bodyPitchEnv;
  ADSR  bodyAmpEnv;
  
  // 2. 倍音（Overtone）パート用
  Oscil overtoneOsc;
  ADSR  overtoneAmpEnv;
  
  // 3. スナッピー（Noise）パート用
  Noise      snappyNoise;
  //HighPassSP snappyFilter;
  ADSR       snappyAmpEnv;

  SnareInstrument2(float masterVol, float velocity) {
    Summer mixer = new Summer();
    
    // 全体の音量調整
    float baseAmp = masterVol * velocity * 0.005f; 
    
    // ==========================================
    // パラメータ設定（ここをいじって音色をチューニングします）
    // ==========================================
    
    // --- 1. 胴鳴り（ベースとなる太さ） ---
    float bodyFreq     = 172.3f;  // ★データ最上部の「172.3 Hz (強さ: 0.63)」をそのまま指定！
    float bodyPitchMod = 3.0f;    // アタック時は約516Hz付近から172.3Hzへ急降下させる
    float bodySweepTime= 0.025f;  // 一瞬でピッチを落とす
    float bodyDecay    = 0.06f;   
    float bodyVolRatio = 0.63f;    // 172.3Hzは強いエネルギーを持っているので、音量比率を高めに
    
    // --- 2. 倍音（カンカンしたヘッドの芯） ---
    float overtoneFreq  = 323.0f; // ★データ2番目の「323.0 Hz (強さ: 0.55)」をそのまま指定！
    float overtoneDecay = 0.048f;  // 胴鳴り（172.3Hz）よりも早く減衰させて歯切れを良くする
    float overtoneVolRatio = 0.55f;
    
    // --- 3. スナッピー（ホワイトノイズ） ---
    // データを見ると 1184.3 Hz 付近から徐々に強さが上がり、2.5kHz〜8kHzがエネルギーの塊になっています。
    //float noiseFilterCutoff = 2000.0f; // 2kHzあたりから上のノイズをまるごと通す
    float noiseDecay        = 0.15f;   // スナッピーの余韻
    float noiseVolRatio     = 3.3f;
    float noiseHPCutoff     = 2500.0f;
    float noiseLPCutoff1    = 2800.0f;
    float noiseLPCutoff2    = 4000.0f;
    float noiseLPCutoff3    = 7000.0f;

    // ==========================================
    // 各モジュールの構築とパッチング
    // ==========================================
    
    // --- 1. 胴鳴りパートの構築 ---
    bodyOsc = new Oscil(bodyFreq, baseAmp * bodyVolRatio, Waves.SINE);
    // 叩いた瞬間に音程を急激に下げる（アタック感の演出）
    bodyPitchEnv = new Line(bodySweepTime, bodyFreq * bodyPitchMod, bodyFreq);
    bodyPitchEnv.patch(bodyOsc.frequency);
    // 音量エンベロープ (Attack, Decay, Sustain, Release)
    bodyAmpEnv = new ADSR(1.0f, 0.001f, bodyDecay, 0.0f, 0.05f);
    
    bodyOsc.patch(bodyAmpEnv).patch(mixer);
    
    

    // --- 2. 倍音パートの構築 ---
    overtoneOsc = new Oscil(overtoneFreq, baseAmp * overtoneVolRatio, Waves.SINE);
    overtoneAmpEnv = new ADSR(1.0f, 0.002f, overtoneDecay, 0.0f, 0.05f);
    
    overtoneOsc.patch(overtoneAmpEnv).patch(mixer);
    
    

  // --- 3. スナッピー（Noise）パートの構築 ---
    snappyNoise = new Noise(baseAmp * noiseVolRatio, Noise.Tint.WHITE);
    
    // 4,500Hzに向かってなだらかに立ち上げるためのハイパス
    HighPassSP snappyHP = new HighPassSP(noiseHPCutoff, out.sampleRate());
    
    // 5,500Hzから20,000Hzに向けてなだらかに落とすためのローパス
    LowPassSP  snappyLP1 = new LowPassSP(noiseLPCutoff1, out.sampleRate());
    LowPassSP  snappyLP2 = new LowPassSP(noiseLPCutoff2, out.sampleRate());
    LowPassSP  snappyLP3 = new LowPassSP(noiseLPCutoff3, out.sampleRate());
    
    snappyAmpEnv = new ADSR(1.0f, 0.003f, noiseDecay, 0.0f, 0.05f);
    
    // ノイズを2つのフィルターに順番に通して（挟み撃ちにして）エンベロープへ送る
    snappyNoise.patch(snappyHP).patch(snappyLP1).patch(snappyLP2).patch(snappyLP3).patch(snappyAmpEnv).patch(mixer);
    
    

    // --- 4. マスターエンベロープ ---
    masterEnv = new ADSR(1.0f, 0.001f, 0.0f, 1.0f, 0.01f);
    mixer.patch(masterEnv);
  }

  void noteOn(float duration) {
    masterEnv.noteOn();
    bodyAmpEnv.noteOn();
    overtoneAmpEnv.noteOn();
    snappyAmpEnv.noteOn();
    
    masterEnv.patch(shortOut);
  }

  void noteOff() {
    masterEnv.noteOff();
    bodyAmpEnv.noteOff();
    overtoneAmpEnv.noteOff();
    snappyAmpEnv.noteOff();
    
    masterEnv.unpatchAfterRelease(shortOut);
  }
}



// ==========================================
// 3. 新・ハイハット（Hi-Hat）のクラス (シンセサイズ方式)
// ==========================================
class HiHatInstrument2 implements Instrument {
  ADSR masterEnv;
  
  // 1. 金属共鳴（Metallic Core）パート用
  // グラフから厳選した主要な4つのピークを個別に発振・制御します
  Oscil toneOsc1, toneOsc2, toneOsc3, toneOsc4;
  ADSR  toneEnv1, toneEnv2, toneEnv3, toneEnv4;
  
  Oscil[] toneOscList;
  ADSR[] toneEnvList;
  
  // 2. 打撃摩擦（Noise）パート用
  Noise      hatNoise;
  //HighPassSP hatHP;
  ADSR       noiseEnv;

  HiHatInstrument2(float masterVol, float velocity) {
    Summer mixer = new Summer();
    
    // 全体の音量調整（歪まないようにスネア等のバランスに合わせて調整してください）
    float baseAmp = masterVol * velocity * 0.002f; 
    
    // ==========================================
    // パラメータ設定（ここをいじって音色をチューニングします！）
    // ==========================================
    
    // --- 1. 金属共鳴（チキチキ・カンカンした芯の成分） ---
    // FFT解析データの上位トップ4の強いピークをそのままスタンドアロンで指定
    /*
    float toneFreq1     = 7149.0f; // ★最強のセンターピーク（強さ: 1.00）
    float toneVolRatio1 = 1.00f;
    float toneDecay1    = 0.109f;  // 金属的なアタックのみを出すため、非常に短く
    
    float toneFreq2     = 7644.3f; // ★2番目に強い高域ピーク（強さ: 0.62）
    float toneVolRatio2 = 0.62f;
    float toneDecay2    = 0.040f;
    
    float toneFreq3     = 5964.7f; // ★3番目に強い中高域ピーク（強さ: 0.61）
    float toneVolRatio3 = 0.61f;
    float toneDecay3    = 0.060f;
    
    float toneFreq4     = 13006.1f;// ★超高域の金属的な鋭さを補うピーク（強さ: 0.52）
    float toneVolRatio4 = 0.52f;
    float toneDecay4    = 0.015f;  // 超高域は一瞬で消え去るように
    */
    
    float[][] toneList     = {
                               {21.53f, 0.0619f, 0.131f},
                               {7149.0f, 1.00f, 0.109f},
                               {7644.3f, 0.62f, 0.040f},
                               {5964.7f, 0.61f, 0.060f},
                               {13006.1f, 0.52f, 0.015f}
                             };
    
    // --- 2. 打撃摩擦（シャリシャリ・シュワシュワした高域ノイズ） ---
    float noiseVolRatio = 4.00f;   // ノイズのブレンド比率。シャリシャリ感を強めるなら上げる
    float noiseHPCutoff1 = 7000.0f; // ★ハイパスのカットオフ（Hz）。
                                   // 8k〜10kHz以上にすると、ゴソゴソした中音域が消え、綺麗な「チッ」になります
    float noiseHPCutoff2 = 4000.0f;
    float noiseLPCutoff1 = 5000.0f;
    float noiseLPCutoff2 = 30000.0f;
    //float noiseLPCutoff3 = 3000.0f;
    float noiseDecay    = 0.120f;  // クローズドハイハットの「余韻の長さ（キレ）」を左右する最重要パラメータ
    
    // ==========================================
    // 各モジュールの構築とパッチング
    // ==========================================
    
    // --- 1. 金属共鳴パートの構築 ---
    // 各正弦波の位相（Phase）をランダムにすることで、発音ごとの微妙な「なじみ」を生み出します
    /*
    toneOsc1 = new Oscil(toneFreq1, baseAmp * toneVolRatio1, Waves.SINE);
    toneOsc1.setPhase(random(1.0f));
    toneEnv1 = new ADSR(1.0f, 0.001f, toneDecay1, 0.0f, 0.01f);
    toneOsc1.patch(toneEnv1).patch(mixer);
    
    toneOsc2 = new Oscil(toneFreq2, baseAmp * toneVolRatio2, Waves.SINE);
    toneOsc2.setPhase(random(1.0f));
    toneEnv2 = new ADSR(1.0f, 0.001f, toneDecay2, 0.0f, 0.01f);
    toneOsc2.patch(toneEnv2).patch(mixer);
    
    toneOsc3 = new Oscil(toneFreq3, baseAmp * toneVolRatio3, Waves.SINE);
    toneOsc3.setPhase(random(1.0f));
    toneEnv3 = new ADSR(1.0f, 0.001f, toneDecay3, 0.0f, 0.01f);
    toneOsc3.patch(toneEnv3).patch(mixer);
    
    toneOsc4 = new Oscil(toneFreq4, baseAmp * toneVolRatio4, Waves.SINE);
    toneOsc4.setPhase(random(1.0f));
    toneEnv4 = new ADSR(1.0f, 0.001f, toneDecay4, 0.0f, 0.01f);
    toneOsc4.patch(toneEnv4).patch(mixer);
    */
    
    toneOscList = new Oscil[toneList.length];
    toneEnvList = new ADSR[toneList.length];
    
    for (int i = 0; i < toneList.length; i++){
      toneOscList[i] = new Oscil(toneList[i][0], baseAmp * toneList[i][1], Waves.SINE);
      toneOscList[i].setPhase(random(1.0f));
      toneEnvList[i] = new ADSR(1.0f, 0.001f, toneList[i][2], 0.0f, 0.01f);
      toneOscList[i].patch(toneEnvList[i]).patch(mixer);
    }
    
    // --- 2. ノイズパートの構築 ---
    hatNoise = new Noise(baseAmp * noiseVolRatio, Noise.Tint.WHITE);
    HighPassSP hatHP1    = new HighPassSP(noiseHPCutoff1, out.sampleRate());
    HighPassSP hatHP2    = new HighPassSP(noiseHPCutoff2, out.sampleRate());
    LowPassSP hatLP1    = new LowPassSP(noiseLPCutoff1, out.sampleRate());
    LowPassSP hatLP2    = new LowPassSP(noiseLPCutoff2, out.sampleRate());
    //LowPassSP hatLP3    = new LowPassSP(noiseLPCutoff3, out.sampleRate());
    noiseEnv = new ADSR(1.0f, 0.001f, noiseDecay, 0.0f, 0.02f);
    
    // ホワイトノイズ -> ハイパスフィルター -> エンベロープ -> ミキサー
    hatNoise.patch(hatHP1).patch(hatHP2).patch(hatLP1).patch(hatLP2).patch(noiseEnv).patch(mixer);
    
    // --- 3. 全体の結合とマスターエンベロープ ---
    masterEnv = new ADSR(1.0f, 0.001f, 0.0f, 1.0f, 0.02f); // リリースも極短に
    mixer.patch(masterEnv);
  }

  void noteOn(float duration) {
    masterEnv.noteOn();
    //toneEnv1.noteOn();
    //toneEnv2.noteOn();
    //toneEnv3.noteOn();
    //toneEnv4.noteOn();
    
    for (int i = 0; i<toneEnvList.length; i++ ) toneEnvList[i].noteOn();
    
    noiseEnv.noteOn();
    
    masterEnv.patch(shortOut);
  }

  void noteOff() {
    masterEnv.noteOff();
    //toneEnv1.noteOff();
    //toneEnv2.noteOff();
    //toneEnv3.noteOff();
    //toneEnv4.noteOff();
    
    for (int i = 0; i < toneEnvList.length; i++) {if (toneEnvList[i] != null) toneEnvList[i].noteOff();}
    
    
    noiseEnv.noteOff();
    
    masterEnv.unpatchAfterRelease(shortOut);
  }
}
