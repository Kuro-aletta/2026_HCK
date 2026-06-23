class DataUtils {
  private float[][] note;
  
  private float[][][] fluteFFLUT, fluteMFLUT, flutePPLUT;
  
  private float[][][] violinFFLUT, violinMFLUT, violinPPLUT;
  private float[][][] violaFFLUT,  violaMFLUT,  violaPPLUT;
  private float[][][] celloFFLUT,  celloMFLUT,  celloPPLUT;
  private float[][][] bassFFLUT,   bassMFLUT,   bassPPLUT;
  
  private float[][][] pianoFFLUT, pianoMFLUT, pianoPPLUT;
  private float[][] pianoDecayFFLUT, pianoWobbleRateFFLUT, pianoWobbleDepthFFLUT;
  private float[][] pianoDecayMFLUT, pianoWobbleRateMFLUT, pianoWobbleDepthMFLUT;
  private float[][] pianoDecayPPLUT, pianoWobbleRatePPLUT, pianoWobbleDepthPPLUT;
  
  private float[][] kickLUT, snareLUT, hihatLUT;
  
  
  DataUtils() {
    //println("Loading JSON data...");
    
    // JSONファイルからデータをロードする
    
    note = Load2LUT("かえるのうた8小節ver「酒場でブギウギ(強弱付き)」「王宮のメヌエット(強弱なし)」「トルコ行進曲」_processing.json");
    
    fluteFFLUT = Load3LUT("fluteFFLUT.json");
    fluteMFLUT = Load3LUT("fluteMFLUT.json");
    flutePPLUT = Load3LUT("flutePPLUT.json");
    
    violinFFLUT = Load3LUT("violinFFLUT.json");
    violinMFLUT = Load3LUT("violinMFLUT.json");
    violinPPLUT = Load3LUT("violinPPLUT.json");
    
    violaFFLUT = Load3LUT("violaFFLUT.json");
    violaMFLUT = Load3LUT("violaMFLUT.json");
    violaPPLUT = Load3LUT("violaPPLUT.json");
    
    celloFFLUT = Load3LUT("celloFFLUT.json");
    celloMFLUT = Load3LUT("celloMFLUT.json");
    celloPPLUT = Load3LUT("celloPPLUT.json");
    
    bassFFLUT = Load3LUT("bassFFLUT.json");
    bassMFLUT = Load3LUT("bassMFLUT.json");
    bassPPLUT = Load3LUT("bassPPLUT.json");
    
    pianoFFLUT = Load3LUT("pianoFFLUT.json");
    pianoMFLUT = Load3LUT("pianoMFLUT.json");
    pianoPPLUT = Load3LUT("pianoPPLUT.json");
    pianoDecayFFLUT = Load2LUT("pianoDecaysFF.json");
    pianoWobbleRateMFLUT = Load2LUT("pianoWobbleRatesFF.json");
    pianoWobbleDepthPPLUT = Load2LUT("pianoWobbleDepthsFF.json");
    
    // ドラムのLUTをロード
    kickLUT  = Load2LUT("kickLUT.json");
    snareLUT = Load2LUT("snareLUT.json");
    hihatLUT = Load2LUT("hihatLUT.json");
    
    //println("Data loaded successfully!");
  }
  
  
  // JSONファイルを読み込んで float[][] 配列に変換する便利関数
  float[][] Load2LUT(String fileName) {
    JSONArray jsonArray = loadJSONArray(fileName);
    float[][] lut = new float[jsonArray.size()][];
    
    for (int i = 0; i < jsonArray.size(); i++) {
      JSONArray row = jsonArray.getJSONArray(i);
      if (row.size() > 0) {
        lut[i] = new float[row.size()];
        for (int j = 0; j < row.size(); j++) {
          lut[i][j] = row.getFloat(j);
        }
      } else {
        lut[i] = null; // データが欠損している部分は null にする（今までの仕様通り）
      }
    }
    return lut;
  }
  
  
  // JSONファイルを読み込んで float[][][] の3次元可変長配列に変換する関数
  float[][][] Load3LUT(String fileName) {
    JSONArray jsonArray = loadJSONArray(fileName);
    // 第1次元（音程の数）を確定
    float[][][] lut = new float[jsonArray.size()][][];
    
    for (int i = 0; i < jsonArray.size(); i++) {
      // JSON上で null になっている、または要素が欠損している場合の処理
      if (jsonArray.isNull(i)) {
        lut[i] = null; // 今までの仕様通り、存在しない音程は null にする
        continue;
      }
      
      JSONArray peaksArray = jsonArray.getJSONArray(i);
      int numPeaks = peaksArray.size();
      
      if (numPeaks > 0) {
        // 第2次元（その音程が持つピークの数）を動的に確定
        lut[i] = new float[numPeaks][2]; 
        
        for (int j = 0; j < numPeaks; j++) {
          JSONArray peakPair = peaksArray.getJSONArray(j);
          
          // [周波数, 振幅] のペア（要素数2）を確実に取得
          if (peakPair.size() == 2) {
            lut[i][j][0] = peakPair.getFloat(0); // 周波数 (Hz)
            lut[i][j][1] = peakPair.getFloat(1); // 相対振幅 (0.0 ~ 1.0)
          }
        }
      } else {
        lut[i] = null; // ピーク数が0個の場合もデータなしとして null を代入
      }
    }
    return lut;
  }
  
  
  
  // ① 汎用版：特定のLUTから、指定したピッチの倍音レシピを安全に取り出す関数
  /*
  float[] GetProfileForPitch(float pitch, float[][] lut, int numHarmonics, int baseMidiNote) {
    
    float[] result = new float[numHarmonics];
    
    // LUTの要素数から自動的に最高音を算出して安全にクランプする
    float maxMidiNote = baseMidiNote + lut.length - 1;
    float clampedPitch = constrain(pitch, baseMidiNote, maxMidiNote);
    
    int baseIndexLower = floor(clampedPitch) - baseMidiNote;
    int baseIndexUpper = ceil(clampedPitch) - baseMidiNote;
    
    // 下に向かって一番近い有効データを探す
    int lowerIndex = baseIndexLower;
    while (lowerIndex >= 0 && lut[lowerIndex] == null) { lowerIndex--; }
    
    // 上に向かって一番近い有効データを探す
    int upperIndex = baseIndexUpper;
    while (upperIndex < lut.length && lut[upperIndex] == null) { upperIndex++; }
    
    
    // ==============================================
    // 限界値のセーフティーネット
    // ==============================================
    // 上に有効データが一つも無かったら、下のデータを採用する（最高音の延長）
    if (upperIndex >= lut.length) upperIndex = lowerIndex;
    
    // 下に有効データが一つも無かったら、上のデータを採用する（最低音の延長）
    if (lowerIndex < 0) lowerIndex = upperIndex; 
    
    if (lowerIndex < 0 && upperIndex >= lut.length) {
      // どちらにもデータが無い場合のフォールバック（基音のみ1.0）
      float[] fallback = new float[numHarmonics];
      fallback[0] = 1.0f;
      return fallback;
    }
    
    float lowerMidi = lowerIndex + baseMidiNote;
    float upperMidi = upperIndex + baseMidiNote;
    
    float[] lowerProfile = lut[lowerIndex];
    float[] upperProfile = lut[upperIndex];
    
    float t = 0;
    if (upperMidi > lowerMidi) {
      t = (clampedPitch - lowerMidi) / (upperMidi - lowerMidi);
    }
    
    for (int i = 0; i < numHarmonics; i++) {
      result[i] = lerp(lowerProfile[i], upperProfile[i], t);
    }
    
    return result;
  }
  */
  
  /*
  // ① 刷新版：特定の3次元LUTから、指定したピッチに「最も近い有効データ」を生のまま取り出す関数
  // 戻り値：float[ピーク数][2] -> [h][0]:周波数(Hz), [h][1]:振幅
  float[][] GetProfileForPitch(float pitch, float[][][] lut, int baseMidiNote) {
    
    // LUTの要素数から自動的に最高音を算出して安全にクランプする
    float maxMidiNote = baseMidiNote + lut.length - 1;
    float clampedPitch = constrain(pitch, baseMidiNote, maxMidiNote);
    
    // 四捨五入(round)で、最もピッチが近いサンプルのインデックスを狙う
    int targetIndex = round(clampedPitch) - baseMidiNote;
    targetIndex = constrain(targetIndex, 0, lut.length - 1);
    
    // もし狙ったインデックスがnull（データ欠損）の場合、最も近い「有効なデータ」を探索する
    int finalIndex = targetIndex;
    if (lut[finalIndex] == null) {
      int lowerIndex = finalIndex;
      while (lowerIndex >= 0 && lut[lowerIndex] == null) { lowerIndex--; }
      
      int upperIndex = finalIndex;
      while (upperIndex < lut.length && lut[upperIndex] == null) { upperIndex++; }
      
      // 上下のうち、存在する方、あるいはより近い方を採用する
      if (lowerIndex >= 0 && upperIndex < lut.length) {
        if ((finalIndex - lowerIndex) <= (upperIndex - finalIndex)) {
          finalIndex = lowerIndex;
        } else {
          finalIndex = upperIndex;
        }
      } else if (lowerIndex >= 0) {
        finalIndex = lowerIndex;
      } else if (upperIndex < lut.length) {
        finalIndex = upperIndex;
      } else {
        // 万が一、LUT全体が空っぽだった場合の完全フォールバック（MIDIピッチから計算した基音のみ生成）
        float f0 = 440.0f * pow(2.0f, (clampedPitch - 69.0f) / 12.0f);
        float[][] fallback = new float[1][2];
        fallback[0][0] = f0;   // 周波数
        fallback[0][1] = 1.0f; // 振幅
        return fallback;
      }
    }
    
    // 見つかった有効なサンプルのデータをディープコピーして返す（参照渡しによるデータ破壊を防ぐため）
    float[][] sourceProfile = lut[finalIndex];
    int numPeaks = sourceProfile.length;
    float[][] result = new float[numPeaks][2];
    
    for (int h = 0; h < numPeaks; h++) {
      result[h][0] = sourceProfile[h][0]; // 周波数 (Hz)
      result[h][1] = sourceProfile[h][1]; // 振幅
    }
    
    return result;
  }
  */
  
  
  // ① 確定修正版：特定の3次元LUTから、指定したピッチに「最も近い有効データ」を取り出し、正確なピッチへシフトして返す関数
  // 戻り値：float[ピーク数][2] -> [h][0]:周波数(Hz), [h][1]:振幅
  float[][] GetProfileForPitch(float pitch, float[][][] lut, int baseMidiNote) {
    
    // 【バグ解決の核心1】ユーザーが要求した本来のピッチ（小数ビブラートや範囲外のC3/A7など）を完全に生のまま保持
    float originalPitch = pitch;
    
    // LUTの要素数から自動的に最高音を算出し、インデックス探索用のみ安全にクランプする
    float maxMidiNote = baseMidiNote + lut.length - 1;
    float searchPitch = constrain(pitch, baseMidiNote, maxMidiNote);
    
    // 四捨五入(round)で、最もピッチが近いサンプルのインデックスを狙う
    int targetIndex = round(searchPitch) - baseMidiNote;
    targetIndex = constrain(targetIndex, 0, lut.length - 1);
    
    // もし狙ったインデックスがnull（データ欠損）の場合、最も近い「有効なデータ」を探索する
    int finalIndex = targetIndex;
    println(finalIndex);
    if (lut[finalIndex] == null) {
      int lowerIndex = finalIndex;
      while (lowerIndex >= 0 && lut[lowerIndex] == null) { lowerIndex--; }
      
      int upperIndex = finalIndex;
      while (upperIndex < lut.length && lut[upperIndex] == null) { upperIndex++; }
      
      // 上下のうち、存在する方、あるいは要求された元のピッチ（searchPitch）により近い方を採用する
      if (lowerIndex >= 0 && upperIndex < lut.length) {
        if (abs(searchPitch - (lowerIndex + baseMidiNote)) <= abs((upperIndex + baseMidiNote) - searchPitch)) {
          finalIndex = lowerIndex;
        } else {
          finalIndex = upperIndex;
        }
      } else if (lowerIndex >= 0) {
        finalIndex = lowerIndex;
      } else if (upperIndex < lut.length) {
        finalIndex = upperIndex;
      } else {
        // 万が一、LUT全体が空っぽだった場合の完全フォールバック（MIDIピッチから計算した基音のみ生成）
        float f0 = 440.0f * pow(2.0f, (originalPitch - 69.0f) / 12.0f);
        float[][] fallback = new float[1][2];
        fallback[0][0] = f0;   // 周波数
        fallback[0][1] = 1.0f; // 振幅
        return fallback;
      }
    }
    
    // 見つかったサンプルのデータを取得
    float[][] sourceProfile = lut[finalIndex];
    int numPeaks = sourceProfile.length;
    float[][] result = new float[numPeaks][2];
    
    // =================================================================
    // 【バグ解決の核心2：流用元ピッチからの絶対距離によるシフト計算】
    // =================================================================
    // 流用元のサンプルが本来持っている「正しい基準MIDIノート番号」を逆算
    float sourceMidi = finalIndex + baseMidiNote;
    
    // 制限のない本来の要求ピッチ（originalPitch）と、流用元（sourceMidi）のガチの差分（半音単位）を計算。
    // これにより、範囲外のC3を弾いた時（例：48 - 59 = -11半音）でも正確なスケーリング係数が算出されます！
    float pitchShiftFactor = pow(2.0f, (originalPitch - sourceMidi) / 12.0f);
    // =================================================================
    
    for (int h = 0; h < numPeaks; h++) {
      // 元のデータが持っている「実測の生の周波数構造」に対して、計算した倍率を掛け算する
      // これにより、インハーモニシティのデコボコを100%維持したまま、滑らかにピッチがスケーリングされます
      result[h][0] = sourceProfile[h][0] * pitchShiftFactor; 
      result[h][1] = sourceProfile[h][1]; // 振幅はそのままコピー
    }
    
    return result;
  }
  
  
  
  
  
  // ② 汎用版：ピッチとベロシティの2軸から、最終的な倍音レシピを生成する関数
  /*
  float[] GetDynamicProfile(float pitch, float velocity, String type, int numHarmonics, int baseMidiNote, float basePower) {
    float[] profile = new float[numHarmonics];
    
    // 3つのLUTから、現在のピッチに応じた倍音構成をそれぞれ取得
    float[] profileFF, profilePP, profileMF;
    
    switch (type)
    {
    case "Flute":
      profilePP = GetProfileForPitch(pitch, flutePPLUT, numHarmonics, baseMidiNote);
      profileMF = GetProfileForPitch(pitch, fluteMFLUT, numHarmonics, baseMidiNote);
      profileFF = GetProfileForPitch(pitch, fluteFFLUT, numHarmonics, baseMidiNote);
      break;
    case "Violin":
      profilePP = GetProfileForPitch(pitch, violinPPLUT, numHarmonics, baseMidiNote);
      profileMF = GetProfileForPitch(pitch, violinMFLUT, numHarmonics, baseMidiNote);
      profileFF = GetProfileForPitch(pitch, violinFFLUT, numHarmonics, baseMidiNote);
      break;
    case "Viola":
      profilePP = GetProfileForPitch(pitch, violaPPLUT, numHarmonics, baseMidiNote);
      profileMF = GetProfileForPitch(pitch, violaMFLUT, numHarmonics, baseMidiNote);
      profileFF = GetProfileForPitch(pitch, violaFFLUT, numHarmonics, baseMidiNote);
      break;
    case "Cello":
      profilePP = GetProfileForPitch(pitch, celloPPLUT, numHarmonics, baseMidiNote);
      profileMF = GetProfileForPitch(pitch, celloMFLUT, numHarmonics, baseMidiNote);
      profileFF = GetProfileForPitch(pitch, celloFFLUT, numHarmonics, baseMidiNote);
      break;
    case "Bass":
      profilePP = GetProfileForPitch(pitch, bassPPLUT, numHarmonics, baseMidiNote);
      profileMF = GetProfileForPitch(pitch, bassMFLUT, numHarmonics, baseMidiNote);
      profileFF = GetProfileForPitch(pitch, bassFFLUT, numHarmonics, baseMidiNote);
      break;
    case "Piano":
      profilePP = GetProfileForPitch(pitch, pianoPPLUT, numHarmonics, baseMidiNote);
      profileMF = GetProfileForPitch(pitch, pianoMFLUT, numHarmonics, baseMidiNote);
      profileFF = GetProfileForPitch(pitch, pianoFFLUT, numHarmonics, baseMidiNote);
      break;
    default:
      println("Error: LUT type '" + type + "'が見つかりません!! ピアノを適用しました。");
      profilePP = GetProfileForPitch(pitch, pianoPPLUT, numHarmonics, baseMidiNote);
      profileMF = GetProfileForPitch(pitch, pianoMFLUT, numHarmonics, baseMidiNote);
      profileFF = GetProfileForPitch(pitch, pianoFFLUT, numHarmonics, baseMidiNote);
      break;
    }
    
    // ベロシティ(0〜127)を0.0〜1.0に正規化
    float normVel = constrain(velocity, 0, 127) / 127.0f;
    
    // ユーザー定義のベロシティ閾値
    float threshPP = 32.0f / 127.0f;
    float threshMF = 80.0f / 127.0f;
    float threshFF = 112.0f / 127.0f;
    
    for (int i = 0; i < numHarmonics; i++) {
      if (normVel <= threshPP) {
        // 0〜32 (無音〜pp) の間は、波形の形はppのまま固定（音量だけが小さくなる）
        profile[i] = profilePP[i];
        
      } else if (normVel <= threshMF) {
        // 32〜80 (pp〜mf) の間を補間
        float t = map(normVel, threshPP, threshMF, 0.0f, 1.0f);
        profile[i] = lerp(profilePP[i], profileMF[i], t);
        
      } else if (normVel <= threshFF) {
        // 80〜112 (mf〜ff) の間を補間
        float t = map(normVel, threshMF, threshFF, 0.0f, 1.0f);
        profile[i] = lerp(profileMF[i], profileFF[i], t);
        
      } else {
        // 112〜127 (ff〜fff) の間は、波形の形はffのまま固定（音量は最大へ向かう）
        profile[i] = profileFF[i];
      }
    }
    
    // 合計値に対する割合（シェア）による音量算出
    float totalSum = 0;
    for (int i = 0; i < numHarmonics; i++) {
      totalSum += profile[i]; 
    }
    
    // ベロシティに応じた「目標の全体音量（パイの大きさ）」を決定する
    // 音量(0.0)の場合はここでtargetVolumeが0になり、完全に無音になります
    float targetVolume = basePower * pow(normVel, 0.7f);
    
    // 各倍音の割合(シェア)を計算し、目標音量を掛け合わせる
    for (int i = 0; i < numHarmonics; i++) {
      // profile[i] / totalSum が「割合(0.0〜1.0)」。そこにtargetVolumeを掛ける。
      // +0.0001f は、ゼロ除算（0で割ってエラーになること）を防ぐためのおまじないです。
      profile[i] = (profile[i] / (totalSum + 0.0001f)) * targetVolume; 
    }
    
    return profile;
  }
  */
  
  
  // ② 刷新版：ピッチとベロシティの2軸から、最終的な「周波数と音量のペア」の2次元配列を生成する関数
  // 戻り値：float[ピーク数][2] -> [h][0]:周波数(Hz), [h][1]:最終音量
  float[][] GetDynamicProfile(float pitch, float velocity, String type, int baseMidiNote, float basePower) {
    
    // 3つの3次元LUTから、現在のピッチに最も近い実測スペクトルをそれぞれ取得
    float[][] profilePP, profileMF, profileFF;
    
    switch (type) {
      case "Flute":
        profilePP = GetProfileForPitch(pitch, flutePPLUT, baseMidiNote);
        profileMF = GetProfileForPitch(pitch, fluteMFLUT, baseMidiNote);
        profileFF = GetProfileForPitch(pitch, fluteFFLUT, baseMidiNote);
        break;
      case "Violin":
        profilePP = GetProfileForPitch(pitch, violinPPLUT, baseMidiNote);
        profileMF = GetProfileForPitch(pitch, violinMFLUT, baseMidiNote);
        profileFF = GetProfileForPitch(pitch, violinFFLUT, baseMidiNote);
        break;
      case "Viola":
        profilePP = GetProfileForPitch(pitch, violaPPLUT, baseMidiNote);
        profileMF = GetProfileForPitch(pitch, violaMFLUT, baseMidiNote);
        profileFF = GetProfileForPitch(pitch, violaFFLUT, baseMidiNote);
        break;
      case "Cello":
        profilePP = GetProfileForPitch(pitch, celloPPLUT, baseMidiNote);
        profileMF = GetProfileForPitch(pitch, celloMFLUT, baseMidiNote);
        profileFF = GetProfileForPitch(pitch, celloFFLUT, baseMidiNote);
        break;
      case "Bass":
        profilePP = GetProfileForPitch(pitch, bassPPLUT, baseMidiNote);
        profileMF = GetProfileForPitch(pitch, bassMFLUT, baseMidiNote);
        profileFF = GetProfileForPitch(pitch, bassFFLUT, baseMidiNote);
        break;
      case "Piano":
        profilePP = GetProfileForPitch(pitch, pianoPPLUT, baseMidiNote);
        profileMF = GetProfileForPitch(pitch, pianoMFLUT, baseMidiNote);
        profileFF = GetProfileForPitch(pitch, pianoFFLUT, baseMidiNote);
        break;
      default:
        println("Error: LUT type '" + type + "'が見つかりません!! ピアノを適用しました。");
        profilePP = GetProfileForPitch(pitch, pianoPPLUT, baseMidiNote);
        profileMF = GetProfileForPitch(pitch, pianoMFLUT, baseMidiNote);
        profileFF = GetProfileForPitch(pitch, pianoFFLUT, baseMidiNote);
        break;
    }
    
    // ベロシティ(0〜127)を0.0〜1.0に正規化
    float normVel = constrain(velocity, 0, 127) / 127.0f;
    
    // ユーザー定義のベロシティ閾値
    float thresholdPP = 32.0f / 127.0f;
    float thresholdMF = 80.0f / 127.0f;
    float thresholdFF = 112.0f / 127.0f;
    
    // 現在のベロシティ層に応じて、ベースとなる波形プロファイル（周波数・振幅の骨組み）を決定
    float[][] baseProfile;
    float t = 0;
    //boolean needInterpolation = false;
    //float[][] lowerProfile = null;
    //float[][] upperProfile = null;
    
    if (normVel <= thresholdPP) {
      baseProfile = profilePP;
    } else if (normVel <= thresholdMF) {
      // pp ～ mf の間：構造が近い方のスペクトル形状を選択（あるいは、より高度に処理するためのフラグ設定）
      t = map(normVel, thresholdPP, thresholdMF, 0.0f, 1.0f);
      baseProfile = (t < 0.5f) ? profilePP : profileMF;
    } else if (normVel <= thresholdFF) {
      // mf ～ ff の間
      t = map(normVel, thresholdMF, thresholdFF, 0.0f, 1.0f);
      baseProfile = (t < 0.5f) ? profileMF : profileFF;
    } else {
      baseProfile = profileFF;
    }
    
    //if (normVel >= thresholdFF) baseProfile = profileFF;
    //else if (normVel >= thresholdMF) baseProfile = profileMF;
    //else baseProfile = profilePP;
    
    // 決定した形状ベース（baseProfile）を元に、最終出力用の2次元配列を確保
    int numPeaks = baseProfile.length;
    float[][] finalProfile = new float[numPeaks][2];
    
    
    // 周波数は選択したベースサンプルの値を100%そのまま継承（濁りを防ぐ）
    //float totalSum = 0;
    for (int h = 0; h < numPeaks; h++) {
      finalProfile[h][0] = baseProfile[h][0]; // 周波数 (Hz) 固定
      finalProfile[h][1] = baseProfile[h][1]; // 振幅の初期値
      //totalSum += finalProfile[h][1];
    }
    
    
    // ベロシティに応じた「目標の全体音量（エネルギーの総量）」の計算
    float targetVolume = basePower * pow(normVel, 1.1f);
    
    // 全体のエネルギー配分（シェア）を計算し、各ピークに最終音量を割り当てる
    /*for (int h = 0; h < numPeaks; h++) {
      //finalProfile[h][1] = (finalProfile[h][1] / (totalSum + 0.0001f)) * targetVolume;
      finalProfile[h][1] = finalProfile[h][1] * targetVolume;
    }*/
    
    float energy = 0;
    for(int h = 0; h < numPeaks; h++){
      energy += baseProfile[h][1] * baseProfile[h][1];
    }
    float gain = targetVolume / sqrt(energy + 1e-9f);
    
    for (int h = 0; h < numPeaks; h++) {
      /*float freq = baseProfile[h][0]; // 周波数 (Hz)
      
      // --- 低音ブーストの計算 ---
      // 例：200Hz以下を緩やかに持ち上げるカーブ（ローシェルフ風）
      float bassBoost = 1.0f;
      if (freq < 400.0f) {
          // 400Hz未満なら、低い周波数ほど最大1.5倍までゲインを上げる
          // (400 - freq) / 400 で 0.0〜1.0 のブレンド率を作り、0.5fを掛ける
          bassBoost += ( (400.0f - freq) / 400.0f ) * 0.1f; 
      }*/
      
      // 最終的なゲインを適用
      finalProfile[h][1] = baseProfile[h][1] * gain;
      //finalProfile[h][1] *= bassBoost;
    }
    
    return finalProfile;
  }
  
  
  
  
  
  float[][] GetLUT(String type) {
    switch (type) {
      case "Note":
        return note;
      
      case "PianoDecayFF":
        return pianoDecayFFLUT;
      case "PianoWobbleRateFF":
        return pianoWobbleRateFFLUT;
      case "PianoWobbleDepthFF":
        return pianoWobbleDepthFFLUT;
        
      case "PianoDecayMF":
        return pianoDecayMFLUT;
      case "PianoWobbleRateMF":
        return pianoWobbleRateMFLUT;
      case "PianoWobbleDepthMF":
        return pianoWobbleDepthMFLUT;
        
      case "PianoDecayPP":
        return pianoDecayPPLUT;
      case "PianoWobbleRatePP":
        return pianoWobbleRatePPLUT;
      case "PianoWobbleDepthPP":
        return pianoWobbleDepthPPLUT;
        
      case "Kick":
        return kickLUT;
      case "Snare":
        return snareLUT;
      case "HiHat":
        return hihatLUT;
        
      default:
        println("Error: LUT type '" + type + "'が見つかりません!!");
        return null; // 存在しない名前が指定された場合は null を返す
    }
  }
}





// --- 周波数を対数スケールのX座標に変換する関数 ---
float FreqToX(float f) {
  float minFreq = 20.0f;
  float maxFreq = 20000.0f;
  
  // 範囲外の値を制限する
  if (f < minFreq) f = minFreq;
  if (f > maxFreq) f = maxFreq;
  
  // log() を使って対数スケールにマッピングする
  return map(log(f), log(minFreq), log(maxFreq), 0, width);
};
