import java.util.Arrays;
import java.util.Comparator;

// ==========================================
// 究極のストリングス・インストゥルメント (ビブラート数式モデル実装版)
// ==========================================
class StringsInstrument implements Instrument {
  //byte numHarmonics = 30;
  //Summer mixer;
  ADSR masterEnv; 
  //ADSR[] harmonicEnvs = new ADSR[numHarmonics];
  
  /*
  Line[] ampLines = new Line[numHarmonics];
  float[] startAmps = new float[numHarmonics];
  float[] endAmps = new float[numHarmonics];
  
  // ビブラートの深さをコントロールするためのLine
  Line[] vibDepthLines = new Line[numHarmonics];
  float[] targetVibDepths = new float[numHarmonics]; // 各倍音の最終的な揺れ幅(Hz)を保存
  */
  
  // クラス上部のメンバー変数宣言部分の修正
  byte MAX_TOTAL_OSCILS = 40; // クロスフェード時に2つの楽器が混ざるため、多めに確保
  Oscil[] oscils = new Oscil[MAX_TOTAL_OSCILS];
  Line[] ampLines = new Line[MAX_TOTAL_OSCILS];
  Line[] vibDepthLines = new Line[MAX_TOTAL_OSCILS];
  
  float[] startAmps = new float[MAX_TOTAL_OSCILS];
  float[] endAmps = new float[MAX_TOTAL_OSCILS];
  float[] targetVibDepths = new float[MAX_TOTAL_OSCILS];
  
  byte totalActiveOscils = 0; // 今回の音で実際に生成されたオシレーターの総数
  
  //Noise biteNoise;
  //MoogFilter biteFilter;
  ADSR biteEnv;
  ADSR hissEnv;
  
  //Noise hissNoise;
  //MoogFilter hissFilter;
  Line hissAmpLine;
  //Oscil hissWobble;
  float startHissVol, endHissVol;
  
