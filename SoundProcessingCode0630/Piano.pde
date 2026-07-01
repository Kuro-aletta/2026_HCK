
//float[][] pianoDecayLUT;
//float[][] pianoWobbleRateLUT;
//float[][] pianoWobbleDepthLUT;

// ==========================================
// 究極のピアノ・インストゥルメント (デュアル・ストリング & ハイブリッドデータ駆動版)
// ==========================================
class PianoInstrument implements Instrument {
  // 分析データに合わせて最大80倍音まで生成
  byte numHarmonics/* = 40*/;
  
  ADSR masterEnv; // 全体の音の長さを管理し、離鍵時にミュートする（ダンパーフェルトの役割）
  ADSR hammerEnv; // ハンマーが弦を叩く一瞬のノイズ用エンベロープ
  
  // 個別の減衰（Damp）を管理するリスト。
  // 芯の弦と共鳴弦でDampの数が変動するため、配列ではなくArrayListを使用します。
  ArrayList<Damp> damps = new ArrayList<Damp>();
  
  PianoInstrument(float midiNote, float velocity, float masterVol) {
    Summer mixer = new Summer();
    
    // ユーザー定義のベロシティ閾値
    float thresholdPP = 32.0f / 127.0f;
    float thresholdMF = 80.0f / 127.0f;
    float thresholdFF = 112.0f / 127.0f;
    
    // 現在のベロシティ層に応じて、ベースとなる波形プロファイル（周波数・振幅の骨組み）を決定
    String baseVelocity;
    float t = 0;
    //boolean needInterpolation = false;
    //float[][] lowerProfile = null;
    //float[][] upperProfile = null;
    
    if (velocity <= thresholdPP) {
      baseVelocity = "PP";
    } else if (velocity <= thresholdMF) {
      // pp ～ mf の間：構造が近い方のスペクトル形状を選択（あるいは、より高度に処理するためのフラグ設定）
      t = map(velocity, thresholdPP, thresholdMF, 0.0f, 1.0f);
      baseVelocity = (t < 0.5f) ? "PP" : "MF";
    } else if (velocity <= thresholdFF) {
      // mf ～ ff の間
      t = map(velocity, thresholdMF, thresholdFF, 0.0f, 1.0f);
      baseVelocity = (t < 0.5f) ? "MF" : "FF";
    } else {
      baseVelocity = "FF";
    }
    
    float[][]pianoDecayLUT = utils.GetLUT("PianoDecay" + baseVelocity);
    float[][]pianoWobbleRateLUT = utils.GetLUT("PianoWobbleRate" + baseVelocity);
    float[][]pianoWobbleDepthLUT = utils.GetLUT("PianoWobbleDepth" + baseVelocity);
    
    // ==========================================
    // 1. 全体のエンベロープ設定（ダンパーの挙動）
    // ==========================================
    // 鍵盤を押している間は減衰を邪魔せず(Sustain=1.0)、離した瞬間(noteOff)に0.15秒でミュート
    masterEnv = new ADSR(1.0f, 0.001f, 0.8f, 0.4f, 0.09f);
    mixer.patch(masterEnv); 
    
    //float f0 = Frequency.ofMidiNote(midiNote).asHz();
    float normVel = pow(constrain(velocity, 0, 127) / 127.0f, 0.9f);
    float volFactor = masterVol * 0.022f; 
    
    //volFactor *= (0.5 + (midiNote/254.0f));  // 必要かどうか検討 --> 不要
    
    // ==========================================
    // 2. LUTデータの取得とインハーモニシティ設定
    // ==========================================
    // 強弱に応じた倍音構成（音色レシピ）を取得
    float[][] profile = utils.GetDynamicProfile(midiNote, velocity, "Piano", 21, 1.0);
    
    // 【修正の核心1】実測ピークデータから、今回のループ回数を動的に確定させる！
    numHarmonics = (byte)profile.length;
    //if (numHarmonics > 30) numHarmonics = 30;
    
    /*
    // インハーモニシティ（弦の硬さによるピッチの上擦り）。高音ほどズレが大きくなる。
    float B = 0.0001f * pow(f0 / 261.6f, 1.5f); 
    B = constrain(B, 0.00002f, 0.003f);     
    */
    
    // 現在の音階のLUT配列用インデックス (A0(MIDI:21)を0とする)
    int lutIndex = constrain(round(midiNote) - 21, 0, 87);
    
    // Pythonで解析したJSONデータが欠損していないかチェック
    // ※汎用メソッド LoadLUT で読み込んだ3つのグローバル配列を使用します
    //boolean hasRawData = (pianoDecayLUT != null && pianoDecayLUT[lutIndex] != null);
    // 【修正の核心2】コンパイル警告を完全に消し去るための厳格な3軸構造チェック
    /*boolean hasRawData = false;
    if (pianoDecayLUT != null && lutIndex < pianoDecayLUT.length && pianoDecayLUT[lutIndex] != null) {
      if (pianoWobbleRateLUT != null && lutIndex < pianoWobbleRateLUT.length && pianoWobbleRateLUT[lutIndex] != null) {
        if (pianoWobbleDepthLUT != null && lutIndex < pianoWobbleDepthLUT.length && pianoWobbleDepthLUT[lutIndex] != null) {
          hasRawData = true;
        }
      }
    }*/

    // --- データ欠損時のバックアップ用（数式モデル）の事前計算 ---
    // Pythonのグラフ解析から導き出した「ピアノの物理特性の傾向」を数式化
    float mathBaseDecay = 29.0f * pow(0.9757f, midiNote);
    if (midiNote < 40) mathBaseDecay = min(mathBaseDecay, 20.0f);            // 低音の物理的限界（頭打ち）
    if (midiNote >= 89) mathBaseDecay *= map(midiNote, 89, 108, 1.0f, 3.0f); // 超高音のダンパーレス構造による伸び
    
    float mathBaseWobbleRate = map(abs(midiNote - 66.0f), 0, 45, 0.5f, 4.5f); // うなりの速さ(MIDI66を底としたU字型)
    float mathBaseDepth = map(midiNote, 21, 108, 0.03f, 0.15f);               // うなりの深さ(高音ほど深い)

    // リバーブ（共鳴）が最大音量になるまでの時間。低音はゆっくり、高音は速く立ち上がる。
    float buildUpTime = map(midiNote, 21, 108, 3.0f, 0.5f);

    // ==========================================
    // 3. 弦のモデリング（デュアル・ストリング構造）
    // ==========================================
    for (int i = 0; i < numHarmonics; i++) {
      float amp = profile[i][1] * volFactor;
      if (amp <= 0.0001f) continue; // 音量が極端に小さい倍音はCPU負荷軽減のためスキップ
      // 省エネ設計
      
      /*
      int h = i + 1;
      float inharmonicity = sqrt(1.0f + B * h * h);
      float targetFreq = f0 * h * inharmonicity; // 実際の周波数
      */
      
      float targetFreq = profile[i][0]; // 実測された上擦り済みの正確な周波数
      if (targetFreq > 22050.0f) continue; // 人間の可聴域を超えたらスキップ
      
      float decayTime, wobbleRate, wobbleDepth;
      
      // 実測データ(JSON)があれば使い、なければ数式で補完する「ハイブリッド方式」
      //if (hasRawData && i < pianoDecayLUT[lutIndex].length && pianoDecayLUT[lutIndex][i] > 0.1f) {
      // 実測データ(JSON)の適用と数式補完
      if (pianoDecayLUT != null && pianoWobbleRateLUT != null && pianoWobbleDepthLUT != null && 
          i < pianoDecayLUT[lutIndex].length) {
        decayTime = pianoDecayLUT[lutIndex][i];
        wobbleRate = pianoWobbleRateLUT[lutIndex][i];
        wobbleDepth = pianoWobbleDepthLUT[lutIndex][i];
        
        // もしデータが0、または異常値だった場合は数式モデルで安全に保護する
        if (decayTime <= 0.1f) {
          float harmonicDecayCurve = (i <= 14) ? map(i, 0, 14, 1.0f, 0.3f) : map(i, 14, 80, 0.3f, 1.5f);
          decayTime = max(mathBaseDecay * harmonicDecayCurve, 0.1f);
        }
      } else {
        // データがない場合は、インデックス14を底とする減衰のU字カーブを適用
        float harmonicDecayCurve = (i <= 14) ? map(i, 0, 14, 1.0f, 0.3f) : map(i, 14, 80, 0.3f, 1.5f);
        decayTime = max(mathBaseDecay * harmonicDecayCurve, 0.1f);
        wobbleRate = mathBaseWobbleRate * (1.0f + i * 0.02f); 
        wobbleDepth = mathBaseDepth * pow(0.9f, i);
      }
      
      decayTime *= 0.7;
      
      // ----------------------------------------
      // レイヤーA：アタックの芯（Dry弦）
      // ----------------------------------------
      Oscil coreOsc = new Oscil(targetFreq, amp, Waves.SINE);
      // アタックのインパクトを最大化するため、位相(波のスタート位置)は0付近に固定
      coreOsc.setPhase(random(0.0f, 0.1f)); 
      
      // 0.001秒で素早く立ち上がり、それぞれの寿命(decayTime)で消えていく
      Damp coreDamp = new Damp(0.001f, decayTime);
      coreOsc.patch(coreDamp).patch(mixer);
      damps.add(coreDamp);
      
      // ----------------------------------------
      // レイヤーB：時間差で来る響き（共鳴弦）
      // ----------------------------------------
      float reverbAmp = amp * wobbleDepth; // 共鳴の音量は、芯の音の数%〜十数%程度に抑える
      
      // うなりのスピード(wobbleRate)が設定されており、かつ音量が十分ある場合のみ共鳴弦を生成
      if (reverbAmp > 0.0001f && wobbleRate > 0.0f) {
        // 周波数をわずかにズラす（Detune）ことで、芯の弦と干渉して自然な「うなり(Beat)」を生む
        Oscil resOsc = new Oscil(targetFreq + wobbleRate, reverbAmp, Waves.SINE);
        //resOsc.setPhase(random(1.0f)); // 芯の弦と複雑に干渉させるため、位相は完全にランダム
        
        // アタックタイムを buildUpTime に設定し、数秒かけてゆっくり音量を上げる
        Damp resDamp = new Damp(buildUpTime, decayTime);
        resOsc.patch(resDamp).patch(mixer);
        damps.add(resDamp);
      }
    }
    
    // ==========================================
    // 4. ハンマーの打撃ノイズ（アタック）
    // ==========================================
    float hammerVol = masterVol * 0.003f * normVel; 
    Noise hammerNoise = new Noise(hammerVol, Noise.Tint.WHITE);
    
    // 高音の鍵盤ほど、硬い「カチッ」としたノイズになるようにフィルターを調整
    float hammerCutoff = map(midiNote, 21, 108, 600f, 4000f);
    MoogFilter hammerFilter = new MoogFilter(hammerCutoff, 0.1f);
    hammerFilter.type = MoogFilter.Type.LP; 
    
    // 0.03秒で消滅する、極めてタイトなエンベロープ（ミュートの影響を受けない）
    hammerEnv = new ADSR(1.0f, 0.001f, 0.02f, 0.0f, 0.01f);
    
    hammerNoise.patch(hammerFilter).patch(hammerEnv);
  }
  
  // ==========================================
  // 発音と停止のコントロール
  // ==========================================
  void noteOn(float dur) {
    masterEnv.noteOn();
    hammerEnv.noteOn();
    
    // 準備した芯の弦と共鳴弦のDamp（エンベロープ）を一斉にスタート
    for (Damp d : damps) {
      d.activate(); 
    }
    
    masterEnv.patch(longOut); 
    hammerEnv.patch(longOut); // ハンマーノイズは独立して出力
  }
  
  void noteOff() {
    masterEnv.noteOff(); // ここでダンパーペダルが降りてミュート開始
    hammerEnv.noteOff(); 
    masterEnv.unpatchAfterRelease(longOut); 
    hammerEnv.unpatchAfterRelease(longOut);
  }
}
