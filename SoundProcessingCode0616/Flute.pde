// ==========================================
// トリル専用 LFOウェーブテーブル（台形波）の生成と保持
// ==========================================
Wavetable trillWave = CreateTrapezoidWave();

// 台形波（角の丸いパルス波）を生成して返す関数
Wavetable CreateTrapezoidWave() {
  int waveSize = 1024; // 波形の解像度
  float[] waveData = new float[waveSize];
  
  // 傾斜（スロープ）の幅を設定。
  // 全体の何%を「移動時間」に使うか。例えば 0.15 なら 15% がスロープ、85%が平らな部分になる。
  float slopeRatio = 0.5f;
  // この数値を 0.05（より矩形波に近い、素早い指の動き）や 0.3（もったりとしたゆっくりな指の動き）に変更することで
  // トリルの「ニュアンス（奏者の癖）」までプログラミングできるようになる。
  
  for (int i = 0; i < waveSize; i++) {
    float phase = (float)i / waveSize; // 1周期を -1.0 〜 +1.0 の間で描く
    
    if (phase < 0.5f) { // 前半（高い音に向かう部分）
      float localPhase = phase / 0.5f; // 0.0 〜 1.0 に正規化
      if (localPhase < slopeRatio) {
        // 立ち上がりのスロープ（-1.0 から +1.0 へ滑らかに移動）
        // smoothstep関数(3x^2 - 2x^3)を使って、S字カーブを描いてより滑らかにする
        float t = localPhase / slopeRatio;
        waveData[i] = -1.0f + 2.0f * (3*t*t - 2*t*t*t); // smoothstep
      } else {
        // 平らな部分（高い音を維持）
        waveData[i] = 1.0f;
      }
    
    } else {
      // 後半（低い音に戻る部分）
      float localPhase = (phase - 0.5f) / 0.5f; // 0.0 〜 1.0 に正規化
      if (localPhase < slopeRatio) {
        // 立ち下がりのスロープ（+1.0 から -1.0 へ滑らかに移動）
        float t = localPhase / slopeRatio;
        waveData[i] = 1.0f - 2.0f * (3*t*t - 2*t*t*t); // smoothstep
      } else {
        // 平らな部分（低い音を維持）
        waveData[i] = -1.0f;
      }
    }
  }
  
  return new Wavetable(waveData);
}












class FluteInstrument implements Instrument {
  byte numHarmonics/* = 15*/;
  
  ADSR masterEnv;
  ADSR[] harmonicEnvs/* = new ADSR[numHarmonics]*/;
  
  Line[] wobbleLines;    // 6/12【追加】倍音ウナリ（AM）用のフェードライン
  float[] wobbleFactors; // 6/12【追加】倍音ごとの固有ウナリ比率の保持用
  
  Line[] ampLines/* = new Line[numHarmonics]*/;
  float[] startAmps/* = new float[numHarmonics]*/;
  float[] endAmps/* = new float[numHarmonics]*/;
  
  ADSR breathEnv;
  
  
  // ==========================================
  // 【新規追加】 持続する空気の渦と管の共鳴（サブハーモニクス層）
  // ==========================================
  ADSR sustainEnv;
  
  // 【追加】持続ノイズの音量変化（クレッシェンド/デクレッシェンド）用
  Line sustainAmpLine;
  Line sustainWobbleLine; // 6/12【追加】持続ノイズのウナリ用のフェードライン
  float startSustainVol;
  float endSustainVol;
  
  
  
