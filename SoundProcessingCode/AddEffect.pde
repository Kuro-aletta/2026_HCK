import ddf.minim.AudioEffect;

// 講義の「たたみ込み積分」をそのまま再現した自作エフェクトクラス
class SimpleConvolutionEffect implements AudioEffect {
  float[] impulseResponse; // h(τ) に相当するインパルス応答データ
  float[] historyBuffer;   // 過去の音を記憶しておくバッファ
  int bufferIndex = 0;
  int kernelSize;          // ★過去の音をどれくらい参照するか（サンプル数）

  SimpleConvolutionEffect(int size) {
    this.kernelSize = size;
    impulseResponse = new float[kernelSize];
    historyBuffer = new float[kernelSize];
    
    // 簡易的なインパルス応答を自動生成（指数関数的に減衰するノイズ ＝ 擬似的な部屋の響き）
    for (int i = 0; i < kernelSize; i++) {
      float decay = exp(-3.8f * i / kernelSize); // 過去にいくほど音が小さくなる重み
      impulseResponse[i] = random(-1.0f, 1.0f) * decay * 0.1f; // 響きの強さを調整
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
