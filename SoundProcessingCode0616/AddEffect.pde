/*import ddf.minim.AudioEffect;

// 講義の「たたみ込み積分」をそのまま再現した自作エフェクトクラス
class SimpleConvolutionEffect implements AudioEffect {
  float[] impulseResponse; // h(τ) に相当するインパルス応答データ
  float[] historyBuffer;   // 過去の音を記憶しておくバッファ
  int bufferIndex = 0;
  int kernelSize;          // ★過去の音をどれくらい参照するか（サンプル数）

  SimpleConvolutionEffect(int size, float levrl) {
    this.kernelSize = size;
    impulseResponse = new float[kernelSize];
    historyBuffer = new float[kernelSize];
    
    // 簡易的なインパルス応答を自動生成（指数関数的に減衰するノイズ ＝ 擬似的な部屋の響き）
    for (int i = 0; i < kernelSize; i++) {
      float decay = exp(-3.8f * i / kernelSize); // 過去にいくほど音が小さくなる重み
      impulseResponse[i] = random(-1.0f, 1.0f) * decay * levrl; // 響きの強さを調整
    }
  }

  // モノラル信号（現在のシステム）にリアルタイムでたたみ込み演算を行う関数
  void process(float[] signal) {
    for (int i = 0; i < signal.length; i++) {
      float input = signal[i];
      
      // 1. 最新の入力を過去の記憶バッファに格納
      historyBuffer[bufferIndex] = input;
      
      // 2. たたみ込み積分の計算（スライドの数式の再現）
      float output = 0;
      for (int j = 0; j < kernelSize; j++) {
        // 過去へ遡るインデックスを計算
        int idx = (bufferIndex - j + kernelSize) % kernelSize;
        output += historyBuffer[idx] * impulseResponse[j];
      }
      
      // 3. 元のクリーンな音に、生成された反響音を混ぜて出力
      signal[i] = input + output;
      
      // 4. 記憶バッファの書き込み位置を1つ進める
      bufferIndex = (bufferIndex + 1) % kernelSize;
    }
  }

  // ステレオ用（Minimの仕様上必要ですが、中身はモノラル処理を両チャンネルに適用）
  void process(float[] left, float[] right) {
    process(left);
    process(right);
  }
}

*/





/*
// Minimの最新推奨規格「UGen」に従って生まれ変わった反響音クラス
class SimpleConvolutionUGen extends UGen {
  // 前のミキサー（stringsBus）から流れてくる音声信号を受け取るための「ポート（入り口）」
  public UGenInput audio;
  
  float[] impulseResponse; // h(τ) に相当するインパルス応答データ
  float[] historyBuffer;   // 過去の音を記憶しておくバッファ
  int bufferIndex = 0;
  int kernelSize;          // 過去の音をどれくらい参照するか（サンプル数）

  SimpleConvolutionUGen(int size, float level) {
    // 入力ポートを初期化
    audio = new UGenInput(InputType.AUDIO);
    
    this.kernelSize = size;
    impulseResponse = new float[kernelSize];
    historyBuffer = new float[kernelSize];
    
    // 簡易的なインパルス応答を自動生成（指数関数的に減衰する部屋の響き）
    for (int i = 0; i < kernelSize; i++) {
      float decay = exp(-3.8f * i / kernelSize);
      impulseResponse[i] = random(-1.0f, 1.0f) * decay * level;
    }
  }

  // UGenの心臓部：Minimが音声を1サンプル処理するたびに自動で呼び出される関数
  protected void uGenerate(float[] channels) {
    // 1. 直前のミキサー（stringsBus）から流れてきた「現在の入力音」を1サンプル取得
    float input = audio.getLastValue();
    
    // 2. 最新の入力を過去の記憶バッファに格納
    historyBuffer[bufferIndex] = input;
    
    // 3. たたみ込み積分の計算（講義スライドの数式の完全再現）
    float output = 0;
    for (int j = 0; j < kernelSize; j++) {
      int idx = (bufferIndex - j + kernelSize) % kernelSize;
      output += historyBuffer[idx] * impulseResponse[j];
    }
    
    // 4. 記憶バッファの書き込み位置を1つ進める
    bufferIndex = (bufferIndex + 1) % kernelSize;
    
    // 5. 元の音に反響音を足し合わせる
    float finalOutput = input + output;
    
    // 6. 出力先へ音を流し込む（ループにすることでモノラル・ステレオどちらにも自動対応！）
    for (int i = 0; i < channels.length; i++) {
      channels[i] = finalOutput;
    }
  }
}*/






// Minimの最新推奨規格「UGen」に従って生まれ変わった反響音クラス（完全ステレオ対応版）
class SimpleConvolutionUGen extends UGen {
  public UGenInput audio;
  
  float[] impulseResponse;
  
  // ★改造ポイント1：記憶バッファを左右の耳で完全に独立させる
  float[] historyBufferL;
  float[] historyBufferR;
  
  // UGenの uGenerate は1サンプルフレーム（左右同時）ごとに呼ばれるため、時間は共通（1つ）でOK
  int bufferIndex = 0;
  int kernelSize;

  SimpleConvolutionUGen(int size, float level) {
    audio = new UGenInput(InputType.AUDIO);
    this.kernelSize = size;
    
    impulseResponse = new float[kernelSize];
    historyBufferL = new float[kernelSize];
    historyBufferR = new float[kernelSize];
    
    // インパルス応答の生成
    for (int i = 0; i < kernelSize; i++) {
      float decay = exp(-3.8f * i / kernelSize);
      impulseResponse[i] = random(-1.0f, 1.0f) * decay * level;
    }
  }

  // UGenの心臓部
  protected void uGenerate(float[] channels) {
    // ★改造ポイント2：入力音を「配列」として取得し、左右の音を別々に取り出す
    float[] inputs = audio.getLastValues();
    float inL = inputs[0]; 
    // もし入力がモノラル（1ch）だった場合は、右耳用にも左と同じ音を入れるセーフティガード
    float inR = (inputs.length > 1) ? inputs[1] : inL;
    
    // 最新の入力を左右それぞれの記憶バッファに格納
    historyBufferL[bufferIndex] = inL;
    historyBufferR[bufferIndex] = inR;
    
    // ★改造ポイント3：たたみ込み積分の計算を、左右独立して行う
    float outL = 0;
    float outR = 0;
    for (int j = 0; j < kernelSize; j++) {
      int idx = (bufferIndex - j + kernelSize) % kernelSize;
      outL += historyBufferL[idx] * impulseResponse[j];
      outR += historyBufferR[idx] * impulseResponse[j];
    }
    
    // 記憶バッファの書き込み位置を1つ進める（左右共通の時間が進む）
    bufferIndex = (bufferIndex + 1) % kernelSize;
    
    // ★改造ポイント4：出力先（channels）がモノラルかステレオかで安全に音を振り分ける
    if (channels.length == 1) {
      // 出力先がモノラルの場合
      channels[0] = inL + outL;
    } else if (channels.length >= 2) {
      // 出力先がステレオの場合
      channels[0] = inL + outL; // 左チャンネルの出力
      channels[1] = inR + outR; // 右チャンネルの出力
    }
  }
}