  FluteInstrument(float midiNote, float startVel, float endVel, float masterVol) {
    Summer mixer = new Summer();
    
    // 【修正】masterEnv の一番最後の引数（リリース時間）を 0.3f から 0.4f に延ばす。
    // 内部の音が 0.3秒 かけて完全に消え去るのを待ってから、安全にアンパッチさせるための余裕（バッファ）です。
    // 【修正】masterEnv のリリース時間を、希望のフェードアウト時間（例：0.35秒）に設定
    masterEnv = new ADSR(1.0f, 0.01f, 0.0f, 1.0f, 0.2f);
    
    mixer.patch(masterEnv);
    
    // ==========================================
    // 【新規】トリル判定と実音の計算
    // ==========================================
    boolean isTrill = midiNote >= 128;
    float actualMidiNote = isTrill ? midiNote - 128 : midiNote;
    
    // 実音の周波数と、トリル先（全音上＝+2）の周波数
    //float f0 = Frequency.ofMidiNote(actualMidiNote).asHz();
    //float f0_trill = Frequency.ofMidiNote(actualMidiNote + 1).asHz(); // 半音トリルにしたい場合は +1 にする

    // LUTの倍音プロファイル
    // 10倍音、最低音59、LUT配列、フルートのパワー(1.4f)
    //float[][] startProfile = utils.GetDynamicProfile( actualMidiNote, startVel, "Flute", 59, 1.3f);
    //float[][] endProfile   = utils.GetDynamicProfile( actualMidiNote, endVel, "Flute", 59, 1.3f);
    
    //float volFactor = masterVol * 0.11f; 
    
    
    //numHarmonics = (byte)startProfile.length;
    // 【重要：NPE解決策】実際のデータ数に合わせて、動的に配列のメモリを確保する！
    //harmonicEnvs = new ADSR[numHarmonics];
    //ampLines     = new Line[numHarmonics];
    //startAmps    = new float[numHarmonics];
    //endAmps      = new float[numHarmonics];
    
    
    // 変更6/12
    // 1. 倍音レシピを安全に取り出すための基準ベロシティ（0除算・ロード不全の防止）
    float profileVel = (startVel > 0) ? startVel : endVel;
    if (profileVel <= 0) profileVel = 64.0f; // どちらも0の場合のセーフティ
    
    // 2. 開始・終了のゲインファクターをフルートの特性（0.7乗カーブ）に基づいて独立計算
    float startGainFactor = pow(startVel / profileVel, 0.9f);
    float endGainFactor   = pow(endVel / profileVel, 0.9f);
    
    // 安全にロードされた基準プロファイルを取得
    float[][] startProfile = utils.GetDynamicProfile(actualMidiNote, profileVel, "Flute", 59, 1.3f);
    
    float volFactor = masterVol * 0.013f;
    
    numHarmonics = (byte)startProfile.length;
    
    harmonicEnvs  = new ADSR[numHarmonics];
    ampLines      = new Line[numHarmonics];
    wobbleLines   = new Line[numHarmonics];    // 初期化を追加
    wobbleFactors = new float[numHarmonics];   // 初期化を追加
    startAmps     = new float[numHarmonics];
    endAmps       = new float[numHarmonics];
    
    
    
    
    //float fundamentalFreq = 440.0 * pow(2.0, (actualMidiNote - 69) / 12.0);
    byte baseWaveNum = 0;
    for (byte i = 1; i < numHarmonics; i++) {
      if (startProfile[i-1][0] < startProfile[i][0]) baseWaveNum = i;
    }
    
    
    // ==========================================
    // 【新規】倍音ごとの自然な振幅揺らぎ（変動率ベース）
    // ==========================================
    // Pythonで解析した変動率(%)を参考に、基音の振幅に対して何倍の揺れ(±)を許容するかを設定。
    // 実測データの変動率(%)から数式 [ Variation / 500 ] によって導出された、
    // 倍音ごとの自然な振幅揺らぎ（AM変調）の深度設定。
    float[] wobbleDepths = {0.1250f, 0.1616f, 0.2078f, 0.2340f, 0.2114f, 0.2742f, 0.3716f, 0.2946f, 0.7420f, 0.8796f, 
                            0.7850f, 0.5070f, 0.6242f, 0.7654f, 0.6702f, 0.3898f, 0.8850f, 0.5942f, 0.3152f, 0.5030f};
    
    // ==========================================
    // 【新規】この音符全体の「呼吸のスピード」を決定
    // forループの外で1つだけ定義し、全倍音で共有することで相殺を防ぐ
    // ==========================================
    float globalBreathSpeed = random(4.5f, 5.5f); // 生楽器の自然なビブラート周期
    
    
    


    // 1. 加算合成パート（7つのサイン波）
    for (int i = 0; i < numHarmonics; i++) {
      /*
      int h = i + 1;
      // あなたがPythonで導き出した厳密なインハーモニシティ公式を適用
      float B = 0.0005f; // インハーモニシティ係数
      float inharmonicity = sqrt(1.0f + B * h * h);
      float targetFreq = f0 * h * inharmonicity;
      */
      float targetFreq = startProfile[i][0];
      
      Oscil osc = new Oscil(targetFreq, 0.0f, Waves.SINE);
      
      // 【追加】初期位相を 0.0 〜 1.0 (0度〜360度) の間で完全にランダムに散らす
      // これにより「カチッ」とした機械的なアタック音が消え、音割れ（ピーク）も防げる
      osc.setPhase(random(1.0f));
      
      
      //startAmps[i] = startProfile[i][1] * volFactor;
      //endAmps[i] = endProfile[i] * volFactor;
        // 聴覚特性（0.7乗）に完全同期させた、開始時から終了時への音量変化比率を算出
        //float velRatio = pow(endVel / (startVel + 0.0001f), 0.7f);
      // 【確定修正】すでにvolFactorが掛けられたstartAmpsに対して、正しいべき乗比率を乗算する
      //endAmps[i]   = startAmps[i] * pow(endVel / (startVel + 0.0001f), 0.7f);
      
      // 6/12追加
      // 独立した開始・終了音量を厳密に算出
      float baseAmp = startProfile[i][1] * volFactor;
      startAmps[i] = baseAmp * startGainFactor;
      endAmps[i]   = baseAmp * endGainFactor;
      
      
      // ==========================================
      // 【修正】LFOをトリルとビブラートで分岐
      // ==========================================
      if (isTrill) {
        // トリル時の上限周波数
        //float trillFreq = f0_trill * (i+1) * inharmonicity;
        float trillFreq = targetFreq * pow(2.0f, 1.0f/12.0f);
        
        // 矩形波LFOの中心を2つの音の真ん中に置き、振幅を「差の半分」にする
        float centerFreq = (targetFreq + trillFreq) / 2.0f;
        float ampFreq = abs(trillFreq - targetFreq) / 2.0f;
        
        // 7.5Hzのスピードで生成したグローバル変数 trillWave を使って瞬間的に音を切り替える
        Oscil freqController = new Oscil(6.5f, ampFreq, trillWave);
        freqController.offset.setLastValue(centerFreq);
        
        // トリル時のみ、オシレーターの周波数にLFOを接続する
        freqController.patch(osc.frequency);
        
        wobbleLines[i] = null;   // トリル時はAM不要のため安全ガード
        wobbleFactors[i] = 0.0f;
        
      } else {
        // 通常のビブラート（サイン波）
        
        // ==========================================
        // ① 極小のピッチ揺れ (FM変調) の復活
        // 以前の0.0132fを「0.003f」に激減させ、音痴にならない程度の「空気の揺らぎ」を作る
        // ==========================================
        float vibDepthHz = targetFreq * 0.005f; 
        Oscil freqController = new Oscil(globalBreathSpeed, vibDepthHz, Waves.SINE);
        freqController.offset.setLastValue(targetFreq); 
        freqController.patch(osc.frequency);
        
        // ==========================================
        // ② 呼吸に同期した音量揺らぎ (AM変調)
        // ==========================================
        // この倍音の基準音量に対して、配列で設定した割合だけ揺らす
        //float wobbleAmp = startAmps[i] * wobbleDepths[i]; 
        //float wobbleAmp = startAmps[i] * random(0.1f, 0.3f);
        
        // 1.5Hz 〜 3.5Hz の間で、倍音ごとにランダムなスピードで揺らす
        // 【修正】ランダムではなく、統一された globalBreathSpeed を使う！
        //Oscil ampLFO = new Oscil(globalBreathSpeed, wobbleAmp, Waves.SINE);
        
        // 位相（スタート位置）は少しだけバラけさせると、音が立体的になります
        //ampLFO.setPhase(random(1.0f)); 
        
        // ampLFOを osc.amplitude にパッチ(追加)する。
        // Minimでは複数のUGenを同じ入力にパッチすると「加算(Sum)」されるため、
        // ampLines の基準値に対して、ampLFO が ±wobbleAmp の揺れを足し引きしてくれます。
        //ampLFO.patch(osc.amplitude);
        
        // --- 音量揺らぎ（AM変調）のフェード構造化 ---
        wobbleFactors[i] = random(0.1f, 0.3f); 
        wobbleFactors[i] = wobbleDepths[i]; 
        wobbleLines[i] = new Line();
        Oscil ampLFO = new Oscil(globalBreathSpeed, 0.0f, Waves.SINE); // 初期振幅は0
        ampLFO.setPhase(random(1.0f)); 
        
        wobbleLines[i].patch(ampLFO.amplitude); // 新設LineをLFOの振幅へ接続
        ampLFO.patch(osc.amplitude);
      }
      
      ampLines[i] = new Line();
      ampLines[i].patch(osc.amplitude); 
      
      float attackTime = (i == baseWaveNum) ? 0.058f : 0.395f; 
      
      // 【修正】内部のサイン波のリリースを 0.3f から 10.0f（10秒）にして、急激な角を作らせない
      harmonicEnvs[i] = new ADSR(1.0f, attackTime/3, 1.0f, 0.7f, 10.0f);
      osc.patch(harmonicEnvs[i]);
      harmonicEnvs[i].patch(mixer);
    }
    
    
    // ==========================================
    // 2. 息のノイズ（Chiff）パートの実測値アップデート
    // =========================================
    // 0.0〜1.0 のベロシティ割合を計算（ノイズの音量調整用）
    float startNorm = constrain(startVel, 0, 127) / 127.0f;
    
    // 中低音の破裂音（ドスッという音）になるため、少しだけ音量を上げます（0.01f -> 0.02f）
    float attackNoiseVol = masterVol * 0.02f * startNorm; 
    Noise breathNoise = new Noise(attackNoiseVol, Noise.Tint.WHITE);
    
    // 【修正】ハイパス(HP)からバンドパス(BP)に変更。
    // 3500Hz付近の「シュッ」という音だけを残し、耳障りな高音を削る。
    // 【修正】実測データに基づき、3500Hzから 581.4Hz に変更！
    // 473Hzの山も一緒に拾うため、レゾナンスを 0.3 から 0.15 に下げて帯域を広げる
    MoogFilter breathFilter = new MoogFilter(581.4f, 0.15f);
    breathFilter.type = MoogFilter.Type.BP;
    
    breathEnv = new ADSR(1.0f, 0.01f, 0.08f, 0.0f, 0.0f);
    
    breathNoise.patch(breathFilter);
    breathFilter.patch(breathEnv);
    breathEnv.patch(mixer);
    
    
    // ==========================================
    // 3. 【新規追加】持続する空気の渦と管の共鳴（サブハーモニクス層）
    // ==========================================
    float endNorm = constrain(endVel, 0, 127) / 127.0f; // 【追加】終了時のベロシティ割合
    
    // 【修正】開始時と終了時のノイズ音量を計算して保持する
    startSustainVol = masterVol * 0.01f * startNorm;
    endSustainVol   = masterVol * 0.01f * endNorm;
    
    // ピンクノイズで低音の「フオォォ」という空気感を出す
    // 【修正】Noiseの初期音量は0.0fにし、音量制御はLineに任せる
    Noise sustainNoise = new Noise(0.0f, Noise.Tint.PINK);
    
    // 【追加】持続ノイズのボリュームつまみにLineを接続
    sustainAmpLine = new Line();
    sustainAmpLine.patch(sustainNoise.amplitude);
    
    // ==========================================
    // 【新規】持続ノイズ自体にも「息の乱れ」を適用する
    // サイン波の第1倍音と同等のスピードと深さでノイズを揺らす
    // ==========================================
    //float noiseWobbleAmp = startSustainVol * 0.20f; // 20%揺らす
    //Oscil sustainWobble = new Oscil(random(1.5f, 3.0f), noiseWobbleAmp, Waves.SINE);
    //sustainWobble.setPhase(random(1.0f));
    //sustainWobble.patch(sustainNoise.amplitude); // Lineの音量にLFOの揺れを加算
    // ==========================================
    
    // 6/12変更
    // --- 持続ノイズの息の乱れも完全にフェードさせる ---
    sustainWobbleLine = new Line();
    Oscil sustainWobble = new Oscil(random(1.5f, 3.0f), 0.0f, Waves.SINE); // 初期振幅は0
    sustainWobble.setPhase(random(1.0f));
    
    sustainWobbleLine.patch(sustainWobble.amplitude); // 新設LineをノイズLFOの振幅へ接続
    sustainWobble.patch(sustainNoise.amplitude);      // LFO出力をノイズ振幅へ（加算）
    
    // ローパスフィルターで高音を削りつつ、2500Hz付近に共鳴(レゾナンス0.5)の山を作る
    MoogFilter sustainFilter = new MoogFilter(2500f, 0.5f);
    sustainFilter.type = MoogFilter.Type.LP;
    
    // 音が鳴っている間ずっと持続するエンベロープ（サイン波のアタックに合わせる）
    // 【修正】持続ノイズのリリースも 0.3f から 10.0f（10秒）にする
    sustainEnv = new ADSR(1.0f, 0.058f, 0.0f, 1.0f, 10.0f);
    
    sustainNoise.patch(sustainFilter);
    sustainFilter.patch(sustainEnv);
    sustainEnv.patch(mixer);
  }
  
  
  /*
  void noteOn(float dur) {
    masterEnv.noteOn();
    
    // ====================================================
    // 【修正】Lineの寿命に、リリース時間（0.4秒）分の猶予を足す！
    // これにより、減衰中もLineが生き残り、オシレーターの音量が突然0.0fにリセットされるのを防ぐ
    // ====================================================
    // 【微調整】masterEnvのリリース時間(0.35f)より少し長ければOK
    float safeDur = dur + 0.5f;
    
    for(int i=0; i<numHarmonics; i++) {
      harmonicEnvs[i].noteOn();
      ampLines[i].activate(safeDur, startAmps[i], endAmps[i]);
    }
    
    breathEnv.noteOn();
    sustainEnv.noteOn(); // 【追加】持続ノイズをオン
    sustainAmpLine.activate(safeDur, startSustainVol, endSustainVol); // 【追加】発音と同時に、持続ノイズの音量変化をスタートさせる
    
    masterEnv.patch(out); 
  }*/
  // 6/12変更
  void noteOn(float dur) {
    masterEnv.noteOn();
    float safeDur = dur + 0.5f;
    
    for(int i = 0; i < numHarmonics; i++) {
      harmonicEnvs[i].noteOn();
      
      // 1. 各倍音のベース音量をフェード
      ampLines[i].activate(safeDur, startAmps[i], endAmps[i]);
      
      // 2. 通常ビブラート時のみ、ウナリ（AM）の深さも比例フェードさせる
      if (wobbleLines[i] != null) {
        float factor = wobbleFactors[i];
        wobbleLines[i].activate(safeDur, startAmps[i] * factor, endAmps[i] * factor);
      }
    }
    
    breathEnv.noteOn();
    sustainEnv.noteOn(); 
    
    // 3. 持続ノイズの全体音量と、そのウナリの深さを同時に追従フェード
    sustainAmpLine.activate(safeDur, startSustainVol, endSustainVol); 
    sustainWobbleLine.activate(safeDur, startSustainVol * 0.20f, endSustainVol * 0.20f); 
    
    masterEnv.patch(mediumOut); 
  }
  
  
  
  void noteOff() {
    masterEnv.noteOff();
    for(int i=0; i<numHarmonics; i++) harmonicEnvs[i].noteOff();
    
    // 【削除】breathEnv は既に無音なので noteOff を呼ばない（空撃ちグリッチ防止）
    // breathEnv.noteOff();
    
    sustainEnv.noteOff(); // 【追加】持続ノイズをオフ
    masterEnv.unpatchAfterRelease(mediumOut); 
  }
}