  StringsInstrument(float midiNote, float startVel, float endVel, float masterVol) {
    Summer mixer = new Summer();
    masterEnv = new ADSR(1.0f, 0.04f, 0.5f, 0.9f, 0.15f);
    mixer.patch(masterEnv); 
    
    //float f0 = Frequency.ofMidiNote(midiNote).asHz();
    float volFactor = masterVol * 0.12f; 
    
    float startNorm = constrain(startVel, 0, 127) / 127.0f;
    float endNorm   = constrain(endVel, 0, 127) / 127.0f;
    
    
    // =========================================================
    // 【データ分析から導いた数式①】ビブラートスピード
    // 低音(G3=55)はゆっくり、高音(E7=100)は速く。さらに人間らしいランダムな揺らぎを付加。
    // =========================================================
    float baseVibSpeed = map(midiNote, 48, 100, 5.2f, 6.5f);
    float globalVibSpeed = baseVibSpeed + random(-0.2f, 0.2f);
    
    // =========================================================
    // 【データ分析から導いた数式②】ビブラートの深さ（Cents）
    // 低音は浅く(±10cents)、高音は深く(±25cents)揺れる。異常な暴走はここでカットされる。
    // =========================================================
    float fmDepthCents = map(midiNote, 48, 100, 10.0f, 25.0f)*1.7;
    
    
    /*
    // =========================================================
    // 【クロスフェード処理】オーケストラ・ストリングスの4Wayブレンド
    // =========================================================
    
    // コントラバス：最低音 C1 (MIDI 24)
    float[][] bassStart   = utils.GetDynamicProfile(midiNote, startVel, "Bass", 24, 0.9f);
    float[][] bassEnd     = utils.GetDynamicProfile(midiNote, endVel, "Bass", 24, 0.9f);

    // チェロ：最低音 C2 (MIDI 36)
    float[][] celloStart  = utils.GetDynamicProfile(midiNote, startVel, "Cello", 36, 0.9f);
    float[][] celloEnd    = utils.GetDynamicProfile(midiNote, endVel, "Cello", 36, 0.9f);
    
    // ビオラ：最低音 C3 (MIDI 48)
    float[][] violaStart  = utils.GetDynamicProfile(midiNote, startVel, "Viola", 48, 0.9f);
    float[][] violaEnd    = utils.GetDynamicProfile(midiNote, endVel, "Viola", 48, 0.9f);
    
    // バイオリン：最低音 G3 (MIDI 55)
    float[][] violinStart = utils.GetDynamicProfile(midiNote, startVel, "Violin", 55, 0.9f);
    float[][] violinEnd   = utils.GetDynamicProfile(midiNote, endVel, "Violin", 55, 0.9f);
    
    float[] startProfile = new float[numHarmonics];
    float[] endProfile = new float[numHarmonics];
    
    // ---------------------------------------------------------
    // ベースとなるブレンド割合の計算 (合計が必ず1.0になるように分配)
    // ---------------------------------------------------------
    float baseBassRatio = 0.0f;
    float baseCelloRatio = 0.0f;
    float baseViolaRatio = 0.0f;
    float baseViolinRatio = 0.0f;
    
    if (midiNote <= 36) {
      // C2(36) 以下はコントラバスの独壇場
      baseBassRatio = 1.0f;
    } else if (midiNote <= 48) {
      // C2(36) 〜 C3(48) : コントラバスからチェロへ滑らかにクロスフェード
      baseBassRatio = map(midiNote, 36, 48, 1.0f, 0.0f);
      baseCelloRatio = 1.0f - baseBassRatio;
    } else if (midiNote <= 60) {
      // C3(48) 〜 C4(60) : チェロからビオラへ滑らかにクロスフェード
      baseCelloRatio = map(midiNote, 48, 60, 1.0f, 0.0f);
      baseViolaRatio = 1.0f - baseCelloRatio;
    } else if (midiNote <= 72) {
      // C4(60) 〜 C5(d) : ビオラからバイオリンへ滑らかにクロスフェード
      baseViolaRatio = map(midiNote, 60, 72, 1.0f, 0.0f);
      baseViolinRatio = 1.0f - baseViolaRatio;
    } else {
      // C5(72) 以上はバイオリンの独壇場
      baseViolinRatio = 1.0f;
    }
    
    float bassBlendStart = baseBassRatio, bassBlendEnd = baseBassRatio;
    float celloBlendStart = baseCelloRatio, celloBlendEnd = baseCelloRatio;
    float violaBlendStart = baseViolaRatio, violaBlendEnd = baseViolaRatio;
    float violinBlendStart = baseViolinRatio, violinBlendEnd = baseViolinRatio;
    
    // ---------------------------------------------------------
    // 【特例パッチ】 D6(86) と D#6/Eb6(87) の波形破綻への対応
    // mf(80)まではバイオリン本来の音色。そこからff(112)に向かってビオラを混ぜる
    // ---------------------------------------------------------
    if (midiNote == 86 || midiNote == 87) {
      float threshMF = 80.0f / 127.0f;
      float threshFF = 112.0f / 127.0f;
      
      if (startNorm > threshMF) {
        float clampedStart = constrain(startNorm, threshMF, threshFF);
        violinBlendStart = map(clampedStart, threshMF, threshFF, 1.0f, 0.3f);
        violaBlendStart = 1.0f - violinBlendStart;
      }
      if (endNorm > threshMF) {
        float clampedEnd = constrain(endNorm, threshMF, threshFF);
        violinBlendEnd = map(clampedEnd, threshMF, threshFF, 1.0f, 0.3f);
        violaBlendEnd = 1.0f - violinBlendEnd;
      }
      
      bassBlendStart = 0.0f; bassBlendEnd = 0.0f;
      celloBlendStart = 0.0f; celloBlendEnd = 0.0f;
    }
    // ---------------------------------------------------------
    
    // 4つの楽器のプロファイルを、計算した割合で混ぜ合わせる
    for (int i = 0; i < numHarmonics; i++) {
      startProfile[i] = (bassStart[i] * bassBlendStart) + (celloStart[i] * celloBlendStart) + (violaStart[i] * violaBlendStart) + (violinStart[i] * violinBlendStart);
      endProfile[i]   = (bassEnd[i]   * bassBlendEnd)   + (celloEnd[i]   * celloBlendEnd)   + (violaEnd[i]   * violaBlendEnd)   + (violinEnd[i]   * violinBlendEnd);
    }
    // =========================================================
    
    
    
    // ==================================================
    // 【インハーモニシティ係数(B)の動的計算セクション】
    // ==================================================
    
    // 1. 各楽器の基準B係数（解析結果の中央値から設定）
    float bBassBase   = 0.000070f;
    float bCelloBase  = 0.000065f;
    float bViolaBase  = 0.000055f;
    float bViolinBase = 0.000052f;
    
    // 2. 各楽器の基準となる開放弦周波数（正規化用）
    float fRefBass   = 32.7f;  // C1相当
    float fRefCello  = 65.4f;  // C2相当
    float fRefViola  = 130.8f; // C3相当
    float fRefViolin = 196.0f; // G3相当
    
    // 3. 現在の楽器ブレンド状態に合わせた「基準B」と「基準周波数」を算出
    float blendedBBase = (bBassBase * baseBassRatio) + (bCelloBase * baseCelloRatio) 
                       + (bViolaBase * baseViolaRatio) + (bViolinBase * baseViolinRatio);
                       
    float blendedFRef  = (fRefBass * baseBassRatio) + (fRefCello * baseCelloRatio) 
                       + (fRefViola * baseViolaRatio) + (fRefViolin * baseViolinRatio);
    
    // 4. 【核心】ピッチの2乗に比例してBを増幅させる（ハイポジション効果の再現）
    // あなたの観察通り、C5(523Hz)において約0.00006になるようスケーリングされます
    float B = blendedBBase * pow(f0 / blendedFRef, 2.0f);
    
    // 異常値ガード（物理的に破綻しない範囲に制限）
    B = constrain(B, 0.00001f, 0.0005f);
    
    // ==================================================
    
    
    
    for (int i = 0; i < numHarmonics; i++) {
      int h = i + 1;
      // 動的に計算された B を適用
      float inharmonicity = sqrt(1.0f + B * h * h);
      float targetFreq = f0 * h * inharmonicity; 
      
      // 【改善】アンチエイリアス (20000Hz超えの倍音は、生成処理自体をストップしてCPUを節約)
      if (targetFreq > 22050.0f) {
        continue; // ここでループを抜け、これ以上高い倍音は作らない
      }
      
      float finalStartAmp = startProfile[i] * volFactor;
      float finalEndAmp = endProfile[i] * volFactor;
      
      // アンチエイリアス (20000Hz超えの強制ミュート)
      //if (targetFreq > 20000.0f) {
      //  finalStartAmp = 0.0f;
      //  finalEndAmp = 0.0f;
      //}
      
      Oscil osc = new Oscil(targetFreq, 0.0f, Waves.SINE);
      osc.setPhase(0.0f); // ストリングスの核（エッジ）
      
      // =========================================================
      // ピッチ揺れ (Delayed FM変調) の準備
      // セント(Cents)を周波数(Hz)の揺れ幅に変換して配列に保存しておく
      // =========================================================
      float vibDepthRatio = pow(2.0f, fmDepthCents / 1200.0f) - 1.0f;
      targetVibDepths[i] = targetFreq * vibDepthRatio; 
      
      // 揺れの深さをコントロールするLFO（最初は振幅0でスタート）
      Oscil freqController = new Oscil(globalVibSpeed, 0.0f, Waves.SINE);
      freqController.offset.setLastValue(targetFreq); 
      freqController.patch(osc.frequency);
      
      // ビブラートの深さを0から目標値へ変化させるLine
      vibDepthLines[i] = new Line();
      vibDepthLines[i].patch(freqController.amplitude);
      
      // =========================================================
      // 音量揺らぎ (AM変調) の適用
      // 高次倍音ほど激しく揺れる（15%〜60%）
      // =========================================================
      startAmps[i] = finalStartAmp;
      endAmps[i] = finalEndAmp;
      
      float wobbleDepth = map(i, 0, numHarmonics - 1, 0.15f, 0.60f);
      float wobbleAmp = startAmps[i] * wobbleDepth; 
      
      Oscil ampLFO = new Oscil(globalVibSpeed, wobbleAmp, Waves.SINE);
      ampLFO.setPhase(random(1.0f)); 
      ampLFO.patch(osc.amplitude);
      
      ampLines[i] = new Line();
      ampLines[i].patch(osc.amplitude); 
      
      //harmonicEnvs[i] = new ADSR(1.0f, 0.2f, 0.0f, 1.0f, 0.3f);
      //osc.patch(harmonicEnvs[i]);
      //harmonicEnvs[i].patch(mixer);
      
      // 【修正1】harmonicEnvsを削除し、純粋にミキサーへ送る
      osc.patch(mixer);
    }
    */
    
    // =========================================================
    // 【クロスフェード処理】オーケストラ・ストリングスの4Wayブレンド
    // =========================================================
    // 1. 各楽器のブレンド割合の計算 (合計が必ず1.0になるように分配)
    float baseBassRatio = 0.0f;
    float baseCelloRatio = 0.0f;
    float baseViolaRatio = 0.0f;
    float baseViolinRatio = 0.0f;
    
    if (midiNote <= 36) {
      baseBassRatio = 1.0f;
    } else if (midiNote <= 48) {
      baseBassRatio = map(midiNote, 36, 48, 1.0f, 0.0f);
      baseCelloRatio = 1.0f - baseBassRatio;
    } else if (midiNote <= 60) {
      baseCelloRatio = map(midiNote, 48, 60, 1.0f, 0.0f);
      baseViolaRatio = 1.0f - baseCelloRatio;
    } else if (midiNote <= 72) {
      baseViolaRatio = map(midiNote, 60, 72, 1.0f, 0.0f);
      baseViolinRatio = 1.0f - baseViolaRatio;
    } else {
      baseViolinRatio = 1.0f;
    }
    
    float bassBlend = baseBassRatio;
    float celloBlend = baseCelloRatio;
    float violaBlend = baseViolaRatio;
    float violinBlend = baseViolinRatio;
    
    /*
    // 【特例パッチ】 D6(86) と D#6/Eb6(87) の波形破綻への対応
    if (midiNote == 86 || midiNote == 87) {
      float threshMF = 80.0f / 127.0f;
      float threshFF = 112.0f / 127.0f;
      if (startNorm > threshMF) {
        violinBlend = map(constrain(startNorm, threshMF, threshFF), threshMF, threshFF, 1.0f, 0.0f);
        violaBlend = 1.0f - violinBlend;
      }
      bassBlend = 0.0f; celloBlend = 0.0f;
    }
    */
    
    
    /*
    // ---------------------------------------------------------
    // 2. 新設計：各楽器のプロファイルを「必要な分だけ」動的にオシレーター化して配置
    // ---------------------------------------------------------
    totalActiveOscils = 0; // カウンターリセット
    
    // ループ処理を共通化するための構造化（内部用の一時クラスや処理の連続実行）
    // 比率が 0.0 より大きい楽器だけを狙い撃ちしてオシレーターを生成する（安全装置・負荷対策）
    
    if (bassBlend > 0.0f) {
      float[][] pStart = utils.GetDynamicProfile(midiNote, startVel, "Bass", 24, 0.9f);
      createInstrumentOscillators(pStart, bassBlend, volFactor, globalVibSpeed, fmDepthCents, mixer);
    }
    if (celloBlend > 0.0f) {
      float[][] pStart = utils.GetDynamicProfile(midiNote, startVel, "Cello", 36, 0.9f);
      createInstrumentOscillators(pStart, celloBlend, volFactor, globalVibSpeed, fmDepthCents, mixer);
    }
    if (violaBlend > 0.0f) {
      float[][] pStart = utils.GetDynamicProfile(midiNote, startVel, "Viola", 48, 0.9f);
      createInstrumentOscillators(pStart, violaBlend, volFactor, globalVibSpeed, fmDepthCents, mixer);
    }
    if (violinBlend > 0.0f) {
      float[][] pStart = utils.GetDynamicProfile(midiNote, startVel, "Violin", 55, 0.9f);
      createInstrumentOscillators(pStart, violinBlend, volFactor, globalVibSpeed, fmDepthCents, mixer);
    }
    */
    // ---------------------------------------------------------
    // 2. 改修版：各楽器のプロファイルを「動的な上限数」でオシレーター化
    // ---------------------------------------------------------
    // --- コンストラクタ下部：各楽器呼び出しの直前に追加 ---
    float velRatio = pow(endVel / (startVel + 0.0001f), 0.7f);
    
    totalActiveOscils = 0; // カウンターリセット
    
    if (bassBlend > 0.0f) {
      float[][] pStart = utils.GetDynamicProfile(midiNote, startVel, "Bass", 24, 0.9f);
      // ユーザー様提案のルール：1.0未満（ブレンド時）なら20、単一なら30を上限とする
      int maxPeaks = (bassBlend < 1.0f) ? 20 : 30;
      createInstrumentOscillators(pStart, bassBlend, maxPeaks, volFactor, globalVibSpeed, fmDepthCents, mixer, velRatio);
    }
    
    if (celloBlend > 0.0f) {
      float[][] pStart = utils.GetDynamicProfile(midiNote, startVel, "Cello", 36, 0.9f);
      int maxPeaks = (celloBlend < 1.0f) ? 20 : 30;
      createInstrumentOscillators(pStart, celloBlend, maxPeaks, volFactor, globalVibSpeed, fmDepthCents, mixer, velRatio);
    }
    
    if (violaBlend > 0.0f) {
      float[][] pStart = utils.GetDynamicProfile(midiNote, startVel, "Viola", 48, 0.9f);
      int maxPeaks = (violaBlend < 1.0f) ? 20 : 30;
      createInstrumentOscillators(pStart, violaBlend, maxPeaks, volFactor, globalVibSpeed, fmDepthCents, mixer, velRatio);
    }
    
    if (violinBlend > 0.0f) {
      float[][] pStart = utils.GetDynamicProfile(midiNote, startVel, "Violin", 55, 0.9f);
      int maxPeaks = (violinBlend < 1.0f) ? 20 : 30;
      createInstrumentOscillators(pStart, violinBlend, maxPeaks, volFactor, globalVibSpeed, fmDepthCents, mixer, velRatio);
    }
    
    
    
    // =========================================================
    // 【データ分析から導いた数式③】 摩擦ノイズ(Bite)の動的パラメータ
    // =========================================================
    // 1. 各楽器の基準値を設定（Python解析データより）
    float biteCutoffBass   = 1150f;  float biteDecayBass   = 0.180f;
    float biteCutoffCello  = 1840f;  float biteDecayCello  = 0.093f;
    float biteCutoffViola  = 3280f;  float biteDecayViola  = 0.116f;
    float biteCutoffViolin = 3370f;  float biteDecayViolin = 0.035f;

    // 2. 現在の音階（クロスフェード割合）に合わせてパラメータをブレンド
    float blendedBiteCutoff = (biteCutoffBass * baseBassRatio) + (biteCutoffCello * baseCelloRatio) 
                            + (biteCutoffViola * baseViolaRatio) + (biteCutoffViolin * baseViolinRatio);
                            
    float blendedBiteDecay  = (biteDecayBass * baseBassRatio) + (biteDecayCello * baseCelloRatio) 
                            + (biteDecayViola * baseViolaRatio) + (biteDecayViolin * baseViolinRatio);

    // グラフの傾向（高音ほどノイズが短く・高くなる）を少し加味する微調整
    // 基音(f0)が上がるにつれて、カットオフを少し上げ、ディケイを少し短くする
    float pitchFactor = map(midiNote, 24, 84, 0.8f, 1.2f);
    float finalBiteCutoff = constrain(blendedBiteCutoff * pitchFactor, 800f, 6000f);
    float finalBiteDecay  = constrain(blendedBiteDecay / pitchFactor, 0.01f, 0.3f);


    // --- 摩擦ノイズ層（Bite）の生成 ---
    // アタックの強さ(ベロシティ)に応じてノイズ音量を変える
    float biteVol = masterVol * 0.02f * startNorm; 
    
    Noise biteNoise = new Noise(biteVol, Noise.Tint.WHITE);
    MoogFilter biteFilter = new MoogFilter(finalBiteCutoff, 0.2f); // 動的カットオフを適用
    biteFilter.type = MoogFilter.Type.LP; 
    
    // Attackは固定(超短く)、Decayに動的パラメータを適用
    biteEnv = new ADSR(1.0f, 0.01f, finalBiteDecay, 0.0f, 0.1f);
    
    biteNoise.patch(biteFilter);
    biteFilter.patch(biteEnv);
    // (biteEnvは直接outへ出すためmixerには繋がない)
    
    
    
    // --- 共鳴ノイズ層（Hiss） ---
    startHissVol = masterVol * 0.01f * startNorm;
    endHissVol   = masterVol * 0.01f * endNorm;
    
    Noise hissNoise = new Noise(0.0f, Noise.Tint.PINK);
    hissAmpLine = new Line();
    hissAmpLine.patch(hissNoise.amplitude);
    
    Oscil hissWobble = new Oscil(globalVibSpeed, startHissVol * 0.3f, Waves.SINE);
    hissWobble.setPhase(random(1.0f));
    hissWobble.patch(hissNoise.amplitude);
    
    MoogFilter hissFilter = new MoogFilter(1500f, 0.15f);
    hissFilter.type = MoogFilter.Type.HP;
    hissEnv = new ADSR(1.0f, 0.05f, 0.0f, 1.0f, 0.1f);
    
    hissNoise.patch(hissFilter);
    hissFilter.patch(hissEnv); 
    hissEnv.patch(mixer);
  }
  
  /*
  // 各楽器のピークデータをグローバルなオシレーター配列に安全に展開するヘルパー関数
  private void createInstrumentOscillators(float[][] profile, float blendRatio, float volFactor, float globalVibSpeed, float fmDepthCents, Summer mixer) {
    if (profile == null) return;
    
    byte numPeaks = (byte)profile.length;
    for (byte h = 0; h < numPeaks; h++) {
      // 安全装置：配列の上限を超えないようにガード
      if (totalActiveOscils >= MAX_TOTAL_OSCILS) break;
      
      float targetFreq = profile[h][0]; // Pythonが実測した、非整数倍音が含まれる生の周波数
      float rawAmp     = profile[h][1]; // 正規化された振幅
      
      // 20000Hz超えの超音波は生成をスキップしてCPUを徹底節約（アンチエイリアス）
      if (targetFreq > 22050.0f) continue;
      
      // 【核心】元のスペクトル振幅に、全体のボリュームと「この楽器のブレンド比率」を掛け合わせる
      float finalStartAmp = rawAmp * volFactor * blendRatio;
      float finalEndAmp   = finalStartAmp * (endHissVol / (startHissVol + 0.0001f)); // 代案2の音量比率の維持
      
      int idx = totalActiveOscils;
      startAmps[idx] = finalStartAmp;
      endAmps[idx]   = finalEndAmp;
      
      // オシレーターとエンベロープの生成
      oscils[idx] = new Oscil(targetFreq, 0.0f, Waves.SINE);
      oscils[idx].setPhase(0.0f);
      
      // ビブラート（FM変調）の適用
      float vibDepthRatio = pow(2.0f, fmDepthCents / 1200.0f) - 1.0f;
      targetVibDepths[idx] = targetFreq * vibDepthRatio;
      
      Oscil freqController = new Oscil(globalVibSpeed, 0.0f, Waves.SINE);
      freqController.offset.setLastValue(targetFreq);
      freqController.patch(oscils[idx].frequency);
      
      vibDepthLines[idx] = new Line();
      vibDepthLines[idx].patch(freqController.amplitude);
      
      // 音量揺らぎ（AM変調）の適用 (高次倍音ほど激しく揺らす特性は継承)
      float wobbleDepth = map(idx, 0, MAX_TOTAL_OSCILS - 1, 0.15f, 0.60f);
      float wobbleAmp = startAmps[idx] * wobbleDepth;
      
      Oscil ampLFO = new Oscil(globalVibSpeed, wobbleAmp, Waves.SINE);
      ampLFO.setPhase(random(1.0f));
      ampLFO.patch(oscils[idx].amplitude);
      
      ampLines[idx] = new Line();
      ampLines[idx].patch(oscils[idx].amplitude);
      
      oscils[idx].patch(mixer);
      
      totalActiveOscils++; // 生成に成功したら総数をインクリメント
    }
  }
  */
  // 各楽器のピークデータを、振幅選別フィルタを通した上で安全にオシレーター展開するヘルパー関数
  private void createInstrumentOscillators(final float[][] profile, float blendRatio, int maxPeaks, float volFactor, float globalVibSpeed, float fmDepthCents, Summer mixer, float velRatio) {
    if (profile == null || profile.length == 0) return;
    
    int rawLength = profile.length;
    // 実際に採用する山の数を決定（データ数と制限数の小さい方）
    final int limitPeaks = min(maxPeaks, rawLength);
    
    // ---------------------------------------------------------
    // 【振幅選別フィルタ】振幅が大きい順にインデックスをソートする
    // ---------------------------------------------------------
    Integer[] indices = new Integer[rawLength];
    for (int i = 0; i < rawLength; i++) indices[i] = i;
    
    Arrays.sort(indices, new Comparator<Integer>() {
      public int compare(Integer a, Integer b) {
        // 振幅[1]の降順（大きい順）で並び替え
        return Float.compare(profile[b][1], profile[a][1]);
      }
    });
    
    // 上位 N 個（limitPeaks分）だけを一度抽出し、一時配列に格納
    float[][] filteredProfile = new float[limitPeaks][2];
    for (int i = 0; i < limitPeaks; i++) {
      filteredProfile[i][0] = profile[indices[i]][0]; // 周波数
      filteredProfile[i][1] = profile[indices[i]][1]; // 振幅
    }
    
    // ---------------------------------------------------------
    // 【周波数再整列】Processing側（ビブラート計算など）の仕様に合わせ、周波数の低い順に戻す
    // ---------------------------------------------------------
    Arrays.sort(filteredProfile, new Comparator<float[]>() {
      public int compare(float[] a, float[] b) {
        // 周波数[0]の昇順（低い順）で並び替え
        return Float.compare(a[0], b[0]);
      }
    });
    
    // ---------------------------------------------------------
    // 3. 厳選されたピークデータのみをオシレーターとして生成・接続
    // ---------------------------------------------------------
    for (int h = 0; h < limitPeaks; h++) {
      if (totalActiveOscils >= MAX_TOTAL_OSCILS) break;
      
      float targetFreq = filteredProfile[h][0]; // 周波数
      float rawAmp     = filteredProfile[h][1]; // 厳選された強い振幅
      
      if (targetFreq > 22050.0f) continue;
      
      float finalStartAmp = rawAmp * volFactor * blendRatio;
      float finalEndAmp   = finalStartAmp * velRatio;
      
      int idx = totalActiveOscils;
      startAmps[idx] = finalStartAmp;
      endAmps[idx]   = finalEndAmp;
      
      // オシレーターとビブラート（LFO）、AM変調の適用（既存の高品質ロジックをそのまま継承）
      oscils[idx] = new Oscil(targetFreq, 0.0f, Waves.SINE);
      oscils[idx].setPhase(0.0f);
      
      float vibDepthRatio = pow(2.0f, fmDepthCents / 1200.0f) - 1.0f;
      targetVibDepths[idx] = targetFreq * vibDepthRatio;
      
      Oscil freqController = new Oscil(globalVibSpeed, 0.0f, Waves.SINE);
      freqController.offset.setLastValue(targetFreq);
      freqController.patch(oscils[idx].frequency);
      
      vibDepthLines[idx] = new Line();
      vibDepthLines[idx].patch(freqController.amplitude);
      
      float wobbleDepth = map(idx, 0, MAX_TOTAL_OSCILS - 1, 0.15f, 0.60f);
      float wobbleAmp = startAmps[idx] * wobbleDepth;
      
      Oscil ampLFO = new Oscil(globalVibSpeed, wobbleAmp, Waves.SINE);
      ampLFO.setPhase(random(1.0f));
      ampLFO.patch(oscils[idx].amplitude);
      
      ampLines[idx] = new Line();
      ampLines[idx].patch(oscils[idx].amplitude);
      
      oscils[idx].patch(mixer);
      
      totalActiveOscils++;
    }
  }
  
  
  void noteOn(float dur) {
    masterEnv.noteOn();
    biteEnv.noteOn(); 
    hissEnv.noteOn();
    
    float safeDur = dur + 0.7f; 
    // ビブラートが最大になるまでの時間（0.5秒、または音符の長さの短い方）
    float vibDelayTime = min(0.5f, dur); 
    
    /*
    for(int i = 0; i < numHarmonics; i++) {
      // 【修正】インスタンスが生成されていない（null）場合は、それ以上の倍音はないのでループを終了する
      if (ampLines[i] == null || vibDepthLines[i] == null) {
        continue; 
      }
      
      //harmonicEnvs[i].noteOn();
      
      ampLines[i].activate(safeDur, startAmps[i], endAmps[i]);
      // 【実行】0Hzから目標の揺れ幅(Hz)へ、vibDelayTimeかけて徐々にビブラートを深くする
      vibDepthLines[i].activate(vibDelayTime, 0.0f, targetVibDepths[i]);
    }
    */
    // noteOn 内のループ部分の修正
    for(int i = 0; i < totalActiveOscils; i++) {
      if (ampLines[i] == null || vibDepthLines[i] == null) {
        continue; 
      }
      ampLines[i].activate(safeDur, startAmps[i], endAmps[i]);
      vibDepthLines[i].activate(vibDelayTime, 0.0f, targetVibDepths[i]);
    }
    
    hissAmpLine.activate(safeDur, startHissVol, endHissVol);
    
    masterEnv.patch(out); 
    biteEnv.patch(out); 
  }
  
  void noteOff() {
    masterEnv.noteOff();
    //for(int i=0; i<numHarmonics; i++) harmonicEnvs[i].noteOff();
    biteEnv.noteOff(); 
    hissEnv.noteOff();
    masterEnv.unpatchAfterRelease(out); 
    biteEnv.unpatchAfterRelease(out);
  }
}
